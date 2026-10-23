import 'package:flutter/widgets.dart';

import '../controls/picker_option.dart';
import '../foundation/scope.dart';
import '../overlays/menu_entry.dart';
import 'toolbar_menu_button.dart';

/// A plain menu trigger showing the current sort field. In a FrostToolbar use
/// FrostToolbarItem.sortMenu so its overflow submenu shares the same entries.
class FrostSortMenu<T> extends StatelessWidget {
  FrostSortMenu({required this.fields, required this.value, required this.ascending, required this.onChanged, required this.label, super.key})
    : assert(fields.isNotEmpty),
      assert(fields.map((field) => field.value).toSet().length == fields.length);
  final List<FrostPickerOption<T>> fields;
  final T value;
  final bool ascending;
  final void Function(T field, bool ascending) onChanged;
  final String label;
  @override
  Widget build(BuildContext context) {
    final current = fields.where((field) => field.value == value).firstOrNull;
    return FrostToolbarMenuButton(
      label: label,
      valueLabel: current?.label,
      entries: frostSortMenuEntries(context, fields: fields, value: value, ascending: ascending, onChanged: onChanged),
    );
  }
}

/// Internal source for the standalone trigger and the toolbar overflow.
List<FrostMenuEntry> frostSortMenuEntries<T>(
  BuildContext context, {
  required List<FrostPickerOption<T>> fields,
  required T value,
  required bool ascending,
  required void Function(T field, bool ascending) onChanged,
}) => [
  for (final field in fields)
    FrostMenuAction(field.label, icon: field.icon, checked: field.value == value, onSelected: field.enabled ? () => onChanged(field.value, ascending) : null),
  const FrostMenuDivider(),
  FrostMenuAction(FrostScope.labelsOf(context).sortAscending, checked: ascending, onSelected: () => onChanged(value, true)),
  FrostMenuAction(FrostScope.labelsOf(context).sortDescending, checked: !ascending, onSelected: () => onChanged(value, false)),
];
