#include "frost_window_plugin.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <windowsx.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <string>
#include <variant>
#include <vector>


namespace frost_window {

namespace {
constexpr UINT_PTR kWindowSubclass = 0x46524f53;   // 'FROS'
constexpr UINT_PTR kContentSubclass = 0x46524f54;  // 'FROT'

// RtlGetVersion avoids compatibility-manifest version virtualization.
bool SupportsSystemBackdrop() {
  using GetVersion = LONG(WINAPI*)(OSVERSIONINFOW*);
  const auto get_version = reinterpret_cast<GetVersion>(
      GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
  OSVERSIONINFOW version{};
  version.dwOSVersionInfoSize = sizeof(version);
  return get_version != nullptr && get_version(&version) == 0 &&
         version.dwMajorVersion >= 10 && version.dwBuildNumber >= 22621;
}

bool SystemTransparencyEnabled() {
  HIGHCONTRASTW contrast{sizeof(HIGHCONTRASTW), 0, nullptr};
  if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
      (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0) return false;
  DWORD enabled = 1;
  DWORD bytes = sizeof(enabled);
  // Missing preference means the Windows default (enabled).
  RegGetValueW(HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"EnableTransparency", RRF_RT_REG_DWORD, nullptr, &enabled, &bytes);
  return enabled != 0;
}

double Number(const flutter::EncodableValue& value) {
  if (const auto* number = std::get_if<double>(&value)) return *number;
  if (const auto* number = std::get_if<int32_t>(&value)) return *number;
  if (const auto* number = std::get_if<int64_t>(&value)) {
    return static_cast<double>(*number);
  }
  return 0;
}

POINT CursorPosition() {
  POINT point{};
  GetCursorPos(&point);
  return point;
}

const char* ButtonName(int hit) {
  return hit == HTMAXBUTTON ? "maximize" : "";
}

HGLOBAL CopyToGlobal(const std::vector<uint8_t>& bytes) {
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes.size());
  if (memory == nullptr) return nullptr;
  void* target = GlobalLock(memory);
  if (target == nullptr) {
    GlobalFree(memory);
    return nullptr;
  }
  std::memcpy(target, bytes.data(), bytes.size());
  GlobalUnlock(memory);
  return memory;
}

constexpr uint64_t kMaxClipboardPixels = 16 * 1024 * 1024;

uint32_t BigEndian32(const uint8_t* bytes) {
  return (static_cast<uint32_t>(bytes[0]) << 24) |
         (static_cast<uint32_t>(bytes[1]) << 16) |
         (static_cast<uint32_t>(bytes[2]) << 8) | bytes[3];
}

// Accepts only a 32-bit sRGB BITMAPV5 with its matching
// 8-bit RGB(A) PNG, so a malformed payload never reaches the clipboard.
bool ValidClipboardImage(const std::vector<uint8_t>& dib,
                         const std::vector<uint8_t>& png) {
  if (dib.size() < sizeof(BITMAPV5HEADER) || png.size() < 33 ||
      png.size() > kMaxClipboardPixels * 5 + 1024 * 1024) {
    return false;
  }
  BITMAPV5HEADER header{};
  std::memcpy(&header, dib.data(), sizeof(header));
  if (header.bV5Size != sizeof(header) || header.bV5Width <= 0 ||
      header.bV5Height <= 0 || header.bV5Planes != 1 ||
      header.bV5BitCount != 32 || header.bV5Compression != BI_BITFIELDS ||
      header.bV5RedMask != 0x00ff0000 || header.bV5GreenMask != 0x0000ff00 ||
      header.bV5BlueMask != 0x000000ff || header.bV5AlphaMask != 0xff000000 ||
      header.bV5CSType != LCS_sRGB || header.bV5ProfileData != 0 ||
      header.bV5ProfileSize != 0) {
    return false;
  }
  const uint64_t pixels = static_cast<uint64_t>(header.bV5Width) *
                          static_cast<uint64_t>(header.bV5Height);
  if (pixels > kMaxClipboardPixels || header.bV5SizeImage != pixels * 4 ||
      dib.size() != sizeof(header) + pixels * 4) {
    return false;
  }
  constexpr uint8_t signature[] = {137, 80, 78, 71, 13, 10, 26, 10};
  return std::memcmp(png.data(), signature, sizeof(signature)) == 0 &&
         BigEndian32(png.data() + 8) == 13 &&
         std::memcmp(png.data() + 12, "IHDR", 4) == 0 &&
         BigEndian32(png.data() + 16) ==
             static_cast<uint32_t>(header.bV5Width) &&
         BigEndian32(png.data() + 20) ==
             static_cast<uint32_t>(header.bV5Height) &&
         png[24] == 8 && (png[25] == 2 || png[25] == 6) && png[26] == 0 &&
         png[27] == 0 && png[28] <= 1;
}

// Places an image on the clipboard as CF_DIBV5 (understood by every Windows
// app) plus the registered "PNG" format (keeps alpha for apps that read it).
// The window owns the clipboard and empties it first, as SetClipboardData
// requires; the system takes ownership of each handle once it is set.
bool WriteImageToClipboard(HWND owner, const std::vector<uint8_t>& dib,
                           const std::vector<uint8_t>& png) {
  const UINT png_format = RegisterClipboardFormatW(L"PNG");
  if (png_format == 0) return false;
  HGLOBAL dib_memory = CopyToGlobal(dib);
  HGLOBAL png_memory = CopyToGlobal(png);
  if (dib_memory == nullptr || png_memory == nullptr) {
    if (dib_memory != nullptr) GlobalFree(dib_memory);
    if (png_memory != nullptr) GlobalFree(png_memory);
    return false;
  }
  bool opened = false;
  for (int attempt = 0; attempt < 10 && !opened; ++attempt) {
    opened = OpenClipboard(owner) != FALSE;
    if (!opened) Sleep(10);
  }
  if (!opened) {
    GlobalFree(dib_memory);
    GlobalFree(png_memory);
    return false;
  }
  bool written = false;
  if (EmptyClipboard()) {
    if (SetClipboardData(CF_DIBV5, dib_memory) != nullptr) {
      dib_memory = nullptr;  // Windows owns it even when the PNG step fails.
      if (SetClipboardData(png_format, png_memory) != nullptr) {
        png_memory = nullptr;
        written = true;  // Success requires both promised formats.
      }
    }
  }
  CloseClipboard();
  if (dib_memory != nullptr) GlobalFree(dib_memory);
  if (png_memory != nullptr) GlobalFree(png_memory);
  return written;
}

// A virtual-key-only event has no physical identity for Flutter. Supplement
// only missing scan metadata, before TranslateMessage produces matching text.
// No key state, character conversion, message dispatch or input injection.
bool SupplementMissingScanCode(MSG& message, HKL layout) {
  const bool key = message.message == WM_KEYDOWN ||
                   message.message == WM_KEYUP ||
                   message.message == WM_SYSKEYDOWN ||
                   message.message == WM_SYSKEYUP;
  constexpr LPARAM kScanMask = static_cast<LPARAM>(0xff) << 16;
  constexpr LPARAM kExtended = static_cast<LPARAM>(1) << 24;
  if (!key || message.wParam == VK_PACKET ||
      (message.lParam & kScanMask) != 0) {
    return false;
  }
  UINT virtual_key = static_cast<UINT>(message.wParam);
  if ((message.lParam & kExtended) != 0) {
    if (virtual_key == VK_CONTROL) virtual_key = VK_RCONTROL;
    if (virtual_key == VK_MENU) virtual_key = VK_RMENU;
  }
  const UINT mapped = MapVirtualKeyExW(virtual_key, MAPVK_VK_TO_VSC_EX, layout);
  const UINT scan = mapped & 0xff;
  // E1 multibyte sequences cannot be represented by the E0 extended flag.
  // Preserve such uncommon input instead of guessing a physical identity.
  if (scan == 0 || (mapped & 0xff00) == 0xe100) return false;
  message.lParam |= static_cast<LPARAM>(scan) << 16;
  if ((mapped & 0xff00) == 0xe000) message.lParam |= kExtended;
  return true;
}

bool ModifiersUp() {
  return (GetKeyState(VK_CONTROL) & 0x8000) == 0 &&
         (GetKeyState(VK_SHIFT) & 0x8000) == 0 &&
         (GetKeyState(VK_LWIN) & 0x8000) == 0 &&
         (GetKeyState(VK_RWIN) & 0x8000) == 0;
}
}  // namespace

FrostWindowPlugin* FrostWindowPlugin::instance_ = nullptr;

// static
void FrostWindowPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<FrostWindowPlugin>(registrar));
}

