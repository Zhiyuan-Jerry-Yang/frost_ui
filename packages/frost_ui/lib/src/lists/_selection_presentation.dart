import 'package:flutter/widgets.dart';

/// Shared input routing and presentation for built-in rows and media cards.
/// Kept separate from the generic public scope to avoid widget-type inspection.
class FrostSelectionPresentation extends InheritedWidget {
  const FrostSelectionPresentation({
    required this.active,
    this.drawTrigger,
    required this.selected,
    required this.activate,
    required this.selectInTable,
    required this.longPress,
    required this.textAnchor,
    required super.child,
    super.key,
  });
  final bool active, selected;
  final Object? drawTrigger;
  final void Function(VoidCallback? original) activate;
  final VoidCallback longPress, selectInTable;
  final GlobalKey textAnchor;
  static FrostSelectionPresentation? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostSelectionPresentation>();
  @override
  bool updateShouldNotify(FrostSelectionPresentation oldWidget) =>
      drawTrigger != oldWidget.drawTrigger ||
      active != oldWidget.active ||
      selected != oldWidget.selected ||
      activate != oldWidget.activate ||
      textAnchor != oldWidget.textAnchor;
}

// Marks a built-in main target even when it is disabled and ignores pointers.
// The enclosing generic item must not turn that disabled region into a tap.
const frostSelectionInputTarget = Object();
