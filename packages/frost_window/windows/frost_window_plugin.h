#ifndef FLUTTER_PLUGIN_FROST_WINDOW_PLUGIN_H_
#define FLUTTER_PLUGIN_FROST_WINDOW_PLUGIN_H_

#include <windows.h>
#include <commctrl.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>
#include <vector>

namespace frost_window {

// Replaces the standard non-client area of the app's top-level window with a
// Flutter-drawn title bar while keeping native resizing, snapping, the system
// menu and DWM effects. Hit testing stays outside Flutter's gesture arena: the
// Flutter child HWND passes caption/resize hits to its top-level window.
//
// The plugin needs no runner changes. It subclasses the Flutter view at
// registration and takes over the top-level window as soon as the view is
// parented to it, which happens before the window is first shown.
class FrostWindowPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit FrostWindowPlugin(flutter::PluginRegistrarWindows* registrar);
  ~FrostWindowPlugin() override;
  FrostWindowPlugin(const FrostWindowPlugin&) = delete;
  FrostWindowPlugin& operator=(const FrostWindowPlugin&) = delete;

 private:
  struct Region {
    double left;
    double top;
    double right;
    double bottom;
    int hit;
  };

  static LRESULT CALLBACK WindowProc(HWND, UINT, WPARAM, LPARAM, UINT_PTR,
                                     DWORD_PTR);
  static LRESULT CALLBACK ContentProc(HWND, UINT, WPARAM, LPARAM, UINT_PTR,
                                      DWORD_PTR);
  static LRESULT CALLBACK GetMessageHook(int, WPARAM, LPARAM);

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool Attach();
  void DetachWindow();
  bool InstallFrame();
  LRESULT HandleMessage(HWND, UINT, WPARAM, LPARAM);
  std::optional<LRESULT> HandleInput(HWND, UINT, WPARAM, LPARAM);
  void NavigateBack();
  int HitTest(POINT screen_point) const;
  void UpdateRegions(const flutter::EncodableValue* arguments);
  void ApplyBackdrop();
  bool SetNativeCaptionPainting(bool hidden);
  void UpdateToolbar(const flutter::EncodableMap& arguments);
  flutter::EncodableValue State() const;
  flutter::EncodableValue Diagnostics() const;
  void PublishState();
  void SetHover(int hit);
  void CancelButtonPress();
  void SetMaximizedClientRect(RECT* rect) const;
  void ShowSystemMenu(POINT point);

  static FrostWindowPlugin* instance_;

  HWND window_ = nullptr;
  HWND content_ = nullptr;
  HHOOK message_hook_ = nullptr;
  std::vector<Region> regions_;
  int hovered_button_ = HTNOWHERE;
  int pressed_button_ = HTNOWHERE;
  int64_t revision_ = 0;
  bool back_key_down_ = false;
  bool system_menu_key_down_ = false;
  bool system_menu_char_pending_ = false;
  bool tracking_leave_ = false;
  bool ready_ = false;
  bool shutting_down_ = false;
  int requested_backdrop_ = 1;  // DWMSBT_NONE; 2=Mica, 4=Mica Alt.
  bool reduce_transparency_ = false;
  bool backdrop_available_ = false;
  bool backdrop_active_ = false;
  bool native_caption_hidden_ = false;
  const char* failure_step_ = "not_attached";
  DWORD failure_error_ = 0;
  double minimum_width_ = 0;
  double minimum_height_ = 0;
  double resize_border_width_ = 4;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace frost_window

#endif  // FLUTTER_PLUGIN_FROST_WINDOW_PLUGIN_H_
