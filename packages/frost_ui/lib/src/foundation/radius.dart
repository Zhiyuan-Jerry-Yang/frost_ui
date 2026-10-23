import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'scope.dart';

abstract final class FrostRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 24.0;
  static const _steps = [xs, sm, md, lg, xl, xxl];

  static double full(double height) => height / 2;

  static double forHeight(double height) {
    final candidates = _steps.where((r) => r <= height * .30);
    if (candidates.isEmpty) return xs;
    return candidates.reduce((a, b) => (a - height * .25).abs() <= (b - height * .25).abs() ? a : b);
  }

  static double inner(double outer, double inset) => math.max(xs, outer - inset);
  static BorderRadius borderRadius(double radius) => BorderRadius.circular(radius);
  static ShapeBorder shape(BuildContext context, double radius) => FrostScope.configOf(context).continuousCorners
      ? RoundedSuperellipseBorder(borderRadius: borderRadius(radius))
      : RoundedRectangleBorder(borderRadius: borderRadius(radius));
}