FrostWindowPlugin::FrostWindowPlugin(flutter::PluginRegistrarWindows* registrar) {
  instance_ = this;
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "frost_window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
  if (auto* view = registrar->GetView()) {
    content_ = view->GetNativeWindow();
    // The view is not parented yet; ContentProc attaches once it is.
    if (content_ != nullptr &&
        !SetWindowSubclass(content_, ContentProc, kContentSubclass,
                           reinterpret_cast<DWORD_PTR>(this))) {
      failure_step_ = "content_subclass";
      failure_error_ = GetLastError();
      content_ = nullptr;
    }
  }
  // Runs before GetMessage returns, so before the runner's TranslateMessage.
  message_hook_ = SetWindowsHookExW(WH_GETMESSAGE, GetMessageHook, nullptr,
                                    GetCurrentThreadId());
  Attach();
  // Dart can start before plugins are registered. Announce the handler so the
  // Dart side never races its first call against native startup.
  channel_->InvokeMethod(
      "registered", std::make_unique<flutter::EncodableValue>(Diagnostics()));
}

FrostWindowPlugin::~FrostWindowPlugin() {
  DetachWindow();
  // Registrar destruction can follow engine destruction. The messenger owns
  // its handlers and clears them with the engine; calling SetMethodCallHandler
  // here dereferences that dead engine. Releasing MethodChannel itself is local.
}

