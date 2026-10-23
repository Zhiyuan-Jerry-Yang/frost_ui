import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../motion/_spring_simulation.dart';

/// Animates a lazy row's new layout position rather than replacing the sliver's
/// layout or estimating offscreen row heights. Painting owns no application
/// state: only its displacement simulation and ticker change here.
class FrostReorderMotion extends SingleChildRenderObjectWidget {
  const FrostReorderMotion({
    required this.revision,
    required this.scrollOffset,
    required this.spring,
    required this.reduced,
    required this.tickers,
    this.from,
    required super.child,
    super.key,
  });
  final int revision;
  final double Function() scrollOffset;
  final SpringDescription spring;
  final bool reduced, tickers;
  final double? from;
  @override
  RenderObject createRenderObject(BuildContext context) => FrostReorderMotionBox(this);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as FrostReorderMotionBox).update(this);
}

class FrostReorderMotionBox extends RenderProxyBox {
  FrostReorderMotionBox(this.spec) {
    _ticker = Ticker(_tick)..muted = !spec.tickers;
  }
  FrostReorderMotion spec;
  late final Ticker _ticker;
  SpringSimulation? _simulation;
  double _elapsed = 0, _offset = 0;
  double? _lastOrigin;
  int? _paintedRevision;
  void update(FrostReorderMotion next) {
    spec = next;
    _ticker.muted = !next.tickers;
    if (next.reduced) {
      _ticker.stop();
      _simulation = null;
      _offset = 0;
    }
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final simulation = _simulation;
    if (simulation == null) return;
    _offset = simulation.x(_elapsed);
    if (simulation.isDone(_elapsed)) {
      _offset = 0;
      _simulation = null;
      _ticker.stop();
    }
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final origin = localToGlobal(Offset.zero).dy + spec.scrollOffset();
    if (_paintedRevision != spec.revision) {
      final oldOrigin = spec.from ?? _lastOrigin;
      final from = _offset + (oldOrigin == null ? 0 : oldOrigin - origin);
      final velocity = _simulation?.dx(_elapsed) ?? 0.0;
      _ticker.stop();
      if (!spec.reduced && (from.abs() > precisionErrorTolerance || velocity.abs() > precisionErrorTolerance)) {
        _simulation = frostSpringSimulation(spec.spring, from, 0, velocity);
        _elapsed = 0;
        _offset = from;
        _ticker.start();
      } else {
        _simulation = null;
        _offset = 0;
      }
      _paintedRevision = spec.revision;
      markNeedsSemanticsUpdate();
    }
    _lastOrigin = origin;
    if (child case final child?) context.paintChild(child, offset + Offset(0, _offset));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    transform.translateByDouble(0, _offset, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The moving content can lie outside its new layout slot.
    final hit =
        child != null &&
        result.addWithPaintOffset(
          offset: Offset(0, _offset),
          position: position,
          hitTest: (result, transformed) => child!.hitTest(result, position: transformed),
        );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  Rect get paintBounds => super.paintBounds.expandToInclude(super.paintBounds.shift(Offset(0, _offset)));
  @override
  void detach() {
    _ticker.stop();
    _simulation = null;
    _offset = 0;
    _lastOrigin = null;
    super.detach();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// The sliver's non-interactive keepalive / indexed-semantics wrappers still
/// have the new slot bounds. Route to our owned moving box before those bounds
/// can reject a point painted outside the slot.
FrostReorderMotionBox? frostReorderMotionBoxOf(RenderBox child) {
  RenderObject? current = child;
  while (current != null) {
    if (current is FrostReorderMotionBox) return current;
    RenderObject? next;
    current.visitChildren((child) => next ??= child);
    current = next;
  }
  return null;
}
