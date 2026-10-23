import 'package:flutter/widgets.dart';

import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../layout/window_caption_scope.dart';

/// Internal window-base availability, updated when an ambient image resolves.
class FrostWindowBackgroundScope extends InheritedWidget {
  const FrostWindowBackgroundScope({required this.hasAmbient, required super.child, this.forceSolidBase = false, this.background, super.key});
  final bool hasAmbient;
  final bool forceSolidBase;
  final Color? background;
  static FrostWindowBackgroundScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostWindowBackgroundScope>();
  @override
  bool updateShouldNotify(FrostWindowBackgroundScope oldWidget) =>
      hasAmbient != oldWidget.hasAmbient || forceSolidBase != oldWidget.forceSolidBase || background != oldWidget.background;
}

bool frostHasTranslucentWindowBase(BuildContext context) =>
    !FrostScope.solidSurfaces(context) &&
    !(FrostWindowBackgroundScope.maybeOf(context)?.forceSolidBase ?? false) &&
    ((context.dependOnInheritedWidgetOfExactType<FrostWindowBackgroundScope>()?.hasAmbient ?? false) ||
        FrostWindowCaptionScope.systemBackdropActiveOf(context));

/// Target theme, independent of AnimatedTheme's intermediate paint frames.
class FrostAmbientThemeScope extends InheritedWidget {
  const FrostAmbientThemeScope({required this.tokens, required super.child, super.key});
  final FrostThemeTokens tokens;
  @override
  bool updateShouldNotify(FrostAmbientThemeScope oldWidget) =>
      tokens.brightness != oldWidget.tokens.brightness ||
      tokens.tone != oldWidget.tokens.tone ||
      tokens.canvas != oldWidget.tokens.canvas ||
      tokens.surface != oldWidget.tokens.surface ||
      tokens.textPrimary != oldWidget.tokens.textPrimary ||
      tokens.textSecondary != oldWidget.tokens.textSecondary ||
      tokens.accent != oldWidget.tokens.accent;
}