void FrostWindowPlugin::DetachWindow() {
  if (shutting_down_) return;
  shutting_down_ = true;
  ready_ = false;
  if (instance_ == this) instance_ = nullptr;
  if (message_hook_ != nullptr) {
    UnhookWindowsHookEx(message_hook_);
    message_hook_ = nullptr;
  }
  if (content_ != nullptr && IsWindow(content_)) {
    RemoveWindowSubclass(content_, ContentProc, kContentSubclass);
  }
  if (window_ != nullptr && IsWindow(window_)) {
    RemoveWindowSubclass(window_, WindowProc, kWindowSubclass);
  }
  content_ = nullptr;
  window_ = nullptr;
}

bool FrostWindowPlugin::Attach() {
  if (shutting_down_) return false;
  if (ready_) return true;
  if (content_ == nullptr || !IsWindow(content_)) return false;
  const HWND root = GetAncestor(content_, GA_ROOT);
  if (root == nullptr || root == content_) return false;
  window_ = root;
  ready_ = InstallFrame();
  if (!ready_) window_ = nullptr;
  return ready_;
}

bool FrostWindowPlugin::InstallFrame() {
  failure_error_ = 0;
  failure_step_ = "window_subclass";
  SetLastError(0);
  if (!SetWindowSubclass(window_, WindowProc, kWindowSubclass,
                         reinterpret_cast<DWORD_PTR>(this))) {
    failure_error_ = GetLastError();
    return false;
  }
  // Keep standard capabilities while replacing only the non-client layout.
  const LONG_PTR style = GetWindowLongPtr(window_, GWL_STYLE);
  SetLastError(0);
  const LONG_PTR previous =
      SetWindowLongPtr(window_, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
  const DWORD style_error = GetLastError();
  const bool style_changed = previous != 0 || style_error == 0;
  SetLastError(0);
  const bool frame_changed =
      style_changed &&
      SetWindowPos(window_, nullptr, 0, 0, 0, 0,
                   SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                       SWP_NOACTIVATE) != FALSE;
  const DWORD frame_error = GetLastError();
  if (!style_changed || !frame_changed) {
    failure_step_ = style_changed ? "frame_change" : "window_style";
    failure_error_ = style_changed ? frame_error : style_error;
    RemoveWindowSubclass(window_, WindowProc, kWindowSubclass);
    SetWindowLongPtr(window_, GWL_STYLE, style);
    SetWindowPos(window_, nullptr, 0, 0, 0, 0,
                 SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_NOACTIVATE);
    return false;
  }
  // Cosmetic DWM attributes are optional on older supported Windows versions.
  const DWM_WINDOW_CORNER_PREFERENCE corners = DWMWCP_ROUND;
  DwmSetWindowAttribute(window_, DWMWA_WINDOW_CORNER_PREFERENCE, &corners,
                        sizeof(corners));
  const DWMNCRENDERINGPOLICY rendering = DWMNCRP_ENABLED;
  DwmSetWindowAttribute(window_, DWMWA_NCRENDERING_POLICY, &rendering,
                        sizeof(rendering));
  failure_step_ = "ready";
  return true;
}

void FrostWindowPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();
  if (method == "getDiagnostics") {
    result->Success(Diagnostics());
    return;
  }
  if (!Attach()) {
    result->Error("window_unavailable", "Native window frame is unavailable.",
                  Diagnostics());
    return;
  }
  const auto* map = call.arguments() == nullptr
                        ? nullptr
                        : std::get_if<flutter::EncodableMap>(call.arguments());
  if (method == "getState") {
    result->Success(State());
    return;
  }
  if (method == "setRegions") {
    UpdateRegions(call.arguments());
  } else if (method == "setResizeBorder") {
    const double width = call.arguments() == nullptr ? 0 : Number(*call.arguments());
    if (!std::isfinite(width) || width <= 0) {
      result->Error("invalid_arguments", "Invalid window resize border.");
      return;
    }
    resize_border_width_ = width;
  } else if (method == "setToolbar") {
    if (map == nullptr) {
      result->Error("invalid_arguments", "Invalid window toolbar.");
      return;
    }
    UpdateToolbar(*map);
  } else if (method == "setBackdrop") {
    if (map == nullptr) {
      result->Error("invalid_arguments", "Invalid window backdrop.");
      return;
    }
    const auto mode = map->find(flutter::EncodableValue("backdrop"));
    const auto reduce = map->find(flutter::EncodableValue("reduceTransparency"));
    const auto* name = mode == map->end() ? nullptr : std::get_if<std::string>(&mode->second);
    const auto* solid = reduce == map->end() ? nullptr : std::get_if<bool>(&reduce->second);
    if (name == nullptr || solid == nullptr ||
        (*name != "none" && *name != "mica" && *name != "micaAlt")) {
      result->Error("invalid_arguments", "Invalid window backdrop.");
      return;
    }
    requested_backdrop_ = *name == "mica" ? 2 : *name == "micaAlt" ? 4 : 1;
    reduce_transparency_ = *solid;
    ApplyBackdrop();
    PublishState();
  } else if (method == "configure") {
    const auto* list =
        call.arguments() == nullptr
            ? nullptr
            : std::get_if<flutter::EncodableList>(call.arguments());
    if (list == nullptr || list->size() != 2) {
      result->Error("invalid_arguments", "Invalid window minimum size.");
      return;
    }
    const double width = Number((*list)[0]);
    const double height = Number((*list)[1]);
    if (!std::isfinite(width) || !std::isfinite(height) || width <= 0 ||
        height <= 0) {
      result->Error("invalid_arguments", "Invalid window minimum size.");
      return;
    }
    minimum_width_ = width;
    minimum_height_ = height;
  } else if (method == "minimize") {
    PostMessage(window_, WM_SYSCOMMAND, SC_MINIMIZE, 0);
  } else if (method == "toggleMaximized") {
    PostMessage(window_, WM_SYSCOMMAND,
                IsZoomed(window_) ? SC_RESTORE : SC_MAXIMIZE, 0);
  } else if (method == "close") {
    PostMessage(window_, WM_CLOSE, 0, 0);
  } else if (method == "showSystemMenu") {
    POINT point{};
    ClientToScreen(window_, &point);
    ShowSystemMenu(point);
  } else if (method == "copyImage") {
    const std::vector<uint8_t>* dib = nullptr;
    const std::vector<uint8_t>* png = nullptr;
    if (map != nullptr) {
      if (auto it = map->find(flutter::EncodableValue("dib")); it != map->end()) {
        dib = std::get_if<std::vector<uint8_t>>(&it->second);
      }
      if (auto it = map->find(flutter::EncodableValue("png")); it != map->end()) {
        png = std::get_if<std::vector<uint8_t>>(&it->second);
      }
    }
    if (dib == nullptr || png == nullptr || !ValidClipboardImage(*dib, *png)) {
      result->Error("invalid_arguments", "Invalid clipboard image payload.");
      return;
    }
    if (!WriteImageToClipboard(window_, *dib, *png)) {
      result->Error("clipboard_unavailable",
                    "Could not write the image to the clipboard.");
      return;
    }
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}

flutter::EncodableValue FrostWindowPlugin::Diagnostics() const {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("ready"), flutter::EncodableValue(ready_)},
      {flutter::EncodableValue("step"), flutter::EncodableValue(failure_step_)},
      {flutter::EncodableValue("win32Error"),
       flutter::EncodableValue(static_cast<int64_t>(failure_error_))},
  });
}

