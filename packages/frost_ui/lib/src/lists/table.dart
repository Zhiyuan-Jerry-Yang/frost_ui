import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/click_surface.dart';
import '../primitives/divider.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';
import '_selection_presentation.dart';
import '_table_cells.dart';
import 'list_row.dart';
import 'selection.dart';

// A readable default column and a narrow pointer-only resize target.
const _tableMinimumColumnWidth = 80.0;
const _tableResizeHitWidth = 8.0;

/// [text] supplies compact-list content and cell semantics explicitly. Cells
/// without it are omitted from the compact subtitle; a primary cell without
/// text becomes the leading widget with its column label as the row title.
class FrostTableColumn<T> {
  const FrostTableColumn({
    required this.label,
    required this.cell,
    this.text,
    this.sortKey,
    this.width,
    this.minWidth = _tableMinimumColumnWidth,
    this.numeric = false,
    this.primary = false,
  }) : assert(minWidth > 0 && minWidth < double.infinity),
       assert(width == null || (width > 0 && width < double.infinity));
  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final String Function(T row)? text;
  final Comparable Function(T row)? sortKey;
  final double? width;
  final double minWidth;
  final bool numeric, primary;
}

/// A lazy table with a fixed header; provide a finite height. Sorting belongs
/// to the caller. Header and rows scroll horizontally together. Resized widths
/// are stored under this widget's key in the nearest PageStorage bucket.
///
/// With selection, pointer-down selects immediately and Flutter's double-tap
/// recognizer activates. It does not read the Windows double-click setting.
/// Compact layouts use the shared selectable list's activation rules.
class FrostTable<T> extends StatefulWidget {
  const FrostTable({
    required this.columns,
    required this.rows,
    this.sortColumn,
    this.sortAscending = true,
    this.onSort,
    this.selection,
    this.onActivate,
    super.key,
  }) : assert(columns.length > 0);
  final List<FrostTableColumn<T>> columns;
  final List<T> rows;
  final int? sortColumn;
  final bool sortAscending;
  final ValueChanged<(int column, bool ascending)>? onSort;
  final FrostSelection<T>? selection;
  final ValueChanged<T>? onActivate;
  @override
  State<FrostTable<T>> createState() => _TableState<T>();
}

