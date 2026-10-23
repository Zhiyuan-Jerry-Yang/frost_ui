import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../primitives/_page_outline.dart';
import '../surface/ambient_backdrop.dart';
import '_material_reveal.dart';

/// Shared stationary media/desktop transition. Content, scrim and Hero derive
/// from the same route animation; glass keeps its existing close sequence.
Widget frostPageTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
    frostOwnedPageTransition(context, animation, secondaryAnimation, child);

Widget frostOwnedPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  FrostRevealHandle? revealHandle,
  PageRoute<Object?>? route,
  bool media = true,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  final platform = Theme.of(context).platform;
  if (!media && route != null && (platform == TargetPlatform.android || platform == TargetPlatform.iOS)) {
    final predictive = FrostScope.configOf(context).predictiveBack;
    final builder = platform == TargetPlatform.iOS
        ? const CupertinoPageTransitionsBuilder()
        : predictive
        ? const PredictiveBackPageTransitionsBuilder()
        : const FadeForwardsPageTransitionsBuilder();
    final outline = FrostPageOutline.maybeOf(context);
    final panel = outline != null && outline.radius != BorderRadius.zero;
    // Keep the wrapper mounted across a compact/wide resize so page state,
    // scroll positions and focus survive when the panel outline changes.
    final page = ClipPath(
      clipBehavior: panel ? Clip.antiAlias : Clip.none,
      clipper: panel
          ? FrostPageViewportClip(radius: outline.radius, continuous: FrostScope.configOf(context).continuousCorners, channel: outline.scrollbarChannel)
          : null,
      child: child,
    );
    final media = MediaQuery.of(context);
    // A moving panel owns its outline, including the scrollbar channel and
    // continuous corners. Android's predictive transition otherwise applies
    // physical display corners to this inset viewport a second time. Scope the
    // rectangular native clip to the transition; page content keeps real device
    // metrics, and fullscreen routes keep Flutter's display-corner behavior.
    final native = platform == TargetPlatform.android
        ? MediaQuery(
            data: panel ? media.applyDisplayCornerRadii(BorderRadius.zero) : media,
            child: Builder(
              builder: (context) => builder.buildTransitions(route, context, animation, secondaryAnimation, MediaQuery(data: media, child: page)),
            ),
          )
        : builder.buildTransitions(route, context, animation, secondaryAnimation, page);
    final guarded = AnimatedBuilder(
      animation: animation,
      child: native,
      builder: (context, child) =>
          FrostMaterialReveal(opacity: 1, contentOnly: true, deferNestedBlur: animation.value < 1, handle: revealHandle, child: child!),
    );
    return guarded;
  }
  return _BackGestureBridge(
    child: _PageTransition(animation: animation, revealHandle: revealHandle, child: child),
  );
}

class FrostPageTransitionsBuilder extends PageTransitionsBuilder {
  const FrostPageTransitionsBuilder({this.reducedMotion = false});
  final bool reducedMotion;
  @override
  Duration get transitionDuration => reducedMotion ? Duration.zero : FrostMotion.page;
  @override
  Duration get reverseTransitionDuration => reducedMotion ? Duration.zero : FrostMotion.exit;
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      reducedMotion || route.isFirst ? child : frostOwnedPageTransition(context, animation, secondaryAnimation, child, route: route, media: false);
}

const _previousDimAlpha = .2;

// Content and scrim use raw route progress so a held gesture, its commit and
// its cancellation all paint the same opacity. Hero retains its geometric curve.
class _PageTransition extends StatelessWidget {
  const _PageTransition({required this.animation, required this.child, this.revealHandle});
  final Animation<double> animation;
  final FrostRevealHandle? revealHandle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final moving = animation.status != AnimationStatus.completed;
        final opacity = animation.value.clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: FrostThemeTokens.of(context).onMediaScrim.withValues(alpha: moving ? _previousDimAlpha * opacity : 0)),
              ),
            ),
            FrostMaterialReveal(
              contentOnly: true,
              handle: revealHandle,
              opacity: opacity,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(child: (moving && route?.opaque != false) ? const FrostAmbientBackdrop() : const SizedBox.shrink()),
                  child!,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Only a binding for routes whose visual transition is the stationary media
// fade. Native ordinary transitions own their own binding. There are no release poses or substitute commit motions.
class _BackGestureBridge extends StatefulWidget {
  const _BackGestureBridge({required this.child});
  final Widget child;
  @override
  State<_BackGestureBridge> createState() => _BackGestureBridgeState();
}

class _BackGestureBridgeState extends State<_BackGestureBridge> with WidgetsBindingObserver {
  ModalRoute<Object?>? _route;
  VoidCallback? _finishGesture;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finishGesture?.call();
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    final route = _route;
    if (Theme.of(context).platform != TargetPlatform.android ||
        event.isButtonEvent ||
        route == null ||
        !mounted ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    final root = Navigator.of(context, rootNavigator: true);
    if (route.navigator != root && root.canPop()) return false;
    if (!FrostScope.configOf(context).predictiveBack) return false;
    route.handleStartBackGesture(progress: 1 - event.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent event) {
    _route?.handleUpdateBackGestureProgress(progress: 1 - event.progress);
  }

  @override
  void handleCancelBackGesture() => _route?.handleCancelBackGesture();
  @override
  void handleCommitBackGesture() {
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null) return;
    // R16: TransitionRoute.handleCommitBackGesture reverses from 1 for the
    // official Android visual preset. A media Hero must keep its current route
    // progress instead. Ordinary Navigator.pop already reverses continuously.
    // Keep the gesture alive until that reverse ends so HeroController.didPop
    // continues the existing flight rather than creating a second one.
    navigator.pop();
    final animation = route.animation!;
    if (!animation.isAnimating) {
      if (navigator.mounted && navigator.userGestureInProgress) navigator.didStopUserGesture();
      return;
    }
    var finished = false;
    late AnimationStatusListener status;
    void finish() {
      if (finished) return;
      finished = true;
      animation.removeStatusListener(status);
      _finishGesture = null;
      if (navigator.mounted && navigator.userGestureInProgress) navigator.didStopUserGesture();
    }

    status = (value) {
      if (value == AnimationStatus.dismissed || value == AnimationStatus.completed) finish();
    };
    _finishGesture = finish;
    animation.addStatusListener(status);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
