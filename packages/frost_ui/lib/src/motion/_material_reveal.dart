import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';

// Nested sampling starts only after content has left its opacity buffer.
const frostNestedGlassDuration = FrostMotion.hover;

/// Coordinates a reveal without owning, inspecting or moving retained layers.
class FrostRevealHandle {
  _FrostMaterialRevealState? _state;
  final _glass = <Object>{};
  bool get hasNestedGlass => _glass.isNotEmpty;
  double get nestedProgress => _state?._blur.value ?? 1;
  Future<bool> prepareClose() => _state?._prepareClose() ?? Future.value(true);
  void cancelClose() => _state?._cancelClose();
  void register(Object member) => _glass.add(member);
  void unregister(Object member) => _glass.remove(member);
}

/// Outer materials consume progress directly; generic content is faded as a
/// whole with backdrop sampling deferred until the opacity buffer is gone.
class FrostMaterialReveal extends StatefulWidget {
  const FrostMaterialReveal({
    required this.opacity,
    required this.child,
    this.handle,
    this.paintOpacity,
    this.contentOnly = false,
    this.materialOnly = false,
    this.deferNestedBlur = false,
    this.alwaysIncludeSemantics = false,
    super.key,
  });
  final double opacity;
  final Widget child;
  final FrostRevealHandle? handle;
  final Animation<double>? paintOpacity;
  final bool contentOnly, materialOnly, alwaysIncludeSemantics;
  // Native page transitions own geometry/opacity; defer sampling while they move.
  final bool deferNestedBlur;
  @override
  State<FrostMaterialReveal> createState() => _FrostMaterialRevealState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('opacity', opacity));
  }
}

class _FrostMaterialRevealState extends State<FrostMaterialReveal> with SingleTickerProviderStateMixin {
  late final _owned = FrostRevealHandle();
  FrostRevealHandle get _handle => widget.handle ?? _owned;
  late final _blur = AnimationController(vsync: this, value: widget.opacity >= 1 && !widget.deferNestedBlur ? 1 : 0, duration: frostNestedGlassDuration);
  bool _closing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _handle._state = this;
  }

  void _refresh() {
    if (widget.opacity < 1 || widget.deferNestedBlur) {
      // External routes may start reversing without a pre-close handshake.
      // Never leave a sampler active inside their first opacity buffer.
      _blur.value = 0;
    } else if (!_closing && _blur.value < 1) {
      if (_handle.hasNestedGlass) {
        _blur.forward();
      } else {
        _blur.value = 1;
      }
    }
  }

  void _cancelClose() {
    _generation++;
    _closing = false;
    _blur.stop(canceled: true);
    _refresh();
  }

  Future<bool> _prepareClose() async {
    final generation = ++_generation;
    _closing = true;
    if (_handle.hasNestedGlass && _blur.value > 0) {
      try {
        await _blur.animateTo(0, duration: frostNestedGlassDuration).orCancel;
      } on TickerCanceled {
        return false;
      }
    }
    return mounted && generation == _generation;
  }

  @override
  void didUpdateWidget(FrostMaterialReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      (oldWidget.handle ?? _owned)._state = null;
      _handle._state = this;
    }
    if (oldWidget.opacity != widget.opacity || oldWidget.deferNestedBlur != widget.deferNestedBlur) _refresh();
  }

  @override
  void dispose() {
    _generation++;
    _handle._state = null;
    _blur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _blur,
    builder: (context, _) {
      final progress = widget.opacity.clamp(0.0, 1.0);
      final scope = FrostMaterialRevealScope(
        progress: progress,
        claimed: widget.contentOnly,
        materialOnly: widget.materialOnly,
        handle: _handle,
        nestedProgress: _blur.value,
        alwaysIncludeSemantics: widget.alwaysIncludeSemantics,
        child: widget.child,
      );
      return widget.contentOnly
          ? FrostContentRevealScope(
              opacity: progress,
              nestedProgress: _blur.value,
              handle: _handle,
              parent: FrostContentRevealScope.maybeOf(context),
              child: FrostContentFade(opacity: progress, animation: widget.paintOpacity, alwaysIncludeSemantics: widget.alwaysIncludeSemantics, child: scope),
            )
          : scope;
    },
  );
}

class FrostMaterialRevealScope extends InheritedWidget {
  const FrostMaterialRevealScope({
    required this.progress,
    required this.claimed,
    required this.materialOnly,
    required this.handle,
    required this.nestedProgress,
    required this.alwaysIncludeSemantics,
    required super.child,
    super.key,
  });
  final double progress, nestedProgress;
  final bool claimed, materialOnly, alwaysIncludeSemantics;
  final FrostRevealHandle handle;
  static FrostMaterialRevealScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMaterialRevealScope>();

