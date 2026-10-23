part of 'toolbar.dart';

enum FrostToolbarPriority { high, normal, low }

sealed class FrostToolbarItem {
  const FrostToolbarItem(this.priority);
  final FrostToolbarPriority priority;
  factory FrostToolbarItem.action({
    required FrostIconData icon,
    required String label,
    VoidCallback? onPressed,
    FrostToolbarPriority priority,
    bool showsLabel,
  }) = _Action;
  static FrostToolbarItem picker<T>({
    required List<FrostPickerOption<T>> choices,
    required T value,
    required ValueChanged<T> onChanged,
    required String label,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
  }) => _Picker<T>(choices, value, onChanged, label, priority);

  /// Pass [valueLabel] for a selector: its trigger shows the current value,
  /// and overflow/accessibility retain the selector purpose in [label].
  factory FrostToolbarItem.menu({
    required String label,
    required List<FrostMenuEntry> entries,
    String? valueLabel,
    FrostIconData? icon,
    bool showsLabel,
    FrostToolbarPriority priority,
  }) = _Menu;

  /// Sort trigger and overflow submenu generated from one set of fields.
  static FrostToolbarItem sortMenu<T>({
    required List<FrostPickerOption<T>> fields,
    required T value,
    required bool ascending,
    required void Function(T field, bool ascending) onChanged,
    required String label,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
  }) => _SortMenu<T>(fields, value, ascending, onChanged, label, priority);
  factory FrostToolbarItem.custom({
    required WidgetBuilder builder,
    required double minWidth,
    required FrostMenuEntry overflowEntry,
    FrostToolbarPriority priority,
  }) = _Custom;
  bool get _canCompact;
  bool get _isOverflowGroup => false;
  bool get _isPicker => false;
  Widget _build(BuildContext context, bool compact);
  FrostMenuEntry _overflow(BuildContext context);
}

class _Action extends FrostToolbarItem {
  const _Action({required this.icon, required this.label, this.onPressed, FrostToolbarPriority priority = FrostToolbarPriority.normal, this.showsLabel = false})
    : super(priority);
  final FrostIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool showsLabel;
  @override
  bool get _canCompact => showsLabel;
  @override
  Widget _build(BuildContext context, bool compact) => FrostToolbarControl(label: label, icon: icon, showsLabel: showsLabel && !compact, onPressed: onPressed);
  @override
  FrostMenuEntry _overflow(BuildContext context) => FrostMenuAction(label, icon: icon, onSelected: onPressed);
}

class _Picker<T> extends FrostToolbarItem {
  const _Picker(this.choices, this.value, this.onChanged, this.label, super.priority) : assert(choices.length > 0);
  final List<FrostPickerOption<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;
  List<FrostMenuEntry> get _entries => [
    for (final choice in choices)
      FrostMenuAction(choice.label, icon: choice.icon, checked: choice.value == value, onSelected: choice.enabled ? () => onChanged(choice.value) : null),
  ];
  @override
  bool get _canCompact => true;
  @override
  bool get _isPicker => true;
  @override
  Widget _build(BuildContext context, bool compact) => compact
      ? FrostPicker<T>.menu(value: value, options: choices, onChanged: onChanged, label: label)
      : FrostPicker<T>.segmented(options: choices, value: value, onChanged: onChanged, label: label);
  @override
  FrostMenuEntry _overflow(BuildContext context) =>
      FrostMenuSubmenu(_overflowChoiceLabel(label, choices.where((choice) => choice.value == value).firstOrNull?.label), entries: _entries);
}

class _Menu extends FrostToolbarItem {
  const _Menu({
    required this.label,
    required this.entries,
    this.icon,
    this.valueLabel,
    this.showsLabel = true,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
  }) : assert(showsLabel || icon != null),
       super(priority);
  final String label;
  final List<FrostMenuEntry> entries;
  final String? valueLabel;
  final FrostIconData? icon;
  final bool showsLabel;
  @override
  bool get _canCompact => false;
  @override
  bool get _isOverflowGroup => !showsLabel;
  @override
  Widget _build(BuildContext context, bool compact) =>
      FrostToolbarMenuButton(label: label, valueLabel: valueLabel, entries: entries, icon: icon, showsLabel: showsLabel);
  @override
  FrostMenuEntry _overflow(BuildContext context) => !showsLabel && label == FrostScope.labelsOf(context).more
      ? FrostMenuSection(entries: entries)
      : FrostMenuSubmenu(_overflowChoiceLabel(label, valueLabel), icon: icon, entries: entries);
}

class _Custom extends FrostToolbarItem {
  const _Custom({required this.builder, required this.minWidth, required this.overflowEntry, FrostToolbarPriority priority = FrostToolbarPriority.normal})
    : assert(minWidth >= 0 && minWidth < double.infinity),
      super(priority);
  final WidgetBuilder builder;
  final double minWidth;
  final FrostMenuEntry overflowEntry;
  @override
  bool get _canCompact => false;
  @override
  bool get _isOverflowGroup => overflowEntry is FrostMenuSection;
  @override
  Widget _build(BuildContext context, bool compact) => SizedBox(
    width: minWidth,
    child: Builder(builder: builder),
  );
  @override
  FrostMenuEntry _overflow(BuildContext context) => overflowEntry;
}

class _SortMenu<T> extends FrostToolbarItem {
  _SortMenu(this.fields, this.value, this.ascending, this.onChanged, this.label, super.priority)
    : assert(fields.isNotEmpty),
      assert(fields.map((field) => field.value).toSet().length == fields.length);
  final List<FrostPickerOption<T>> fields;
  final T value;
  final bool ascending;
  final void Function(T field, bool ascending) onChanged;
  final String label;
  @override
  bool get _canCompact => false;
  @override
  Widget _build(BuildContext context, bool compact) => FrostSortMenu<T>(fields: fields, value: value, ascending: ascending, onChanged: onChanged, label: label);
  @override
  FrostMenuEntry _overflow(BuildContext context) => FrostMenuSubmenu(
    _overflowChoiceLabel(label, fields.where((field) => field.value == value).firstOrNull?.label),
    entries: frostSortMenuEntries(context, fields: fields, value: value, ascending: ascending, onChanged: onChanged),
  );
}

// Overflow selectors keep their purpose after the visible value leaves its
// original toolbar context. Unknown values retain the selector name alone.
String _overflowChoiceLabel(String label, String? value) => value == null || value == label ? label : [label, value].join(' · ');
