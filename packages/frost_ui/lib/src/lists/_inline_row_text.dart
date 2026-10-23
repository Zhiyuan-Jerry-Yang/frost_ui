import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';

/// Shared cold-layout text flow. Only the canonical title is allowed to wrap;
/// the translation occupies the remainder of that first, baseline-aligned line.
class FrostInlineRowText extends MultiChildRenderObjectWidget {
  FrostInlineRowText({required Widget title, required Widget subtitle, required this.direction, super.key}) : super(children: [title, subtitle]);
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderInlineText(direction);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderInlineText).direction = direction;
}

class _InlineParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderInlineText extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _InlineParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _InlineParentData> {
  _RenderInlineText(this._direction);
  TextDirection _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  bool _showSubtitle = false;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _InlineParentData) child.parentData = _InlineParentData();
  }

  Size _measure(BoxConstraints limits, {required bool dry}) {
    final title = firstChild!, subtitle = lastChild!;
    final available = limits.hasBoundedWidth ? limits.maxWidth : getMaxIntrinsicWidth(double.infinity);
    Size measure(RenderBox child, BoxConstraints bounds) {
      if (dry) return child.getDryLayout(bounds);
      child.layout(bounds, parentUsesSize: true);
      return child.size;
    }

    final titleSize = measure(title, BoxConstraints(maxWidth: available));
    final subtitleWidth = math.max(0.0, available - titleSize.width - FrostGap.related);
    final subtitleBounds = BoxConstraints(maxWidth: subtitleWidth);
    final subtitleSize = measure(subtitle, subtitleBounds);
    final visible = subtitleWidth > 0;
    double baseline(RenderBox child, BoxConstraints bounds, Size measured) =>
        (dry ? child.getDryBaseline(bounds, TextBaseline.alphabetic) : child.getDistanceToBaseline(TextBaseline.alphabetic)) ?? measured.height;
    final titleBaseline = baseline(title, BoxConstraints(maxWidth: available), titleSize);
    final subtitleBaseline = visible ? baseline(subtitle, subtitleBounds, subtitleSize) : titleBaseline;
    final baselineY = math.max(titleBaseline, subtitleBaseline);
    final titleY = baselineY - titleBaseline;
    final subtitleY = baselineY - subtitleBaseline;
    final width = titleSize.width + (visible ? FrostGap.related + subtitleSize.width : 0);
    final size = limits.constrain(Size(width, math.max(titleY + titleSize.height, visible ? subtitleY + subtitleSize.height : 0)));
    if (!dry) {
      _showSubtitle = visible;
      (title.parentData! as _InlineParentData).offset = Offset(_direction == TextDirection.ltr ? 0 : size.width - titleSize.width, titleY);
      (subtitle.parentData! as _InlineParentData).offset = Offset(
        _direction == TextDirection.ltr ? titleSize.width + FrostGap.related : size.width - titleSize.width - FrostGap.related - subtitleSize.width,
        subtitleY,
      );
    }
    return size;
  }

  @override
  void performLayout() => size = _measure(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, dry: true);
  @override
  double computeMaxIntrinsicWidth(double height) => firstChild!.getMaxIntrinsicWidth(height) + FrostGap.related + lastChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicWidth(double height) => firstChild!.getMinIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(firstChild!, offset + (firstChild!.parentData! as _InlineParentData).offset);
    if (_showSubtitle) context.paintChild(lastChild!, offset + (lastChild!.parentData! as _InlineParentData).offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
