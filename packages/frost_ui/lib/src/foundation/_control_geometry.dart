import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'sizes.dart';
import 'typography.dart';

/// Preserves the unscaled line's vertical space as text grows.
({double height, double verticalInset}) frostControlGeometry(BuildContext context, FrostControlSize size, {FrostTextRole role = FrostTextRole.body}) =>
    frostControlTextGeometry(baseHeight: size.height(context), style: FrostTypography.of(context).style(role), textScaler: MediaQuery.textScalerOf(context));

({double height, double verticalInset}) frostControlTextGeometry({
  required double baseHeight,
  required TextStyle style,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  double lineHeight(TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }

  final unscaled = lineHeight(TextScaler.noScaling), scaled = lineHeight(textScaler);
  return (height: baseHeight + math.max(0, scaled - unscaled), verticalInset: math.max(0, (baseHeight - unscaled) / 2));
}
