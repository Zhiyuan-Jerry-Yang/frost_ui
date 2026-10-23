import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controls/buttons.dart';
import '../display/section_header.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../primitives/_scroll_edge_fade.dart';
import '../primitives/keyline.dart';

/// A titled horizontal row of items. The title, its actions and the first and
/// last items share one inset, so the row lines up with the grid below it.
/// Pointer platforms also get previous/next buttons next to the title,
/// because a mouse wheel does not scroll a horizontal list.
class FrostShelf extends StatefulWidget {
  const FrostShelf({
    required this.title,
    required this.itemCount,
    required this.itemExtent,
    required this.height,
    required this.itemBuilder,
    this.action,
    this.spacing = FrostGap.group,
    this.inset,
    super.key,
  });

  final String title;
  final int itemCount;
  final double itemExtent;
  final double height;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? action;
  final double spacing;

  /// Defaults to [FrostMetrics.browseInset] for the shelf's own width.
  final double? inset;

  /// Item size that fills [width] with [count] items, within [min]..[max].
  static double fillingExtent({required double width, required int count, required double min, required double max, double spacing = FrostGap.group}) {
    if (count <= 0 || !width.isFinite) return min;
    return ((width - spacing * (count - 1)) / count).clamp(min, max);
  }

  @override
  State<FrostShelf> createState() => _ContentShelfState();
}

class _ContentShelfState extends State<FrostShelf> {
  // This private horizontal position must never read the page's vertical key.
  final _controller = ScrollController(keepScrollOffset: false);
  final _edges = ValueNotifier((back: false, forward: false));
  ({bool back, bool forward}) _pendingEdges = (back: false, forward: false);
  bool _edgeUpdateScheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    _edges.dispose();
    super.dispose();
  }

  bool _updateEdges(ScrollMetrics metrics) {
    _pendingEdges = (back: metrics.extentBefore > 0, forward: metrics.extentAfter > 0);
    // Applying viewport dimensions can synchronously emit scroll notifications
    // during layout. Even a ValueNotifier would rebuild its listeners there;
    // coalesce those notifications until the frame ends, using latest metrics.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (!_edgeUpdateScheduled) {
        _edgeUpdateScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _edgeUpdateScheduled = false;
          if (mounted) _edges.value = _pendingEdges;
        });
      }
    } else {
      _edges.value = _pendingEdges;
    }
    return false;
  }

  double get _spacing => widget.spacing == FrostGap.group ? FrostGap.of(context).group : widget.spacing;

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final step = math.max(widget.itemExtent + _spacing, position.viewportDimension - widget.itemExtent);
    final target = (position.pixels + step * direction).clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = FrostMotion.duration(context, FrostMotion.expand);
    if (duration == Duration.zero) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointer = switch (Theme.of(context).platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = widget.inset ?? FrostMetrics.browseInset(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder(
              valueListenable: _edges,
              builder: (context, _, _) {
                // The fixed item geometry also establishes cold-frame and resize
                // button states before ScrollPosition applies new dimensions.
                final maximum = math.max(
                  0.0,
                  inset * 2 + widget.itemCount * widget.itemExtent + math.max(0, widget.itemCount - 1) * _spacing - constraints.maxWidth,
                );
                final pixels = _controller.hasClients ? _controller.position.pixels.clamp(0.0, maximum) : 0.0;
                final edges = (back: pixels > 0, forward: pixels < maximum);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: FrostKeyline(
                    leadingRoom: inset,
                    trailingRoom: inset,
                    edgeDistanceStart: inset,
                    edgeDistanceEnd: inset,
                    insideContainer: false,
                    contentStart: inset,
                    child: FrostSectionHeader(
                      title: widget.title,
                      trailing: [
                        ?widget.action,
                        if (pointer) ...[
                          FrostButton.icon(
                            label: FrostScope.labelsOf(context).previous,
                            size: FrostControlSize.compact,
                            onPressed: edges.back ? () => _page(-1) : null,
                            icon: FrostIconSet.of(context).chevronLeft,
                          ),
                          FrostButton.icon(
                            label: FrostScope.labelsOf(context).next,
                            size: FrostControlSize.compact,
                            onPressed: edges.forward ? () => _page(1) : null,
                            icon: FrostIconSet.of(context).chevronRight,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(
              height: widget.height,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) => _updateEdges(notification.metrics),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => _updateEdges(notification.metrics),
                  child: FrostScrollEdgeFade(
                    controller: _controller,
                    repaint: _edges,
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      itemCount: widget.itemCount,
                      separatorBuilder: (context, index) => SizedBox(width: _spacing),
                      itemBuilder: (context, index) => SizedBox(width: widget.itemExtent, child: widget.itemBuilder(context, index)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
