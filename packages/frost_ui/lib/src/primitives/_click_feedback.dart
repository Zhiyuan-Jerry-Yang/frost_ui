import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../foundation/_ambient_material.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';
import '../motion/_spring_simulation.dart';
import '../surface/_window_background.dart';
import '_focus_outline.dart';
import '_media_image_registry.dart';
import '_shape_fill.dart';
import 'click_surface.dart' show FrostClickFeedback;
import 'surface.dart';

/// Shared feedback paint only; owners decide which input events are active.
class FrostClickFeedbackVisual extends StatelessWidget {
  const FrostClickFeedbackVisual({
    required this.states,
    required this.child,
    this.feedback = FrostClickFeedback.surface,
    this.shape,
    this.clipsContent = true,
    this.fillsBounds = false,
    this.highlighted = false,
    this.scalesOnPress = false,
    this.mediaImages,
    super.key,
  });
  final Set<WidgetState> states;
  final Widget child;
  final FrostClickFeedback feedback;
  final ShapeBorder? shape;
  final bool clipsContent;
  final bool fillsBounds;
  final bool highlighted;
  // Slider animates its own thumb diameter but shares feedback and focus.
  final bool scalesOnPress;
  final FrostMediaImageRegistry? mediaImages;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final activeStates = TickerMode.valuesOf(context).enabled ? states : (states.toSet()..removeAll({WidgetState.pressed, WidgetState.hovered}));
    final enabled = !activeStates.contains(WidgetState.disabled);
    final border = shape ?? FrostRadius.shape(context, FrostRadius.md);
    var color = switch (feedback) {
      FrostClickFeedback.surface => frostFeedbackSurface(tokens, activeStates, resting: highlighted ? tokens.fillSubtle : Colors.transparent),
      FrostClickFeedback.quiet => frostButtonStateLayer(tokens, activeStates, FrostFeedbackRole.quiet),
      FrostClickFeedback.media => Colors.transparent,
    };
    final actualWindow = FrostWindowBackgroundScope.maybeOf(context)?.background;
    if (actualWindow != null && color.a > 0) {
      color = frostReadableWindowFill(tokens, color, FrostSurfaceScope.maybeOf(context)?.background ?? actualWindow, tokens.textSecondary);
    }
    final rectangular = fillsBounds || (clipsContent && frostNeedsClippedFill(border, Directionality.of(context)));
    Widget content = FrostInteractionDecoration(
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      decoration: rectangular ? BoxDecoration(color: color) : ShapeDecoration(shape: border, color: color),
      foregroundDecoration: rectangular && border is OutlinedBorder && border.side != BorderSide.none ? ShapeDecoration(shape: border) : null,
      child: child,
    );
    if (clipsContent) {
      content = ClipPath(
        clipper: ShapeBorderClipper(shape: border),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }
    if (scalesOnPress) {
      // Scale the clipped shape as a unit. Clipping a stationary outer shape
      // around a shrinking rectangular image exposes square inner corners.
      content = FrostInteractionScale(
        mediaImages: mediaImages,
        value: enabled && activeStates.contains(WidgetState.pressed) ? FrostMetrics.pressedScale(context, media: feedback == FrostClickFeedback.media) : 1,
        child: content,
      );
    }
    return CustomPaint(
      foregroundPainter: enabled && frostShowsFocus(activeStates)
          ? FrostFocusOutlinePainter(border, tokens.focus, FrostMetrics.focusBorderWidth, Directionality.of(context))
          : null,
      child: content,
    );
  }
}

/// Internal transient feedback, unlike a layout/selection spring: a covered
/// route must not retain a partially pressed or hovered scale for Hero landing.
/// The child stays mounted when tickers mute; only this feedback is reset.
class FrostInteractionScale extends StatefulWidget {
  const FrostInteractionScale({required this.value, required this.child, this.mediaImages, super.key});
  final double value;
  final Widget child;
  final FrostMediaImageRegistry? mediaImages;
  @override
  State<FrostInteractionScale> createState() => _InteractionScaleState();
}

