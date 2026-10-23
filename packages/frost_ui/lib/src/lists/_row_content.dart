import 'package:flutter/widgets.dart';

/// Rich secondary content uses the ordinary row's layout, focus, input and
/// layout transition. This scope is deliberately absent from public exports.
class FrostRowContent extends InheritedWidget {
  const FrostRowContent({required this.belowTitle, required this.semanticValue, this.selected = false, required super.child, super.key});
  final Widget belowTitle;
  final String semanticValue;
  final bool selected;
  static FrostRowContent? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowContent>();
  @override
  bool updateShouldNotify(FrostRowContent oldWidget) =>
      belowTitle != oldWidget.belowTitle || semanticValue != oldWidget.semanticValue || selected != oldWidget.selected;
}
