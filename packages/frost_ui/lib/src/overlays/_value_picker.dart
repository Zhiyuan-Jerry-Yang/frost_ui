import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/picker_option.dart';
import '../foundation/_row_metrics.dart';
import '../foundation/control_scope.dart';
import '../foundation/spacing.dart';
import '../lists/_list_viewport.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../primitives/divider.dart';
import '../primitives/keyline.dart';
import 'adaptive_panel.dart';
import 'menu_anchor.dart';
import 'menu_entry.dart';
import 'sheet.dart';

/// Internal shared entry point for compact selectors and sidebar overflow.
/// The private result wrapper distinguishes a nullable value from cancellation.
Future<void> showFrostValueSheet<T>({
  required BuildContext context,
  required List<FrostPickerOption<T>> items,
  required T? value,
  required ValueChanged<T> onSelected,
  String? title,
}) async {
  final result = await showFrostSheet<_PickedValue<T>>(
    context: context,
    title: title,
    detents: const [FrostSheetDetent.fitted],
    scrollable: false,
    builder: (_) => _ValuePickerList<T>(items: items, value: value),
  );
  if (context.mounted && result != null) onSelected(result.value);
}

/// One presentation boundary for fields and settings rows. Toolbar choices
/// deliberately keep the anchored menu at every window width.
class FrostPickerMenuHost<T> extends StatefulWidget {
  const FrostPickerMenuHost({
    required this.items,
    required this.value,
    required this.onSelected,
    required this.builder,
    this.title,
    this.enabled = true,
    super.key,
  });
  final List<FrostPickerOption<T>> items;
  final T? value;
  final String? title;
  final bool enabled;
  final ValueChanged<T> onSelected;
  final FrostMenuTriggerBuilder builder;

  @override
  State<FrostPickerMenuHost<T>> createState() => _ValuePickerHostState<T>();
}

class _ValuePickerHostState<T> extends State<FrostPickerMenuHost<T>> {
  final _focus = FocusNode();
  bool _open = false;

  Future<void> _showSheet() async {
    if (_open || !widget.enabled || widget.items.isEmpty) return;
    _open = true;
    _focus.requestFocus();
    try {
      await showFrostValueSheet<T>(
        context: context,
        title: widget.title,
        items: widget.items,
        value: widget.value,
        onSelected: (value) {
          if (mounted) widget.onSelected(value);
        },
      );
    } finally {
      _open = false;
      if (mounted && _focus.canRequestFocus) _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => frostPanelUsesSheet(context) && !FrostControlScope.toolbarOf(context)
      ? widget.builder(context, _focus, _showSheet)
      : FrostMenuAnchor(
          entries: [
            for (final item in widget.items)
              FrostMenuAction(
                item.label,
                icon: item.icon,
                checked: item.value == widget.value,
                onSelected: widget.enabled && item.enabled ? () => widget.onSelected(item.value) : null,
              ),
          ],
          builder: widget.builder,
        );
}

class _PickedValue<T> {
  const _PickedValue(this.value);
  final T value;
}

class _ValuePickerList<T> extends StatefulWidget {
  const _ValuePickerList({required this.items, required this.value});
  final List<FrostPickerOption<T>> items;
  final T? value;
  @override
  State<_ValuePickerList<T>> createState() => _ValuePickerListState<T>();
}

class _ValuePickerListState<T> extends State<_ValuePickerList<T>> {
  final _center = GlobalKey();
  final _selectedFocus = FocusNode();
  late final _start = math.max(0, widget.items.indexWhere((item) => item.value == widget.value));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _selectedFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _selectedFocus.dispose();
    super.dispose();
  }

  Widget _row(int index) => _ValuePickerRow<T>(
    item: widget.items[index],
    selected: widget.items[index].value == widget.value,
    focusNode: index == _start ? _selectedFocus : null,
    hasDivider: index < widget.items.length - 1,
    onSelected: () => Navigator.of(context).pop(_PickedValue(widget.items[index].value)),
  );

  @override
  Widget build(BuildContext context) => FrostListScrollView(
    fitContent: true,
    center: _center,
    slivers: [
      // The selected sliver starts in the viewport on the cold frame. Earlier
      // rows grow upward lazily; no guessed height or post-layout jump is used.
      if (_start > 0) SliverList(delegate: SliverChildBuilderDelegate((context, index) => _row(_start - index - 1), childCount: _start)),
      SliverList(
        key: _center,
        delegate: SliverChildBuilderDelegate((context, index) => _row(_start + index), childCount: widget.items.length - _start),
      ),
    ],
  );
}

/// Keeps the lazy viewport and selected focus while sharing ordinary row UI.
class _ValuePickerRow<T> extends StatelessWidget {
  const _ValuePickerRow({required this.item, required this.selected, required this.focusNode, required this.hasDivider, required this.onSelected});
  final FrostPickerOption<T> item;
  final bool selected, hasDivider;
  final FocusNode? focusNode;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final inset = FrostGap.of(context).rowInset;
    // The common 28-wide icon column plus related spacing sets the text edge.
    final textStart = inset + (item.icon == null ? 0 : frostRowIconColumn + FrostGap.related);
    Widget row = FrostListRow.check(
      title: item.label,
      subtitle: item.subtitle,
      icon: item.icon,
      checked: selected,
      onPressed: item.enabled ? onSelected : null,
    );
    if (focusNode case final focus?) row = FrostRowFocus(focusNode: focus, child: row);
    return FrostKeyline(
      leadingRoom: 0,
      trailingRoom: 0,
      edgeDistanceStart: 0,
      edgeDistanceEnd: 0,
      insideContainer: true,
      contentStart: inset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          if (hasDivider)
            Padding(
              padding: EdgeInsetsDirectional.only(start: textStart, end: inset),
              child: const FrostDivider(),
            ),
        ],
      ),
    );
  }
}
