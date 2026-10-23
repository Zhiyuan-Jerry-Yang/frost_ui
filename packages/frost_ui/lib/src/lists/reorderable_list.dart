import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../motion/spring.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '_reorder_motion.dart';

// Matches Flutter's native reorderable list edge auto-scroll velocity scalar.
const _reorderAutoScrollVelocity = 80.0;
// A lifted row is deliberately subtler than a media hover zoom.
const _reorderLiftScale = 1.02;

/// A lazy vertical list with a trailing handle, touch dragging and keyboard
/// pickup. Items must be unique. The caller applies [onReorder] to its list.
/// [onReorder]'s newIndex is the final zero-based destination AFTER removal,
/// unlike Flutter's obsolete insertion-before-removal onReorder callback.
class FrostReorderableList<T> extends StatefulWidget {
  const FrostReorderableList({required this.items, required this.itemBuilder, required this.onReorder, super.key});
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  @override
  State<FrostReorderableList<T>> createState() => _ReorderListState<T>();
}

class _Cell {
  final content = GlobalKey();
  final slot = GlobalKey();
  final focus = FocusNode();
  Widget? body;
  void dispose() => focus.dispose();
}

class _Grab<T> {
  _Grab(this.item, this.oldIndex, {this.position, this.pointerOrigin, this.size});
  final T item;
  final int oldIndex;
  Offset? position;
  final Offset? pointerOrigin;
  final Size? size;
  bool get pointer => position != null;
}

class _ReorderListState<T> extends State<FrostReorderableList<T>> {
  final _scroll = ScrollController();
  final _cells = <T, _Cell>{};
  late Map<T, int> _indices;
  late List<T> _sourceItems;
  List<T>? _pendingCommit;
  Map<T, int> _orderIndices = {};
  List<T>? _preview;
  _Grab<T>? _grab;
  final _portal = OverlayPortalController();
  final _proxyPosition = ValueNotifier(Offset.zero);
  EdgeDraggingAutoScroller? _autoScroll;
  int _revision = 0;
  double? _dropFrom;
  T? _dropItem;
  bool _enabled = true;
  List<T> get _order => _preview ?? widget.items;
  double get _scrollOffset => _scroll.hasClients ? _scroll.offset : 0;
  @override
  void initState() {
    super.initState();
    _index();
  }

  void _index() {
    _indices = {for (var i = 0; i < widget.items.length; i++) widget.items[i]: i};
    assert(_indices.length == widget.items.length, 'Reorder items must be unique.');
    _sourceItems = List.of(widget.items);
    _orderIndices = {for (var i = 0; i < _order.length; i++) _order[i]: i};
  }

