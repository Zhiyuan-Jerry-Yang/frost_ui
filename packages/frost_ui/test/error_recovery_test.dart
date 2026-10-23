import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Widget recoveryApp(Widget child, Future<bool> Function() resolve) => frostTestApp(
  FrostScope(
    config: FrostConfig(
      palettes: testConfig.palettes,
      fonts: testFonts,
      icons: testIcons,
      labels: testLabels,
      errors: FrostErrorPresenter(
        message: (_, error) => 'Recoverable failure',
        details: (_) => null,
        title: (_, error) => 'Mapped title',
        icon: (_, error) => testIcons.clock,
        action: (_, error) => error == 'plain' ? null : FrostErrorAction(label: 'Verify', icon: testIcons.user, onPressed: resolve),
      ),
    ),
    child: child,
  ),
);

Finder verify() => find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Verify');

class _Source extends FrostListSource<int> {
  _Source(this.footer);
  final bool footer;
  var initialCalls = 0, nextCalls = 0;
  bool resolved = false;
  @override
  Future<List<int>> initList() async {
    initialCalls++;
    if (!footer && !resolved) throw 'verify';
    return footer ? [1] : [];
  }

  @override
  Future<List<int>> nextList() async {
    nextCalls++;
    if (!resolved) throw 'verify';
    return [];
  }
}

void main() {
  for (final footer in [false, true]) {
    testWidgets('recovery retries the failed ${footer ? 'footer' : 'page'} once and guards repeat activation', (tester) async {
      final source = _Source(footer);
      await source.refresh(true);
      if (footer) await source.loadMore();
      final pending = Completer<bool>();
      var resolves = 0;
      await tester.pumpWidget(
        recoveryApp(
          Scaffold(
            body: FrostLoadingScrollView(
              slivers: [
                FrostSliverDataList<int>(
                  source: source,
                  autoLoadMore: false,
                  firstLoadSkeleton: const SizedBox(height: 40),
                  itemBuilder: (_, value, index) => Text('$value'),
                ),
              ],
            ),
          ),
          () {
            resolves++;
            return pending.future;
          },
        ),
      );
      await tester.pump();
      if (!footer) {
        expect(find.text('Mapped title'), findsOneWidget);
        expect(tester.widget<FrostIcon>(find.byType(FrostIcon).first).icon, testIcons.clock);
      }
      await tester.ensureVisible(verify());
      await tester.tap(verify());
      await tester.pump();
      await tester.tap(verify());
      await tester.pump();
      expect(resolves, 1);
      source.resolved = true;
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(source.initialCalls, footer ? 1 : 2);
      expect(source.nextCalls, footer ? 2 : 0);
      expect(source.lastError, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      source.dispose();
    });
  }
  testWidgets('replacing the source with the same error cannot retry the new list', (tester) async {
    final first = _Source(false), second = _Source(false);
    await first.refresh(true);
    await second.refresh(true);
    expect(identical(first.lastError, second.lastError), isTrue);
    final pending = Completer<bool>();
    var source = first;
    late StateSetter update;
    await tester.pumpWidget(
      recoveryApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostLoadingScrollView(
              slivers: [FrostSliverDataList<int>(source: source, firstLoadSkeleton: const SizedBox(), itemBuilder: (_, value, index) => Text('$value'))],
            );
          },
        ),
        () => pending.future,
      ),
    );
    await tester.tap(verify());
    await tester.pump();
    update(() => source = second);
    await tester.pump();
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(first.initialCalls, 1);
    expect(second.initialCalls, 1);
    expect(second.lastError, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
  });
  for (final direction in TextDirection.values) {
    for (final width in [180.0, 800.0]) {
      testWidgets('footer keeps wide row and reflows narrow actions in first layout $direction $width', (tester) async {
        final source = _Source(true);
        await source.refresh(true);
        await source.loadMore();
        await tester.pumpWidget(
          recoveryApp(
            Center(
              child: Directionality(
                textDirection: direction,
                child: SizedBox(
                  width: width,
                  child: FrostLoadingMoreIndicator(source: source),
                ),
              ),
            ),
            () async => false,
          ),
        );
        final message = tester.getRect(find.byType(FrostCompactMessage));
        final retry = tester.getRect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.retry'));
        expect(retry.center.dy, width == 800 ? closeTo(message.center.dy, .001) : greaterThan(message.bottom));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        source.dispose();
      });
    }
  }
  for (final outcome in ['false', 'exception', 'unmount', 'replace']) {
    testWidgets('$outcome recovery does not retry; failed actions restore controls', (tester) async {
      final pending = Completer<bool>();
      var retries = 0;
      var error = 'first';
      late StateSetter update;
      await tester.pumpWidget(
        recoveryApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return Center(
                child: FrostErrorActionButton(error: error, onResolved: () => retries++),
              );
            },
          ),
          () => pending.future,
        ),
      );
      await tester.tap(verify());
      await tester.pump();
      if (outcome == 'unmount') await tester.pumpWidget(const SizedBox());
      if (outcome == 'replace') {
        update(() => error = 'second');
        await tester.pump();
      }
      if (outcome == 'exception') {
        pending.completeError(StateError('Verification failed'));
      } else {
        pending.complete(outcome == 'unmount' || outcome == 'replace');
      }
      await tester.pumpAndSettle();
      expect(retries, 0);
      if (outcome == 'exception') expect(tester.takeException(), isA<StateError>());
      expect(tester.takeException(), isNull);
      if (outcome == 'false' || outcome == 'exception') {
        expect(tester.widget<FrostButton>(verify()).loading, isFalse);
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('page and details scrolling stay isolated from the primary controller', (tester) async {
    final primary = ScrollController();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: PrimaryScrollController(
            controller: primary,
            child: SizedBox(
              height: 240,
              child: FrostErrorContent(message: 'Failed', onRetry: () {}, details: List.filled(50, 'Technical').join('\n')),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('L.errorDetails'));
    await tester.tap(find.text('L.errorDetails'));
    await tester.pumpAndSettle();
    expect(primary.positions, isEmpty);
    final positions = tester.stateList<ScrollableState>(find.byType(Scrollable)).map((s) => s.position).toList();
    expect(positions.where((p) => p.maxScrollExtent > 0).length, 2);
    for (final position in positions) {
      position.jumpTo(position.maxScrollExtent);
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    primary.dispose();
  });
  testWidgets('unmapped errors render no recovery control and narrow large text can wrap actions', (tester) async {
    await tester.pumpWidget(recoveryApp(const Center(child: FrostErrorActionButton(error: 'plain', onResolved: null)), () async => true));
    expect(verify(), findsNothing);
    await tester.pumpWidget(
      recoveryApp(
        Center(
          child: SizedBox(
            width: 180,
            height: 280,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: FrostErrorContent.fromError(error: 'mapped', onRetry: () {}),
            ),
          ),
        ),
        () async => true,
      ),
    );
    await tester.pumpAndSettle();
    expect(verify(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
