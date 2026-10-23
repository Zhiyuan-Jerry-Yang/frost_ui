import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

import '../foundation/tokens.dart';
import 'refresh_indicator.dart';

typedef FrostRefreshViewBuilder = Widget Function(BuildContext context, ScrollPhysics? physics, FrostRefreshLocators locators);

typedef FrostNestedRefreshBodyBuilder = Widget Function(BuildContext context, FrostRefreshLocators locators);

typedef FrostNestedRefreshViewBuilder = Widget Function(BuildContext context, FrostNestedRefreshContext refresh);

typedef FrostRefreshAction = FutureOr<bool> Function();

const _dataRefreshPrimaryScrollPlatforms = <TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.fuchsia,
  TargetPlatform.iOS,
  TargetPlatform.linux,
  TargetPlatform.macOS,
  TargetPlatform.windows,
};

class FrostNestedRefreshContext {
  const FrostNestedRefreshContext._({required this.physics, required this.scrollController, required this.locators, required this._bodyBuilder});

  final ScrollPhysics? physics;
  final ScrollController scrollController;
  final FrostRefreshLocators locators;
  final Widget Function(FrostNestedRefreshBodyBuilder builder) _bodyBuilder;

  Widget body({required FrostNestedRefreshBodyBuilder builder}) {
    return _bodyBuilder(builder);
  }
}

class FrostRefreshLocators {
  const FrostRefreshLocators._({this.sliverHeader});

  final Widget? sliverHeader;

  static const refresh = FrostRefreshLocators._(sliverHeader: FrostRefreshSliverHeader());
}

class FrostRefreshView extends StatefulWidget {
  const FrostRefreshView({required this.builder, this.scrollController, this.onRefresh, super.key});

  final ScrollController? scrollController;
  final FrostRefreshAction? onRefresh;
  final FrostRefreshViewBuilder builder;

  @override
  State<FrostRefreshView> createState() => _DataRefreshViewState();
}

class FrostNestedRefreshView extends StatefulWidget {
  const FrostNestedRefreshView({required this.builder, this.onRefresh, this.headerSnapExtent, this.headerMobileSnapTriggerExtent = 64, super.key});

  final FrostRefreshAction? onRefresh;
  final double? headerSnapExtent;
  final double headerMobileSnapTriggerExtent;
  final FrostNestedRefreshViewBuilder builder;

  @override
  State<FrostNestedRefreshView> createState() => _DataNestedRefreshViewState();
}

mixin _DataRefreshCallbackMixin<T extends StatefulWidget> on State<T> {
  FrostRefreshAction? get _onRefresh;

  Future<bool>? _refreshTask;

  Future<bool> _handleRefresh() {
    final active = _refreshTask;
    if (active != null) return active;
    late final Future<bool> task;
    task = _refresh().whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
    _refreshTask = task;
    return task;
  }

  Future<bool> _refresh() async {
    final onRefresh = _onRefresh;
    if (onRefresh == null) {
      return true;
    }

    await _waitForSafeCallbackPhase();
    if (!mounted) return false;
    try {
      return await Future<bool>.value(onRefresh());
    } catch (e, s) {
      log('Failed to refresh data view.', error: e, stackTrace: s);
      return false;
    }
  }

  Future<void> _waitForSafeCallbackPhase() async {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      return;
    }

    await SchedulerBinding.instance.endOfFrame;
  }
}

class _DataRefreshViewState extends State<FrostRefreshView> with _DataRefreshCallbackMixin<FrostRefreshView> {
  late final ScrollController _ownedScrollController = ScrollController();

  ScrollController get _effectiveScrollController => widget.scrollController ?? _ownedScrollController;

  @override
  FrostRefreshAction? get _onRefresh => widget.onRefresh;

  @override
  Widget build(BuildContext context) {
    final child = ScrollConfiguration(
      behavior: frostRefreshPageScrollBehavior,
      child: PrimaryScrollController(
        controller: _effectiveScrollController,
        automaticallyInheritForPlatforms: _dataRefreshPrimaryScrollPlatforms,
        child: widget.builder(context, frostRefreshPhysics, FrostRefreshLocators.refresh),
      ),
    );

    return PullToRefreshNotification(
      color: FrostThemeTokens.of(context).textPrimary,
      maxDragOffset: FrostRefreshSliverHeader.maxDragOffset,
      refreshOffset: FrostRefreshSliverHeader.refreshOffset,
      reachToRefreshOffset: FrostRefreshSliverHeader.reachToRefreshOffset,
      armedDragUpCancel: false,
      // Keep the refresh extent until the action Future completes.
      pullBackOnRefresh: false,
      pullBackOnError: true,
      onRefresh: _handleRefresh,
      // Refresh availability can change with a tab. Keep the child at the
      // same tree location so its pager, providers and scroll state survive.
      notificationPredicate: (notification) => widget.onRefresh != null && defaultNotificationPredicate(notification),
      child: child,
    );
  }

