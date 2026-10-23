import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';

/// Media foregrounds use the current onMedia ink and circular icon-button scrim.
/// This changes neither the page theme nor separately opened menus and dialogs.
/// It adds no surface; use FrostSurface with the onMediaChrome role for a panel.
class FrostOnMediaChromeScope extends InheritedWidget {
  const FrostOnMediaChromeScope({required super.child, super.key}) : _enabled = true;
  const FrostOnMediaChromeScope._without({required super.child}) : _enabled = false;
  final bool _enabled;

  static Color? inkOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostOnMediaChromeScope>()?._enabled == true ? FrostThemeTokens.of(context).onMediaInk : null;

  @override
  bool updateShouldNotify(FrostOnMediaChromeScope oldWidget) => _enabled != oldWidget._enabled;
}

// A separately surfaced menu/popover keeps the page palette even when an
// OverlayPortal inherits the media trigger's complete ancestry.
Widget frostWithoutOnMediaChrome(Widget child) => FrostOnMediaChromeScope._without(child: child);