void FrostWindowPlugin::UpdateRegions(const flutter::EncodableValue* arguments) {
  const auto* list = arguments == nullptr
                         ? nullptr
                         : std::get_if<flutter::EncodableList>(arguments);
  regions_.clear();
  if (list == nullptr) return;
  for (const auto& value : *list) {
    const auto* row = std::get_if<flutter::EncodableList>(&value);
    if (row == nullptr || row->size() != 5) continue;
    const auto* kind = std::get_if<std::string>(&(*row)[4]);
    if (kind == nullptr || (*kind != "caption" && *kind != "maximize")) {
      continue;
    }
    Region region{Number((*row)[0]), Number((*row)[1]), Number((*row)[2]),
                  Number((*row)[3]),
                  *kind == "maximize" ? HTMAXBUTTON : HTCAPTION};
    if (std::isfinite(region.left) && std::isfinite(region.top) &&
        std::isfinite(region.right) && std::isfinite(region.bottom) &&
        region.right > region.left && region.bottom > region.top) {
      regions_.push_back(region);
    }
  }
}

void FrostWindowPlugin::ApplyBackdrop() {
  if (window_ == nullptr) return;
  // Attribute 38 is DWMWA_SYSTEMBACKDROP_TYPE (Win11 22H2+). Older SDKs can
  // still build the plugin; runtime support is checked before setting it.
  const bool eligible = requested_backdrop_ != 1 && !reduce_transparency_ &&
                        SupportsSystemBackdrop() && SystemTransparencyEnabled();
  const int mode = eligible ? requested_backdrop_ : 1;
  const HRESULT applied = DwmSetWindowAttribute(
      window_, static_cast<DWMWINDOWATTRIBUTE>(38), &mode, sizeof(mode));
  backdrop_available_ = SupportsSystemBackdrop() && SystemTransparencyEnabled() && SUCCEEDED(applied);
  const bool active = eligible && backdrop_available_;
  // Full-client glass is required by the Flutter child swapchain. Caption
  // painting is suppressed separately; window capabilities stay unchanged.
  const MARGINS margins = active ? MARGINS{-1, -1, -1, -1} : MARGINS{0, 0, 0, 0};
  const HRESULT extended = DwmExtendFrameIntoClientArea(window_, &margins);
  backdrop_active_ = active && SUCCEEDED(extended);
  if (!SetNativeCaptionPainting(backdrop_active_)) {
    backdrop_active_ = false;
    const MARGINS clear{0, 0, 0, 0};
    DwmExtendFrameIntoClientArea(window_, &clear);
  }
  if (active && !backdrop_active_) {
    const int none = 1;
    DwmSetWindowAttribute(window_, static_cast<DWMWINDOWATTRIBUTE>(38), &none, sizeof(none));
  }
}

