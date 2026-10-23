import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:loading_more_list/loading_more_list.dart';
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_page_scroll_behavior.dart';
import '../primitives/icon.dart';
import '../primitives/text.dart';
import 'refresh_dots.dart';

typedef FrostLoadingItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

const frostRefreshPhysics = AlwaysScrollableClampingScrollPhysics();
const frostRefreshScrollBehavior = _DataRefreshScrollBehavior();
// Single page viewports own a window-edge bar; coordinated nested bodies do not.
const frostRefreshPageScrollBehavior = _DataRefreshScrollBehavior(scrollbars: true);

class _DataRefreshScrollBehavior extends MaterialScrollBehavior {
  const _DataRefreshScrollBehavior({this.scrollbars = false});
  final bool scrollbars;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return scrollbars ? frostPageScrollbar(context, super.buildScrollbar(context, child, details)) : child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}

class FrostRefreshSliverHeader extends StatelessWidget {
  const FrostRefreshSliverHeader({super.key});

  static const refreshOffset = 56.0;
  static const reachToRefreshOffset = 84.0;
  static const maxDragOffset = 120.0;

  @override
  Widget build(BuildContext context) {
    return PullToRefreshContainer((info) {
      final mode = info?.mode;
      final offset = info?.dragOffset ?? 0.0;

      if ((mode == null || mode == PullToRefreshIndicatorMode.canceled) && offset <= 0) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      return SliverToBoxAdapter(child: _DataPullRefreshHeaderBody(info: info));
    });
  }
}

class _DataPullRefreshHeaderBody extends StatelessWidget {
  const _DataPullRefreshHeaderBody({required this.info});

  final PullToRefreshScrollNotificationInfo? info;

  @override
  Widget build(BuildContext context) {
    final translations = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    final mode = info?.mode;
    final offset = info?.dragOffset ?? 0.0;
    final height = offset.clamp(0.0, FrostRefreshSliverHeader.maxDragOffset);
    final statusText = switch (mode) {
      PullToRefreshIndicatorMode.armed => translations.releaseToRefresh,
      PullToRefreshIndicatorMode.snap || PullToRefreshIndicatorMode.refresh => translations.refreshing,
      PullToRefreshIndicatorMode.done => translations.refreshComplete,
      PullToRefreshIndicatorMode.error => translations.refreshFailed,
      _ => translations.pullToRefresh,
    };

    final indicator = switch (mode) {
      PullToRefreshIndicatorMode.snap || PullToRefreshIndicatorMode.refresh => const ExcludeSemantics(child: FrostRefreshDots()),
      PullToRefreshIndicatorMode.done => FrostIcon(icons.check, size: 22, color: FrostThemeTokens.of(context).textPrimary),
      PullToRefreshIndicatorMode.error => FrostIcon(icons.error, size: 22, color: FrostThemeTokens.of(context).negativeInk),
      _ => AnimatedRotation(
        // Keep the same arrow mounted for drag <-> armed so interrupted
        // transitions continue from the currently painted angle.
        turns: mode == PullToRefreshIndicatorMode.armed ? .5 : 0,
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        child: FrostIcon(icons.arrowDown, size: 22, color: FrostThemeTokens.of(context).textPrimary),
      ),
    };

    final child = SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: FrostRefreshSliverHeader.refreshOffset,
          child: Center(
            child: _InlineRefreshStatus(icon: indicator, label: statusText),
          ),
        ),
      ),
    );

    if (mode == PullToRefreshIndicatorMode.error && info != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => info!.pullToRefreshNotificationState.show(notificationDragOffset: FrostRefreshSliverHeader.reachToRefreshOffset),
        child: child,
      );
    }

    return child;
  }
}

class _InlineRefreshStatus extends StatelessWidget {
  const _InlineRefreshStatus({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 22, child: Center(child: icon)),
        const SizedBox(width: FrostGap.related),
        Flexible(
          child: FrostText(label, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
        ),
      ],
    );
  }
}

class FrostLoadingScrollView extends StatelessWidget {
  const FrostLoadingScrollView({
    required this.slivers,
    this.controller,
    this.physics,
    this.primary,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.preloadExtent = 480,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool? primary;
  final bool shrinkWrap;
  final double? cacheExtent;
  final double preloadExtent;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: frostRefreshPageScrollBehavior,
      child: LoadingMoreCustomScrollView(
        controller: controller,
        physics: physics ?? frostRefreshPhysics,
        primary: primary,
        shrinkWrap: shrinkWrap,
        cacheExtent: math.max(cacheExtent ?? 0, preloadExtent),
        preloadExtent: preloadExtent,
        showGlowLeading: false,
        getConfigFromSliverContext: true,
        clipBehavior: clipBehavior,
        // Content scrolls beneath a floating bottom bar (mobile navigation),
        // but the last items and the load-more footer must end above it.
        slivers: [
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class FrostSliverFillBody extends StatelessWidget {
  const FrostSliverFillBody({required this.child, this.physics, this.sliverHeader, this.leadingSlivers = const [], super.key});

  final Widget child;
  final ScrollPhysics? physics;
  final Widget? sliverHeader;
  final List<Widget> leadingSlivers;

  @override
  Widget build(BuildContext context) {
    return FrostLoadingScrollView(
      physics: physics,
      slivers: [
        ...leadingSlivers,
        ?sliverHeader,
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }
}
