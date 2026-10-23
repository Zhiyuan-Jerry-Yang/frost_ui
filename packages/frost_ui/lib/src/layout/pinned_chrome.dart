import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '../navigation/shell_navigation_scope.dart';
import '../primitives/_page_outline.dart';
import '../primitives/surface.dart';
import 'auto_scaffold.dart' show FrostAutoScaffold;
import 'window_caption_scope.dart';

part 'pinned_chrome_glass.dart';

/// A bar pinned over the top of a scrolling body. The body scrolls beneath
/// the bar, and the bar's glass material appears once content is actually
/// underneath it, so a page at rest keeps one continuous backdrop.
///
/// The body receives the bar's height as its top [MediaQuery] padding, which
/// insets the scrollbar; scroll views add [FrostChromeSpacer] as their first
/// sliver so the first item starts below the bar.
///
/// System top and horizontal safe areas surround chrome, without changing its
/// own height. Chrome descendants receive consumed MediaQuery padding. Nested
/// pinned bars do not mistake the body's reserved bar height for a system inset.
///
/// Scrolling over the bar scrolls the list beneath it: wheel and drag input
/// that no control in the bar takes goes to the vertical scroll view under
/// the pointer.
class FrostPinnedChrome extends StatefulWidget {
  const FrostPinnedChrome({required this.chrome, required this.body, this.extent, super.key});

  /// Fixed height of the bar, including any top safe area it covers. When
  /// null the bar is measured during layout before the body is laid out.
  final double? extent;

  final Widget chrome;
  final Widget body;

  @override
  State<FrostPinnedChrome> createState() => _FpPinnedChromeState();
}

class _FpPinnedChromeState extends State<FrostPinnedChrome> {
  /// How much of the glass is showing: it follows the first [_revealDistance]
  /// of scrolling, so the bar stops wherever the finger stops instead of
  /// snapping in at a threshold.
  double _coverage = 0;

  final _bodyKey = GlobalKey();

  /// Vertical scroll views in the body, gathered from their metrics
  /// notifications; input over the bar goes to the one under the pointer.
  final _scrollables = <ScrollableState>{};
  Drag? _drag;
  ScrollMetrics? _pendingMetrics;
  bool _coverageUpdateScheduled = false;

  static const _revealDistance = 24.0;

  bool _handleMetrics(ScrollMetricsNotification notification) {
    _track(notification.context);
    _refreshCoverage(notification.metrics);
    return false;
  }

  void _track(BuildContext? context) {
    final scrollable = context?.findAncestorStateOfType<ScrollableState>();
    if (scrollable != null && scrollable.position.axis == Axis.vertical) _scrollables.add(scrollable);
  }

  /// The deepest visible vertical scroll view in the body at [global].
  ScrollPosition? _scrollTargetAt(Offset global) {
    final body = _bodyKey.currentContext?.findRenderObject();
    if (body is! RenderBox || !body.hasSize) return null;
    final result = BoxHitTestResult();
    if (!body.hitTest(result, position: body.globalToLocal(global))) return null;
    final depth = <HitTestTarget, int>{};
    for (final (index, entry) in result.path.indexed) {
      depth.putIfAbsent(entry.target, () => index);
    }
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    ScrollableState? target;
    var targetDepth = result.path.length;
    for (final scrollable in _scrollables) {
      final index = depth[scrollable.context.findRenderObject()];
      if (index != null && index < targetDepth && scrollable.position.axis == Axis.vertical) {
        target = scrollable;
        targetDepth = index;
      }
    }
    return target?.position;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = _scrollTargetAt(event.position);
    if (position == null || !position.hasPixels) return;
    final delta = axisDirectionIsReversed(position.axisDirection) ? -event.scrollDelta.dy : event.scrollDelta.dy;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (delta == 0 || target == position.pixels) return;
    // A control in the bar that scrolls registered first and keeps the event.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) => position.pointerScroll(delta));
  }

  void _handleDragStart(DragStartDetails details) {
    final position = _scrollTargetAt(details.globalPosition);
    if (position == null) return;
    _drag = position.drag(details, () => _drag = null);
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    _track(notification.context);
    _refreshCoverage(notification.metrics);
    return false;
  }