bool FrostWindowPlugin::SetNativeCaptionPainting(bool hidden) {
  if (native_caption_hidden_ == hidden) return true;
  const LONG_PTR style = GetWindowLongPtr(window_, GWL_STYLE);
  // DWM paints caption glyphs whenever WS_SYSMENU is present. Keep WS_CAPTION,
  // WS_THICKFRAME and both min/max boxes: they own animations and Snap.
  // As in Mozilla's custom titlebar, initialize the lazy menu before hiding
  // its native drawing. Our existing Alt+Space/right-click path still uses it.
  if (hidden && GetSystemMenu(window_, FALSE) == nullptr) return false;
  SetLastError(0);
  const LONG_PTR previous = SetWindowLongPtr(
      window_, GWL_STYLE, hidden ? style & ~WS_SYSMENU : style | WS_SYSMENU);
  if (previous == 0 && GetLastError() != 0) return false;
  if (!SetWindowPos(window_, nullptr, 0, 0, 0, 0,
                    SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                        SWP_NOACTIVATE)) {
    SetWindowLongPtr(window_, GWL_STYLE, style);
    return false;
  }
  native_caption_hidden_ = hidden;
  return true;
}

void FrostWindowPlugin::UpdateToolbar(const flutter::EncodableMap& arguments) {
  if (auto title = arguments.find(flutter::EncodableValue("title"));
      title != arguments.end()) {
    if (const auto* text = std::get_if<std::string>(&title->second)) {
      const int length =
          MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
                              static_cast<int>(text->size()), nullptr, 0);
      if (length > 0) {
        std::wstring wide(length, L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(),
                            static_cast<int>(text->size()), wide.data(),
                            length);
        SetWindowTextW(window_, wide.c_str());
      }
    }
  }
  if (auto dark = arguments.find(flutter::EncodableValue("dark"));
      dark != arguments.end()) {
    if (const auto* enabled = std::get_if<bool>(&dark->second)) {
      const BOOL value = *enabled ? TRUE : FALSE;
      DwmSetWindowAttribute(window_, DWMWA_USE_IMMERSIVE_DARK_MODE, &value,
                            sizeof(value));
    }
  }
}

int FrostWindowPlugin::HitTest(POINT point) const {
  if (window_ == nullptr) return HTCLIENT;
  const UINT dpi = GetDpiForWindow(window_);
  POINT client_point = point;
  ScreenToClient(content_, &client_point);
  const double scale = static_cast<double>(dpi) / USER_DEFAULT_SCREEN_DPI;
  const double client_x = client_point.x / scale;
  const double client_y = client_point.y / scale;
  if (!IsZoomed(window_) && !IsIconic(window_)) {
    RECT client{};
    GetClientRect(window_, &client);
    MapWindowPoints(window_, nullptr, reinterpret_cast<POINT*>(&client), 2);
    // Three resize edges live entirely in the system's invisible frame.
    // Only the top strip occupies visible client pixels. Its intersections
    // with the outer side borders form the two upper corner targets.
    const bool left = point.x < client.left;
    const bool right = point.x >= client.right;
    const bool bottom = point.y >= client.bottom;
    const int top_width = (std::max)(1, static_cast<int>(std::round(
        resize_border_width_ * dpi / USER_DEFAULT_SCREEN_DPI)));
    const bool top = point.y < client.top + top_width;
    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
  }
  for (const auto& region : regions_) {
    if (client_x >= region.left && client_x < region.right &&
        client_y >= region.top && client_y < region.bottom) {
      return region.hit;
    }
  }
  return HTCLIENT;
}

flutter::EncodableValue FrostWindowPlugin::State() const {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("captionMode"), flutter::EncodableValue("client")},
      {flutter::EncodableValue("leftButtons"), flutter::EncodableValue(flutter::EncodableList{})},
      {flutter::EncodableValue("rightButtons"), flutter::EncodableValue(flutter::EncodableList{
          flutter::EncodableValue("minimize"), flutter::EncodableValue("maximize"), flutter::EncodableValue("close")})},
      {flutter::EncodableValue("maximized"),
       flutter::EncodableValue(IsZoomed(window_) != FALSE)},
      {flutter::EncodableValue("active"),
       flutter::EncodableValue(GetForegroundWindow() == window_)},
      {flutter::EncodableValue("minimized"),
       flutter::EncodableValue(IsIconic(window_) != FALSE)},
      {flutter::EncodableValue("hoveredButton"),
       flutter::EncodableValue(ButtonName(hovered_button_))},
      {flutter::EncodableValue("pressedButton"),
       flutter::EncodableValue(ButtonName(pressed_button_))},
      {flutter::EncodableValue("reduceTransparency"),
       flutter::EncodableValue(!SystemTransparencyEnabled())},
      {flutter::EncodableValue("backdropAvailable"),
       flutter::EncodableValue(backdrop_available_)},
      {flutter::EncodableValue("backdropActive"),
       flutter::EncodableValue(backdrop_active_)},
      {flutter::EncodableValue("revision"), flutter::EncodableValue(revision_)},
  });
}

