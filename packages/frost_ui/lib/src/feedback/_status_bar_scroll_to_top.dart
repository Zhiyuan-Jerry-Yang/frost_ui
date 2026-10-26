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
    if (!widget.enabled || Theme.of(context).platform != TargetPlatform.iOS || !TickerMode.valuesOf(context).enabled || !_isForeground()) return;
    final positions = widget.controller.positions;
    // Fail closed while a viewport is detaching/replacing its controller.
    if (positions.length != 1) return;
    final position = positions.single;
    if (position.axis != Axis.vertical || !position.hasContentDimensions || !position.hasPixels || position.pixels <= position.minScrollExtent) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(position.minScrollExtent);
    } else {
      unawaited(position.animateTo(position.minScrollExtent, duration: FrostMotion.gentleDuration, curve: Curves.easeOutCubic));
    }
  }

  bool _isForeground() {
    // A nested branch's own route can remain current underneath a root modal.
    // Check its containing routes as well, including push/pop transitions.
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