class _TableState<T> extends State<FrostTable<T>> {
  final _focus = FocusNode();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  final _overrides = <int, double>{};
  int? _highlight;
  bool _restored = false;
  int _revealGeneration = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      final saved = PageStorage.maybeOf(context)?.readState(context, identifier: widget.key);
      if (saved is Map<int, double>) _overrides.addAll(saved);
    }
  }

  @override
  void didUpdateWidget(FrostTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_highlight != null && _highlight! >= widget.rows.length) _highlight = widget.rows.isEmpty ? null : widget.rows.length - 1;
    _overrides.removeWhere((index, _) => index >= widget.columns.length);
  }

  @override
  void dispose() {
    _revealGeneration++;
    _focus.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  TextStyle _headerStyle(BuildContext context) => FrostTypography.of(context)
      .style(FrostTextRole.footnote)
      .copyWith(color: FrostThemeTokens.of(context).textSecondary, fontWeight: FrostTypography.of(context).style(FrostTextRole.callout).fontWeight);

  List<double> _widths(BuildContext context, double available) {
    final primary = widget.columns.indexWhere((column) => column.primary);
    final main = primary < 0 ? 0 : primary;
    final style = _headerStyle(context);
    final result = <double>[];
    for (var i = 0; i < widget.columns.length; i++) {
      final column = widget.columns[i], explicit = _overrides[i] ?? widget.columns[i].width;
      if (explicit != null) {
        result.add(math.max(column.minWidth, explicit));
      } else {
        final painter = TextPainter(
          text: TextSpan(text: column.label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        // Reserve the sort glyph even when hidden, so sorting never shifts columns.
        final sort = column.sortKey == null ? 0.0 : FrostGap.inline + FrostControlSize.compact.iconSize;
        result.add(math.max(column.minWidth, painter.width + sort + FrostGap.related * 2));
        painter.dispose();
      }
    }
    if (_overrides[main] == null && widget.columns[main].width == null) {
      final others = result.indexed.where((entry) => entry.$1 != main).fold(0.0, (sum, entry) => sum + entry.$2);
      result[main] = math.max(result[main], available - others);
    }
    return result;
  }

  void _resize(int index, double? width) {
    setState(() {
      if (width == null) {
        _overrides.remove(index);
      } else {
        _overrides[index] = math.max(widget.columns[index].minWidth, width);
      }
    });
    PageStorage.maybeOf(context)?.writeState(context, Map<int, double>.of(_overrides), identifier: widget.key);
  }

  void _point(int index) {
    _revealGeneration++;
    _focus.requestFocus();
    if (_highlight != index) setState(() => _highlight = index);
  }

  void _reveal(int index, int generation) {
    if (!mounted || generation != _revealGeneration || !_vertical.hasClients) return;
    final target = _rowKeys[index]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      return;
    }
    final position = _vertical.position;
    final step = frostControlGeometry(context, FrostControlSize.regular).height;
    final mountedRows = _rowKeys.entries.where((entry) => entry.value.currentContext != null).map((entry) => entry.key);
    if (mountedRows.isEmpty) return;
    final first = mountedRows.reduce(math.min), last = mountedRows.reduce(math.max);
    final delta = index > last ? index - last : index - first;
    final next = (position.pixels + delta * step).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) return;
    position.jumpTo(next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index, generation));
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    // Independent cell controls own their activation keys.
    if (!_focus.hasPrimaryFocus || widget.rows.isEmpty || !FrostControlScope.enabledOf(context)) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final old = _highlight;
      final next = old == null
          ? (key == LogicalKeyboardKey.arrowDown ? 0 : widget.rows.length - 1)
          : (old + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, widget.rows.length - 1);
      final generation = ++_revealGeneration;
      // Preserve direction until an offscreen lazy row has been reached.
      final target = _rowKeys[next]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: key == LogicalKeyboardKey.arrowDown
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      } else if (_vertical.hasClients) {
        final position = _vertical.position;
        final estimate = frostControlGeometry(context, FrostControlSize.regular).height;
        position.jumpTo((next * estimate).clamp(0.0, position.maxScrollExtent));
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(next, generation));
      }
      setState(() => _highlight = next);
      return KeyEventResult.handled;
    }
    if (_highlight case final index?) {
      if (key == LogicalKeyboardKey.space && widget.selection != null) {
        widget.selection!.toggle(widget.rows[index]);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter) {
        widget.onActivate?.call(widget.rows[index]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _compact(BuildContext context) {
    final primary = widget.columns.indexWhere((c) => c.primary);
    final index = primary < 0 ? 0 : primary, column = widget.columns[primary < 0 ? 0 : primary];
    Widget row(BuildContext context, T item) => FrostListRow(
      title: column.text?.call(item) ?? column.label,
      leading: column.text == null ? column.cell(context, item) : null,
      subtitle: [
        for (var i = 0; i < widget.columns.length; i++)
          if (i != index && widget.columns[i].text != null) widget.columns[i].text!(item),
      ].join(' · '),
      onPressed: widget.onActivate == null ? null : () => widget.onActivate!(item),
    );
    if (widget.selection case final selection?) {
      return FrostSelectableList<T>(selection: selection, items: widget.rows, itemBuilder: (context, item, _) => row(context, item));
    }
    return ListView.builder(controller: _vertical, itemCount: widget.rows.length, itemBuilder: (context, index) => row(context, widget.rows[index]));
  }

  @override
  Widget build(BuildContext context) {
    if (FrostSizeClass.of(context) == FrostSizeClass.compact) return _compact(context);
    Widget table = Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      onFocusChange: (_) => setState(() {}),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = _widths(context, constraints.maxWidth);
          final total = widths.fold(0.0, (a, b) => a + b);
          return SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: total,
              height: constraints.maxHeight,
              child: Semantics(
                role: SemanticsRole.table,
                container: true,
                explicitChildNodes: true,
                label: FrostScope.labelsOf(context).tableDimensions(widget.rows.length, widget.columns.length),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, widths),
                    Expanded(
                      child: Scrollable(
                        controller: _vertical,
                        excludeFromSemantics: true,
                        axisDirection: AxisDirection.down,
                        viewportBuilder: (context, offset) => Viewport(
                          offset: offset,
                          axisDirection: AxisDirection.down,
                          crossAxisDirection: Directionality.of(context) == TextDirection.ltr ? AxisDirection.right : AxisDirection.left,
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _row(context, index, widths),
                                childCount: widget.rows.length,
                                addSemanticIndexes: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (widget.selection case final selection?) table = FrostSelectionScope<T>(selection: selection, items: widget.rows, child: table);
    return table;
  }

  Widget _header(BuildContext context, List<double> widths) {
    final tokens = FrostThemeTokens.of(context), direction = Directionality.of(context);
    final geometry = frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.footnote);
    var edge = 0.0;
    return Semantics(
      role: SemanticsRole.row,
      container: true,
      explicitChildNodes: true,
      child: Stack(
        children: [
          FrostTableCells(
            widths: widths,
            numeric: widget.columns.map((c) => c.numeric).toList(),
            minimumHeight: geometry.height,
            verticalInset: geometry.verticalInset,
            horizontalInset: FrostGap.related,
            direction: direction,
            children: [
              for (var i = 0; i < widget.columns.length; i++)
                Semantics(
                  role: SemanticsRole.columnHeader,
                  container: true,
                  button: widget.columns[i].sortKey != null && widget.onSort != null,
                  onTap: widget.columns[i].sortKey == null || widget.onSort == null
                      ? null
                      : () => widget.onSort!((i, widget.sortColumn == i ? !widget.sortAscending : true)),
                  label: widget.columns[i].label,
                  value: widget.sortColumn == i
                      ? (widget.sortAscending ? FrostScope.labelsOf(context).sortAscending : FrostScope.labelsOf(context).sortDescending)
                      : null,
                  excludeSemantics: true,
                  child: FrostClickSurface(
                    onTap: widget.columns[i].sortKey == null || widget.onSort == null
                        ? null
                        : () => widget.onSort!((i, widget.sortColumn == i ? !widget.sortAscending : true)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FrostSkeletonText(child: Text(widget.columns[i].label, style: _headerStyle(context))),
                        ),
                        if (widget.columns[i].sortKey != null)
                          FrostPresence(
                            visible: widget.sortColumn == i,
                            effect: FrostPresenceEffect.expand,
                            axis: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(start: FrostGap.inline),
                              child: AnimatedRotation(
                                turns: widget.sortAscending ? 0 : .5,
                                duration: FrostMotion.duration(context, FrostMotion.hover),
                                curve: FrostMotion.hoverCurve,
                                child: FrostIcon(FrostIconSet.of(context).chevronUp, size: FrostControlSize.compact.iconSize, color: tokens.textSecondary),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          for (var i = 0; i < widths.length; i++) ...[_resizeHandle(context, i, edge += widths[i], widths[i], direction)],
        ],
      ),
    );
  }

  Widget _resizeHandle(BuildContext context, int index, double edge, double width, TextDirection direction) {
    var current = width;
    return PositionedDirectional(
      start: edge - _tableResizeHitWidth / 2,
      top: 0,
      bottom: 0,
      width: _tableResizeHitWidth,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => current = width,
            onHorizontalDragUpdate: (details) {
              current += (direction == TextDirection.ltr ? 1 : -1) * details.delta.dx;
              current = math.max(widget.columns[index].minWidth, current);
              _resize(index, current);
            },
            onDoubleTap: () => _resize(index, null),
            child: const Center(child: FrostDivider(axis: Axis.vertical)),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index, List<double> widths) {
    final item = widget.rows[index];
    Widget buildRow(BuildContext context) {
      final presentation = widget.selection == null ? null : FrostSelectionPresentation.of(context);
      final tokens = FrostThemeTokens.of(context);
      final geometry = frostControlGeometry(context, FrostControlSize.regular);
      return _TableRow(
        key: _rowKeys.putIfAbsent(index, () => GlobalKey()),
        selected: presentation?.selected,
        highlighted: _highlight == index && _focus.hasFocus,
        point: () => _point(index),
        select: presentation?.selectInTable,
        activate: widget.onActivate == null ? null : () => widget.onActivate!(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostTableCells(
              widths: widths,
              numeric: widget.columns.map((c) => c.numeric).toList(),
              minimumHeight: geometry.height,
              verticalInset: geometry.verticalInset,
              horizontalInset: FrostGap.related,
              direction: Directionality.of(context),
              children: [
                for (final column in widget.columns)
                  Semantics(
                    role: SemanticsRole.cell,
                    container: true,
                    label: column.text?.call(item),
                    excludeSemantics: column.text != null,
                    child: DefaultTextStyle(
                      style: FrostTypography.of(context).style(FrostTextRole.body, numeric: column.numeric).copyWith(color: tokens.textPrimary),
                      textAlign: column.numeric ? TextAlign.end : TextAlign.start,
                      child: column.cell(context, item),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: FrostGap.related),
              child: const FrostDivider(),
            ),
          ],
        ),
      );
    }

    return widget.selection == null
        ? buildRow(context)
        : FrostTableSelectionItem<T>(
            item: item,
            child: Builder(builder: buildRow),
          );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.child,
    required this.point,
    required this.select,
    required this.activate,
    required this.selected,
    required this.highlighted,
    super.key,
  });
  final Widget child;
  final VoidCallback point;
  final VoidCallback? select, activate;
  final bool? selected;
  final bool highlighted;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  final _marker = Object();
  bool _hover = false, _pressed = false;
  bool get _enabled => FrostControlScope.enabledOf(context);
  bool _mainTarget(PointerEvent event) {
    final hit = HitTestResult();
    GestureBinding.instance.hitTestInView(hit, event.position, event.viewId);
    for (final entry in hit.path) {
      final target = entry.target;
      if (target is RenderMetaData && identical(target.metaData, _marker)) return true;
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer) return false;
    }
    return false;
  }

  void _down(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton || !_mainTarget(event)) return;
    widget.point();
    widget.select?.call();
    setState(() => _pressed = true);
  }

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final row = MetaData(
      metaData: frostSelectionInputTarget,
      behavior: HitTestBehavior.translucent,
      child: Semantics(
        role: SemanticsRole.row,
        container: true,
        explicitChildNodes: true,
        selected: widget.selected,
        onTap: _enabled
            ? () {
                widget.point();
                if (widget.select case final select?) {
                  select();
                } else {
                  widget.activate?.call();
                }
              }
            : null,
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (event) => setState(() => _hover = _mainTarget(event)),
          onHover: (event) {
            final hover = _mainTarget(event);
            if (hover != _hover) setState(() => _hover = hover);
          },
          onExit: (_) => setState(() => _hover = false),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _down,
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: _enabled
                  ? () {
                      if (widget.select == null) widget.activate?.call();
                    }
                  : null,
              onTapCancel: _release,
              child: AnimatedContainer(
                duration: FrostMotion.duration(context, FrostMotion.hover),
                curve: FrostMotion.hoverCurve,
                color: widget.selected == true ? tokens.selectionFill : (_hover || widget.highlighted ? tokens.fillSubtle : Colors.transparent),
                child: FrostClickFeedbackVisual(
                  states: {if (_pressed) WidgetState.pressed, if (widget.highlighted) WidgetState.focused},
                  scalesOnPress: false,
                  child: MetaData(metaData: _marker, behavior: HitTestBehavior.translucent, child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: {
        if (_enabled && widget.select != null && widget.activate != null)
          _TableDoubleTap: GestureRecognizerFactoryWithHandlers<_TableDoubleTap>(
            () => _TableDoubleTap(_mainTarget),
            (recognizer) => recognizer.onDoubleTap = widget.activate,
          ),
      },
      child: row,
    );
  }
}

// A row's double-tap recognizer must not delay a nested cell button's tap.
class _TableDoubleTap extends DoubleTapGestureRecognizer {
  _TableDoubleTap(this.mainTarget);
  final bool Function(PointerEvent) mainTarget;
  @override
  bool isPointerAllowed(PointerDownEvent event) => mainTarget(event) && super.isPointerAllowed(event);
}
