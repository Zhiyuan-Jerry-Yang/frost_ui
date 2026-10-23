import 'package:flutter/widgets.dart';

/// Library-owned composites may replace automatic page navigation without
/// expanding the public PageHeader API or changing the shell's back behavior.
class FrostPageHeaderLeading extends InheritedWidget {
  const FrostPageHeaderLeading({required this.leading, required super.child, super.key});
  final Widget? leading;
  static FrostPageHeaderLeading? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPageHeaderLeading>();
  @override
  bool updateShouldNotify(FrostPageHeaderLeading oldWidget) => leading != oldWidget.leading;
}
