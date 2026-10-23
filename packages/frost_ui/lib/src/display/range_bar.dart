import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_labeled_track.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../primitives/text.dart';
import '_data_track.dart';

// Range punctuation joins numbers without generating localized prose.
const _rangeSeparator = ' – ';

class FrostRangeBar extends StatefulWidget {
  const FrostRangeBar({
    required this.low,
    required this.high,
    this.min = 0,
    this.max = 1,
    this.lowLabel,
    this.highLabel,
    this.dataColor = 0,
    required this.semanticLabel,
    super.key,
  }) : assert(min > double.negativeInfinity && max < double.infinity && max > min);
  final double low, high, min, max;
  final String? lowLabel, highLabel;
  final int dataColor;
  final String semanticLabel;
  @override
  State<FrostRangeBar> createState() => _RangeBarState();
}

class _RangeBarState extends State<FrostRangeBar> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final a = widget.low.clamp(widget.min, widget.max), b = widget.high.clamp(widget.min, widget.max);
    final low = math.min(a, b), high = math.max(a, b), reversed = a > b;
    final lowLabel = reversed ? widget.highLabel : widget.lowLabel, highLabel = reversed ? widget.lowLabel : widget.highLabel;
    return Semantics(
      label: widget.semanticLabel,
      value: [low, high].join(_rangeSeparator),
      excludeSemantics: true,
      child: FrostMotionSize(
        duration: FrostMotion.duration(context, FrostMotion.layoutFade),
        alignment: AlignmentDirectional.topStart,
        child: FrostLayoutCrossfade(
          layoutIdentity: _identity,
          settleDuration: Duration.zero,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: tokens.categorical[widget.dataColor % tokens.categorical.length]),
            duration: FrostMotion.duration(context, FrostMotion.hover),
            curve: FrostMotion.hoverCurve,
            builder: (context, color, _) => FrostSpringBuilder(
              value: (low - widget.min) / (widget.max - widget.min),
              spring: FrostMotion.snappy,
              builder: (context, lo, _) => FrostSpringBuilder(
                value: (high - widget.min) / (widget.max - widget.min),
                spring: FrostMotion.snappy,
                builder: (context, hi, _) => FrostLabeledTrackLayout(
                  identity: _identity,
                  direction: Directionality.of(context),
                  hasLeading: lowLabel != null,
                  hasTrailing: highLabel != null,
                  trackHeight: frostDataTrackHeight,
                  children: [
                    SizedBox(
                      height: frostDataTrackHeight,
                      child: CustomPaint(
                        painter: FrostDataTrackPainter(track: tokens.fillStrong, data: color!, direction: Directionality.of(context), low: lo, high: hi),
                      ),
                    ),
                    lowLabel == null ? const SizedBox.shrink() : FrostText(lowLabel, role: FrostTextRole.caption, tone: FrostTextTone.secondary, numeric: true),
                    highLabel == null
                        ? const SizedBox.shrink()
                        : FrostText(highLabel, role: FrostTextRole.caption, tone: FrostTextTone.secondary, numeric: true, textAlign: TextAlign.end),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
