import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../motion/_material_reveal.dart';
import '../motion/page_transition.dart';

/// A pushed detail page with the shared page transition. It is a plain
/// [Page], so any router that takes pages (go_router's pageBuilder,
/// Navigator 2.0) can use it. Media Hero flights run independently of the
/// ordinary page motion.
///
/// Prefer this page for content containing Frost glass surfaces. Nested blur
/// starts after the page transition has completed. Before dismissal it fades out
/// over 140 ms while content stays opaque, then the usual route exit runs. Predictive back
/// keeps its interactive pose and cancellation behavior. Plain or solid pages
/// keep their original exit duration.
class FrostDetailPage<T> extends Page<T> {
  const FrostDetailPage({required this.child, this.opaque = true, super.key, super.name, super.arguments, super.restorationId}) : _media = false;

  /// Stationary Hero-compatible content timing, with native route progress.
  /// Android gestures drive route progress directly and commit through normal
  /// Navigator.pop, so the in-flight Hero never restarts at full size.
  const FrostDetailPage.media({required this.child, this.opaque = true, super.key, super.name, super.arguments, super.restorationId}) : _media = true;

  final bool _media;

  final Widget child;

  /// Whether this page fully obscures the route below it after its transition.
  /// Set false for media viewers whose background fades during drag dismissal.
  /// This retains the owned glass exit sequence and predictive back behavior.
  final bool opaque;

  @override
  Route<T> createRoute(BuildContext context) => _FrostDetailRoute<T>(page: this, context: context);
}

class _FrostDetailRoute<T> extends PageRoute<T> {
  _FrostDetailRoute({required FrostDetailPage<T> page, required BuildContext context})
    : _duration = FrostMotion.duration(context, _nativeBuilder(page, context)?.transitionDuration ?? FrostMotion.page),
      _reverseDuration = FrostMotion.duration(context, _nativeBuilder(page, context)?.reverseTransitionDuration ?? FrostMotion.exit),
      super(settings: page);

  static PageTransitionsBuilder? _nativeBuilder(FrostDetailPage<Object?> page, BuildContext context) {
    final platform = Theme.of(context).platform;
    // Cupertino owns its edge recognizer, including media Hero progress.
    if (platform == TargetPlatform.iOS) return const CupertinoPageTransitionsBuilder();
    if (!page._media && platform == TargetPlatform.android) {
      return FrostScope.configOf(context).predictiveBack ? const PredictiveBackPageTransitionsBuilder() : const FadeForwardsPageTransitionsBuilder();
    }
    return null;
  }

  final _glass = FrostRevealHandle();
  final Duration _duration;
  final Duration _reverseDuration;
  FrostDetailPage<T> get _page => settings as FrostDetailPage<T>;
  @override
  Duration get transitionDuration => _duration;
  @override
  Duration get reverseTransitionDuration => _reverseDuration + (_glass.hasNestedGlass && _glass.nestedProgress > 0 ? frostNestedGlassDuration : Duration.zero);

  @override
  Simulation? createSimulation({required bool forward}) =>
      (forward || navigator?.userGestureInProgress == true) ? null : frostGlassExitSimulation(_glass, controller!.value, _reverseDuration);

  @override
  bool get opaque => _page.opaque;
  @override
  bool get maintainState => true;
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => _page.child;
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => frostOwnedPageTransition(
    context,
    animation,
    secondaryAnimation,
    child,
    revealHandle: _glass,
    route: this,
    media: _page._media && Theme.of(context).platform != TargetPlatform.iOS,
  );
}
