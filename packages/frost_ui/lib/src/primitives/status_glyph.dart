import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/activity_indicator.dart';
import '../feedback/loading_gate.dart' show frostLoadingHasShown;
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';

/// Library-drawn status strokes; ordinary icons remain app-owned.
enum FrostStatusGlyphKind { success, failure, warning }

const frostStatusCheckDuration = Duration(milliseconds: 250);
const frostStatusCrossStrokeDuration = Duration(milliseconds: 140);
const frostStatusCrossOverlap = .6;
const frostStatusWarningStemDuration = Duration(milliseconds: 180);
const frostStatusWarningDotDuration = Duration(milliseconds: 70);
const frostStatusRingDuration = Duration(milliseconds: 200);
const frostStatusReducedDuration = Duration(milliseconds: 100);
const frostSelectionDrawDuration = Duration(milliseconds: 150);

Duration frostStatusDuration(FrostStatusGlyphKind kind) => switch (kind) {
  FrostStatusGlyphKind.success => frostStatusCheckDuration,
  FrostStatusGlyphKind.failure => Duration(microseconds: (frostStatusCrossStrokeDuration.inMicroseconds * (1 + frostStatusCrossOverlap)).round()),
  FrostStatusGlyphKind.warning => frostStatusWarningStemDuration + frostStatusWarningDotDuration,
};

double frostStatusStrokeWidth(double size) => math.max(1.5, size * .09);
Color frostStatusInk(FrostThemeTokens tokens, FrostStatusGlyphKind kind) => switch (kind) {
  FrostStatusGlyphKind.success => tokens.positiveInk,
  FrostStatusGlyphKind.failure => tokens.negativeInk,
  FrostStatusGlyphKind.warning => tokens.cautionInk,
};

/// A decorative status glyph. The enclosing component owns result semantics.
/// Mounting displays the final shape; only a later kind change draws it again.
/// Reduced motion replaces drawing with a 100 ms fade of the final shape.
class FrostStatusGlyph extends StatelessWidget {
  const FrostStatusGlyph({required this.kind, required this.size, this.color, this.animate = true, super.key}) : assert(size > 0 && size < double.infinity);
  final FrostStatusGlyphKind kind;
  final double size;
  final Color? color;
  final bool animate;
  @override
  Widget build(BuildContext context) => FrostStatusGlyphAnimation(kind: kind, size: size, color: color, animateChanges: animate);
}

/// Internal trigger-aware version for a reveal or a user-originated selection.
/// The public primitive deliberately has no replay or mount-animation switch.
class FrostStatusGlyphAnimation extends StatefulWidget {
  const FrostStatusGlyphAnimation({
    required this.kind,
    required this.size,
    this.color,
    this.visible = true,
    this.animateChanges = true,
    this.drawOnMount = false,
    this.replay,
    this.duration,
    super.key,
  });
  final FrostStatusGlyphKind kind;
  final double size;
  final Color? color;
  final bool visible, animateChanges, drawOnMount;
  final Object? replay;
  final Duration? duration;
  @override
  State<FrostStatusGlyphAnimation> createState() => _GlyphAnimationState();
}

class _GlyphAnimationState extends State<FrostStatusGlyphAnimation> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: widget.visible && !widget.drawOnMount ? 1 : 0);
  bool _draw = true, _started = false;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  void _show() {
    _draw = true;
    _controller.duration = _reduced ? frostStatusReducedDuration : widget.duration ?? frostStatusDuration(widget.kind);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.visible && widget.drawOnMount && widget.animateChanges) _show();
    }
  }

  @override
  void didUpdateWidget(FrostStatusGlyphAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible && widget.kind == oldWidget.kind && widget.replay == oldWidget.replay) return;
    if (!widget.animateChanges) {
      _controller.value = widget.visible ? 1 : 0;
    } else if (widget.visible) {
      _show();
    } else {
      _draw = false;
      _controller.duration = _reduced ? frostStatusReducedDuration : FrostMotion.hover;
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Opacity(
      opacity: _reduced || !_draw ? _controller.value : 1,
      child: FrostStatusGlyphDrawing(
        kind: widget.kind,
        size: widget.size,
        color: widget.color,
        progress: _reduced || !_draw ? 1 : _controller.value,
        duration: widget.duration,
      ),
    ),
  );
}

