import 'package:flutter/widgets.dart';

/// Container-owned page keylines. A scroll view retains its full pane width;
/// only its box/sliver content columns consume these insets.
class FrostContentPadding extends InheritedWidget {
  const FrostContentPadding({required this.padding, required super.child, super.key});
  final EdgeInsetsGeometry? padding;
  static EdgeInsets? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostContentPadding>()?.padding?.resolve(Directionality.of(context));
  @override
  bool updateShouldNotify(FrostContentPadding oldWidget) => padding != oldWidget.padding;
}
