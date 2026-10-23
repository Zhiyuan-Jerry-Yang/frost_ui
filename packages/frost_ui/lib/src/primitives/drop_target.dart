import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_presence_timing.dart';
import '_shape_fill.dart';
import '_surface_geometry.dart';
import 'presence.dart';
import 'surface.dart';

// The drag highlight is an inside stroke and never consumes layout space.
const _dropBorderWidth = 2.0;

extension FrostDropTargetX on Widget {
  /// Adds visual drop feedback only. The host owns drag data and sets [active].
  /// The overlay does not intercept pointer events.
  Widget frostDropTarget({required bool active, String? hint}) => _FrostDropTarget(active: active, hint: hint, child: this);
}

class _FrostDropTarget extends StatelessWidget {
  const _FrostDropTarget({required this.active, required this.child, this.hint});
  final bool active;
  final String? hint;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final geometry = FrostSurfaceGeometry.of(context);
    final surface = child is FrostSurface ? child as FrostSurface : null;
    final radius = surface != null ? frostSurfaceRadius(surface) : geometry?.radius ?? FrostRadius.borderRadius(FrostRadius.lg);
    final continuous = surface != null
        ? FrostScope.configOf(context).continuousCorners && surface.join == FrostSurfaceJoin.none
        : geometry?.continuous ?? FrostScope.configOf(context).continuousCorners;
    final tokens = FrostThemeTokens.of(context);
    final side = BorderSide(color: tokens.actionFill, width: _dropBorderWidth, strokeAlign: BorderSide.strokeAlignInside);
    final shape = continuous ? RoundedSuperellipseBorder(borderRadius: radius, side: side) : RoundedRectangleBorder(borderRadius: radius, side: side);
    final rectangular = frostNeedsClippedFill(shape, Directionality.maybeOf(context) ?? TextDirection.ltr);
    Widget overlay = DecoratedBox(
      decoration: ShapeDecoration(shape: shape, color: rectangular ? null : tokens.selectionFill),
      child: hint == null
          ? const SizedBox.expand()
          : Center(
              child: ExcludeSemantics(
                child: FrostSkeletonText(
                  child: Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: FrostTypography.of(context).style(FrostTextRole.callout).copyWith(color: tokens.selectionInk),
                  ),
                ),
              ),
            ),
    );
    if (rectangular) {
      overlay = ClipPath(
        clipper: ShapeBorderClipper(shape: shape, textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr),
        child: ColoredBox(color: tokens.selectionFill, child: overlay),
      );
    }
    return Semantics(
      liveRegion: active,
      hint: active ? hint : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: FrostPresenceTiming(
                duration: FrostMotion.hover,
                child: FrostPresence(visible: active, child: overlay),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