class _InteractionScaleState extends State<FrostInteractionScale> with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: widget.mediaImages == null ? widget.value : 1);
  bool _tickersEnabled = true, _reducedMotion = false;
  @override
  void initState() {
    super.initState();
    widget.mediaImages?.addListener(_update);
  }

  void _update() {
    // Presence changes can arrive during descendant build/deactivation. Only
    // render objects listen to the media animation: no ancestor setState,
    // post-frame readiness lag, or image-state-dependent subtree replacement.
    final displayed = widget.mediaImages?.hasImages ?? true;
    final target = displayed && _tickersEnabled ? widget.value : 1.0;
    if (!displayed || !_tickersEnabled || _reducedMotion) {
      _scale.value = target;
    } else {
      _scale.animateWith(frostSpringSimulation(FrostMotion.snappy, _scale.value, target, _scale.velocity));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.mediaImages != null || !_tickersEnabled || _reducedMotion) _update();
  }

  @override
  void didUpdateWidget(FrostInteractionScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaImages != widget.mediaImages) {
      oldWidget.mediaImages?.removeListener(_update);
      widget.mediaImages?.addListener(_update);
    }
    if (widget.value != oldWidget.value || widget.mediaImages != oldWidget.mediaImages || !_tickersEnabled) _update();
  }

  @override
  void dispose() {
    widget.mediaImages?.removeListener(_update);
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.mediaImages == null
      ? AnimatedBuilder(
          animation: _scale,
          child: widget.child,
          builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        )
      : _MediaScaleTransform(animation: _scale, child: widget.child);
}

/// A normal RenderTransform driven directly by animation. Unlike rebuilding an
/// AnimatedBuilder, this can synchronously cancel scaling when a descendant
/// image unregisters during build. The whole clipped card still scales as one
/// unit on press; only the image inside that clip zooms on hover.
class _MediaScaleTransform extends SingleChildRenderObjectWidget {
  const _MediaScaleTransform({required this.animation, required super.child});
  final Animation<double> animation;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMediaScale(animation);
  @override
  void updateRenderObject(BuildContext context, covariant _RenderMediaScale renderObject) => renderObject.animation = animation;
}

class _RenderMediaScale extends RenderTransform {
  _RenderMediaScale(this._animation) : super(transform: Matrix4.diagonal3Values(_animation.value, _animation.value, 1), alignment: Alignment.center);
  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(_update);
    _animation = value;
    if (attached) _animation.addListener(_update);
    _update();
  }

  void _update() => transform = Matrix4.diagonal3Values(_animation.value, _animation.value, 1);
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_update);
    _update();
  }

  @override
  void detach() {
    _animation.removeListener(_update);
    super.detach();
  }
}

/// Decoration feedback uses Flutter's normal implicit tween, but completes it
/// when a route's tickers mute, even if its resting target was already set.
/// Merely changing duration to zero would leave an unchanged tween paused.
class FrostInteractionDecoration extends ImplicitlyAnimatedWidget {
  const FrostInteractionDecoration({required this.decoration, this.foregroundDecoration, required this.child, required super.duration, super.curve, super.key});
  final Decoration decoration;
  final Decoration? foregroundDecoration;
  final Widget child;
  @override
  AnimatedWidgetBaseState<FrostInteractionDecoration> createState() => _InteractionDecorationState();
}

class _InteractionDecorationState extends AnimatedWidgetBaseState<FrostInteractionDecoration> {
  DecorationTween? _decoration, _foreground;
  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _decoration = visitor(_decoration, widget.decoration, (value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
    _foreground = visitor(_foreground, widget.foregroundDecoration, (value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) controller.value = 1;
  }

  @override
  void didUpdateWidget(FrostInteractionDecoration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!TickerMode.valuesOf(context).enabled) controller.value = 1;
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _decoration!.evaluate(animation),
    child: _foreground == null
        ? widget.child
        : DecoratedBox(decoration: _foreground!.evaluate(animation), position: DecorationPosition.foreground, child: widget.child),
  );
}
