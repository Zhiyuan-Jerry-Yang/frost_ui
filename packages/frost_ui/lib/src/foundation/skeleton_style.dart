import 'package:flutter/widgets.dart';

import 'tokens.dart';

enum FrostSkeletonEffect { pulse, shimmer, solid }

/// Appearance only: the app's real layout supplies every skeleton shape.
/// Resolve custom colours from FrostThemeTokens for the current theme. A null resolver
/// resolves to fill / fillStrong; reduced motion always uses the solid fill.
@immutable
class FrostSkeletonStyle {
  const FrostSkeletonStyle({
    this.color,
    this.highlightColor,
    this.effect = FrostSkeletonEffect.pulse,
    this.period = const Duration(milliseconds: 1000),
    this.textRadius,
    this.textHeightFactor = .7,
  }) : assert(textRadius == null || (textRadius >= 0 && textRadius < double.infinity)),
       assert(textHeightFactor > 0 && textHeightFactor < double.infinity);

  final Color Function(FrostThemeTokens tokens)? color, highlightColor;
  final FrostSkeletonEffect effect;

  /// Positive animation period. Solid effects have no running clock.
  final Duration period;
  final double? textRadius;
  final double textHeightFactor;
}
