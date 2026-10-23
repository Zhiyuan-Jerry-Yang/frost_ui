import 'dart:math' as math;
import 'package:flutter/material.dart' show TooltipVisibility;
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';

/// A Frost material tooltip with explicit timing, placement and semantics.
class FrostTooltip extends StatelessWidget {
  const FrostTooltip({required this.message, required this.child, this.excludeFromSemantics = false, super.key});
  final String message;
  final Widget child;
  final bool excludeFromSemantics;

  // Tooltip geometry and gesture delays are specified in design system 5.7.2.
  static const _maximumWidth = 280.0, _horizontalInset = 8.0, _verticalInset = 4.0, _targetGap = 6.0;
  static const _hoverDelay = Duration(milliseconds: 500), _touchDelay = Duration(milliseconds: 1500);

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty || !TooltipVisibility.of(context)) return child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return RawTooltip(
      semanticsTooltip: excludeFromSemantics ? null : message,
      hoverDelay: _hoverDelay,
      touchDelay: _touchDelay,
      dismissDelay: Duration.zero,
      enableFeedback: false,
      enableTapToDismiss: true,
      ignorePointer: true,
      triggerMode: TooltipTriggerMode.longPress,
      animationStyle: AnimationStyle(
        duration: reduced ? FrostMotion.reducedFade : FrostMotion.reveal,
        reverseDuration: reduced ? FrostMotion.reducedFade : FrostMotion.dismiss,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      positionDelegate: (position) {
        final target = position.target, targetSize = position.targetSize, tooltip = position.tooltipSize, room = position.overlaySize;
        final below = target.dy + targetSize.height / 2 + _targetGap;
        final above = target.dy - targetSize.height / 2 - _targetGap - tooltip.height;
        return Offset(
          (target.dx - tooltip.width / 2).clamp(0, math.max(0, room.width - tooltip.width)).toDouble(),
          (below + tooltip.height <= room.height ? below : above).clamp(0, math.max(0, room.height - tooltip.height)).toDouble(),
        );
      },
      tooltipBuilder: (context, animation) {
        final tokens = FrostThemeTokens.of(context);
        final radius = BorderRadius.circular(FrostRadius.xs);
        final side = BorderSide(color: tokens.edgeHairline, width: 1 / MediaQuery.devicePixelRatioOf(context));
        final shape = FrostScope.configOf(context).continuousCorners
            ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
            : RoundedRectangleBorder(borderRadius: radius, side: side);
        return FadeTransition(
          opacity: animation,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maximumWidth),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape.copyWith(side: BorderSide.none),
                shadows: [...tokens.shadowAmbient, ...tokens.shadowContact],
              ),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: ShapeDecoration(shape: shape),
                child: FrostSurfaceScope(
                  isGlass: false,
                  background: tokens.surfaceRaised,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: tokens.surfaceRaised,
                      shape: shape.copyWith(side: BorderSide.none),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _horizontalInset, vertical: _verticalInset),
                      child: FrostText(message, role: FrostTextRole.footnote, tone: FrostTextTone.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

extension FrostTooltipX on Widget {
  Widget frostTooltip(String message, {bool excludeFromSemantics = false}) =>
      FrostTooltip(message: message, excludeFromSemantics: excludeFromSemantics, child: this);
}
