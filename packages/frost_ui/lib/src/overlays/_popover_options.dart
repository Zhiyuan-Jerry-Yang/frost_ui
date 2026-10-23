import 'package:flutter/widgets.dart';

import 'sheet.dart';

/// Internal adaptive-panel policy, without another public Popover parameter.
class FrostPopoverDetents extends InheritedWidget {
  const FrostPopoverDetents({required this.detents, required super.child, super.key});
  final List<FrostSheetDetent> detents;
  static List<FrostSheetDetent>? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPopoverDetents>()?.detents;
  @override
  bool updateShouldNotify(FrostPopoverDetents oldWidget) => detents != oldWidget.detents;
}
