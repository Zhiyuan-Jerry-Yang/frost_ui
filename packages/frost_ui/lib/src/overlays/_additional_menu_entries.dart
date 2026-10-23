import 'package:flutter/widgets.dart';

import 'menu_entry.dart';

/// Operation wrappers add menu entries to a built-in child's own menu.
class FrostAdditionalMenuEntries extends InheritedWidget {
  const FrostAdditionalMenuEntries({required this.entries, required super.child, super.key});
  final List<FrostMenuEntry> entries;
  static List<FrostMenuEntry> of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostAdditionalMenuEntries>()?.entries ?? const [];
  @override
  bool updateShouldNotify(FrostAdditionalMenuEntries oldWidget) => entries != oldWidget.entries;
}
