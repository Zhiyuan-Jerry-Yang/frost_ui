import 'package:flutter/widgets.dart';

/// Shared concentric keyboard outline, outside the control's feedback shape.
class FrostFocusOutlinePainter extends CustomPainter {
  const FrostFocusOutlinePainter(this.shape, this.color, this.width, this.direction);
  final ShapeBorder shape;
  final Color color;
  final double width;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    // Leave a two-pixel gap between the hit surface and the keyboard ring.
    final gap = width / 2 + 2;
    final rect = (Offset.zero & size).inflate(gap);
    if (rect.isEmpty) return;
    // Grow rounded corners with the ring so it stays concentric with the
    // surface instead of pinching tighter at each corner.
    final ringShape = switch (shape) {
      RoundedSuperellipseBorder(:final borderRadius) => RoundedSuperellipseBorder(borderRadius: borderRadius.resolve(direction) + BorderRadius.circular(gap)),
      RoundedRectangleBorder(:final borderRadius) => RoundedRectangleBorder(borderRadius: borderRadius.resolve(direction) + BorderRadius.circular(gap)),
      _ => shape,
    };
    canvas.drawPath(
      ringShape.getOuterPath(rect, textDirection: direction),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(FrostFocusOutlinePainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color || width != oldDelegate.width || direction != oldDelegate.direction;
}
