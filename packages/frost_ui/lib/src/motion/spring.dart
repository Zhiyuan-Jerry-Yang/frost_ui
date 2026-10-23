import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '_material_reveal.dart';

/// A no-bounce spring's path as a [Curve] over [duration], for implicit
/// animations that only take a curve (sizes, cross-fades). It keeps the
/// spring's shape (a quick start easing into rest) but not its velocity
/// hand-off; use [FrostSpringBuilder] or [FrostMotion.springTo] where a motion can
/// be redirected mid-flight.
class FrostSpringCurve extends Curve {
  FrostSpringCurve(this.spring, this.duration) : _end = SpringSimulation(spring, 0, 1, 0).x(duration.inMicroseconds / 1e6);

  final SpringDescription spring;
  final Duration duration;
  final double _end;

  @override
  double transformInternal(double t) => SpringSimulation(spring, 0, 1, 0).x(t * duration.inMicroseconds / 1e6) / _end;
}

/// Animates a number toward [value] on a spring and rebuilds with it.
///
/// Unlike an implicit animation, a new target taken mid-flight continues from
/// the current value *and velocity*, so quick reversals never jump back or
/// stall. With reduced motion the value is applied at once.
class FrostSpringBuilder extends StatefulWidget {
  const FrostSpringBuilder({required this.value, required this.spring, required this.builder, this.child, super.key});

  final double value;
  final SpringDescription spring;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<FrostSpringBuilder> createState() => _FrostSpringBuilderState();
}

class _FrostSpringBuilderState extends State<FrostSpringBuilder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(vsync: this, value: widget.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = widget.value;
  }

  @override
  void didUpdateWidget(FrostSpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) FrostMotion.springTo(context, _controller, widget.value, widget.spring);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (context, child) => widget.builder(context, _controller.value, child), child: widget.child);
  }
}

/// Shows [child] by growing it out of [alignment] (from [hiddenScale]) and
/// fading it in on the standard spring; hiding runs on the quicker snappy
/// spring. For panels that open from the button that summons them.
class FrostSpringReveal extends StatefulWidget {
  const FrostSpringReveal({required this.shown, required this.alignment, required this.child, this.hiddenScale = .9, super.key});
  final bool shown;
  final AlignmentGeometry alignment;
  final double hiddenScale;
  final Widget child;
  @override
  State<FrostSpringReveal> createState() => _FrostSpringRevealState();
}

class _FrostSpringRevealState extends State<FrostSpringReveal> {
  final _glass = FrostRevealHandle();
  late bool _shown = widget.shown;

  @override
  void didUpdateWidget(FrostSpringReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown == oldWidget.shown) return;
    if (widget.shown) {
      _glass.cancelClose();
      _shown = true;
    } else if (_glass.hasNestedGlass && _glass.nestedProgress > 0) {
      _glass.prepareClose().then((ready) {
        if (ready && mounted && !widget.shown) setState(() => _shown = false);
      });
    } else {
      _shown = false;
    }
  }

  @override
  Widget build(BuildContext context) => FrostSpringBuilder(
    value: _shown ? 1 : 0,
    spring: _shown ? FrostMotion.standard : FrostMotion.snappy,
    child: widget.child,
    builder: (context, progress, child) => FrostMaterialReveal(
      handle: _glass,
      contentOnly: true,
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: MediaQuery.disableAnimationsOf(context) ? 1 : widget.hiddenScale + (1 - widget.hiddenScale) * progress,
        alignment: widget.alignment.resolve(Directionality.of(context)),
        child: child,
      ),
    ),
  );
}
