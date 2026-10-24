# frost_window

Native window integration for Frost UI. Put `FrostWindowHost` above the app
Navigator and compose `FrostShell` or shared page headers inside it. The plugin
reports native capabilities and geometry; apps do not select decoration from a
theme platform value.

- **Windows:** Flutter caption controls, native hit testing, Snap Layouts and
  optional system Mica. The existing DWM frame remains responsible for resizing.
- **Linux:** no system decoration row. Flutter controls follow GTK's
  `gtk-decoration-layout`, including left/right placement and order. GTK/GDK own
  dragging, resizing and window actions using the original input event. A
  compositor window menu is available only when the compositor provides it.
- **macOS:** full-size Flutter content with a transparent title area. AppKit's
  original traffic-light controls remain native. Their measured bounds update
  with native layout/full-screen changes; Frost headers reserve that space.

The native API baseline is **macOS 12** and **GTK 3.24**, within Flutter 3.47's
[supported platforms](https://docs.flutter.dev/reference/supported-platforms).
Do not raise the minimum solely to match the local test machine. Unsupported
platform versions receive no compatibility branches. Linux binaries additionally
require the build distribution's glibc and linked media-library ABI.

Custom, full-window headers compose `FrostNativeCaptionPadding` before content
gutters, and `FrostCaptionButtons` for both sides when client controls are needed.
`FrostCaptionClearance` prevents nested headers from reserving space twice when
an owner already placed its content below the title region. Remove app-runner
code that independently changes title-bar decoration.

Mica is Windows-only and is inactive normally on the other platforms.
`showSystemMenu` and image clipboard transport are Windows-specific controller
operations. Linux requests its compositor menu from the native right-click
handler; macOS has no equivalent window menu.

## macOS package managers

Both Swift Package Manager and CocoaPods are supported. They compile the same
Swift sources under `macos/frost_window/Sources/frost_window`; the CocoaPods
specification points to that directory. The deployment minimum remains macOS 12.
Flutter 3.47 discovers the SPM manifest automatically. Applications can still use
CocoaPods, or mix SPM plugins with CocoaPods-only dependencies.

For integration checks, build the consuming app once with SPM enabled and once
with the project-local `flutter.config.enable-swift-package-manager: false`.
Keep that validation setting local to the test copy instead of changing the
machine-wide Flutter configuration. A successful mixed build does not establish
that the app is independent of CocoaPods.

## Linux caption appearance

Client decorations use system symbolic window icons, an Adwaita baseline, and
limited Breeze hover styling. Missing, non-symbolic, or invalid icon resources
use Frost's vector fallback. Layout follows GTK settings, including a single
close button and leading/trailing controls. Theme and display-scale changes
refresh icons. This intentionally does not reproduce arbitrary GTK/KWin window
decoration themes. Window movement, resizing and state remain native GDK calls.

macOS keeps AppKit's original traffic lights in the transparent full-size content
title region. Applications reserve their reported bounds with
`FrostNativeCaptionPadding`. `FrostShell` keeps a native-only draggable strip
(normally 28 logical pixels, growing with measured native controls) and puts Back
on the sidebar icon axis below it. The brand appears beside Back only while the
sidebar is expanded. Wide mobile layouts without a client titlebar share this
sidebar header; Windows/Linux client captions keep their existing navigation. No SDK, engine or dependency patches are required.

Native contract checks (no screenshots or probe windows shown):

```sh
sh packages/frost_window/test/check_linux_caption.sh /path/to/app/linux/flutter/ephemeral
sh packages/frost_window/test/check_macos_caption.sh /path/to/FlutterMacOS.xcframework/macos-arm64_x86_64
```

Run from the repository root with the target platform's compiler/display session.
The Linux check needs GTK 3.24 development libraries and an installed symbolic
icon theme. Flutter widget checks cover caption layout, keyboard operation and
macOS native-control clearance; these native checks cover the actual host APIs.
