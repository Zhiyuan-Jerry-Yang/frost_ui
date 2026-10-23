import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_focus_modality.dart';
import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../primitives/_measured_keyline.dart';
import '../primitives/divider.dart';
import '../primitives/keyline.dart';
import '_list_input.dart';
import '_list_viewport.dart';
import '_row_scope.dart';
import 'list_row.dart';

/// A lazy plain list of [FrostListRow]s. Give its scrolling axis
/// a finite height. The list owns selection when [onSelected] is supplied;
/// otherwise Enter and clicks retain each row's own action.
class FrostList<T> extends StatefulWidget {
  const FrostList({
    required this.items,
    required this.itemBuilder,
    this.selected,
    this.onSelected,
    this.dividers = false,
    this.reserveIconColumn = false,
    super.key,
  });
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool highlighted) itemBuilder;
  final T? selected;
  final ValueChanged<T>? onSelected;
  final bool dividers;

  /// Set true for mixed-icon lists so every row reserves the shared icon column.
  /// Explicit metadata keeps arbitrary item builders lazy, without type inspection.
  final bool reserveIconColumn;
  @override
  State<FrostList<T>> createState() => _ListState<T>();
}

class _ListState<T> extends State<FrostList<T>> {
  final _focus = FocusNode();
  final _scroll = ScrollController(keepScrollOffset: false);
  final _center = GlobalKey();
  int _origin = 0;
  final _cells = <int, ({GlobalKey key, GlobalKey text, FrostListItemHandle handle})>{};
  int? _keyboard, _hover;
  FrostListInput<T>? _input;
  int _revealGeneration = 0;
  int? get _active => _hover ?? _keyboard;
  int? _selectedIndex() {
    if (widget.selected == null) return null;
    final index = widget.items.indexOf(widget.selected as T);
    return index < 0 ? null : index;
  }

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
    _keyboard = _selectedIndex();
    _origin = _keyboard ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _input?.controller.unbind(this);
    _input = FrostListInput.of<T>(context);
    _input?.controller.bind(this, (event) => _key(_focus, event), () => _keyboard == null ? null : widget.items[_keyboard!]);
  }

  @override
  void didUpdateWidget(FrostList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_input != null && _keyboard != null && _keyboard! < oldWidget.items.length) {
      final previous = oldWidget.items[_keyboard!];
      final identity = _input?.identity;
      final next = identity == null ? widget.items.indexOf(previous) : widget.items.indexWhere((item) => identity(item) == identity(previous));
      _keyboard = next >= 0
          ? next
          : widget.items.isEmpty
          ? null
          : _keyboard!.clamp(0, widget.items.length - 1);
    }
    if (oldWidget.selected != widget.selected) {
      _keyboard = _selectedIndex();
      if (_keyboard != null && _cells[_keyboard]?.key.currentContext == null) _origin = _keyboard!;
    }
    if (_keyboard != null && _keyboard! >= widget.items.length) _keyboard = null;
    if (_origin >= widget.items.length) _origin = 0;
    if (_input == null || !listEquals(oldWidget.items, widget.items)) _hover = null;
    _revealGeneration++;
  }

  void _modalityChanged() {
    if (!mounted || !FrostInputModality.instance.touch || _active == null) return;
    setState(() {
      _hover = null;
      _keyboard = null;
    });
    _announceHighlight();
  }

  void _updateHover(int index, PointerEvent event) {
    if (!FrostInputModality.instance.acceptsHover(event) || _hover == index) return;
    setState(() => _hover = index);
    _announceHighlight();
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    _input?.controller.unbind(this);
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reveal(int index, int generation) {
    if (!mounted || generation != _revealGeneration || !_scroll.hasClients) return;
    final target = _cells[index]?.key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: FrostMotion.duration(context, FrostMotion.layoutFade), curve: FrostMotion.hoverCurve);
      return;
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent || widget.items.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      if (_active case final index?) {
        // The row handle also enforces enabled, and delegates exactly once to
        // onSelected when present. A disabled row cannot be keyboard-selected.
        final activate = _cells[index]?.handle.activate;
        if (activate != null) {
          activate();
        } else {
          // A preceding Home/End can rebase before this input turn is painted.
          // Wait for that row, then enforce its own enabled/action contract.
          final generation = _revealGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && generation == _revealGeneration && _active == index) _cells[index]?.handle.activate?.call();
          });
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final last = widget.items.length - 1;
    final target = switch (key) {
      LogicalKeyboardKey.arrowDown => _keyboard == null ? 0 : (_keyboard! + 1).clamp(0, last),
      LogicalKeyboardKey.arrowUp => _keyboard == null ? last : (_keyboard! - 1).clamp(0, last),
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => last,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    setState(() {
      _keyboard = target;
      _hover = null;
      // Rebase a distant target at the viewport center instead of asking a
      // variable-height sliver to walk every intervening row to find its offset.
      if (_cells[target]?.key.currentContext == null) _origin = target;
    });
    _announceHighlight();
    final generation = ++_revealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(target, generation));
    return KeyEventResult.handled;
  }

  void _announceHighlight() {
    final index = _active;
    _input?.onHighlight(index == null ? null : widget.items[index], index);
  }

  Widget _item(BuildContext context, int index) {
    final cell = _cells.putIfAbsent(index, () => (key: GlobalKey(), text: GlobalKey(), handle: FrostListItemHandle()));
    final item = widget.items[index];
    return MouseRegion(
      key: cell.key,
      onEnter: (event) => _updateHover(index, event),
      onHover: (event) => _updateHover(index, event),
      onExit: (_) {
        if (_hover == index) {
          setState(() => _hover = null);
          _announceHighlight();
        }
      },
      child: FrostListItemScope(
        selected: widget.selected != null && item == widget.selected,
        reserveIconColumn: widget.reserveIconColumn,
        highlighted: index == _active,
        onSelected: widget.onSelected == null ? null : () => widget.onSelected!(item),
        handle: cell.handle,
        viewportInset: frostBleedOutsetsOf(context),
        child: ExcludeFocus(
          child: FrostRowPlacement(
            textAnchor: cell.text,
            corners: null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.itemBuilder(context, item, index == _active),
                if (widget.dividers && index < widget.items.length - 1)
                  FrostMeasuredKeyline(
                    target: cell.text,
                    child: const FrostDivider(inset: FrostDividerInset.keyline),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FrostBleed(
    amount: FrostGap.of(context).hitInset,
    child: Focus(
      focusNode: _focus,
      canRequestFocus: _input == null,
      onKeyEvent: _key,
      child: Listener(
        onPointerDown: _input == null ? (_) => _focus.requestFocus() : null,
        child: FrostListScrollView(
          // A rebase starts at the target with no estimated offset or restoration.
          key: ValueKey(_origin),
          controller: _scroll,
          fitContent: _input != null,
          center: _center,
          slivers: [
            if (_origin > 0) SliverList(delegate: SliverChildBuilderDelegate((context, index) => _item(context, _origin - index - 1), childCount: _origin)),
            SliverList(
              key: _center,
              delegate: SliverChildBuilderDelegate((context, index) => _item(context, _origin + index), childCount: widget.items.length - _origin),
            ),
            if (_input?.footer case final footer?) SliverToBoxAdapter(child: footer),
          ],
        ),
      ),
    ),
  );
}
