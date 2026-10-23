part of 'picker.dart';

class _PickerInline<T> extends StatelessWidget {
  const _PickerInline({required this.owner});
  final _PickerState<T> owner;
  @override
  Widget build(BuildContext context) {
    final placement = FrostRowPlacement.of(context);
    final rows = [
      for (final (index, option) in owner.widget.options.indexed)
        ExcludeFocusTraversal(
          excluding: index != owner._tabIndex,
          child: FrostRowFocus(
            focusNode: owner._nodes[index],
            child: Semantics(
              label: option.label,
              value: option.subtitle,
              checked: index == owner._selected,
              inMutuallyExclusiveGroup: true,
              enabled: owner._enabled && option.enabled,
              onTap: owner._enabled && option.enabled ? () => owner._choose(index) : null,
              excludeSemantics: true,
              child: FrostListRow(
                title: option.label,
                subtitle: option.subtitle,
                leading: FrostChoiceMark(value: index == owner._selected, kind: FrostChoiceKind.radio),
                enabled: owner._enabled && option.enabled,
                onPressed: owner._enabled && option.enabled ? () => owner._choose(index) : null,
              ),
            ),
          ),
        ),
    ];
    return placement == null
        ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)
        : FrostContiguousRows(corners: placement.corners ?? BorderRadius.zero, lastTextAnchor: placement.textAnchor, children: rows);
  }
}
