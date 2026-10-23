import 'package:flutter/widgets.dart';

import '../foundation/radius.dart';
import 'surface.dart';

BorderRadiusGeometry frostSurfaceRadius(FrostSurface surface) =>
    surface.borderRadius ??
    BorderRadius.circular(switch (surface.role) {
      FrostSurfaceRole.overlay => FrostRadius.xxl,
      FrostSurfaceRole.sheet || FrostSurfaceRole.module => FrostRadius.lg,
      _ => FrostRadius.xl,
    });

/// Internal geometry accompanies the actual surface, including custom radii.
class FrostSurfaceGeometry extends InheritedWidget {
  const FrostSurfaceGeometry({required this.radius, required this.continuous, required super.child, super.key});
  final BorderRadiusGeometry radius;
  final bool continuous;
  static FrostSurfaceGeometry? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostSurfaceGeometry>();
  @override
  bool updateShouldNotify(FrostSurfaceGeometry oldWidget) => radius != oldWidget.radius || continuous != oldWidget.continuous;
}
