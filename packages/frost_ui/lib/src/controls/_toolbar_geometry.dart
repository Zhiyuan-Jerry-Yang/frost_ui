import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/density.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '_button_control.dart';

/// Internal graphic alignment shared by every kind of toolbar control.
class FrostToolbarEdge extends InheritedWidget {
  const FrostToolbarEdge({required this.trailing, required super.child, super.key});
  final bool trailing;
  static bool trailingOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarEdge>()?.trailing ?? false;
  @override
  bool updateShouldNotify(FrostToolbarEdge oldWidget) => trailing != oldWidget.trailing;
}

FrostButtonGeometry frostToolbarButtonGeometry(BuildContext context) {
  final inset = FrostGap.of(context).hitInset;
  return FrostButtonGeometry(
    horizontalInset: inset,
    verticalInset: FrostGap.inline,
    minimumWidth: math.max(FrostDensity.of(context).targetHeight, FrostControlSize.compact.iconSize + inset * 2),
    alignment: FrostToolbarEdge.trailingOf(context) ? MainAxisAlignment.end : MainAxisAlignment.start,
  );
}

// Only natural-width leading menus opt into title-like truncation. Action
// controls retain their measured width and their existing overflow behavior.
class FrostToolbarLeadingScope extends InheritedWidget {
  const FrostToolbarLeadingScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarLeadingScope>() != null;
  @override
  bool updateShouldNotify(FrostToolbarLeadingScope oldWidget) => false;
}
