import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';
import '_measured_keyline.dart';
import 'keyline.dart';

enum FrostDividerInset { none, keyline }

/// One physical pixel. Keyline alignment changes paint, never layout.
class FrostDivider extends StatelessWidget {
  const FrostDivider({this.axis = Axis.horizontal, this.inset = FrostDividerInset.none, this.length, super.key})
    : assert(axis != Axis.vertical || inset != FrostDividerInset.keyline, 'Vertical dividers do not support keyline insets.');
  final Axis axis;
  final FrostDividerInset inset;
  final double? length;
  @override
  Widget build(BuildContext context) {
    final keyline = axis == Axis.horizontal && inset == FrostDividerInset.keyline ? FrostKeyline.maybeOf(context) : null;
    return _DividerLine(
      axis: axis,
      length: length,
      dpr: MediaQuery.devicePixelRatioOf(context),
      color: FrostThemeTokens.of(context).separator,
      direction: Directionality.of(context),
      contentStart: keyline?.contentStart ?? 0,
      textAnchor: inset == FrostDividerInset.keyline ? FrostMeasuredKeyline.of(context) : null,
      provider: keyline == null ? null : context.getElementForInheritedWidgetOfExactType<FrostKeyline>(),
    );
  }
}

class _DividerLine extends LeafRenderObjectWidget {
  const _DividerLine({
    required this.axis,
    required this.length,
    required this.dpr,
    required this.color,
    required this.direction,
    required this.contentStart,
    required this.textAnchor,
    required this.provider,
  });
  final Axis axis;
  final double? length;
  final double dpr;
  final Color color;
  final TextDirection direction;
  final double contentStart;
  final GlobalKey? textAnchor;
  final BuildContext? provider;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDivider(this);
  @override
  void updateRenderObject(BuildContext context, _RenderDivider renderObject) => renderObject.update(this);
}

class _RenderDivider extends RenderBox {
  _RenderDivider(this.spec);
  _DividerLine spec;
  double get thickness => 1 / spec.dpr;
  void update(_DividerLine value) {
    if (spec.axis != value.axis || spec.length != value.length || spec.dpr != value.dpr) markNeedsLayout();
    spec = value;
    markNeedsPaint();
  }

  @override
  double computeMinIntrinsicWidth(double height) => spec.axis == Axis.vertical ? thickness : 0;
  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) => spec.axis == Axis.horizontal ? thickness : spec.length ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    spec.axis == Axis.horizontal
        ? Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, thickness)
        : Size(thickness, spec.length ?? (constraints.hasBoundedHeight ? constraints.maxHeight : 0)),
  );
  @override
  void performLayout() {
    assert(spec.axis != Axis.vertical || spec.length != null || constraints.hasBoundedHeight, 'A vertical divider needs length or a bounded parent height.');
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final origin = localToGlobal(Offset.zero);
    // Resolve a physical hairline after the final canvas transform. Global
    // snapping recorded into a retained row layer becomes stale when a sliver
    // moves that layer, and can be clipped away at the next row boundary.
    final paint = Paint()
      ..color = spec.color
      ..strokeWidth = 0
      ..isAntiAlias = false;
    if (spec.axis == Axis.vertical) {
      final x = offset.dx + thickness / 2;
      context.canvas.drawLine(Offset(x, offset.dy), Offset(x, offset.dy + size.height), paint);
      return;
    }
    var inset = 0.0;
    // A grouped row can be replaced during this frame. GlobalKey still exposes
    // its inactive Element until finalization; findRenderObject asserts there.
    // Read the public Element render reference and only use attached boxes.
    RenderObject? attachedRender(BuildContext? source) {
      if (source is! Element || !source.mounted) return null;
      final render = source.renderObject;
      return render?.attached == true ? render : null;
    }

    final text = attachedRender(spec.textAnchor?.currentContext);
    final provider = attachedRender(spec.provider);
    if (text is RenderBox && text.attached && text.hasSize) {
      final textOrigin = text.localToGlobal(Offset.zero);
      inset = (spec.direction == TextDirection.ltr ? textOrigin.dx - origin.dx : origin.dx + size.width - textOrigin.dx - text.size.width).clamp(
        0.0,
        size.width,
      );
    } else if (provider is RenderBox && provider.attached) {
      final providerOrigin = provider.localToGlobal(Offset.zero);
      final existing = spec.direction == TextDirection.ltr ? origin.dx - providerOrigin.dx : providerOrigin.dx + provider.size.width - origin.dx - size.width;
      inset = math.max(0.0, spec.contentStart - existing).clamp(0.0, size.width);
    }
    final start = spec.direction == TextDirection.ltr ? inset : 0.0;
    final y = offset.dy + thickness / 2;
    context.canvas.drawLine(Offset(offset.dx + start, y), Offset(offset.dx + start + size.width - inset, y), paint);
  }
}
