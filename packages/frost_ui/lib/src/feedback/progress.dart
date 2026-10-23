import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../motion/spring.dart';

// Determinate progress uses a thin capsule or the activity indicator's sizes.
const _barHeight = 4.0;
const _compactDiameter = 16.0, _regularDiameter = 20.0, _largeDiameter = 28.0;
const _regularStroke = 2.0, _largeStroke = 3.0;
// Announcements follow target progress, in five percentage point increments.
const _percentScale = 100, _announcementStep = 5;
const _percentSign = '%';

/// Actual progress, clamped to 0–1. For unknown progress use
/// FrostActivityIndicator rather than an indeterminate bar.
class FrostProgressBar extends StatelessWidget {
  const FrostProgressBar({required this.value, required this.semanticLabel, super.key});
  final double value;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => _Progress(value: value, label: semanticLabel);
}

/// Actual progress, clockwise from twelve o'clock, independent of direction.
/// For unknown progress use FrostActivityIndicator instead.
class FrostProgressRing extends StatelessWidget {
  const FrostProgressRing({required this.value, this.size = FrostControlSize.regular, required this.semanticLabel, super.key});
  final double value;
  final FrostControlSize size;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => _Progress(value: value, label: semanticLabel, ring: size);
}

/// Library-only palette override; geometry, spring and painter stay shared.
class FrostProgressInk extends InheritedWidget {
  const FrostProgressInk({required this.ink, required super.child, super.key});
  final Color ink;
  static Color? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostProgressInk>()?.ink;
  @override
  bool updateShouldNotify(FrostProgressInk oldWidget) => ink != oldWidget.ink;
}

class _Progress extends StatefulWidget {
  const _Progress({required this.value, required this.label, this.ring});
  final double value;
  final String label;
  final FrostControlSize? ring;
  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  late int _announced = _percent;
  int get _percent => (widget.value.clamp(0.0, 1.0) * _percentScale).round();
  @override
  void didUpdateWidget(_Progress oldWidget) {
    super.didUpdateWidget(oldWidget);
    final percent = _percent;
    if ((percent - _announced).abs() >= _announcementStep || percent == 0 || percent == _percentScale) _announced = percent;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final diameter = switch (widget.ring) {
      null => double.infinity,
      FrostControlSize.compact => _compactDiameter,
      FrostControlSize.regular => _regularDiameter,
      FrostControlSize.large => _largeDiameter,
    };
    return Semantics(
      label: widget.label,
      value: '$_announced$_percentSign',
      excludeSemantics: true,
      child: TweenAnimationBuilder<(Color, Color)>(
        tween: FrostProgressPaletteTween(end: (tokens.fillStrong, FrostProgressInk.of(context) ?? tokens.actionFill)),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        builder: (context, colors, _) => FrostSpringBuilder(
          value: widget.value.clamp(0.0, 1.0),
          spring: FrostMotion.snappy,
          builder: (context, value, _) => SizedBox(
            width: diameter,
            height: widget.ring == null ? _barHeight : diameter,
            child: CustomPaint(
              painter: FrostProgressPainter(
                value.clamp(0.0, 1.0),
                colors.$1,
                colors.$2,
                widget.ring == null
                    ? null
                    : widget.ring == FrostControlSize.large
                    ? _largeStroke
                    : _regularStroke,
                Directionality.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared internal track palette, also used by a slider's determinate track.
class FrostProgressPaletteTween extends Tween<(Color, Color)> {
  FrostProgressPaletteTween({required super.end});
  @override
  (Color, Color) lerp(double t) => (Color.lerp(begin!.$1, end!.$1, t)!, Color.lerp(begin!.$2, end!.$2, t)!);
}

// Internal drawing contract, intentionally absent from the package exports.
class FrostProgressPainter extends CustomPainter {
  FrostProgressPainter(this.value, this.track, this.ink, this.stroke, this.direction, {this.buffered, this.bufferedInk});
  final double value;
  final Color track, ink;
  final double? buffered;
  final Color? bufferedInk;
  final double? stroke;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = track;
    if (stroke case final width?) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final rect = (Offset.zero & size).deflate(width / 2);
      canvas.drawCircle(rect.center, rect.width / 2, paint);
      if (value > 0) {
        paint.color = ink;
        if (value == 1) {
          canvas.drawCircle(rect.center, rect.width / 2, paint);
        } else {
          canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
        }
      }
    } else {
      final radius = Radius.circular(size.height / 2);
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, radius), paint);
      if (buffered != null && bufferedInk != null) {
        final width = size.width * buffered!.clamp(0.0, 1.0);
        final left = direction == TextDirection.rtl ? size.width - width : 0.0;
        paint.color = bufferedInk!;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, width, size.height), radius), paint);
      }
      if (value > 0) {
        final width = size.width * value;
        final left = direction == TextDirection.rtl ? size.width - width : 0.0;
        paint.color = ink;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, width, size.height), radius), paint);
      }
    }
  }

  @override
  bool shouldRepaint(FrostProgressPainter oldDelegate) =>
      buffered != oldDelegate.buffered ||
      bufferedInk != oldDelegate.bufferedInk ||
      value != oldDelegate.value ||
      track != oldDelegate.track ||
      ink != oldDelegate.ink ||
      stroke != oldDelegate.stroke ||
      direction != oldDelegate.direction;
}
