import 'package:flutter/widgets.dart';

/// Library-owned compositions whose root surface consumes reveal progress.
/// Consumed by the next Presence; nested generic content keeps its usual fade.
class FrostPresenceMaterial extends InheritedWidget {
  const FrostPresenceMaterial({this.enabled = true, required super.child, super.key});
  final bool enabled;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPresenceMaterial>()?.enabled ?? false;
  @override
  bool updateShouldNotify(FrostPresenceMaterial oldWidget) => enabled != oldWidget.enabled;
}
