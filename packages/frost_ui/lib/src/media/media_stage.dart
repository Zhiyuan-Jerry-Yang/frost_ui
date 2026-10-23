import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../motion/spring.dart';

// Invalid release-mode metadata uses a square until a decoded ratio arrives.
const _fallbackAspectRatio = 1.0;

/// Measures the media rectangle without adding padding, a surface or clipping.
/// In a finite slot it contains the media and fills at least one axis. With
/// unbounded height it fills the available width and grows to the full image
/// height, including very tall images. At least one axis must be bounded.
/// Supply the metadata ratio initially, then the decoded ratio: changes follow
/// the standard spring without replacing the child. Reduced motion is immediate.
/// Decode tall images at their displayed width rather than their original size.
class FrostMediaStage extends StatelessWidget {
  const FrostMediaStage({required this.aspectRatio, required this.child, super.key}) : assert(aspectRatio > 0 && aspectRatio < double.infinity);
  final double aspectRatio;
  final Widget child;

  /// Shared detail-stage corners: edge-to-edge narrow media is square; finite
  /// wide stages use the media radius. Read below FrostDetailLayout.stage.
  static double radiusOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMediaStagePresentation>()?.radius ?? FrostRadius.lg;

  @override
  Widget build(BuildContext context) => FrostSpringBuilder(
    value: aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : _fallbackAspectRatio,
    spring: FrostMotion.standard,
    child: child,
    builder: (context, ratio, child) => FrostMediaStageGeometry(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth && !constraints.hasBoundedHeight) {
            throw FlutterError('FrostMediaStage requires a finite width or height.');
          }
          final width = math.min(constraints.maxWidth, constraints.maxHeight * ratio);
          final height = width / ratio;
          return Align(
            alignment: Alignment.center,
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(width: width, height: height, child: child),
          );
        },
      ),
    ),
  );
}

/// Library-only geometry shared with Hero, so stale card metadata cannot
/// introduce a second contain rectangle inside an already measured stage.
class FrostMediaStageGeometry extends InheritedWidget {
  const FrostMediaStageGeometry({required this.aspectRatio, required super.child, super.key});
  final double aspectRatio;
  static double? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMediaStageGeometry>()?.aspectRatio;
  @override
  bool updateShouldNotify(FrostMediaStageGeometry oldWidget) => aspectRatio != oldWidget.aspectRatio;
}

// Library-owned presentation, shared by the image, interaction and Hero outline.
class FrostMediaStagePresentation extends InheritedWidget {
  const FrostMediaStagePresentation({required this.radius, required super.child, super.key});
  final double radius;
  @override
  bool updateShouldNotify(FrostMediaStagePresentation oldWidget) => radius != oldWidget.radius;
}