  @override
  void didUpdateWidget(FrostReorderableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_sourceItems, widget.items)) {
      _cancel(notify: false);
      if (!listEquals(_pendingCommit, widget.items)) {
        _dropFrom = null;
        _revision++;
      }
      _pendingCommit = null;
      final current = widget.items.toSet();
      for (final item in _cells.keys.toList()) {
        if (!current.contains(item)) _cells.remove(item)!.dispose();
      }
    }
    _index();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = FrostControlScope.enabledOf(context);
    if (_enabled && !enabled) _cancel(notify: false);
    _enabled = enabled;
  }

  Rect? _rect(T item, {bool slot = false}) {
    final box = (slot ? _cells[item]?.slot : _cells[item]?.content)?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _announce(int index) => unawaited(
    SemanticsService.sendAnnouncement(View.of(context), FrostScope.labelsOf(context).itemPosition(index + 1, widget.items.length), Directionality.of(context)),
  );
  void _previewMove(int destination) {
    final grab = _grab;
    if (grab == null || !_enabled) return;
    final current = _orderIndices[grab.item]!;
    final next = destination.clamp(0, _order.length - 1);
    if (next == current) return;
    setState(() {
      _preview!.removeAt(current);
      _preview!.insert(next, grab.item);
      _orderIndices = {for (var i = 0; i < _order.length; i++) _order[i]: i};
      _dropFrom = null;
      _revision++;
    });
    _announce(next);
    if (!grab.pointer) {
      final revision = _revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _revision != revision || _grab == null) return;
        final target = _cells[grab.item]?.slot.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: FrostMotion.duration(context, FrostMotion.standardDuration),
            curve: FrostSpringCurve(FrostMotion.standard, FrostMotion.standardDuration),
          );
        }
      });
    }
  }

  void _toggle(T item) {
    if (!_enabled) return;
    if (_grab != null) {
      _finish();
      return;
    }
    setState(() {
      _preview = List.of(widget.items);
      _grab = _Grab(item, _indices[item]!);
      _dropFrom = null;
      _revision++;
      _index();
    });
  }

  KeyEventResult _key(T item, KeyEvent event) {
    if (!_enabled || (event is! KeyDownEvent && event is! KeyRepeatEvent) || _grab == null || _grab!.item != item) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    _previewMove(_orderIndices[item]! + delta);
    return KeyEventResult.handled;
  }

  void _start(T item, DragStartDetails details) {
    if (!_enabled) return;
    final rect = _rect(item);
    final cell = _cells[item];
    if (rect == null || cell?.body == null) return;
    _cancel();
    setState(() {
      _preview = List.of(widget.items);
      _grab = _Grab(item, _indices[item]!, position: rect.topLeft, pointerOrigin: details.globalPosition, size: rect.size);
      _dropFrom = null;
      _revision++;
      _index();
    });
    _proxyPosition.value = rect.topLeft;
    _portal.show();
    final scrollable = Scrollable.maybeOf(cell!.slot.currentContext!);
    if (scrollable != null) {
      _autoScroll = EdgeDraggingAutoScroller(scrollable, velocityScalar: _reorderAutoScrollVelocity, onScrollViewScrolled: _autoScrolled);
    }
  }

  Widget _buildProxy(BuildContext context) {
    final grab = _grab;
    if (grab == null || !grab.pointer) return const SizedBox.shrink();
    final cell = _cells[grab.item]!;
    final overlay = Overlay.of(context, rootOverlay: true).context.findRenderObject()! as RenderBox;
    return ValueListenableBuilder<Offset>(
      valueListenable: _proxyPosition,
      builder: (context, position, child) {
        final local = overlay.globalToLocal(position);
        return Positioned(
          left: local.dx,
          top: local.dy,
          width: grab.size!.width,
          child: IgnorePointer(child: ExcludeSemantics(child: child!)),
        );
      },
      child: _ReorderLift(key: cell.content, lifted: true, child: cell.body!),
    );
  }

  void _update(DragUpdateDetails details) {
    final grab = _grab;
    if (!_enabled || grab == null || !grab.pointer) return;
    grab.position = grab.position! + Offset(0, details.delta.dy);
    _proxyPosition.value = grab.position!;
    _hitGap();
    _autoScroll?.startAutoScrollIfNecessary(_dragTarget(grab));
  }

  Rect _dragTarget(_Grab<T> grab) {
    final viewport = _autoScroll?.scrollable.context.findRenderObject();
    final limit = viewport is RenderBox ? viewport.size : grab.size!;
    // Long, fully wrapped rows can exceed the viewport; the framework helper
    // requires a target no larger than it. This does not resize the lifted row.
    return grab.position! & Size(grab.size!.width.clamp(0, limit.width), grab.size!.height.clamp(0, limit.height));
  }

  void _autoScrolled() {
    final grab = _grab;
    if (!mounted || grab == null || !grab.pointer) return;
    _hitGap();
    _autoScroll?.startAutoScrollIfNecessary(_dragTarget(grab));
  }

  void _hitGap() {
    final grab = _grab;
    if (grab == null || !grab.pointer) return;
    final current = _orderIndices[grab.item]!;
    var next = current;
    final currentRect = _rect(grab.item, slot: true);
    var closest = currentRect == null ? double.infinity : (grab.position!.dy - currentRect.top).abs();
    // Pick the nearest actual insertion slot, including unequal-height rows.
    // Above the placeholder it is a row's top; below, it is its bottom with
    // the placeholder removed. Fast pointer jumps cannot skip a legal slot.
    for (final item in _cells.keys) {
      if (item == grab.item) continue;
      final index = _orderIndices[item];
      final rect = _rect(item, slot: true);
      if (index == null || rect == null) continue;
      final top = index < current ? rect.top : rect.bottom - grab.size!.height;
      final distance = (grab.position!.dy - top).abs();
      if (distance < closest) {
        closest = distance;
        next = index;
      }
    }
    _previewMove(next);
  }

  void _finish() {
    final grab = _grab;
    if (grab == null) return;
    final destination = _orderIndices[grab.item]!;
    _pendingCommit = List.of(_order);
    _dropItem = grab.item;
    final top = grab.pointer ? grab.position!.dy : _rect(grab.item)?.top;
    _dropFrom = top == null ? null : top + _scrollOffset;
    _autoScroll?.stopAutoScroll();
    _autoScroll = null;
    setState(() {
      _grab = null;
      _preview = null;
      _revision++;
      _index();
    });
    if (grab.oldIndex != destination && _enabled) widget.onReorder(grab.oldIndex, destination);
  }

  void _cancel({bool notify = true}) {
    if (_grab == null) return;
    _autoScroll?.stopAutoScroll();
    _autoScroll = null;
    void reset() {
      _grab = null;
      _preview = null;
      _dropFrom = null;
      _revision++;
      _index();
    }

    if (notify) {
      setState(reset);
    } else {
      reset();
    }
  }

  Widget _handle(T item) {
    final cell = _cells[item]!;
    final labels = FrostScope.labelsOf(context);
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _key(item, event),
      child: GestureDetector(
        onVerticalDragStart: _enabled ? (details) => _start(item, details) : null,
        onVerticalDragUpdate: _enabled ? _update : null,
        onVerticalDragEnd: _enabled ? (_) => _finish() : null,
        onVerticalDragCancel: _cancel,
        child: Semantics(
          label: labels.reorderHandle,
          value: labels.itemPosition(_orderIndices[item]! + 1, widget.items.length),
          button: true,
          enabled: _enabled,
          toggled: _grab != null && _grab!.item == item,
          excludeSemantics: true,
          child: FrostClickSurface(
            focusNode: cell.focus,
            onTap: _enabled ? () => _toggle(item) : null,
            child: SizedBox.square(
              dimension: FrostDensity.of(context).targetHeight,
              child: Center(
                child: FrostIcon(
                  FrostIconSet.of(context).dragHandle,
                  size: FrostControlSize.compact.iconSize,
                  color: FrostThemeTokens.of(context).textTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: _buildProxy,
    child: _LazyReorderListView(
      controller: _scroll,
      semanticChildCount: _order.length,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = _order[index];
          final cell = _cells.putIfAbsent(item, _Cell.new);
          final dragging = _grab != null && _grab!.item == item && _grab!.pointer;
          if (!dragging) {
            cell.body = Row(
              children: [
                Expanded(child: widget.itemBuilder(context, item)),
                _handle(item),
              ],
            );
          }
          return KeyedSubtree(
            key: ValueKey<T>(item),
            child: _ReorderKeepAlive(
              keep: _grab != null && _grab!.item == item,
              child: FrostReorderMotion(
                key: cell.slot,
                revision: _revision,
                scrollOffset: () => _scrollOffset,
                spring: FrostMotion.standard,
                reduced: MediaQuery.disableAnimationsOf(context),
                tickers: TickerMode.valuesOf(context).enabled,
                from: _dropFrom != null && item == _dropItem ? _dropFrom : null,
                child: dragging
                    ? SizedBox(height: _grab!.size!.height)
                    : _ReorderLift(key: cell.content, lifted: _grab != null && _grab!.item == item, child: cell.body!),
              ),
            ),
          );
        },
        childCount: _order.length,
        addRepaintBoundaries: false,
        findChildIndexCallback: (key) => key is ValueKey<T> ? _orderIndices[key.value] : null,
      ),
    ),
  );
  @override
  void dispose() {
    _autoScroll?.stopAutoScroll();
    for (final cell in _cells.values) {
      cell.dispose();
    }
    _scroll.dispose();
    _proxyPosition.dispose();
    super.dispose();
  }
}

class _ReorderLift extends StatelessWidget {
  const _ReorderLift({required this.lifted, required this.child, super.key});
  final bool lifted;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return FrostSpringBuilder(
      value: lifted && !MediaQuery.disableAnimationsOf(context) ? _reorderLiftScale : 1,
      spring: FrostMotion.standard,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        decoration: ShapeDecoration(
          shape: FrostRadius.shape(context, FrostRadius.sm),
          color: lifted ? tokens.surface : Colors.transparent,
          shadows: lifted ? tokens.shadowAmbient : const [],
        ),
        child: child,
      ),
    );
  }
}

/// Cached rows can still occupy the viewport while springing out to a new slot.
/// Paint the finite cache as well as the new visible range; the scroll view's
/// normal clip confines it. Layout and child construction remain fully lazy.
class _LazyReorderListView extends ListView {
  const _LazyReorderListView({required super.controller, required SliverChildDelegate delegate, required super.semanticChildCount})
    : super.custom(childrenDelegate: delegate);
  @override
  Widget buildChildLayout(BuildContext context) => _ReorderSliver(delegate: childrenDelegate);
}

class _ReorderSliver extends SliverList {
  const _ReorderSliver({required super.delegate});
  @override
  RenderSliverList createRenderObject(BuildContext context) => _PaintCachedReorderList(childManager: context as SliverMultiBoxAdaptorElement);
}

class _PaintCachedReorderList extends RenderSliverList {
  _PaintCachedReorderList({required super.childManager});
  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    final boxes = BoxHitTestResult.wrap(result);
    RenderBox? child = lastChild;
    while (child != null) {
      final motion = frostReorderMotionBoxOf(child);
      final hit = boxes.addWithPaintOffset(
        offset: Offset(childCrossAxisPosition(child), childMainAxisPosition(child)),
        position: Offset(crossAxisPosition, mainAxisPosition),
        hitTest: (result, point) => (motion ?? child!).hitTest(result, position: point),
      );
      if (hit) return true;
      child = childBefore(child);
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!geometry!.visible) return;
    RenderBox? child = firstChild;
    while (child != null) {
      context.paintChild(child, offset + Offset(childCrossAxisPosition(child), childMainAxisPosition(child)));
      child = childAfter(child);
    }
  }
}

class _ReorderKeepAlive extends StatefulWidget {
  const _ReorderKeepAlive({required this.keep, required this.child});
  final bool keep;
  final Widget child;
  @override
  State<_ReorderKeepAlive> createState() => _ReorderKeepAliveState();
}

class _ReorderKeepAliveState extends State<_ReorderKeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keep;
  @override
  void didUpdateWidget(_ReorderKeepAlive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keep != widget.keep) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
