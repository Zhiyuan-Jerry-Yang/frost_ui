import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

import 'support.dart';

void main() {
  testWidgets('native event scrolls below the shell Scaffold and retains header state', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    final query = TextEditingController(text: 'sky');
    addTearDown(scroll.dispose);
    addTearDown(query.dispose);
    var refreshes = 0;
    await tester.pumpWidget(
      _app(
        FrostShell(
          destinations: [FrostNavDestination(label: 'Browse', icon: testIcons.image)],
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          child: FrostShellDestination(
            child: _feed(scroll, query: query, onRefresh: () => ++refreshes > 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.state(find.byType(EditableText));
    scroll.jumpTo(2500);
    await tester.pump();
    tester.simulateStatusBarTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.offset, allOf(greaterThan(0), lessThan(2500)));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(query.text, 'sky');
    expect(tester.state(find.byType(EditableText)), same(editor));
    expect(refreshes, 0);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('offstage retained tabs do not move and switching tabs targets the visible feed', (tester) async {
    final first = ScrollController(), second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return IndexedStack(index: selected, children: [_feed(first), _feed(second)]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.jumpTo(700);
    second.jumpTo(900);
    await tester.pump();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(first.offset, 0);
    expect(second.offset, 900);
    first.jumpTo(600);
    update(() => selected = 1);
    await tester.pumpAndSettle();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(first.offset, 600);
    expect(second.offset, 0);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('root sheet blocks a nested Navigator feed until dismissal completes', (tester) async {
    final scroll = ScrollController();
    final nested = GlobalKey<NavigatorState>();
    addTearDown(scroll.dispose);
    late BuildContext feedContext;
    await tester.pumpWidget(
      _app(
        Navigator(
          key: nested,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              feedContext = context;
              return _feed(scroll);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(850);
    unawaited(showModalBottomSheet<void>(context: feedContext, useRootNavigator: true, builder: (_) => const SizedBox(height: 120)));
    await tester.pumpAndSettle();
    expect(ModalRoute.of(feedContext)!.isCurrent, isTrue, reason: 'Nearest-route checks alone are insufficient.');
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 850);
    Navigator.of(feedContext, rootNavigator: true).pop();
    await tester.pump();
    tester.simulateStatusBarTap();
    await tester.pump(const Duration(milliseconds: 50));
    expect(scroll.offset, 850);
    await tester.pumpAndSettle();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a sibling Navigator covering a current feed blocks its status-bar action', (tester) async {
    final scroll = ScrollController();
    final foreground = GlobalKey<NavigatorState>();
    addTearDown(scroll.dispose);
    var covered = true;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Stack(
              fit: StackFit.expand,
              children: [
                Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _feed(scroll))),
                if (covered)
                  Navigator(
                    key: foreground,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Detail or verification'))),
                  ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(850);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 850);
    update(() => covered = false);
    await tester.pumpAndSettle();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('controller replacement targets only the newly attached collection', (tester) async {
    final first = ScrollController(), second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var scroll = first;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return _feed(scroll);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.jumpTo(700);
    update(() => scroll = second);
    await tester.pumpAndSettle();
    expect(first.hasClients, isFalse);
    second.jumpTo(800);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(second.offset, 0);
    await _unmount(tester);
    tester.simulateStatusBarTap();
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('tap leaves an in-flight pull refresh running without triggering another', (tester) async {
    final scroll = ScrollController();
    final response = Completer<bool>();
    addTearDown(scroll.dispose);
    var calls = 0;
    await tester.pumpWidget(
      _app(
        _feed(
          scroll,
          onRefresh: () {
            calls++;
            return response.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final refresh = tester.state<PullToRefreshNotificationState>(find.byType(PullToRefreshNotification));
    final pending = refresh.show(notificationDragOffset: FrostRefreshSliverHeader.reachToRefreshOffset)!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(calls, 1);
    scroll.jumpTo(800);
    tester.simulateStatusBarTap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(scroll.offset, 0);
    expect(calls, 1);
    expect(refresh.refreshIndicatorMode, PullToRefreshIndicatorMode.refresh);
    response.complete(true);
    await tester.pump();
    await pending;
    await tester.pumpAndSettle();
    expect(calls, 1);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reduced motion returns immediately without starting a scroll animation', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_app(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: _feed(scroll))));
    await tester.pumpAndSettle();
    scroll.jumpTo(900);
    tester.simulateStatusBarTap();
    await tester.pump();
    expect(scroll.offset, 0);
    expect(scroll.position.isScrollingNotifier.value, isFalse);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('unopted view keeps its current scrolling behavior', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_app(_feed(scroll, enabled: false)));
    await tester.pumpAndSettle();
    scroll.jumpTo(900);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 900);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('initial loading without an attached viewport safely ignores the event', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_app(FrostRefreshView(scrollController: scroll, scrollToTopOnStatusBarTap: true, builder: (_, _, _) => const SizedBox.expand())));
    await tester.pumpAndSettle();
    expect(scroll.hasClients, isFalse);
    tester.simulateStatusBarTap();
    await tester.pump();
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

Widget _app(Widget child) => frostTestApp(child, platform: TargetPlatform.iOS);

Widget _feed(ScrollController scroll, {TextEditingController? query, FrostRefreshAction? onRefresh, bool enabled = true}) => FrostRefreshView(
  scrollController: scroll,
  scrollToTopOnStatusBarTap: enabled,
  onRefresh: onRefresh,
  builder: (_, physics, locators) => FrostBrowseLayout(
    header: query == null ? const SizedBox(height: 52, child: Text('Feed')) : Material(child: TextField(controller: query)),
    slivers: [
      ?locators.sliverHeader,
      const SliverToBoxAdapter(child: SizedBox(height: 6000, child: Text('Loaded posts'))),
    ],
  ),
);

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
