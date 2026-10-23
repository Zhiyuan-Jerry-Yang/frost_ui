import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../motion/_material_reveal.dart';
import '../motion/_spring_simulation.dart';
import '_pager_media_scope.dart';

// Match the source viewer's tolerance for an identity transform.
const _zoomThreshold = 1.001;
const _dismissDistance = 120.0;
const _dismissVelocity = 700.0;
const _dismissScaleLoss = .1;

/// A lightweight media transform handle. Unbound calls are harmless; one controller
/// can be attached to one viewport at a time and owns no disposable resources.
class FrostMediaViewportController {
  VoidCallback? _reset;
  ValueChanged<double>? _zoom;

  /// Zooms about the viewport center, clamped to 1–maxScale, with the shared
  /// standard spring and current velocity. Reduced motion takes the endpoint
  /// immediately. The owning viewport reports actual intermediate scale frames.
  void zoomTo(double scale) {
    assert(scale.isFinite && scale > 0, 'Scale must be finite and positive.');
    _zoom?.call(scale);
  }

  void reset() => _reset?.call();
  void _attach(VoidCallback reset, ValueChanged<double> zoom) {
    assert(_reset == null || _reset == reset, 'A viewport controller can only bind one viewport.');
    _reset = reset;
    _zoom = zoom;
  }

  void _detach(VoidCallback reset) {
    if (_reset == reset) {
      _reset = null;
      _zoom = null;
    }
  }
}

/// Gesture and animation shell only; the app owns media loading and navigation.
/// [background] stays behind the media and fades independently while dismissing.
/// Escape remains the caller's responsibility.
class FrostMediaViewport extends StatefulWidget {
  const FrostMediaViewport({
    required this.child,
    this.onZoomChanged,
    this.onScaleChanged,
    this.onDismiss,
    this.controller,
    this.background,
    this.overlay,
    this.maxScale = 5,
    this.doubleTapScale = 2.5,
    super.key,
  }) : assert(maxScale >= 1 && maxScale < double.infinity),
       assert(doubleTapScale > 1 && doubleTapScale < double.infinity);
  final Widget child;
  final ValueChanged<bool>? onZoomChanged;

  /// Actual image scale, coalesced after each frame that changes it. This
  /// includes gesture updates and spring frames, not dismissal's visual shrink.
  /// The initial scale is 1; panning alone does not notify. No callback follows
  /// disposal, and callbacks never run during build or layout.
  final ValueChanged<double>? onScaleChanged;

  /// Called after the viewport has finished its inertial pull-down exit.
  /// Remove the containing route without a second transition from this callback.
  /// Button, Escape and system-back exits remain the route owner's responsibility.
  final VoidCallback? onDismiss;
  final FrostMediaViewportController? controller;
  final Widget? background;

  /// Fixed viewer controls: not zoomed or panned with the media. They fade with
  /// pull-down dismissal using the shared glass-safe reveal path. The viewport
  /// owns the only background; its containing route must expose the route below
  /// while that background fades. Omitted controls leave gestures unchanged.
  final Widget? overlay;
  final double maxScale;
  final double doubleTapScale;
  @override
  State<FrostMediaViewport> createState() => _FrostMediaViewportState();
}

