import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../motion/spring.dart';

/// Reveals the visible part of a lazy vertical sliver on the standard spring.
/// Rows retain their real heights and their paint/cache window during motion.
/// Offscreen tails switch immediately; the scrollbar's total range can therefore
/// change before the reveal finishes. No whole-list height is animated.
///
/// Keep the group header immediately before this sliver so they scroll together.
/// Do not scroll the header into view before toggling: ordinary viewport boundary
/// correction owns any necessary adjustment near the end of the scroll range.
class FrostSliverExpand extends StatelessWidget {
  const FrostSliverExpand({required this.expanded, required this.sliver, super.key});
  final bool expanded;
  final Widget sliver;

  @override
  Widget build(BuildContext context) => FrostSpringBuilder(
    value: expanded ? 1 : 0,
    spring: FrostMotion.standard,
    child: sliver,
    builder: (context, progress, child) => _Expand(expanded: expanded, progress: progress.clamp(0.0, 1.0), sliver: child!),
  );
}

class _Expand extends SingleChildRenderObjectWidget {
  const _Expand({required this.expanded, required this.progress, required Widget sliver}) : super(child: sliver);
  final bool expanded;
  final double progress;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderExpand(expanded, progress);
  @override
  void updateRenderObject(BuildContext context, _RenderExpand renderObject) => renderObject
    ..expanded = expanded
    ..progress = progress;
}

class _RenderExpand extends RenderProxySliver {
  _RenderExpand(this._expanded, this._progress);
  bool _expanded;
  double _progress;
  double? _window, _cache;
  Size? _viewport;
  set expanded(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    markNeedsLayout();
  }

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    assert(constraints.axis == Axis.vertical, 'FrostSliverExpand requires a vertical viewport.');
    final settled = _progress == (_expanded ? 1 : 0);
    final viewport = Size(constraints.crossAxisExtent, constraints.viewportMainAxisExtent);
    if (settled) {
      _window = _cache = null;
    } else if (_window == null || _viewport != viewport) {
      // The same finite length owns paint AND layout. Multiplying the complete
      // lazy estimate while clipping a viewport-sized fraction leaves a hole
      // before the following group. Capture once so reversal preserves rows.
      _window = constraints.remainingPaintExtent;
      _cache = constraints.remainingCacheExtent;
    }
    _viewport = viewport;
    final closed = (settled || _window == 0) && !_expanded;
    final offscreen = _window == 0;
    final paintWindow = offscreen ? constraints.remainingPaintExtent : (_window ?? constraints.remainingPaintExtent);
    final cacheWindow = offscreen ? constraints.remainingCacheExtent : (_cache ?? constraints.remainingCacheExtent);
    child!.layout(
      constraints.copyWith(
        scrollOffset: closed ? 0 : constraints.scrollOffset,
        cacheOrigin: closed ? 0 : constraints.cacheOrigin,
        remainingPaintExtent: closed ? 0 : paintWindow,
        remainingCacheExtent: closed ? 0 : cacheWindow,
      ),
      parentUsesSize: true,
    );
    // Even a closed retained child must lay out after a theme/data change.
    if (closed) {
      geometry = SliverGeometry.zero;
      return;
    }
    final childGeometry = child!.geometry!;
    if (childGeometry.scrollOffsetCorrection case final correction?) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    if (settled || _window == 0) {
      // An offscreen tail has no visual distance to animate. Restoring the full
      // length at the expanded endpoint only moves content below the viewport.
      geometry = _expanded ? childGeometry : SliverGeometry.zero;
      return;
    }
    final extent = math.min(childGeometry.scrollExtent, _window!) * _progress;
    final paint = math.min(math.min(childGeometry.paintExtent, constraints.remainingPaintExtent), math.max(0.0, extent - constraints.scrollOffset));
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintOrigin: childGeometry.paintOrigin,
      paintExtent: paint,
      layoutExtent: math.min(childGeometry.layoutExtent, paint),
      maxPaintExtent: math.max(extent, paint),
      hitTestExtent: math.min(childGeometry.hitTestExtent, paint),
      cacheExtent: math.min(childGeometry.cacheExtent, calculateCacheOffset(constraints, from: 0, to: extent)),
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry!.paintExtent <= 0) return;
    if (_window == null) {
      super.paint(context, offset);
      return;
    }
    // Preserve the keyline's granted horizontal ink and focus-ring bleed.
    final viewport = RenderAbstractViewport.of(this);
    final bounds = MatrixUtils.transformRect(viewport.getTransformTo(this), viewport.paintBounds);
    final clip = Rect.fromLTRB(
      math.min(0, bounds.left),
      geometry!.paintOrigin,
      math.max(constraints.crossAxisExtent, bounds.right),
      geometry!.paintOrigin + geometry!.paintExtent,
    );
    context.pushClipRect(needsCompositing, offset, clip, super.paint);
  }
}
