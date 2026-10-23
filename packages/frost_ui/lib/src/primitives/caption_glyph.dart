import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Caption button glyphs, drawn rather than loaded so the plugin ships no
/// icon assets. Shapes follow the Windows caption buttons.
enum FrostCaptionGlyphKind { minimize, maximize, restore, close, retry }

class FrostCaptionGlyph extends StatelessWidget {
  const FrostCaptionGlyph(this.kind, {required this.color, this.size = 10, super.key});

  final FrostCaptionGlyphKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _GlyphBox(kind: kind, color: color, extent: size, dpr: MediaQuery.devicePixelRatioOf(context));
}

class _GlyphBox extends LeafRenderObjectWidget {
  const _GlyphBox({required this.kind, required this.color, required this.extent, required this.dpr});
  final FrostCaptionGlyphKind kind;
  final Color color;
  final double extent;
  final double dpr;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGlyph(this);
  @override
  void updateRenderObject(BuildContext context, _RenderGlyph renderObject) => renderObject.update(this);
}

class _RenderGlyph extends RenderBox {
  _RenderGlyph(this.spec);
  _GlyphBox spec;
  void update(_GlyphBox value) {
    if (spec.extent != value.extent) markNeedsLayout();
    spec = value;
    markNeedsPaint();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size.square(spec.extent));
  @override
  double computeMinIntrinsicWidth(double height) => spec.extent;
  @override
  double computeMaxIntrinsicWidth(double height) => spec.extent;
  @override
  double computeMinIntrinsicHeight(double width) => spec.extent;
  @override
  double computeMaxIntrinsicHeight(double width) => spec.extent;
  @override
  void performLayout() => size = computeDryLayout(constraints);
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    _GlyphPainter(spec.kind, spec.color, spec.dpr).paint(context.canvas, size, localToGlobal(Offset.zero));
    context.canvas.restore();
  }
}

class _GlyphPainter {
  const _GlyphPainter(this.kind, this.color, this.devicePixelRatio);

  final FrostCaptionGlyphKind kind;
  final Color color;
  final double devicePixelRatio;

  void paint(Canvas canvas, Size size, Offset origin) {
    // One physical pixel wide strokes at 100%, matching the system glyphs.
    final stroke = math.max(1.0, devicePixelRatio.roundToDouble()) / devicePixelRatio;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = kind == FrostCaptionGlyphKind.close || kind == FrostCaptionGlyphKind.retry;
    final w = size.width;
    final h = size.height;
    // Align strokes to the pixel grid.
    final half = stroke / 2;
    // Snap stroke centres against the actual window origin, including
    // fractional layout offsets. Local rounding alone loses thin strokes.
    double x(double value) => ((origin.dx + value) * devicePixelRatio - stroke * devicePixelRatio / 2).round() / devicePixelRatio + half - origin.dx;
    double y(double value) => ((origin.dy + value) * devicePixelRatio - stroke * devicePixelRatio / 2).round() / devicePixelRatio + half - origin.dy;
    Offset point(double dx, double dy) => Offset(x(dx), y(dy));
    double edgeX(double value) => ((origin.dx + value) * devicePixelRatio).round() / devicePixelRatio - origin.dx;
    double edgeY(double value) => ((origin.dy + value) * devicePixelRatio).round() / devicePixelRatio - origin.dy;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = false;
    void horizontal(double left, double right, double top) => canvas.drawRect(Rect.fromLTWH(edgeX(left), edgeY(top), edgeX(right) - edgeX(left), stroke), fill);
    void vertical(double left, double top, double bottom) => canvas.drawRect(Rect.fromLTWH(edgeX(left), edgeY(top), stroke, edgeY(bottom) - edgeY(top)), fill);
    void frame(double left, double top, double right, double bottom) {
      horizontal(left, right, top);
      horizontal(left, right, bottom - stroke);
      vertical(left, top, bottom);
      vertical(right - stroke, top, bottom);
    }

    switch (kind) {
      case FrostCaptionGlyphKind.minimize:
        horizontal(0, w, h / 2);
      case FrostCaptionGlyphKind.maximize:
        frame(0, 0, w, h);
      case FrostCaptionGlyphKind.restore:
        final inset = w * .2;
        frame(0, inset, w - inset, h);
        horizontal(inset, w, 0);
        vertical(inset, 0, inset);
        vertical(w - stroke, 0, h - inset);
        horizontal(w - inset, w, h - inset - stroke);
      case FrostCaptionGlyphKind.close:
        canvas.drawLine(point(half, half), point(w - half, h - half), paint);
        canvas.drawLine(point(w - half, half), point(half, h - half), paint);
      case FrostCaptionGlyphKind.retry:
        final rect = Rect.fromLTWH(half, half, w - stroke, h - stroke);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 1.6, false, paint);
        final tip = Offset(w / 2, half);
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx - w * .3, tip.dy - h * .05)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(tip.dx - w * .2, tip.dy + h * .25),
          paint,
        );
    }
  }
}
