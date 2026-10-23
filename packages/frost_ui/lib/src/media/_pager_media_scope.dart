import 'package:flutter/widgets.dart';

/// Internal coordination: a zoomed current media page owns horizontal panning.
/// This scope does not change the public Viewport callback or expose its State.
class FrostPagerMediaScope extends InheritedWidget {
  const FrostPagerMediaScope({required this.index, required this.onZoomChanged, required super.child, super.key});
  final int index;
  final void Function(Object source, int index, bool zoomed) onZoomChanged;
  static FrostPagerMediaScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPagerMediaScope>();
  void report(Object source, bool zoomed) => onZoomChanged(source, index, zoomed);
  @override
  bool updateShouldNotify(FrostPagerMediaScope oldWidget) => index != oldWidget.index || onZoomChanged != oldWidget.onZoomChanged;
}
