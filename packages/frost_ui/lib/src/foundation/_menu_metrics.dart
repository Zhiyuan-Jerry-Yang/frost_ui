import 'package:flutter/widgets.dart';

import 'density.dart';
import 'sizes.dart';

/// Menu geometry shared by Frost overlays and the Material fallback theme.
abstract final class FrostMenuMetrics {
  // Compact menus stay readable while long labels wrap within the panel.
  static const minimumWidth = 160.0, maximumWidth = 360.0;
  // Panel and row insets keep the nested corners concentric.
  static const panelInset = 4.0, rowInset = 8.0;
  // One leading slot is shared by checks and icons across an entire panel.
  static const iconGap = 8.0;
  static FrostControlSize sizeFor(FrostDensity density) => switch (density.platform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux when density.name == FrostDensity.compact.name => FrostControlSize.compact,
    _ => FrostControlSize.regular,
  };
  static FrostControlSize sizeOf(BuildContext context) => sizeFor(FrostDensity.of(context));
}
