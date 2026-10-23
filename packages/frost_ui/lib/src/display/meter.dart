import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../motion/spring.dart';
import '_data_track.dart';

class FrostMeter extends StatelessWidget {
  const FrostMeter({required this.value, this.min = 0, this.max = 1, this.marks = const [], this.dataColor = 0, required this.semanticLabel, super.key})
    : assert(min > double.negativeInfinity && max < double.infinity && max > min);
  final double value, min, max;
  final List<double> marks;
  final int dataColor;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context), clamped = value.clamp(min, max);
    final height = marks.isEmpty ? frostMeterMarkerSize : frostMeterMarkerSize / 2 + frostDataTrackHeight / 2 + FrostGap.inline + frostMeterMarkHeight;
    return Semantics(
      label: semanticLabel,
      value: clamped.toString(),
      excludeSemantics: true,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: tokens.categorical[dataColor % tokens.categorical.length]),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        builder: (context, color, _) => FrostSpringBuilder(
          value: (clamped - min) / (max - min),
          spring: FrostMotion.snappy,
          builder: (context, progress, _) => SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: FrostDataTrackPainter(
                track: tokens.fillStrong,
                data: color!,
                direction: Directionality.of(context),
                marker: progress,
                surface: tokens.surface,
                markInk: tokens.textTertiary,
                marks: [for (final mark in marks) (mark.clamp(min, max) - min) / (max - min)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