  void _refreshCoverage(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // Restoring a scrolled pane or changing its content can start/end a
      // ballistic activity inside applyContentDimensions. Do not interrupt that
      // layout with setState: only the paint-only glass coverage needs updating.
      _pendingMetrics = metrics;
      if (!_coverageUpdateScheduled) {
        _coverageUpdateScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _coverageUpdateScheduled = false;
          final pending = _pendingMetrics;
          _pendingMetrics = null;
          if (mounted && pending != null) _applyCoverage(pending);
        });
      }
      return;
    }
    // A newer input/metrics event supersedes any queued layout notification.
    _pendingMetrics = null;
    _applyCoverage(metrics);
  }

  void _applyCoverage(ScrollMetrics metrics) {
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    // Independently scrolling panes share one band. A pane returning to zero
    // must not hide glass while another pane still has content under the bar.
    var coverage = (metrics.extentBefore / _revealDistance).clamp(0.0, 1.0);
    for (final scrollable in _scrollables) {
      final position = scrollable.position;
      if (position.hasContentDimensions) {
        final amount = (position.extentBefore / _revealDistance).clamp(0.0, 1.0);
        if (amount > coverage) coverage = amount;
      }
    }
    if (coverage != _coverage) setState(() => _coverage = coverage);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Body top padding describes chrome, not the system status bar. Only the
    // outer pinned bar consumes the system top; side insets remain local.
    final systemTop = _PinnedBodyScope.isInside(context) ? 0.0 : media.padding.top;
    final safeInsets = EdgeInsets.only(top: systemTop, left: media.padding.left, right: media.padding.right);
    final chrome = Padding(
      padding: safeInsets,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeLeft: true,
        removeRight: true,
        child: widget.extent != null ? SizedBox.expand(child: widget.chrome) : widget.chrome,
      ),
    );

    return CustomMultiChildLayout(
      delegate: _PinnedLayoutDelegate(widget.extent),
      children: [
        LayoutId(
          id: _PinnedSlot.body,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The delegate lays out chrome first and encodes its measured
              // height in minHeight, so this body builds correctly in this frame.
              final extent = constraints.minHeight;
              return SizedBox.expand(
                child: MediaQuery(
                  key: _bodyKey,
                  data: media.copyWith(
                    padding: media.padding.copyWith(top: extent),
                    viewPadding: media.viewPadding.copyWith(top: extent),
                  ),
                  child: _PinnedBodyScope(
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _handleMetrics,
                      child: NotificationListener<ScrollNotification>(onNotification: _handleScroll, child: widget.body),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        LayoutId(
          id: _PinnedSlot.chrome,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: RawGestureDetector(
              gestures: {
                VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(supportedDevices: ScrollConfiguration.of(context).dragDevices),
                  (recognizer) => recognizer
                    ..supportedDevices = ScrollConfiguration.of(context).dragDevices
                    ..onStart = _handleDragStart
                    ..onUpdate = ((details) => _drag?.update(details))
                    ..onEnd = ((details) => _drag?.end(details))
                    ..onCancel = (() => _drag?.cancel()),
                ),
              },
              child: FrostPinnedChromeGlass(
                opacity: FrostPinnedChromeMaterial.enabledOf(context) ? _coverage : 0,
                // The value already follows the scroll position frame by frame.
                animate: false,
                child: chrome,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// The body keeps the public MediaQuery/spacer contract, but its top padding
// must never be consumed as another system safe area by a nested pinned bar.
class _PinnedBodyScope extends InheritedWidget {
  const _PinnedBodyScope({required super.child});
  static bool isInside(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_PinnedBodyScope>() != null;
  @override
  bool updateShouldNotify(_PinnedBodyScope oldWidget) => false;
}

enum _PinnedSlot { body, chrome }

class _PinnedLayoutDelegate extends MultiChildLayoutDelegate {
  _PinnedLayoutDelegate(this.extent);
  final double? extent;

  @override
  void performLayout(Size size) {
    final fixed = extent?.clamp(0.0, size.height);
    final chromeSize = layoutChild(
      _PinnedSlot.chrome,
      BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: fixed ?? 0, maxHeight: fixed ?? size.height),
    );
    positionChild(_PinnedSlot.chrome, Offset.zero);
    layoutChild(_PinnedSlot.body, BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: chromeSize.height, maxHeight: size.height));
    positionChild(_PinnedSlot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_PinnedLayoutDelegate oldDelegate) => extent != oldDelegate.extent;
}

/// First sliver of a scroll view under [FrostPinnedChrome].
class FrostChromeSpacer extends StatelessWidget {
  const FrostChromeSpacer({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top));
}

/// A page's refresh header preceded by [FrostChromeSpacer], for bodies that
/// take a single leading sliver.
Widget frostChromeSliverHeader(Widget? header) => SliverMainAxisGroup(slivers: [const FrostChromeSpacer(), ?header]);

// DetailLayout keeps one measured chrome slot while media controls turn into a
// normal header. Only its material changes; body padding never changes on scroll.
class FrostPinnedChromeMaterial extends InheritedWidget {
  const FrostPinnedChromeMaterial({required this.enabled, required super.child, super.key});
  final bool enabled;
  static bool enabledOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPinnedChromeMaterial>()?.enabled ?? true;
  @override
  bool updateShouldNotify(FrostPinnedChromeMaterial oldWidget) => enabled != oldWidget.enabled;
}
