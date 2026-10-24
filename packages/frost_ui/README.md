# frost_ui

Shared Frost UI components, adaptive layouts, materials and motion.

## Native window integration

`frost_ui` owns `FrostWindowHost`, caption controls, native-button clearance,
theme/transparency integration, focus management and Flutter Back navigation.
The lower-level `frost_window` plugin owns native capabilities and operations;
it does not depend on this UI package. Public window APIs are available through
`package:frost_ui/frost_ui.dart`.

Applications select only the UI branch:

```yaml
dependencies:
  frost_ui:
    git:
      url: https://github.com/normalllll/frost_ui.git
      ref: v0.2.0
      path: packages/frost_ui
```

The relative `../frost_window` dependency uses the sibling checkout locally and
the same repository commit when consumed through Git. Do not declare a second
plugin Git ref. Local development, the example and app CI need no dependency
overrides or Pub workspace.

Install `FrostWindowHost` above the app Navigator and compose `FrostShell` or
shared page headers inside it. Windows/Linux use Flutter client controls with
native window actions; macOS retains AppKit's original traffic lights in a
transparent full-size content title region. `FrostShell` reserves a native-only
drag strip on macOS and places Back and branding below it. Wide mobile layouts
share the sidebar header when no client titlebar is available.

Full-window media headers compose `FrostNativeCaptionPadding` before their
content gutters. `FrostCaptionClearance` prevents nested headers from reserving
native-button space twice. Keep app-runner decoration settings in the plugin.

Linux controls follow GTK's button layout and system symbolic icons, with
Adwaita defaults and limited Breeze hover styling. Missing icons use Frost's
vector fallback. Window dragging, resizing and actions remain native GTK/GDK
operations; arbitrary compositor decoration themes are not reproduced.

Run checks from the corresponding package directories:

```sh
cd packages/frost_window && flutter pub get && flutter test
cd ../frost_ui && flutter pub get && flutter test
cd ../frost_window/example && flutter pub get && flutter analyze
```

No SDK, engine or dependency patches are required.
