part of 'picker.dart';

class _PickerMenu<T> extends StatelessWidget {
  const _PickerMenu({required this.owner, this.measurement = false});
  final _PickerState<T> owner;
  final bool measurement;
  @override
  Widget build(BuildContext context) {
    final picker = owner.widget, size = picker.size ?? FrostControlScope.sizeOf(context);
    final selected = picker.options.where((option) => option.value == picker.value).firstOrNull;
    final toolbar = FrostControlScope.toolbarOf(context), row = FrostPickerRowScope.of(context);
    final field = !toolbar && !row;
    final trigger = FrostMenuTarget(
      child: FrostPickerMenuHost<T>(
        items: picker.options,
        value: picker.value,
        title: picker.label,
        enabled: owner._enabled,
        onSelected: (value) {
          if (owner._enabled) picker.onChanged!(value);
        },
        builder: (context, focus, toggle) {
          if (!measurement) owner._menuFocus = focus;
          if (field) {
            return FrostFieldTrigger(
              label: picker.label,
              value: selected?.label ?? '',
              leading: selected?.icon,
              focus: focus,
              onPressed: owner._enabled ? toggle : null,
              size: size,
              error: picker.error,
              chevron: FrostButtonChevron.upDown,
            );
          }
          return FrostButtonControl(
            label: selected?.label ?? '',
            semanticLabel: selected == null ? picker.label : [picker.label, selected.label].join(', '),
            icon: selected?.icon,
            focusNode: focus,
            onPressed: owner._enabled ? toggle : null,
            size: toolbar ? FrostControlSize.compact : size,
            variant: FrostButtonVariant.plain,
            chevron: toolbar ? FrostButtonChevron.down : FrostButtonChevron.upDown,
            textRole: FrostTextRole.callout,
            geometry: toolbar ? frostToolbarButtonGeometry(context) : null,
            truncates: toolbar,
            wrapsLabel: !toolbar,
          );
        },
      ),
    );
    return field || picker.error == null ? trigger : FrostFieldLayout(error: picker.error, enabled: owner._enabled, child: trigger);
  }
}
