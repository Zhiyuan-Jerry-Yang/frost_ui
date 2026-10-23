import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../motion/_page_curve.dart';
import 'media_stage.dart';

/// Pairs a card instance with the detail it opened, using object identity.
/// Do not derive tags from a work ID: the same work can occupy several cards.
final class FrostMediaHeroTag {
  FrostMediaHeroTag({required this.image, required double aspectRatio, required BorderRadius sourceRadius})
    : assert(aspectRatio > 0 && aspectRatio < double.infinity),
      _geometry = (aspectRatio: aspectRatio, sourceRadius: sourceRadius);

  /// The card's already decoded preview, used for both push and return flights.
  /// The tag keeps this provider for its lifetime; it owns no decoded image.
  final ImageProvider image;
  ({double aspectRatio, BorderRadius sourceRadius}) _geometry;
  double get aspectRatio => _geometry.aspectRatio;
  BorderRadius get sourceRadius => _geometry.sourceRadius;
}

/// Holds one tag while this card represents the same [identity].
/// Source geometry can update without changing the identity of an open flight.
class FrostMediaHeroSource extends StatefulWidget {
  const FrostMediaHeroSource({required this.image, required this.builder, required this.aspectRatio, required this.sourceRadius, this.identity, super.key})
    : assert(aspectRatio > 0 && aspectRatio < double.infinity);
  final ImageProvider image;
  final Widget Function(BuildContext context, FrostMediaHeroTag tag) builder;
  final double aspectRatio;
  final BorderRadius sourceRadius;
  final Object? identity;
  @override
  State<FrostMediaHeroSource> createState() => _FrostMediaHeroSourceState();
}

class _FrostMediaHeroSourceState extends State<FrostMediaHeroSource> {
  late FrostMediaHeroTag _tag = _newTag();
  FrostMediaHeroTag _newTag() => FrostMediaHeroTag(image: widget.image, aspectRatio: widget.aspectRatio, sourceRadius: widget.sourceRadius);
  @override
  void didUpdateWidget(FrostMediaHeroSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _tag = _newTag();
    } else {
      _tag._geometry = (aspectRatio: widget.aspectRatio, sourceRadius: widget.sourceRadius);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tag);
}

/// Places the same tag around the card and its detail stage.
/// Resting content can include loading and interaction widgets. Flights create
/// one plain Image from the tag preview; they never mount the source child.
/// Network loading and decoded-image ownership remain with the app.
/// Use [HeroMode] outside this widget when a stage switches to another image.
class FrostMediaHero extends StatefulWidget {
  const FrostMediaHero({required this.tag, required this.child, required this.radius, this.fit = BoxFit.cover, super.key});
  final FrostMediaHeroTag tag;
  final Widget child;
  final BorderRadius radius;
  final BoxFit fit;
  @override
  State<FrostMediaHero> createState() => _FrostMediaHeroState();
}