class _FrostMediaViewportState extends State<FrostMediaViewport> with TickerProviderStateMixin {
  final _transform = TransformationController();
  late final _x = AnimationController.unbounded(vsync: this);
  late final _y = AnimationController.unbounded(vsync: this);
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  late final _drag = AnimationController.unbounded(vsync: this);
  late final _dismiss = AnimationController(vsync: this, duration: FrostMotion.exit);
  _DismissFlight? _flight;
  Offset _doubleTapPoint = Offset.zero, _gestureOrigin = Offset.zero;
  Offset? _pointerOrigin;
  FrostPagerMediaScope? _pager;
  bool _zoomed = false, _reportedZoom = false, _notificationScheduled = false, _dismissEligible = false;
  double _reportedScale = 1;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_reset, _zoomTo);
    _transform.addListener(_changed);
    for (final controller in [_x, _y, _scale]) {
      controller.addListener(_writeTransform);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pager = FrostPagerMediaScope.maybeOf(context);
    final old = _pager;
    _pager = pager;
    if (old != pager && _zoomed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old?.report(this, false);
        if (mounted) _pager?.report(this, _zoomed);
      });
    }
  }

  @override
  void didUpdateWidget(FrostMediaViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_reset);
      widget.controller?._attach(_reset, _zoomTo);
    }
    if (widget.onDismiss == null) {
      _dismissEligible = false;
      _dismiss.stop();
      _flight = null;
      _dismiss.value = 0;
      if (_drag.value != 0) FrostMotion.springTo(context, _drag, 0, FrostMotion.standard);
    }
  }

  void _changed() {
    final scale = _transform.value.getMaxScaleOnAxis();
    _zoomed = scale > _zoomThreshold;
    if (_notificationScheduled || (_zoomed == _reportedZoom && scale == _reportedScale)) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!mounted) return;
      // Read one final snapshot for the frame. Several transform writes, or a
      // change back to the last reported value, produce at most one notice.
      final scale = _transform.value.getMaxScaleOnAxis();
      final zoomed = scale > _zoomThreshold;
      final scaleChanged = scale != _reportedScale, zoomChanged = zoomed != _reportedZoom;
      _reportedScale = scale;
      _reportedZoom = zoomed;
      if (zoomChanged) _pager?.report(this, zoomed);
      if (scaleChanged) widget.onScaleChanged?.call(scale);
      if (mounted && zoomChanged) widget.onZoomChanged?.call(zoomed);
    });
  }

  void _writeTransform() => _transform.value = Matrix4.identity()
    ..translateByDouble(_x.value, _y.value, 0, 1)
    ..scaleByDouble(_scale.value, _scale.value, 1, 1);

  void _stopTransform() {
    for (final controller in [_x, _y, _scale]) {
      controller.stop();
    }
  }

  void _animateAxis(AnimationController controller, double current, double target) {
    final velocity = controller.isAnimating ? controller.velocity : 0.0;
    controller.stop();
    controller.value = current;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = target;
    } else {
      controller.animateWith(frostSpringSimulation(FrostMotion.standard, current, target, velocity));
    }
  }

  void _animateTransform(Matrix4 target) {
    final current = _transform.value.clone();
    _animateAxis(_x, current.storage[12], target.storage[12]);
    _animateAxis(_y, current.storage[13], target.storage[13]);
    _animateAxis(_scale, current.getMaxScaleOnAxis(), target.getMaxScaleOnAxis());
  }

  void _reset() {
    if (_flight != null) return;
    _animateTransform(Matrix4.identity());
    FrostMotion.springTo(context, _drag, 0, FrostMotion.standard);
  }

  void _zoomTo(double requested) {
    if (_flight != null) return;
    final scale = requested.clamp(1.0, widget.maxScale);
    if (scale == 1) {
      _reset();
      return;
    }
    final viewport = context.findRenderObject()! as RenderBox;
    final center = viewport.size.center(Offset.zero);
    final scene = _transform.toScene(center);
    _animateTransform(
      Matrix4.identity()
        ..translateByDouble(center.dx - scene.dx * scale, center.dy - scene.dy * scale, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1),
    );
  }

  void _doubleTap() {
    if (_zoomed) {
      _reset();
    } else {
      final scale = math.min(widget.doubleTapScale, widget.maxScale);
      final scene = _transform.toScene(_doubleTapPoint);
      _animateTransform(
        Matrix4.identity()
          ..translateByDouble(_doubleTapPoint.dx - scene.dx * scale, _doubleTapPoint.dy - scene.dy * scale, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1),
      );
    }
  }

  void _start(ScaleStartDetails details) {
    if (_flight != null) return;
    _stopTransform();
    _drag.stop();
    _gestureOrigin = (_pointerOrigin ?? details.focalPoint) - Offset(0, _drag.value);
    _dismissEligible = widget.onDismiss != null && !_zoomed && details.pointerCount == 1;
  }

  void _update(ScaleUpdateDetails details) {
    if (!_dismissEligible) return;
    if (_zoomed || details.pointerCount > 1 || (details.scale - 1).abs() > _zoomThreshold - 1) {
      _dismissEligible = false;
      FrostMotion.springTo(context, _drag, 0, FrostMotion.standard);
      return;
    }
    _drag.value = math.max(0, details.focalPoint.dy - _gestureOrigin.dy);
  }

  void _end(ScaleEndDetails details) {
    if (_flight != null) return;
    final dismiss = _dismissEligible && (_drag.value > _dismissDistance || details.velocity.pixelsPerSecond.dy > _dismissVelocity);
    _dismissEligible = false;
    if (dismiss) {
      final viewport = context.findRenderObject()! as RenderBox;
      _flight = _DismissFlight(_drag.value, viewport.size.height, details.velocity.pixelsPerSecond.dy, FrostMotion.exit);
      if (MediaQuery.disableAnimationsOf(context)) {
        _dismiss.value = 1;
        widget.onDismiss?.call();
      } else {
        _dismiss.forward().orCancel.then(
          (_) {
            if (mounted && _flight != null) widget.onDismiss?.call();
          },
          onError: (Object error) {
            if (error is! TickerCanceled) Error.throwWithStackTrace(error, StackTrace.current);
          },
        );
      }
    } else {
      FrostMotion.springTo(context, _drag, 0, FrostMotion.standard);
    }
  }

  @override
  void dispose() {
    final pager = _pager;
    if (pager != null) WidgetsBinding.instance.addPostFrameCallback((_) => pager.report(this, false));
    widget.controller?._detach(_reset);
    _transform.removeListener(_changed);
    _transform.dispose();
    for (final controller in [_x, _y, _scale, _drag, _dismiss]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRect(
      child: AnimatedBuilder(
        animation: Listenable.merge([_transform, _drag, _dismiss]),
        builder: (context, child) {
          final progress = (_drag.value / _dismissDistance).clamp(0.0, 1.0);
          final flight = _flight;
          final time = _dismiss.value;
          final backgroundOpacity = (1 - progress) * (1 - time);
          return IgnorePointer(
            ignoring: flight != null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.background case final background?)
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: Opacity(opacity: backgroundOpacity, child: background),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0, flight?.position(time) ?? _drag.value),
                  child: Transform.scale(
                    scale: 1 - _dismissScaleLoss * (progress + (1 - progress) * time),
                    child: Opacity(
                      opacity: 1 - time,
                      child: Listener(
                        onPointerDown: (event) => _pointerOrigin = event.position,
                        child: GestureDetector(
                          onDoubleTapDown: (details) => _doubleTapPoint = details.localPosition,
                          onDoubleTap: _doubleTap,
                          child: InteractiveViewer(
                            transformationController: _transform,
                            minScale: 1,
                            maxScale: widget.maxScale,
                            panEnabled: _zoomed,
                            onInteractionStart: _start,
                            onInteractionUpdate: _update,
                            onInteractionEnd: _end,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Center(child: widget.child),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.overlay case final overlay?) FrostMaterialReveal(opacity: backgroundOpacity, contentOnly: true, child: overlay),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// A timed monotone Hermite flight carries release velocity without overshooting
// the offscreen endpoint. A very fast fling caps its initial tangent at 3: larger
// tangents would reverse direction before reaching the endpoint.
class _DismissFlight {
  _DismissFlight(this.start, double height, double velocity, Duration duration)
    : distance = math.max(1, height - start),
      seconds = duration.inMicroseconds / Duration.microsecondsPerSecond,
      velocity = math.max(0, velocity);
  final double start, distance, seconds, velocity;
  double position(double t) {
    final tangent = (velocity * seconds / distance).clamp(0.0, 3.0);
    return start + distance * ((-2 * t + 3) * t * t + tangent * (t * t * t - 2 * t * t + t));
  }
}
