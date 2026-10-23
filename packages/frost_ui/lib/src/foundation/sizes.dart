import 'package:flutter/widgets.dart';

import 'density.dart';

/// All three sizes exist in both densities; density selects the height column.
enum FrostControlSize {
  compact,
  regular,
  large;

  double visualHeight({required bool touch}) => switch ((this, touch)) {
    (compact, false) => 32,
    (regular, false) => 40,
    (large, false) => 48,
    (compact, true) => 36,
    (regular, true) => 44,
    (large, true) => 52,
  };

  double get iconSize => this == compact ? 18 : 20;

  double height(BuildContext context) => FrostDensity.of(context).heightFor(this);
  static double minimumHitHeight({required bool touch}) => touch ? 44 : 36;
}
