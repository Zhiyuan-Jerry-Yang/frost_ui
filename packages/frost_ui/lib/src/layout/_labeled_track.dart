import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '../motion/_layout_identity.dart';

// A labeled data track stays useful before labels move below it.
const frostMinimumTrackWidth = 48.0;
// RangeBar and Slider share the vertical gap after first-frame reflow.
const frostTrackBelowGap = 4.0;

class _Data extends ContainerBoxParentData<RenderBox> {}

class FrostLabeledTrackLayout extends MultiChildRenderObjectWidget {
  const FrostLabeledTrackLayout({
    required this.identity,
    required this.direction,
    required this.hasLeading,
    required this.hasTrailing,
    required this.trackHeight,
    this.minimumTrackWidth = frostMinimumTrackWidth,
    required super.children,
    super.key,
  });
  final FrostLayoutIdentity identity;
  final TextDirection direction;
  final bool hasLeading, hasTrailing;
  final double trackHeight, minimumTrackWidth;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLabeledTrack(this);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderLabeledTrack).config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderLabeledTrack extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderLabeledTrack(this.config);
  FrostLabeledTrackLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  Size _layout(BoxConstraints limits, {required bool dry}) {
    final all = getChildrenAsList(), track = all[0], low = all[1], high = all[2];
    final loWidth = low.getMaxIntrinsicWidth(double.infinity), hiWidth = high.getMaxIntrinsicWidth(double.infinity);
    final gaps = (config.hasLeading ? FrostGap.related : 0) + (config.hasTrailing ? FrostGap.related : 0);
    final width = limits.hasBoundedWidth ? limits.maxWidth : loWidth + hiWidth + gaps + config.minimumTrackWidth;
    final inline = width - loWidth - hiWidth - gaps >= config.minimumTrackWidth || !config.hasLeading && !config.hasTrailing;
    if (!dry) config.identity.update(inline, viewport: limits);
    Size measure(RenderBox child, double maxWidth, {double? height, bool tight = false}) {
      final c = BoxConstraints(minWidth: tight ? maxWidth : 0, maxWidth: maxWidth, minHeight: height ?? 0, maxHeight: height ?? double.infinity);
      if (dry) return child.getDryLayout(c);
      child.layout(c, parentUsesSize: true);
      return child.size;
    }

    void place(RenderBox child, double start, double top, double w) {
      if (!dry) (child.parentData! as _Data).offset = Offset(config.direction == TextDirection.ltr ? start : width - start - w, top);
    }

    double height;
    if (inline) {
      final a = measure(low, loWidth),
          b = measure(high, hiWidth),
          t = measure(track, math.max(0, width - loWidth - hiWidth - gaps), height: config.trackHeight, tight: true);
      height = [a.height, b.height, t.height].reduce(math.max);
      place(low, 0, (height - a.height) / 2, a.width);
      place(track, a.width + (config.hasLeading ? FrostGap.related : 0), (height - t.height) / 2, t.width);
      place(high, width - b.width, (height - b.height) / 2, b.width);
    } else {
      final cell = config.hasLeading && config.hasTrailing ? math.max(0.0, (width - FrostGap.related) / 2) : width;
      final a = measure(low, cell), b = measure(high, cell), t = measure(track, width, height: config.trackHeight, tight: true);
      height = t.height + frostTrackBelowGap + math.max(a.height, b.height);
      place(track, 0, 0, width);
      place(low, 0, t.height + frostTrackBelowGap, a.width);
      place(high, width - b.width, t.height + frostTrackBelowGap, b.width);
    }
    return limits.constrain(Size(width, height));
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);
  @override
  double computeMaxIntrinsicWidth(double height) =>
      config.minimumTrackWidth +
      getChildrenAsList().skip(1).fold(0.0, (sum, child) => sum + child.getMaxIntrinsicWidth(height)) +
      (config.hasLeading ? FrostGap.related : 0) +
      (config.hasTrailing ? FrostGap.related : 0);
  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