  Widget consume(BuildContext context, Widget child) {
    if (claimed) return child;
    final content = FrostMaterialRevealScope(
      progress: progress,
      claimed: true,
      materialOnly: materialOnly,
      handle: handle,
      nestedProgress: nestedProgress,
      alwaysIncludeSemantics: alwaysIncludeSemantics,
      child: child,
    );
    return materialOnly
        ? content
        : FrostContentRevealScope(
            opacity: progress,
            nestedProgress: nestedProgress,
            handle: handle,
            parent: FrostContentRevealScope.maybeOf(context),
            child: FrostContentFade(opacity: progress, alwaysIncludeSemantics: alwaysIncludeSemantics, child: content),
          );
  }

  @override
  bool updateShouldNotify(FrostMaterialRevealScope oldWidget) =>
      progress != oldWidget.progress ||
      claimed != oldWidget.claimed ||
      nestedProgress != oldWidget.nestedProgress ||
      handle != oldWidget.handle ||
      materialOnly != oldWidget.materialOnly ||
      alwaysIncludeSemantics != oldWidget.alwaysIncludeSemantics;
}

class FrostContentRevealScope extends InheritedWidget {
  const FrostContentRevealScope({
    required this.opacity,
    required this.nestedProgress,
    required this.handle,
    required this.parent,
    required super.child,
    super.key,
  });
  final double opacity, nestedProgress;
  final FrostRevealHandle handle;
  final FrostContentRevealScope? parent;
  static FrostContentRevealScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostContentRevealScope>();
  static double blurFactorOf(BuildContext context) {
    var factor = 1.0;
    for (var scope = maybeOf(context); scope != null; scope = scope.parent) {
      if (scope.opacity < 1) return 0;
      factor *= scope.nestedProgress;
    }
    return factor;
  }

  @override
  bool updateShouldNotify(FrostContentRevealScope oldWidget) =>
      opacity != oldWidget.opacity || nestedProgress != oldWidget.nestedProgress || handle != oldWidget.handle || parent != oldWidget.parent;
}

/// Registration has no notifications or animation writes during build/layout.
class FrostGlassRegistration extends StatefulWidget {
  const FrostGlassRegistration({required this.enabled, required this.child, super.key});
  final bool enabled;
  final Widget child;
  @override
  State<FrostGlassRegistration> createState() => _FrostGlassRegistrationState();
}

