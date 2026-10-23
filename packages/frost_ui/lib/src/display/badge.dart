import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/icon.dart';

// Status badges keep their unscaled vertical breathing room at larger type.
const _badgeHeight = 20.0;
const _badgeInset = 6.0;
const _badgeIconSize = 12.0;

enum FrostBadgeTone { neutral, accent, positive, caution, negative, onMedia }

/// A noninteractive status label. Its icon is decorative in text semantics.
class FrostBadge extends StatelessWidget {
  const FrostBadge({required this.label, this.tone = FrostBadgeTone.neutral, this.icon, super.key});
  final String label;
  final FrostBadgeTone tone;
  final FrostIconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final (fill, ink) = switch (tone) {
      FrostBadgeTone.neutral => (tokens.fill, tokens.textSecondary),
      FrostBadgeTone.accent => (tokens.selectionFill, tokens.accentInk),
      FrostBadgeTone.positive => (tokens.positiveTint, tokens.positiveInk),
      FrostBadgeTone.caution => (tokens.cautionTint, tokens.cautionInk),
      FrostBadgeTone.negative => (tokens.negativeTint, tokens.negativeInk),
      FrostBadgeTone.onMedia => (tokens.onMediaScrim, tokens.onMediaInk),
    };
    final style = FrostTypography.of(context).style(FrostTextRole.caption);
    final geometry = frostControlTextGeometry(baseHeight: _badgeHeight, style: style, textScaler: MediaQuery.textScalerOf(context));
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: FrostSkeletonShape(
        shape: FrostRadius.shape(context, FrostRadius.xs),
        child: AnimatedContainer(
          duration: FrostMotion.duration(context, FrostMotion.hover),
          curve: FrostMotion.hoverCurve,
          decoration: ShapeDecoration(color: fill, shape: FrostRadius.shape(context, FrostRadius.xs)),
          constraints: BoxConstraints(minHeight: geometry.height),
          padding: const EdgeInsets.symmetric(horizontal: _badgeInset),
          child: AnimatedDefaultTextStyle(
            style: style.copyWith(color: ink),
            duration: FrostMotion.duration(context, FrostMotion.hover),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final icon?) ...[
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: ink),
                    duration: FrostMotion.duration(context, FrostMotion.hover),
                    builder: (_, color, _) => FrostIcon(icon, size: _badgeIconSize, color: color),
                  ),
                  const SizedBox(width: FrostGap.inline),
                ],
                Flexible(
                  child: FrostSkeletonText(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