/// One drawing path shared by standalone status, checkbox and media marks.
class FrostStatusGlyphDrawing extends StatelessWidget {
  const FrostStatusGlyphDrawing({required this.kind, required this.size, this.color, this.progress = 1, this.duration, super.key});
  final FrostStatusGlyphKind kind;
  final double size, progress;
  final Color? color;
  final Duration? duration;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: FrostStatusGlyphPainter(kind: kind, color: color ?? frostStatusInk(FrostThemeTokens.of(context), kind), progress: progress),
    ),
  );
}

List<Path> frostStatusPaths(FrostStatusGlyphKind kind, Size size) {
  Path line(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    return path;
  }

  return switch (kind) {
    FrostStatusGlyphKind.success => [
      line([const Offset(.2, .5), const Offset(.4, .7), const Offset(.8, .3)]),
    ],
    FrostStatusGlyphKind.failure => [
      line([const Offset(.28, .28), const Offset(.72, .72)]),
      line([const Offset(.72, .28), const Offset(.28, .72)]),
    ],
    // A nearly zero-length round-capped stroke makes the dot use the same
    // PathMetric clipping and paint as every other stroke, without a font.
    FrostStatusGlyphKind.warning => [
      line([const Offset(.5, .20), const Offset(.5, .58)]),
      line([const Offset(.5, .78), const Offset(.5001, .78)]),
    ],
  };
}

List<double> frostStatusStrokeProgress(FrostStatusGlyphKind kind, double progress) {
  final elapsed = frostStatusDuration(kind).inMicroseconds * progress.clamp(0.0, 1.0);
  double phase(double start, double length) => FrostMotion.hoverCurve.transform(((elapsed - start) / length).clamp(0.0, 1.0));
  final cross = frostStatusCrossStrokeDuration.inMicroseconds.toDouble();
  return switch (kind) {
    FrostStatusGlyphKind.success => [FrostMotion.hoverCurve.transform(progress.clamp(0.0, 1.0))],
    FrostStatusGlyphKind.failure => [phase(0, cross), phase(cross * frostStatusCrossOverlap, cross)],
    FrostStatusGlyphKind.warning => [
      phase(0, frostStatusWarningStemDuration.inMicroseconds.toDouble()),
      phase(frostStatusWarningStemDuration.inMicroseconds.toDouble(), frostStatusWarningDotDuration.inMicroseconds.toDouble()),
    ],
  };
}

void frostPaintStatusGlyph(Canvas canvas, Size size, FrostStatusGlyphKind kind, Color color, double progress) {
  Paint stroke(Color ink) => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = frostStatusStrokeWidth(size.shortestSide)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final paths = frostStatusPaths(kind, size), phases = frostStatusStrokeProgress(kind, progress);
  for (var i = 0; i < paths.length; i++) {
    if (phases[i] <= 0) continue;
    for (final metric in paths[i].computeMetrics()) {
      // The warning dot is a near-zero-length round stroke: fade its ink
      // during the dot phase so a round cap cannot pop in at full size.
      final ink = kind == FrostStatusGlyphKind.warning && i == 1 ? color.withValues(alpha: color.a * phases[i]) : color;
      canvas.drawPath(metric.extractPath(0, metric.length * phases[i]), stroke(ink));
    }
  }
}

class FrostStatusGlyphPainter extends CustomPainter {
  const FrostStatusGlyphPainter({required this.kind, required this.color, required this.progress});
  final FrostStatusGlyphKind kind;
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) => frostPaintStatusGlyph(canvas, size, kind, color, progress);
  @override
  bool shouldRepaint(FrostStatusGlyphPainter oldDelegate) => kind != oldDelegate.kind || color != oldDelegate.color || progress != oldDelegate.progress;
}

