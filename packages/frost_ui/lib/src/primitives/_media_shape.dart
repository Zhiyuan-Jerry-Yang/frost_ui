import 'package:flutter/widgets.dart';

/// Internal circle presentation; media loading keeps the shared frame path.
class FrostMediaCircle extends InheritedWidget {
  const FrostMediaCircle({required super.child, this.enabled = true, super.key});
  final bool enabled;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMediaCircle>()?.enabled ?? false;
  @override
  bool updateShouldNotify(FrostMediaCircle oldWidget) => enabled != oldWidget.enabled;
}

/// An enclosing media card paints the stroke outside its hover transform.
class FrostMediaInnerStroke extends InheritedWidget {
  const FrostMediaInnerStroke({required this.enabled, required super.child, super.key});
  final bool enabled;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMediaInnerStroke>()?.enabled ?? true;
  @override
  bool updateShouldNotify(FrostMediaInnerStroke oldWidget) => enabled != oldWidget.enabled;
}
