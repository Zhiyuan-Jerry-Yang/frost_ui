import 'package:flutter/widgets.dart';

/// Library-only timing override for wrappers with a specified presence timing.
class FrostPresenceTiming extends InheritedWidget {
  const FrostPresenceTiming({required this.duration, required super.child, super.key});
  final Duration duration;
  static Duration? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPresenceTiming>()?.duration;
  @override
  bool updateShouldNotify(FrostPresenceTiming oldWidget) => duration != oldWidget.duration;
}