void FrostWindowPlugin::PublishState() {
  if (shutting_down_ || !channel_ || window_ == nullptr) return;
  ++revision_;
  channel_->InvokeMethod("stateChanged",
                         std::make_unique<flutter::EncodableValue>(State()));
}

void FrostWindowPlugin::SetHover(int hit) {
  const int button = hit == HTMAXBUTTON ? hit : HTNOWHERE;
  if (hovered_button_ == button) return;
  hovered_button_ = button;
  PublishState();
}

void FrostWindowPlugin::CancelButtonPress() {
  if (pressed_button_ == HTNOWHERE) return;
  pressed_button_ = HTNOWHERE;
  if (GetCapture() == window_) ReleaseCapture();
  PublishState();
}

void FrostWindowPlugin::SetMaximizedClientRect(RECT* rect) const {
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST),
                      &info)) {
    return;
  }
  *rect = info.rcWork;
  // Leave room for the auto-hidden taskbar to reveal on any monitor edge.
  for (UINT edge : {ABE_LEFT, ABE_TOP, ABE_RIGHT, ABE_BOTTOM}) {
    APPBARDATA bar{sizeof(APPBARDATA)};
    bar.uEdge = edge;
    bar.rc = info.rcMonitor;
    if (SHAppBarMessage(ABM_GETAUTOHIDEBAREX, &bar) == 0) continue;
    if (edge == ABE_LEFT && rect->left == info.rcMonitor.left) rect->left += 2;
    if (edge == ABE_TOP && rect->top == info.rcMonitor.top) rect->top += 2;
    if (edge == ABE_RIGHT && rect->right == info.rcMonitor.right) {
      rect->right -= 2;
    }
    if (edge == ABE_BOTTOM && rect->bottom == info.rcMonitor.bottom) {
      rect->bottom -= 2;
    }
  }
}

void FrostWindowPlugin::ShowSystemMenu(POINT point) {
  const HMENU menu = GetSystemMenu(window_, FALSE);
  const bool maximized = IsZoomed(window_) != FALSE;
  EnableMenuItem(menu, SC_RESTORE,
                 MF_BYCOMMAND | (maximized ? MF_ENABLED : MF_GRAYED));
  EnableMenuItem(menu, SC_MAXIMIZE,
                 MF_BYCOMMAND | (maximized ? MF_GRAYED : MF_ENABLED));
  EnableMenuItem(menu, SC_MOVE,
                 MF_BYCOMMAND | (maximized ? MF_GRAYED : MF_ENABLED));
  EnableMenuItem(menu, SC_SIZE,
                 MF_BYCOMMAND | (maximized ? MF_GRAYED : MF_ENABLED));
  const UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
                                      point.x, point.y, 0, window_, nullptr);
  if (command) PostMessage(window_, WM_SYSCOMMAND, command, 0);
}

void FrostWindowPlugin::NavigateBack() {
  if (channel_ && ready_ && !IsIconic(window_)) {
    channel_->InvokeMethod("navigateBack", nullptr);
  }
}

