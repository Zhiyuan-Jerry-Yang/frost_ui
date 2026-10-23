import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';

// Two half modules need their full minimum width plus the intervening gap.
const _minimumHalfWidth = 160.0;

enum FrostModuleSpan { half, full }

class FrostModuleGridItem {
  const FrostModuleGridItem({required this.child, this.span = FrostModuleSpan.half});
  final Widget child;
  final FrostModuleSpan span;
}

/// Consecutive halves pair in source order. An unpaired half stays in the
/// leading column (left in LTR). Both cells are equal height on their first frame.
class FrostModuleGrid extends StatefulWidget {
  const FrostModuleGrid({required this.items, super.key});
  final List<FrostModuleGridItem> items;
  @override
  State<FrostModuleGrid> createState() => _ModuleGridState();
}

class _ModuleGridState extends State<FrostModuleGrid> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMotionSize(
    duration: FrostMotion.duration(context, FrostMotion.layoutFade),
    alignment: AlignmentDirectional.topStart,
    child: FrostLayoutCrossfade(
      layoutIdentity: _identity,
      settleDuration: Duration.zero,
      child: _GridLayout(
        identity: _identity,
        spans: [for (final item in widget.items) item.span],
        direction: Directionality.of(context),
        children: [for (final item in widget.items) item.child],
      ),
    ),
  );
}

class _Data extends ContainerBoxParentData<RenderBox> {}

class _GridLayout extends MultiChildRenderObjectWidget {
  const _GridLayout({required this.identity, required this.spans, required this.direction, required super.children});
  final FrostLayoutIdentity identity;
  final List<FrostModuleSpan> spans;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGrid(this);
  @override
  void updateRenderObject(BuildContext context, _RenderGrid renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderGrid extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderGrid(this.config);
  _GridLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  Size _layout(BoxConstraints limits, {required bool dry}) {
    final children = getChildrenAsList();
    final width = limits.hasBoundedWidth ? limits.maxWidth : _minimumHalfWidth * 2 + FrostGap.group;
    final wide = width >= _minimumHalfWidth * 2 + FrostGap.group;
    final half = (width - FrostGap.group) / 2;
    if (!dry) config.identity.update((wide, Object.hashAll(config.spans)), viewport: limits);
    Size measure(RenderBox child, double width, [double? height]) {
      final c = BoxConstraints.tightFor(width: width, height: height);
      if (dry) return child.getDryLayout(c);
      child.layout(c, parentUsesSize: true);
      return child.size;
    }

    void place(RenderBox child, double start, double top, double childWidth) {
      if (!dry) (child.parentData! as _Data).offset = Offset(config.direction == TextDirection.ltr ? start : width - start - childWidth, top);
    }

    var y = 0.0;
    for (var i = 0; i < children.length;) {
      final isHalf = wide && config.spans[i] == FrostModuleSpan.half;
      final paired = isHalf && i + 1 < children.length && config.spans[i + 1] == FrostModuleSpan.half;
      final cell = isHalf ? half : width;
      var height = measure(children[i], cell).height;
      if (paired) height = math.max(height, measure(children[i + 1], cell).height);
      measure(children[i], cell, height);
      place(children[i], 0, y, cell);
      if (paired) {
        measure(children[i + 1], cell, height);
        place(children[i + 1], cell + FrostGap.group, y, cell);
      }
      i += paired ? 2 : 1;
      y += height + (i < children.length ? FrostGap.group : 0);
    }
    return limits.constrain(Size(width, y));
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);
  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
