import 'package:flutter/widgets.dart';

/// A composed control already dims its content, so nested buttons still become
/// noninteractive without multiplying the same disabled opacity again.
class FrostControlDimming extends InheritedWidget {
  const FrostControlDimming({required this.disabled, required super.child, super.key});
  final bool disabled;
  static bool ownsOpacityOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostControlDimming>()?.disabled ?? false;
  @override
  bool updateShouldNotify(FrostControlDimming oldWidget) => disabled != oldWidget.disabled;
}