  @override
  void dispose() {
    _ownedScrollController.dispose();
    super.dispose();
  }
}

class _DataNestedRefreshViewState extends State<FrostNestedRefreshView> with _DataRefreshCallbackMixin<FrostNestedRefreshView> {
  final _nestedScrollController = ScrollController();
  bool _nestedHeaderSnapAnimating = false;

  @override
  FrostRefreshAction? get _onRefresh => widget.onRefresh;

  @override
  Widget build(BuildContext context) {
    final refresh = FrostNestedRefreshContext._(
      physics: frostRefreshPhysics,
      scrollController: _nestedScrollController,
      locators: FrostRefreshLocators.refresh,
      bodyBuilder: _buildNestedBody,
    );

    Widget child = ScrollConfiguration(behavior: frostRefreshScrollBehavior, child: widget.builder(context, refresh));

    if (widget.headerSnapExtent != null) {
      child = NotificationListener<ScrollNotification>(onNotification: _handleNestedHeaderSnapNotification, child: child);
    }

    return PullToRefreshNotification(
      color: FrostThemeTokens.of(context).textPrimary,
      maxDragOffset: FrostRefreshSliverHeader.maxDragOffset,
      refreshOffset: FrostRefreshSliverHeader.refreshOffset,
      reachToRefreshOffset: FrostRefreshSliverHeader.reachToRefreshOffset,
      armedDragUpCancel: false,
      // Keep the refresh extent until the action Future completes.
      pullBackOnRefresh: false,
      pullBackOnError: true,
      onRefresh: _handleRefresh,
      notificationPredicate: (notification) => widget.onRefresh != null && defaultNotificationPredicate(notification),
      child: child,
    );
  }

  @override
  void dispose() {
    _nestedScrollController.dispose();
    super.dispose();
  }

  Widget _buildNestedBody(FrostNestedRefreshBodyBuilder builder) {
    return Builder(builder: (context) => builder(context, FrostRefreshLocators.refresh));
  }

  bool _handleNestedHeaderSnapNotification(ScrollNotification notification) {
    final snapExtent = widget.headerSnapExtent;
    if (snapExtent == null || snapExtent <= 0 || notification.depth != 0 || notification.metrics.axis != Axis.vertical || _nestedHeaderSnapAnimating) {
      return false;
    }

    if (notification is! ScrollUpdateNotification || notification.dragDetails == null) {
      return false;
    }

    final scrollDelta = notification.scrollDelta;
    final pixels = notification.metrics.pixels;
    if (scrollDelta == null || scrollDelta <= 0 || pixels <= 0 || pixels >= snapExtent - 1) {
      return false;
    }

    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.linux || platform == TargetPlatform.macOS || platform == TargetPlatform.windows) {
      return false;
    }

    if (pixels >= widget.headerMobileSnapTriggerExtent) {
      _animateNestedHeaderTo(snapExtent, duration: const Duration(milliseconds: 260));
    }

    return false;
  }

  Future<void> _animateNestedHeaderTo(double target, {required Duration duration}) async {
    if (!_nestedScrollController.hasClients) {
      return;
    }

    ScrollPosition? scrollPosition;
    for (final position in _nestedScrollController.positions) {
      if (position.axis == Axis.vertical) {
        scrollPosition = position;
        break;
      }
    }

    if (scrollPosition == null || !scrollPosition.hasPixels) {
      return;
    }

    final clampedTarget = target.clamp(scrollPosition.minScrollExtent, scrollPosition.maxScrollExtent);
    if ((scrollPosition.pixels - clampedTarget).abs() < 1) {
      return;
    }

    _nestedHeaderSnapAnimating = true;
    try {
      await scrollPosition.animateTo(clampedTarget, duration: duration, curve: Curves.easeOutCubic);
    } finally {
      _nestedHeaderSnapAnimating = false;
    }
  }
}
