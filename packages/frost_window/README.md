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
