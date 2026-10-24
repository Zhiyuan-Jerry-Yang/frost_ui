# frost_window

Native desktop window capabilities and platform operations for Flutter.
This plugin depends only on Flutter; it does not import Frost UI, draw title
controls, select an app theme, or perform Flutter route navigation.

`FrostWindowController` owns registration, state updates, minimum window size,
drag/resize regions, title and appearance, minimize/maximize/close, system
backdrop requests, and native Back event delivery. `FrostWindowState` reports
actual capabilities, decoration mode, native button bounds, symbolic caption
icons and system transparency preference. The controller never infers these
from `Theme.platform`.

- **Windows:** native hit testing, resize borders, Snap Layouts, window menu,
  optional system Mica, and image clipboard transport.
- **Linux:** GTK client decoration capabilities, system button layout/icons,
  and GDK dragging, resizing and window actions from the original input event.
  A compositor window menu is available only when the compositor provides it.
- **macOS:** full-size content and a transparent title area with AppKit's
  original traffic lights. Their bounds follow native layout and full-screen.

The native API baseline is **macOS 12** and **GTK 3.24**, within Flutter 3.47's
[supported platforms](https://docs.flutter.dev/reference/supported-platforms).
Linux binaries also require the build distribution's glibc and media-library ABI.

## Frost UI integration

`FrostWindowHost`, title controls, theme/transparency integration, focus and
Flutter Back handling belong to `frost_ui`. Applications using Frost UI depend
only on `frost_ui` and import its public entry point. Its relative dependency
includes this plugin from the same checkout or Git commit. No overrides or
separate plugin Git ref are needed. The local example follows the same direction.

The plugin can also be consumed independently by non-Frost Flutter apps, which
provide their own widgets and navigation around `FrostWindowController`.

## macOS package managers

Both Swift Package Manager and CocoaPods compile the same Swift sources under
`macos/frost_window/Sources/frost_window`; the podspec points to that directory.
The deployment minimum remains macOS 12. Flutter 3.47 discovers the SPM manifest
automatically and can mix SPM plugins with CocoaPods-only media dependencies.

For integration checks, build the consuming app once with SPM enabled and once
with project-local `flutter.config.enable-swift-package-manager: false`. Keep
that validation setting in the test copy rather than changing global Flutter
configuration. A mixed build does not establish independence from CocoaPods.

## Native contract checks

```sh
sh packages/frost_window/test/check_linux_caption.sh /path/to/app/linux/flutter/ephemeral
sh packages/frost_window/test/check_macos_caption.sh /path/to/FlutterMacOS.xcframework/macos-arm64_x86_64
```

Run from the repository root with the platform compiler/display session. Linux
checks need GTK 3.24 development libraries and an installed symbolic icon theme.
Controller checks live in this package; widget integration checks live in
`packages/frost_ui/test/window_host_test.dart`.
