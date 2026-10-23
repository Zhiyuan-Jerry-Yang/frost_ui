import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class _Source extends FrostListSource<int> {
  _Source({this.count = 40});
  final int count;
  int initialCalls = 0, nextCalls = 0;
  Future<List<int>> Function()? initial;
  Future<List<int>> Function()? next;
  @override
  Future<List<int>> initList() {
    initialCalls++;
    return initial?.call() ?? Future.value(List.generate(count, (i) => i));
  }

  @override
  Future<List<int>> nextList() {
    nextCalls++;
    return next?.call() ?? Future.value([]);
  }
}

class _Limited implements Exception, FrostRetryAfter {
  _Limited(this.retryAt);
  @override
  DateTime retryAt;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Widget row(BuildContext context, int value, int index) => SizedBox(key: ValueKey('item-$value'), height: 40, child: Text('Item $value'));
  Widget list(_Source source) => FrostSliverDataList<int>(
    source: source,
    itemBuilder: row,
    firstLoadSkeleton: const SizedBox(height: 300, child: Text('Initial skeleton')),
  );
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  for (final kind in ['list', 'grid', 'waterfall']) {
    for (final custom in [false, true]) {
      testWidgets('$kind empty content is App-owned=$custom and retained during refresh', (tester) async {
        final source = _Source(count: 0);
        await source.refresh(true);
        const empty = FrostEmptyState(title: 'App empty');
        final Widget? supplied = custom ? empty : null;
        final content = switch (kind) {
          'list' => FrostSliverDataList<int>(source: source, itemBuilder: row, firstLoadSkeleton: const SizedBox(), empty: supplied),
          'grid' => FrostSliverDataGrid<int>(
            source: source,
            itemBuilder: row,
            firstLoadSkeleton: const SizedBox(),
            empty: supplied,
            minTileWidth: 120,
            tileHeight: (_, width) => 60,
          ),
          _ => FrostSliverDataWaterfallGrid<int>(source: source, itemBuilder: row, firstLoadSkeleton: const SizedBox(), empty: supplied),
        };
        await tester.pumpWidget(frostTestApp(Scaffold(body: FrostLoadingScrollView(slivers: [content]))));
        final title = custom ? 'App empty' : 'L.noItems';
        expect(find.text(title), findsOneWidget);
        expect(find.text('L.noMoreItems'), findsNothing);
        final before = tester.getRect(find.text(title));
        final request = Completer<List<int>>();
        source.initial = () => request.future;
        final refreshing = source.refresh(true);
        await tester.pump();
        expect(tester.getRect(find.text(title)), before);
        request.complete([]);
        await refreshing;
        await tester.pump();
        expect(tester.getRect(find.text(title)), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        source.dispose();
      });
    }
  }
  for (final kind in ['list', 'grid', 'waterfall']) {
    testWidgets('$kind automatically starts first load, retains loaded content and uses a single footer', (tester) async {
      final source = _Source();
      final initial = Completer<List<int>>(), next = Completer<List<int>>();
      source.initial = () => initial.future;
      source.next = () => next.future;
      final controller = ScrollController();
      Widget content() => switch (kind) {
        'list' => list(source),
        'grid' => FrostSliverDataGrid<int>(
          source: source,
          itemBuilder: row,
          firstLoadSkeleton: const SizedBox(height: 300, child: Text('Initial skeleton')),
          minTileWidth: 120,
          tileHeight: (_, width) => 60,
        ),
        _ => FrostSliverDataWaterfallGrid<int>(
          source: source,
          itemBuilder: row,
          firstLoadSkeleton: const SizedBox(height: 300, child: Text('Initial skeleton')),
          padding: EdgeInsets.zero,
          preferredTileWidth: 180,
        ),
      };
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: FrostLoadingScrollView(
              controller: controller,
              preloadExtent: 80,
              slivers: [
                const SliverToBoxAdapter(child: Text('Before')),
                content(),
                const SliverToBoxAdapter(child: Text('After')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Initial skeleton'), findsOneWidget);
      await flush(tester);
      expect(source.initialCalls, 1);
      initial.complete(List.generate(80, (i) => i));
      await flush(tester);
      expect(find.text('Initial skeleton'), findsNothing);
      expect(find.text('Item 0'), findsOneWidget);
      final first = tester.element(find.byKey(const ValueKey('item-0')));
      final refreshing = Completer<List<int>>();
      source.initial = () => refreshing.future;
      final refresh = source.refresh(true);
      await flush(tester);
      expect(find.text('Initial skeleton'), findsNothing);
      expect(tester.element(find.byKey(const ValueKey('item-0'))), same(first));
      refreshing.complete(List.generate(80, (i) => i));
      await refresh;
      await flush(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await flush(tester);
      expect(source.nextCalls, 1);
      expect(find.byType(FrostRefreshDots), findsOneWidget);
      expect(find.text('Initial skeleton'), findsNothing);
      expect(find.text('After'), findsOneWidget);
      next.complete([]);
      await flush(tester);
      expect(find.text('L.noMoreItems'), findsOneWidget);
      expect(find.byType(FrostRefreshDots), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      source.dispose();
    });
  }

  testWidgets('two independent sources can mix with ordinary slivers and start the later source next page', (tester) async {
    final a = _Source(count: 10), b = _Source(count: 10);
    final nextA = Completer<List<int>>(), nextB = Completer<List<int>>();
    a.next = () => nextA.future;
    b.next = () => nextB.future;
    await a.refresh(true);
    await b.refresh(true);
    final controller = ScrollController();
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: FrostLoadingScrollView(
            controller: controller,
            preloadExtent: 60,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 100, child: Text('Ranking'))),
              list(a),
              const SliverToBoxAdapter(child: SizedBox(height: 400, child: Text('Between'))),
              list(b),
            ],
          ),
        ),
      ),
    );
    await flush(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await flush(tester);
    expect(b.nextCalls, 1);
    expect(a.hasMore, isTrue);
    expect(find.text('Between', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    nextA.complete([]);
    nextB.complete([]);
    controller.dispose();
    a.dispose();
    b.dispose();
    await flush(tester);
  });

  testWidgets('footer is reserved before loading and reaches the bottom without programmatic reveal or extra blank space', (tester) async {
    final source = _Source();
    await source.refresh(true);
    final result = Completer<List<int>>();
    source.next = () => result.future;
    final controller = ScrollController();
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
            child: Column(
              children: [
                Expanded(
                  child: FrostLoadingScrollView(controller: controller, preloadExtent: 40, slivers: [list(source)]),
                ),
                const SizedBox(key: ValueKey('nav'), height: 64),
              ],
            ),
          ),
        ),
      ),
    );
    await flush(tester);
    final extent = controller.position.maxScrollExtent;
    expect(source.nextCalls, 0);
    controller.jumpTo(extent);
    await flush(tester);
    expect(source.nextCalls, 1);
    expect(controller.offset, extent);
    expect(controller.position.maxScrollExtent, extent);
    final footer = tester.getRect(find.byType(FrostLoadingMoreIndicator<int>));
    final nav = tester.getRect(find.byKey(const ValueKey('nav')));
    expect(footer.height, 56);
    expect(footer.bottom + 24, closeTo(nav.top, .001));
    expect(controller.position.isScrollingNotifier.value, isFalse);
    result.complete([]);
    await flush(tester);
    expect(controller.position.maxScrollExtent, extent);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    source.dispose();
  });

  testWidgets('rate-limited errors count down and disable every retry path', (tester) async {
    final source = _Source();
    final failure = _Limited(DateTime.now().add(const Duration(seconds: 30)));
    source.initial = () async => throw failure;
    await source.refresh(true);
    await tester.pumpWidget(frostTestApp(Scaffold(body: FrostLoadingScrollView(slivers: [list(source)]))));
    await flush(tester);
    expect(tester.widget<FrostButton>(find.byType(FrostButton)).onPressed, isNull);
    expect(await source.refresh(), isFalse);
    expect(await source.loadMore(), isFalse);
    expect(source.initialCalls, 1);
    failure.retryAt = DateTime.now().subtract(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('L.retry'), findsOneWidget);
    expect(tester.widget<FrostButton>(find.byType(FrostButton)).onPressed, isNotNull);
    source.initial = () async => [99];
    source.next = () => Completer<List<int>>().future;
    await tester.tap(find.text('L.retry'));
    await flush(tester);
    expect(source.items, [99]);
    expect(source.refreshRevision, 1);
    await tester.pumpWidget(const SizedBox());
    source.dispose();
  });

  testWidgets('source replacement retains the host and stops the old preload configuration', (tester) async {
    final old = _Source(count: 2), replacement = _Source(count: 2);
    final oldPage = Completer<List<int>>();
    old.next = () => oldPage.future;
    replacement.initial = () async => [77, 78];
    replacement.next = () => Completer<List<int>>().future;
    var source = old;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return FrostLoadingScrollView(slivers: [list(source)]);
            },
          ),
        ),
      ),
    );
    await flush(tester);
    await flush(tester);
    expect(old.nextCalls, 1);
    update(() => source = replacement);
    old.dispose();
    await flush(tester);
    await flush(tester);
    oldPage.complete([123]);
    await flush(tester);
    expect(replacement.initialCalls, 1);
    expect(old.nextCalls, 1);
    expect(find.text('Item 77'), findsOneWidget);
    expect(find.text('Item 123'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    replacement.dispose();
  });

  test('successful refresh revisions exclude failures and superseded responses', () async {
    final source = _Source();
    final old = Completer<List<int>>();
    source.initial = () => old.future;
    final stale = source.refresh();
    source.clearData();
    source.initial = () async => [2];
    final current = source.refresh();
    old.complete([1]);
    await stale;
    await current;
    expect(source.items, [2]);
    expect(source.refreshRevision, 1);
    source.initial = () async => throw StateError('failed');
    expect(await source.refresh(), isFalse);
    expect(source.items, [2]);
    expect(source.refreshRevision, 1);
    source.initial = () async => [3];
    await source.refresh();
    expect(source.refreshRevision, 2);
    source.dispose();
  });
}