/// Internal progress-to-result composition. Unknown progress cross-fades the
/// radial indicator into a ring; known progress finishes its existing ring.
/// The caller retains this widget until [onResultDrawn] and its hold complete.
class FrostProgressResult extends StatefulWidget {
  const FrostProgressResult({required this.result, required this.size, this.color, this.progress, this.onResultDrawn, super.key});
  final FrostStatusGlyphKind? result;
  final double size;
  final Color? color;
  final double? progress;
  final VoidCallback? onResultDrawn;
  @override
  State<FrostProgressResult> createState() => _ProgressResultState();
}

class _ProgressResultState extends State<FrostProgressResult> with TickerProviderStateMixin {
  late final _value = AnimationController.unbounded(vsync: this, value: widget.progress ?? 0);
  late final _result = AnimationController(vsync: this)..addStatusListener(_status);
  double _ringStart = 0;
  bool _started = false;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onResultDrawn?.call();
  }

  void _finish() {
    _ringStart = widget.progress == null ? 0 : _value.value.clamp(0.0, 1.0);
    _result.duration = _reduced ? frostStatusReducedDuration : frostStatusRingDuration + frostStatusDuration(widget.result!);
    _result.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.result != null) _finish();
    }
  }

  @override
  void didUpdateWidget(FrostProgressResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result != oldWidget.result) {
      if (widget.result != null) {
        _finish();
      } else {
        _result.stop();
        _result.value = 0;
      }
    }
    if (widget.progress != oldWidget.progress && widget.result == null) FrostMotion.springTo(context, _value, widget.progress ?? 0, FrostMotion.snappy);
  }

  @override
  void dispose() {
    _result.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: Listenable.merge([_result, _value]),
      builder: (context, _) {
        final color = widget.color ?? IconTheme.of(context).color ?? FrostThemeTokens.of(context).textPrimary;
        final kind = widget.result;
        final elapsed = kind == null ? 0 : _result.value * (frostStatusRingDuration + frostStatusDuration(kind)).inMicroseconds;
        final ringPhase = FrostMotion.hoverCurve.transform((elapsed / frostStatusRingDuration.inMicroseconds).clamp(0.0, 1.0));
        final ring = kind == null ? _value.value.clamp(0.0, 1.0) : _ringStart + (1 - _ringStart) * ringPhase;
        final glyph = kind == null ? 0.0 : ((elapsed - frostStatusRingDuration.inMicroseconds) / frostStatusDuration(kind).inMicroseconds).clamp(0.0, 1.0);
        return SizedBox.square(
          dimension: widget.size,
          child: Opacity(
            opacity: kind != null && _reduced ? _result.value : 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.progress == null && (kind == null || (frostLoadingHasShown(context) && !_reduced && ringPhase < 1)))
                  Opacity(
                    opacity: kind == null ? 1 : 1 - ringPhase,
                    child: FrostActivityForeground(
                      color: color,
                      child: FrostActivityIndicator(size: widget.size <= 16 ? FrostControlSize.compact : FrostControlSize.regular, semanticLabel: null),
                    ),
                  ),
                if (widget.progress != null || kind != null)
                  CustomPaint(
                    size: Size.square(widget.size),
                    painter: FrostStatusRingPainter(color: color, progress: _reduced && kind != null ? 1 : ring),
                  ),
                if (kind != null) FrostStatusGlyphDrawing(kind: kind, size: widget.size * .58, color: color, progress: _reduced ? 1 : glyph),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class FrostStatusRingPainter extends CustomPainter {
  const FrostStatusRingPainter({required this.color, required this.progress});
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = frostStatusStrokeWidth(size.shortestSide);
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: (size.shortestSide - stroke) / 2),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(FrostStatusRingPainter oldDelegate) => color != oldDelegate.color || progress != oldDelegate.progress;
}
