import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../foundation/metrics.dart';

/// Bridges the native event to a feed below the shell's Scaffold. A primary
/// controller below that Scaffold cannot be found by its status-bar handler.
class FrostStatusBarScrollToTop extends StatefulWidget {
  const FrostStatusBarScrollToTop({required this.enabled, required this.controller, required this.child, super.key});

  final bool enabled;
  final ScrollController controller;
  final Widget child;

  @override
  State<FrostStatusBarScrollToTop> createState() => _StatusBarScrollToTopState();
}

class _StatusBarScrollToTopState extends State<FrostStatusBarScrollToTop> with WidgetsBindingObserver {
  final _hitTarget = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void handleStatusBarTap() {
    // An app-wide host owns event routing when installed. Keep the standalone
    // feed API available for callers that have not adopted that host.
    if (FrostScrollToTopScope.contains(context) || !widget.enabled || !frostScrollToTopRouteIsActive(context) || !_isForeground()) return;
    final positions = widget.controller.positions;
    // Fail closed while a viewport is detaching/replacing its controller.
    if (positions.length != 1) return;
    frostScrollPositionToTop(positions.single, context);
  }

  bool _isForeground() {
    final markerContext = _hitTarget.currentContext;
    final marker = markerContext?.findRenderObject();
    if (markerContext == null || marker is! RenderMetaData || !marker.attached || !marker.hasSize || marker.size.isEmpty) return false;
    // Route checks alone cannot see a sibling Navigator covering this feed.
    // Probe inside its top edge, including pinned chrome, in its actual View.
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, marker.localToGlobal(Offset(marker.size.width / 2, .5)), View.of(markerContext).viewId);
    return result.path.any((entry) => identical(entry.target, marker));
  }

  @override
  Widget build(BuildContext context) => MetaData(key: _hitTarget, behavior: HitTestBehavior.translucent, child: widget.child);
}

class FrostScrollToTopScope extends InheritedWidget {
  const FrostScrollToTopScope({required super.child, super.key});
  static bool contains(BuildContext context) => context.getInheritedWidgetOfExactType<FrostScrollToTopScope>() != null;
  @override
  bool updateShouldNotify(FrostScrollToTopScope oldWidget) => false;
}

bool frostScrollToTopRouteIsActive(BuildContext context) {
  if (Theme.of(context).platform != TargetPlatform.iOS || !TickerMode.valuesOf(context).enabled) return false;
  // A nested branch can remain current underneath a containing root modal.
  var route = ModalRoute.of(context);
  while (route != null) {
    if (!route.isCurrent ||
        route.offstage ||
        (route.animation != null && !route.animation!.isCompleted) ||
        (route.secondaryAnimation != null && !route.secondaryAnimation!.isDismissed)) {
      return false;
    }
    final navigator = route.navigator;
    route = navigator == null ? null : ModalRoute.of(navigator.context);
  }
  return true;
}

void frostScrollPositionToTop(ScrollPosition position, BuildContext context) {
  if (position.axis != Axis.vertical || !position.hasContentDimensions || !position.hasPixels) return;
  final top = position.axisDirection == AxisDirection.up ? position.maxScrollExtent : position.minScrollExtent;
  if ((position.pixels - top).abs() < .5) return;
  if (MediaQuery.disableAnimationsOf(context)) {
    position.jumpTo(top);
  } else {
    unawaited(position.animateTo(top, duration: FrostMotion.gentleDuration, curve: Curves.easeOutCubic));
  }
}
