import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shared lazy centered viewport. A fitted selector reports its sliver extent;
/// a plain list keeps its allocated height. Short lists expose earlier rows on
/// the cold frame without querying intrinsic heights or guessing row extents.
class FrostListScrollView extends CustomScrollView {
  const FrostListScrollView({this.fitContent = false, super.controller, required super.center, required super.slivers, super.key});
  final bool fitContent;
  @override
  Widget buildViewport(BuildContext context, ViewportOffset offset, AxisDirection axisDirection, List<Widget> slivers) =>
      _ListViewport(fitContent: fitContent, offset: offset, axisDirection: axisDirection, center: center, slivers: slivers);
}

class _ListViewport extends Viewport {
  _ListViewport({required this.fitContent, required super.offset, required super.axisDirection, required super.center, required super.slivers});
  final bool fitContent;
  @override
  _RenderListViewport createRenderObject(BuildContext context) => _RenderListViewport(
    fitContent,
    offset: offset,
    axisDirection: axisDirection,
    crossAxisDirection: Viewport.getDefaultCrossAxisDirection(context, axisDirection),
  );
  @override
  void updateRenderObject(BuildContext context, _RenderListViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.fitContent = fitContent;
  }
}

class _RenderListViewport extends RenderViewport {
  _RenderListViewport(this._fitContent, {required super.offset, required super.axisDirection, required super.crossAxisDirection});
  bool _fitContent;
  set fitContent(bool value) {
    if (_fitContent == value) return;
    _fitContent = value;
    markNeedsLayout();
  }

  double _fittedAnchor = 0;
  @override
  bool get sizedByParent => false;
  @override
  double get anchor => _fittedAnchor;
  @override
  void performLayout() {
    size = constraints.biggest;
    _fittedAnchor = 0;
    super.performLayout();
    var extent = 0.0, before = 0.0;
    var preceding = true;
    for (var sliver = firstChild; sliver != null; sliver = childAfter(sliver)) {
      if (sliver == center) preceding = false;
      final height = sliver.geometry!.scrollExtent;
      extent += height;
      if (preceding) before += height;
    }
    if (_fitContent) size = constraints.constrain(Size(constraints.maxWidth, math.min(extent, constraints.maxHeight)));
    if (extent <= constraints.maxHeight && size.height > 0) {
      _fittedAnchor = before / size.height;
      super.performLayout();
    }
  }
}
