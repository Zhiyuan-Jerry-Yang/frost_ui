import 'package:flutter/widgets.dart';

import '../foundation/typography.dart';

// Reading sizes are offsets from the host platform's body role.
const frostReaderTextOffsets = [-2.0, -1.0, 0.0, 2.0, 4.0];
const frostReaderLineHeights = [1.45, 1.6, 1.8];

@immutable
class FrostReaderSettings {
  const FrostReaderSettings({this.textSizeStep = 0, this.lineSpacingStep = 1})
    : assert(textSizeStep >= -2 && textSizeStep <= 2),
      assert(lineSpacingStep >= 0 && lineSpacingStep <= 2);
  final int textSizeStep, lineSpacingStep;
  FrostReaderSettings copyWith({int? textSizeStep, int? lineSpacingStep}) =>
      FrostReaderSettings(textSizeStep: textSizeStep ?? this.textSizeStep, lineSpacingStep: lineSpacingStep ?? this.lineSpacingStep);
  @override
  bool operator ==(Object other) => other is FrostReaderSettings && other.textSizeStep == textSizeStep && other.lineSpacingStep == lineSpacingStep;
  @override
  int get hashCode => Object.hash(textSizeStep, lineSpacingStep);
}

/// Internal body-only typography policy; other semantic roles are untouched.
class FrostReaderStyle extends InheritedWidget {
  const FrostReaderStyle({required this.settings, required super.child, super.key});
  final FrostReaderSettings settings;
  static FrostReaderSettings? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostReaderStyle>()?.settings;
  static TextStyle apply(BuildContext context, FrostTextRole role, TextStyle base) {
    final settings = maybeOf(context);
    if (role != FrostTextRole.body || settings == null) return base;
    return base.copyWith(
      fontSize: base.fontSize! + frostReaderTextOffsets[settings.textSizeStep + 2],
      height: frostReaderLineHeights[settings.lineSpacingStep],
    );
  }

  @override
  bool updateShouldNotify(FrostReaderStyle oldWidget) => settings != oldWidget.settings;
}
