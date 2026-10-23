import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/_user_selection_draw.dart';
import '../primitives/_measured_keyline.dart';
import '../primitives/divider.dart';
import '_selection_presentation.dart';

/// Application-owned selection, independent of filtering, pagination or layout.
class FrostSelection<T> extends ChangeNotifier {
  Set<T> _selected = {};
  bool _active = false;
  T? _anchor;
  bool _hasAnchor = false;
  (T, Object)? _drawn;

  /// An immutable snapshot; later changes never mutate a previous snapshot.
  Set<T> get selected => Set<T>.unmodifiable(_selected);
  bool get active => _active;
  bool isSelected(T item) => _selected.contains(item);
  void _update(Set<T> values, {required bool active, (T,)? draw}) {
    if (_active == active && setEquals(_selected, values)) return;
    _drawn = draw != null && !_selected.contains(draw.$1) && values.contains(draw.$1) ? (draw.$1, FrostUserSelectionPulse()) : null;
    _selected = values;
    _active = active;
    notifyListeners();
  }

  void enter() => _update(_selected, active: true);
  void exit() {
    _anchor = null;
    _hasAnchor = false;
    _update({}, active: false);
  }

  void clear() => _update({}, active: _active);
  void toggle(T item) => _toggle(item, false);
  void _toggle(T item, bool user) {
    _anchor = item;
    _hasAnchor = true;
    final values = {..._selected};
    if (!values.add(item)) values.remove(item);
    _update(values, active: true, draw: user ? (item,) : null);
  }

  /// Adds these items, retaining selections outside the current view.
  void selectAll(Iterable<T> items) => _update({..._selected, ...items}, active: true);

  void _activate(T item, _SelectionData<T> scope, VoidCallback? original, {bool table = false}) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) {
      final target = scope.indices[item]!;
      final anchor = _hasAnchor ? scope.indices[_anchor] : null;
      final range = anchor == null ? <T>{item} : scope.items.sublist(anchor < target ? anchor : target, (anchor > target ? anchor : target) + 1).toSet();
      _update(keyboard.isControlPressed ? {..._selected, ...range} : range, active: true, draw: (item,));
    } else if (table && !keyboard.isControlPressed) {
      _anchor = item;
      _hasAnchor = true;
      _update({item}, active: true, draw: (item,));
    } else if (_active || keyboard.isControlPressed) {
      _toggle(item, true);
    } else {
      _anchor = item;
      _hasAnchor = true;
      original?.call();
    }
  }
}

/// Shares selection behavior with any grid, waterfall, sliver or box layout.
/// [items] defines range order and must contain unique values. Filtering does
/// not remove hidden selections. Dispose [selection] in its application owner.
class FrostSelectionScope<T> extends StatefulWidget {
  const FrostSelectionScope({required this.selection, required this.items, required this.child, super.key});
  final FrostSelection<T> selection;
  final List<T> items;
  final Widget child;
  @override
  State<FrostSelectionScope<T>> createState() => _SelectionScopeState<T>();
}

class _SelectionScopeState<T> extends State<FrostSelectionScope<T>> {
  late Map<T, int> _indices;
  @override
  void initState() {
    super.initState();
    _index();
  }

  @override
  void didUpdateWidget(FrostSelectionScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild once per scope update, including callers mutating a list in place.
    _index();
  }

  void _index() {
    _indices = {for (var i = 0; i < widget.items.length; i++) widget.items[i]: i};
    assert(_indices.length == widget.items.length, 'Selection items must be unique.');
  }

  @override
  Widget build(BuildContext context) => _SelectionData<T>(
    selection: widget.selection,
    items: widget.items,
    indices: _indices,
    child: Focus(
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && widget.selection.active) {
          widget.selection.exit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    ),
  );
}

class _SelectionData<T> extends InheritedNotifier<FrostSelection<T>> {
  const _SelectionData({required FrostSelection<T> selection, required this.items, required this.indices, required super.child}) : super(notifier: selection);
  final List<T> items;
  final Map<T, int> indices;
  @override
  bool updateShouldNotify(_SelectionData<T> oldWidget) => super.updateShouldNotify(oldWidget) || !identical(indices, oldWidget.indices);
}

