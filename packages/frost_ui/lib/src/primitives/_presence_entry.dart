import 'package:flutter/widgets.dart';

/// Internal mount-only entry policy for newly inserted, already-visible slots.
class FrostPresenceEntry extends InheritedWidget {
  const FrostPresenceEntry({required this.animate, required super.child, super.key});
  final bool animate;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPresenceEntry>()?.animate ?? false;
  @override
  bool updateShouldNotify(FrostPresenceEntry oldWidget) => animate != oldWidget.animate;
}