class _FrostGlassRegistrationState extends State<FrostGlassRegistration> {
  Set<FrostRevealHandle> _handles = {};
  void _sync() {
    final next = <FrostRevealHandle>{};
    if (widget.enabled) {
      for (var scope = FrostContentRevealScope.maybeOf(context); scope != null; scope = scope.parent) {
        next.add(scope.handle);
      }
    }
    for (final handle in _handles.difference(next)) {
      handle.unregister(this);
    }
    for (final handle in next.difference(_handles)) {
      handle.register(this);
    }
    _handles = next;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FrostGlassRegistration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) _sync();
  }

  @override
  void dispose() {
    for (final handle in _handles) {
      handle.unregister(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Standard painting API only. At full opacity no OpacityLayer is attached.
/// Keeping this render object in place preserves arbitrary child state/focus.
class FrostContentFade extends SingleChildRenderObjectWidget {
  const FrostContentFade({required this.opacity, required super.child, this.alwaysIncludeSemantics = false, this.animation, super.key});
  final Animation<double>? animation;
  final double opacity;
  final bool alwaysIncludeSemantics;
  @override
  RenderFrostContentFade createRenderObject(BuildContext context) => RenderFrostContentFade(opacity, alwaysIncludeSemantics)..animation = animation;
  @override
  void updateRenderObject(BuildContext context, RenderFrostContentFade renderObject) {
    renderObject
      ..opacity = opacity
      ..animation = animation
      ..alwaysIncludeSemantics = alwaysIncludeSemantics;
  }
}

class RenderFrostContentFade extends RenderProxyBox {
  RenderFrostContentFade(double opacity, this.alwaysIncludeSemantics) : _opacity = opacity;
  double _opacity;
  bool alwaysIncludeSemantics;
  Animation<double>? _animation;
  Animation<double>? get animation => _animation;
  set animation(Animation<double>? value) {
    if (_animation == value) return;
    if (attached) _animation?.removeListener(_animationChanged);
    _animation = value;
    if (attached) _animation?.addListener(_animationChanged);
    _animationChanged();
  }

  void _animationChanged() {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation?.addListener(_animationChanged);
  }

  @override
  void detach() {
    _animation?.removeListener(_animationChanged);
    super.detach();
  }

  double get opacity => _animation?.value.clamp(0.0, 1.0) ?? _opacity;
  set opacity(double value) {
    if (_opacity == value) return;
    _opacity = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && opacity > 0 && opacity < 1;
  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || opacity <= 0) return;
    if (opacity >= 1) {
      layer = null;
      super.paint(context, offset);
    } else {
      layer = context.pushOpacity(offset, (opacity * 255).round(), super.paint, oldLayer: layer as OpacityLayer?);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (opacity > 0 || alwaysIncludeSemantics) super.visitChildrenForSemantics(visitor);
  }
}

/// Uses the same reveal contract for an animation owned by another component.
class FrostMaterialRevealTransition extends StatefulWidget {
  const FrostMaterialRevealTransition({
    required this.opacity,
    required this.child,
    this.handle,
    this.contentOnly = false,
    this.alwaysIncludeSemantics = false,
    this.layoutDriven = false,
    super.key,
  });
  final Animation<double> opacity;
  final Widget child;
  final FrostRevealHandle? handle;
  final bool contentOnly, alwaysIncludeSemantics, layoutDriven;
  @override
  State<FrostMaterialRevealTransition> createState() => _FrostMaterialRevealTransitionState();
}

class _FrostMaterialRevealTransitionState extends State<FrostMaterialRevealTransition> {
  void _changed() {
    // A layout identity can synchronously reset the live fade to zero. Its
    // render listener hides that frame without scheduling a build from layout.
    // The next ordinary animation tick resolves the material scope before paint.
    if (widget.layoutDriven && SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.opacity.addListener(_changed);
  }

  @override
  void didUpdateWidget(FrostMaterialRevealTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.opacity != oldWidget.opacity) {
      oldWidget.opacity.removeListener(_changed);
      widget.opacity.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.opacity.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMaterialReveal(
    opacity: widget.opacity.value,
    paintOpacity: widget.layoutDriven ? widget.opacity : null,
    handle: widget.handle,
    contentOnly: widget.contentOnly,
    alwaysIncludeSemantics: widget.alwaysIncludeSemantics,
    child: widget.child,
  );
}

/// Library-owned routes keep their animation alive through the pre-close phase.
/// External route builders cannot extend their owner's dismissal lifetime.
Simulation? frostGlassExitSimulation(FrostRevealHandle handle, double start, Duration duration) {
  if (!handle.hasNestedGlass || handle.nestedProgress <= 0) return null;
  handle.prepareClose();
  return _GlassExitSimulation(handle, start, duration);
}

class _GlassExitSimulation extends Simulation {
  _GlassExitSimulation(this.handle, this.start, Duration duration) : travel = duration.inMicroseconds / Duration.microsecondsPerSecond;
  final FrostRevealHandle handle;
  final double start, travel;
  double? _readyAt;
  @override
  double x(double time) {
    if (handle.nestedProgress > 0) return start;
    // Paint sigma zero once at full content opacity before the route travels.
    // Both phases use ticker time; there is no post-frame callback or tree move.
    _readyAt ??= time;
    return travel == 0 ? 0 : start * (1 - (time - _readyAt!) / travel).clamp(0.0, 1.0);
  }

  @override
  double dx(double time) => _readyAt == null || isDone(time) || travel == 0 ? 0 : -start / travel;
  @override
  bool isDone(double time) => _readyAt != null && time >= _readyAt! + travel;
}

/// Implicit fades use the same pre-close handshake before changing opacity.
class FrostAnimatedMaterialReveal extends StatefulWidget {
  const FrostAnimatedMaterialReveal({
    required this.opacity,
    required this.duration,
    required this.child,
    this.materialOnly = false,
    this.contentOnly = true,
    this.curve = Curves.linear,
    super.key,
  });
  final double opacity;
  final Duration duration;
  final Widget child;
  final bool materialOnly, contentOnly;
  final Curve curve;
  @override
  State<FrostAnimatedMaterialReveal> createState() => _FrostAnimatedMaterialRevealState();
}

class _FrostAnimatedMaterialRevealState extends State<FrostAnimatedMaterialReveal> with SingleTickerProviderStateMixin {
  final _handle = FrostRevealHandle();
  late final _opacity = AnimationController(vsync: this, value: widget.opacity);
  int _generation = 0;

  void _animate() {
    final generation = ++_generation;
    void start() {
      if (mounted && generation == _generation) _opacity.animateTo(widget.opacity, duration: widget.duration, curve: widget.curve);
    }

    if (widget.opacity < _opacity.value && _handle.hasNestedGlass && _handle.nestedProgress > 0) {
      _handle.prepareClose().then((ready) {
        if (ready) start();
      });
    } else {
      if (widget.opacity >= _opacity.value) _handle.cancelClose();
      start();
    }
  }

  @override
  void didUpdateWidget(FrostAnimatedMaterialReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.opacity != oldWidget.opacity) _animate();
  }

  @override
  void dispose() {
    _generation++;
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _opacity,
    child: widget.child,
    builder: (context, child) =>
        FrostMaterialReveal(opacity: _opacity.value, handle: _handle, materialOnly: widget.materialOnly, contentOnly: widget.contentOnly, child: child!),
  );
}