std::optional<LRESULT> FrostWindowPlugin::HandleInput(HWND hwnd, UINT message,
                                                      WPARAM wparam,
                                                      LPARAM lparam) {
  const bool parent = hwnd == window_;
  const bool key = message == WM_KEYDOWN || message == WM_KEYUP ||
                   message == WM_SYSKEYDOWN || message == WM_SYSKEYUP;
  const bool text =
      message == WM_CHAR || message == WM_SYSCHAR || message == WM_DEADCHAR ||
      message == WM_SYSDEADCHAR || message == WM_UNICHAR ||
      message == WM_IME_CHAR || message == WM_IME_SETCONTEXT ||
      message == WM_IME_STARTCOMPOSITION || message == WM_IME_COMPOSITION ||
      message == WM_IME_ENDCOMPOSITION || message == WM_IME_REQUEST ||
      message == WM_INPUTLANGCHANGE;
  const bool alt = (lparam & (1L << 29)) != 0;
  const bool repeat = (lparam & (1L << 30)) != 0;
  // Flutter's child consumes Alt+Space before DefWindowProc can open the
  // parent's system menu. Forward that one native chord, consuming both edges
  // so Flutter never observes an orphan Space release or inserts a character.
  if ((message == WM_SYSKEYDOWN || message == WM_KEYDOWN) &&
      wparam == VK_SPACE && alt && ModifiersUp()) {
    if (!system_menu_key_down_ && !repeat) {
      PostMessage(window_, WM_SYSCOMMAND, SC_KEYMENU, VK_SPACE);
    }
    system_menu_key_down_ = true;
    system_menu_char_pending_ = true;
    return 0;
  }
  if ((message == WM_KEYUP || message == WM_SYSKEYUP) && wparam == VK_SPACE &&
      system_menu_key_down_) {
    system_menu_key_down_ = false;
    return 0;
  }
  if (message == WM_SYSCHAR && wparam == VK_SPACE && system_menu_char_pending_) {
    system_menu_char_pending_ = false;
    return 0;
  }
  // Consume both edges of Alt+Left before Flutter's keyboard manager sees
  // either edge. This guarantees one route operation, including key repeats.
  if ((message == WM_SYSKEYDOWN || message == WM_KEYDOWN) && wparam == VK_LEFT &&
      alt && ModifiersUp()) {
    if (!back_key_down_ && !repeat) NavigateBack();
    back_key_down_ = true;
    return 0;
  }
  if ((message == WM_KEYUP || message == WM_SYSKEYUP) && wparam == VK_LEFT &&
      back_key_down_) {
    back_key_down_ = false;
    return 0;
  }
  if (message == WM_XBUTTONDOWN || message == WM_NCXBUTTONDOWN) {
    if (GET_XBUTTON_WPARAM(wparam) == XBUTTON1) return TRUE;
  }
  if (message == WM_XBUTTONUP || message == WM_NCXBUTTONUP) {
    if (GET_XBUTTON_WPARAM(wparam) == XBUTTON1) {
      NavigateBack();
      return TRUE;  // Prevent DefWindowProc from emitting a second APPCOMMAND.
    }
  }
  if (message == WM_APPCOMMAND &&
      GET_APPCOMMAND_LPARAM(lparam) == APPCOMMAND_BROWSER_BACKWARD) {
    NavigateBack();
    return TRUE;
  }
  // Some native input paths target the host HWND. Forward only from host to
  // its Flutter child; never send a content message twice or synthesize
  // Unicode text from physical keys.
  if (parent && (key || text) && IsWindow(content_)) {
    return SendMessage(content_, message, wparam, lparam);
  }
  return std::nullopt;
}

