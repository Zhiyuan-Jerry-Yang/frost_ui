import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';

int _columns(double width, double minimum, double gap) => math.max(1, ((width + gap) / (minimum + gap)).floor());

/// Equal-width columns. Without an aspect ratio, each row adopts the height of
/// its tallest item. Requires bounded horizontal space, like a normal grid.
class FrostGrid extends StatelessWidget {
  const FrostGrid({required this.minItemWidth, required this.children, this.aspectRatio, super.key})
    : assert(minItemWidth > 0 && minItemWidth < double.infinity),
      assert(aspectRatio == null || aspectRatio > 0 && aspectRatio < double.infinity);
  final double minItemWidth;
  final List<Widget> children;
  final double? aspectRatio;
  @override
  Widget build(BuildContext context) =>
      _GridLayout(minimum: minItemWidth, ratio: aspectRatio, gap: FrostGap.of(context).grid, direction: Directionality.of(context), children: children);
}

/// A lazy grid needs a fixed aspect ratio so offscreen geometry is known.
class FrostSliverGrid extends StatelessWidget {
  const FrostSliverGrid({required this.minItemWidth, required this.itemCount, required this.itemBuilder, this.aspectRatio, super.key})
    : assert(minItemWidth > 0 && minItemWidth < double.infinity),
      assert(itemCount >= 0),
      assert(aspectRatio != null && aspectRatio > 0 && aspectRatio < double.infinity);
  final double minItemWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? aspectRatio;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final gap = FrostGap.of(context).grid;
      return SliverGrid(
        delegate: SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns(constraints.crossAxisExtent, minItemWidth, gap),
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
          childAspectRatio: aspectRatio!,
        ),
      );
    },
  );
}

class _GridData extends ContainerBoxParentData<RenderBox> {}

class _GridLayout extends MultiChildRenderObjectWidget {
  const _GridLayout({required this.minimum, required this.ratio, required this.gap, required this.direction, required super.children});
  final double minimum, gap;
  final double? ratio;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGrid(this);
  @override
  void updateRenderObject(BuildContext context, _RenderGrid renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderGrid extends RenderBox with ContainerRenderObjectMixin<RenderBox, _GridData>, RenderBoxContainerDefaultsMixin<RenderBox, _GridData> {
  _RenderGrid(this.config);
  _GridLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridData) child.parentData = _GridData();
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'FrostGrid requires bounded horizontal space.');
    final columns = _columns(constraints.maxWidth, config.minimum, config.gap);
    final width = (constraints.maxWidth - config.gap * (columns - 1)) / columns;
    final items = getChildrenAsList();
    var top = 0.0;
    for (var first = 0; first < items.length; first += columns) {
      final row = items.skip(first).take(columns);
      var height = config.ratio == null ? 0.0 : width / config.ratio!;
      for (final item in row) {
        item.layout(BoxConstraints.tightFor(width: width, height: config.ratio == null ? null : height), parentUsesSize: true);
        height = math.max(height, item.size.height);
      }
      var column = 0;
      for (final item in row) {
        if (config.ratio == null) item.layout(BoxConstraints.tight(Size(width, height)), parentUsesSize: true);
        final x = column * (width + config.gap);
        (item.parentData! as _GridData).offset = Offset(config.direction == TextDirection.ltr ? x : constraints.maxWidth - x - width, top);
        column++;
      }
      top += height;
      if (first + columns < items.length) top += config.gap;
    }
    size = constraints.constrain(Size(constraints.maxWidth, top));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
