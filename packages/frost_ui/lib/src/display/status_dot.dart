import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/text.dart';
import '_status_metrics.dart';

// A status dot is intentionally smaller than a badge or an icon.
const _dotSize = frostStatusDotExtent;

enum FrostStatusTone { neutral, accent, positive, caution, negative }

class FrostStatusDot extends StatelessWidget {
  const FrostStatusDot({required this.tone, this.label, super.key});
  final FrostStatusTone tone;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final color = switch (tone) {
      FrostStatusTone.neutral => tokens.textTertiary,
      FrostStatusTone.accent => tokens.accentInk,
      FrostStatusTone.positive => tokens.positiveInk,
      FrostStatusTone.caution => tokens.cautionInk,
      FrostStatusTone.negative => tokens.negativeInk,
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FrostSkeletonShape(
            shape: const CircleBorder(),
            child: AnimatedContainer(
              duration: FrostMotion.duration(context, FrostMotion.hover),
              curve: FrostMotion.hoverCurve,
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: frostStatusLabelGap),
            Flexible(
              child: FrostText(label!, role: FrostTextRole.footnote, tone: FrostTextTone.secondary, numeric: true),
            ),
          ],
        ],
      ),
    );
  }
}