LRESULT FrostWindowPlugin::HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                         LPARAM lparam) {
  if (const auto handled = HandleInput(hwnd, message, wparam, lparam)) {
    return *handled;
  }
  switch (message) {

    case WM_SETFOCUS:
      if (IsWindow(content_) && GetFocus() != content_) SetFocus(content_);
      return 0;
    case WM_SYSCOMMAND: {
      const WPARAM command = wparam & 0xfff0;
      if (command == SC_KEYMENU && lparam == VK_SPACE) {
        double caption_bottom = 0;
        for (const auto& region : regions_) {
          if (region.hit == HTCAPTION) {
            caption_bottom = (std::max)(caption_bottom, region.bottom);
          }
        }
        const double scale = static_cast<double>(GetDpiForWindow(hwnd)) /
                             USER_DEFAULT_SCREEN_DPI;
        POINT origin{0, static_cast<LONG>(std::round(caption_bottom * scale))};
        ClientToScreen(hwnd, &origin);
        ShowSystemMenu(origin);
        return 0;
      }
      break;
    }
    case WM_EXITMENULOOP:
      // TrackPopupMenu can consume the release inside its nested message loop.
      // Keep a still-held Space paired, but never poison a later ordinary key.
      if ((GetKeyState(VK_SPACE) & 0x8000) == 0) system_menu_key_down_ = false;
      system_menu_char_pending_ = false;
      break;
    case WM_NCCALCSIZE: {
      RECT* client = wparam
                         ? &reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam)->rgrc[0]
                         : reinterpret_cast<RECT*>(lparam);
      if (IsZoomed(hwnd)) {
        SetMaximizedClientRect(client);
      } else {
        // Keep the native invisible border outside Flutter's client area.
        // Query the current DPI on every calculation, including the runner's
        // SetWindowPos during WM_DPICHANGED; never cache system frame widths.
        const UINT dpi = GetDpiForWindow(hwnd);
        const int frame_x = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
                            GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
        const int frame_y = GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
                            GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
        client->left += frame_x;
        client->right -= frame_x;
        client->bottom -= frame_y;
      }
      return 0;
    }
    case WM_GETMINMAXINFO: {
      if (minimum_width_ <= 0 || minimum_height_ <= 0) break;
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const double scale = static_cast<double>(GetDpiForWindow(hwnd)) /
                           USER_DEFAULT_SCREEN_DPI;
      info->ptMinTrackSize = {static_cast<LONG>(minimum_width_ * scale),
                              static_cast<LONG>(minimum_height_ * scale)};
      return 0;
    }
    case WM_NCHITTEST:
      return HitTest({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)});
    case WM_NCMOUSEMOVE: {
      SetHover(static_cast<int>(wparam));
      if (!tracking_leave_) {
        TRACKMOUSEEVENT event{sizeof(TRACKMOUSEEVENT), TME_LEAVE | TME_NONCLIENT,
                              hwnd, 0};
        tracking_leave_ = TrackMouseEvent(&event) != FALSE;
      }
      // DWM receives HTMAXBUTTON so Windows 11 can show its Snap Layouts menu.
      LRESULT result = 0;
      if (DwmDefWindowProc(hwnd, message, wparam, lparam, &result)) return result;
      break;
    }
    case WM_NCMOUSELEAVE: {
      tracking_leave_ = false;
      SetHover(HTNOWHERE);
      LRESULT result = 0;
      DwmDefWindowProc(hwnd, message, wparam, lparam, &result);
      break;
    }
    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTMAXBUTTON) {
        pressed_button_ = HTMAXBUTTON;
        SetCapture(hwnd);
        PublishState();
        return 0;
      }
      break;  // HTCAPTION movement/double-click is handled by Windows itself.
    case WM_MOUSEMOVE:
      if (pressed_button_ != HTNOWHERE) {
        SetHover(HitTest(CursorPosition()));
        return 0;
      }
      SetHover(HTNOWHERE);
      break;
    case WM_LBUTTONUP:
      if (pressed_button_ != HTNOWHERE) {
        const bool activate = HitTest(CursorPosition()) == pressed_button_;
        CancelButtonPress();
        if (activate) {
          PostMessage(hwnd, WM_SYSCOMMAND,
                      IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE, 0);
        }
        return 0;
      }
      break;
    case WM_CAPTURECHANGED:
    case WM_CANCELMODE:
      CancelButtonPress();
      break;
    case WM_NCRBUTTONUP:
      if (wparam == HTCAPTION) {
        ShowSystemMenu({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)});
        return 0;
      }
      break;
    case WM_SETTINGCHANGE:
    case WM_THEMECHANGED:
    case WM_DWMCOMPOSITIONCHANGED:
      ApplyBackdrop();
      PublishState();
      break;
    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        back_key_down_ = false;
        system_menu_key_down_ = false;
        system_menu_char_pending_ = false;
        PublishState();
        return 0;  // The default runner would refocus its child on deactivation.
      }
      [[fallthrough]];
    case WM_SIZE:
      PublishState();
      // The default runner resizes its Flutter child to the iconic client area
      // (not necessarily zero). Preserve the last real viewport while minimized
      // so responsive layouts and their state do not transition on restoration.
      if (wparam == SIZE_MINIMIZED) return 0;
      break;
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

// static
LRESULT CALLBACK FrostWindowPlugin::WindowProc(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM lparam,
                                               UINT_PTR id, DWORD_PTR data) {
  if (message == WM_DESTROY || message == WM_NCDESTROY) {
    // Run before the runner's WM_DESTROY handler resets FlutterViewController.
    reinterpret_cast<FrostWindowPlugin*>(data)->DetachWindow();
    return DefSubclassProc(hwnd, message, wparam, lparam);
  }
  return reinterpret_cast<FrostWindowPlugin*>(data)->HandleMessage(
      hwnd, message, wparam, lparam);
}

// static
LRESULT CALLBACK FrostWindowPlugin::ContentProc(HWND hwnd, UINT message,
                                                WPARAM wparam, LPARAM lparam,
                                                UINT_PTR id, DWORD_PTR data) {
  auto* self = reinterpret_cast<FrostWindowPlugin*>(data);
  if (message == WM_DESTROY || message == WM_NCDESTROY) {
    self->DetachWindow();
    return DefSubclassProc(hwnd, message, wparam, lparam);
  }
  // The runner parents the view and sizes it before showing the window.
  if (!self->ready_ &&
      (message == WM_SIZE || message == WM_WINDOWPOSCHANGED ||
       message == WM_SHOWWINDOW)) {
    self->Attach();
  }
  if (!self->ready_) return DefSubclassProc(hwnd, message, wparam, lparam);
  if (message == WM_NCHITTEST) {
    if (self->HitTest({GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)}) !=
        HTCLIENT) {
      return HTTRANSPARENT;
    }
  } else if (const auto handled =
                 self->HandleInput(hwnd, message, wparam, lparam)) {
    return *handled;
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

// static
LRESULT CALLBACK FrostWindowPlugin::GetMessageHook(int code, WPARAM wparam,
                                                   LPARAM lparam) {
  if (code == HC_ACTION && wparam == PM_REMOVE && instance_ != nullptr &&
      instance_->window_ != nullptr) {
    auto* message = reinterpret_cast<MSG*>(lparam);
    if (message->hwnd == instance_->window_ ||
        IsChild(instance_->window_, message->hwnd)) {
      SupplementMissingScanCode(*message, GetKeyboardLayout(0));
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

}  // namespace frost_window