/// Adds selection input to an item in [FrostSelectionScope].
/// Built-in FrostListRow and FrostMediaCard route their main action through this
/// scope and automatically show their selection controls. Independent controls
/// inside the item retain their own actions.
class FrostSelectableItem<T> extends StatefulWidget {
  const FrostSelectableItem({required this.item, required this.child, super.key});
  final T item;
  final Widget child;
  @override
  State<FrostSelectableItem<T>> createState() => _SelectableItemState<T>();
}

/// Table rows provide their own structured row/cell semantics.
class FrostTableSelectionItem<T> extends FrostSelectableItem<T> {
  const FrostTableSelectionItem({required super.item, required super.child, super.key});
  @override
  State<FrostSelectableItem<T>> createState() => _TableSelectableItemState<T>();
}

class _SelectableItemState<T> extends State<FrostSelectableItem<T>> {
  bool get table => false;

  final _text = GlobalKey();
  bool _delegated = false;
  bool _touch = false;
  void _pointerDown(PointerDownEvent event) {
    final hit = HitTestResult();
    GestureBinding.instance.hitTestInView(hit, event.position, event.viewId);
    _delegated = hit.path.any((entry) => entry.target is RenderMetaData && identical((entry.target as RenderMetaData).metaData, frostSelectionInputTarget));
    _touch = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SelectionData<T>>();
    assert(scope != null, 'FrostSelectableItem requires a matching FrostSelectionScope.');
    assert(scope!.indices.containsKey(widget.item), 'The item must belong to its scope.');
    final selection = scope!.notifier!;
    void activate(VoidCallback? original) {
      // The selection workspace owns Escape after a pointer selection. Ordinary
      // click controls preserve editing focus; selection explicitly enters its
      // keyboard scope, without moving focus from an already-focused row.
      final focus = Focus.of(context);
      if (!focus.hasFocus) focus.requestFocus();
      selection._activate(widget.item, scope, original);
    }

    void longPress() {
      if (!_touch) return;
      if (!selection.isSelected(widget.item)) {
        selection._toggle(widget.item, true);
      } else {
        selection.enter();
      }
    }

    return FrostSelectionPresentation(
      active: selection.active,
      selected: selection.isSelected(widget.item),
      drawTrigger: selection._drawn?.$1 == widget.item ? selection._drawn?.$2 : null,
      activate: activate,
      selectInTable: () => selection._activate(widget.item, scope, null, table: true),
      longPress: longPress,
      textAnchor: _text,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _pointerDown,
        child: GestureDetector(
          excludeFromSemantics: table,
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (!_delegated) {
              Focus.of(context).requestFocus();
              activate(null);
            }
          },
          onLongPress: () {
            if (!_delegated && _touch) longPress();
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// A lazy vertical list using the same scope/item composition as media grids.
/// Give it a finite height. Its scroll position survives selection-bar resizing.
class FrostSelectableList<T> extends StatelessWidget {
  const FrostSelectableList({required this.selection, required this.items, required this.itemBuilder, super.key});
  final FrostSelection<T> selection;
  final List<T> items;
  final Widget Function(BuildContext context, T item, bool selected) itemBuilder;
  @override
  Widget build(BuildContext context) => FrostSelectionScope<T>(
    selection: selection,
    items: items,
    child: ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => FrostSelectableItem<T>(
        key: ValueKey(items[index]),
        item: items[index],
        child: Builder(
          builder: (context) {
            final presentation = FrostSelectionPresentation.of(context)!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                itemBuilder(context, items[index], presentation.selected),
                if (index < items.length - 1)
                  FrostMeasuredKeyline(
                    target: presentation.textAnchor,
                    child: const FrostDivider(inset: FrostDividerInset.keyline),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _TableSelectableItemState<T> extends _SelectableItemState<T> {
  @override
  bool get table => true;
}
