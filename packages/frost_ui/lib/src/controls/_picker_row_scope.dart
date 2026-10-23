import 'package:flutter/widgets.dart';

/// A row's choice stays a compact value trigger rather than adding a field label.
class FrostPickerRowScope extends InheritedWidget {
  const FrostPickerRowScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPickerRowScope>() != null;
  @override
  bool updateShouldNotify(FrostPickerRowScope oldWidget) => false;
}
