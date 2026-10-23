import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../foundation/spacing.dart';

// Shared data-track geometry. Meter insets derive from its marker radius.
const frostDataTrackHeight = 4.0;
const frostMeterMarkerSize = 10.0;
const frostMeterMarkerStroke = 2.0;
const frostMeterMarkWidth = 1.0;
const frostMeterMarkHeight = 6.0;

class FrostDataTrackPainter extends CustomPainter {
  const FrostDataTrackPainter({
    required this.track,
    required this.data,
    required this.direction,
    this.marker,
    this.surface,
    this.markInk,
    this.marks = const [],
    this.low,
    this.high,
  });
  final Color track, data;
  final Color? surface, markInk;
  final TextDirection direction;
  final double? marker, low, high;
  final List<double> marks;
  @override
  void paint(Canvas canvas, Size size) {
    final meter = marker != null;
    final inset = meter ? math.min(frostMeterMarkerSize / 2, size.width / 2) : 0.0;
    final width = math.max(0.0, size.width - inset * 2);
    final centerY = meter ? frostMeterMarkerSize / 2 : size.height / 2;
    double x(double fraction) => inset + width * (direction == TextDirection.ltr ? fraction : 1 - fraction);
    final rect = Rect.fromLTWH(inset, centerY - frostDataTrackHeight / 2, width, frostDataTrackHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(frostDataTrackHeight / 2)), Paint()..color = track);
    if (meter) {
      final center = Offset(x(marker!.clamp(0.0, 1.0)), centerY);
      canvas.drawCircle(center, frostMeterMarkerSize / 2, Paint()..color = surface!);
      canvas.drawCircle(
        center,
        (frostMeterMarkerSize - frostMeterMarkerStroke) / 2,
        Paint()
          ..color = data
          ..style = PaintingStyle.stroke
          ..strokeWidth = frostMeterMarkerStroke,
      );
      for (final mark in marks) {
        canvas.drawRect(
          Rect.fromLTWH(x(mark) - frostMeterMarkWidth / 2, rect.bottom + FrostGap.inline, frostMeterMarkWidth, frostMeterMarkHeight),
          Paint()..color = markInk!,
        );
      }
    } else {
      final a = x(low!.clamp(0.0, 1.0)), b = x(high!.clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(math.min(a, b), rect.top, math.max(a, b), rect.bottom), const Radius.circular(frostDataTrackHeight / 2)),
        Paint()..color = data,
      );
    }
  }

  @override
  bool shouldRepaint(FrostDataTrackPainter oldDelegate) =>
      track != oldDelegate.track ||
      data != oldDelegate.data ||
      direction != oldDelegate.direction ||
      marker != oldDelegate.marker ||
      surface != oldDelegate.surface ||
      markInk != oldDelegate.markInk ||
      low != oldDelegate.low ||
      high != oldDelegate.high ||
      !listEquals(marks, oldDelegate.marks);
}