class _FrostMediaHeroState extends State<FrostMediaHero> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: FrostMotion.reducedFade, value: 1, animationBehavior: AnimationBehavior.preserve);
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final route = ModalRoute.of(context);
      if (MediaQuery.disableAnimationsOf(context) && route != null && !route.isFirst) _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return HeroMode(
      enabled: !reduced,
      child: Hero(
        tag: widget.tag,
        // Shared media routes keep native route progress continuous at commit.
        transitionOnUserGestures: true,
        // Rect and canvas interpolation share Flutter's non-overshooting curve.
        curve: frostPageCurve,
        reverseCurve: frostPageReverseCurve,
        createRectTween: (begin, end) => RectTween(begin: begin, end: end),
        flightShuttleBuilder: _flight,
        child: FadeTransition(
          opacity: reduced ? _fade : const AlwaysStoppedAnimation(1),
          child: _HeroFrame(
            radius: widget.radius,
            ratio: FrostMediaStageGeometry.maybeOf(context) ?? widget.tag.aspectRatio,
            fit: widget.fit,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

Widget _flight(BuildContext context, Animation<double> animation, HeroFlightDirection direction, BuildContext fromContext, BuildContext toContext) {
  final from = fromContext.findAncestorWidgetOfExactType<FrostMediaHero>()!;
  final to = toContext.findAncestorWidgetOfExactType<FrostMediaHero>()!;
  final (source, destination) = direction == HeroFlightDirection.push ? (from, to) : (to, from);
  // Animation is 0 at the card and 1 at the detail, including on pop.
  final ratio = FrostMediaStageGeometry.maybeOf(direction == HeroFlightDirection.push ? toContext : fromContext) ?? source.tag.aspectRatio;
  final sourceRadius = source.radius;
  final targetRadius = destination.radius;
  Size canvas(BuildContext endpoint, BoxFit fit) {
    final box = endpoint.findRenderObject()! as RenderBox;
    final fitted = applyBoxFit(fit, Size(ratio, 1), box.size);
    return Size(ratio * fitted.destination.width / fitted.source.width, fitted.destination.height / fitted.source.height);
  }

  // Snapshot endpoint geometry once. Ordinary flight frames only interpolate
  // canvas size and radius, without querying render trees or fitting again.
  final cardSize = ((direction == HeroFlightDirection.push ? fromContext : toContext).findRenderObject()! as RenderBox).size;
  final detailSize = ((direction == HeroFlightDirection.push ? toContext : fromContext).findRenderObject()! as RenderBox).size;
  final cardCanvas = canvas(direction == HeroFlightDirection.push ? fromContext : toContext, source.fit);
  final detailCanvas = canvas(direction == HeroFlightDirection.push ? toContext : fromContext, destination.fit);
  return AnimatedBuilder(
    animation: animation,
    child: Image(image: source.tag.image, fit: BoxFit.fill),
    builder: (context, child) {
      final radius = BorderRadius.lerp(sourceRadius, targetRadius, animation.value)!;
      final frame = _FlightFrame(
        frame: Size.lerp(cardSize, detailSize, animation.value)!,
        radius: radius,
        canvas: Size.lerp(cardCanvas, detailCanvas, animation.value)!,
        child: child!,
      );
      return frame;
    },
  );
}

class _FlightFrame extends StatelessWidget {
  const _FlightFrame({required this.frame, required this.radius, required this.canvas, required this.child});
  final Size frame;
  final BorderRadius radius;
  final Size canvas;
  final Widget child;
  @override
  Widget build(BuildContext context) => OverflowBox(
    // Hero's Positioned uses the Navigator size captured at take-off. A shell
    // bottom bar can resize that Overlay during pop; retain the flight's own
    // interpolated rectangle instead of cropping its canvas to the new height.
    alignment: Alignment.topLeft,
    minWidth: frame.width,
    maxWidth: frame.width,
    minHeight: frame.height,
    maxHeight: frame.height,
    child: ClipRRect(
      borderRadius: radius,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: canvas.width,
        maxWidth: canvas.width,
        minHeight: canvas.height,
        maxHeight: canvas.height,
        child: child,
      ),
    ),
  );
}

class _HeroFrame extends StatelessWidget {
  const _HeroFrame({required this.radius, required this.ratio, required this.fit, required this.child});
  final BorderRadius radius;
  final double ratio;
  final BoxFit fit;
  final Widget child;
  Size _canvasSize(Size image, Size frame, BoxFit fit) {
    final fitted = applyBoxFit(fit, image, frame);
    if (fitted.source.isEmpty) return Size.zero;
    return Size(image.width * fitted.destination.width / fitted.source.width, image.height * fitted.destination.height / fitted.source.height);
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return child;
        final frame = constraints.biggest;
        final image = Size(ratio, 1);
        final size = _canvasSize(image, frame, fit);
        return SizedBox.expand(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: size.width,
            maxWidth: size.width,
            minHeight: size.height,
            maxHeight: size.height,
            child: child,
          ),
        );
      },
    );
    return FrostScope.configOf(context).continuousCorners
        ? ClipRSuperellipse(borderRadius: radius, clipBehavior: Clip.antiAlias, child: content)
        : ClipRRect(borderRadius: radius, clipBehavior: Clip.antiAlias, child: content);
  }
}
