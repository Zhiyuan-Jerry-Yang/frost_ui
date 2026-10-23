part of 'picker.dart';

// Color is data: keep the fixed swatch, spacing and selected-ring geometry.
const _swatchGap = 8.0;

class _PickerPalette<T> extends StatelessWidget {
  const _PickerPalette({required this.owner});
  final _PickerState<T> owner;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: _swatchGap,
    runSpacing: _swatchGap,
    children: [
      for (final (index, option) in owner.widget.options.indexed)
        ExcludeFocusTraversal(
          excluding: index != owner._tabIndex,
          child: FrostColorSwatch(
            color: option.color!,
            label: option.label,
            icon: option.icon,
            selected: index == owner._selected,
            focusNode: owner._nodes[index],
            onPressed: owner._enabled && option.enabled ? () => owner._choose(index) : null,
          ),
        ),
      if (owner.widget.trailingSwatch case final swatch?)
        ExcludeFocusTraversal(
          excluding: owner.widget.options.length != owner._tabIndex,
          child: FrostColorSwatch(
            key: swatch.key,
            color: swatch.color,
            label: swatch.label,
            selected: swatch.selected,
            icon: swatch.icon,
            focusNode: owner._node(owner.widget.options.length),
            onPressed: owner._enabled && swatch.onPressed != null ? () => owner._choose(owner.widget.options.length) : null,
          ),
        ),
    ],
  );
}
