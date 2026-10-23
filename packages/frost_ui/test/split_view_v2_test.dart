import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  Widget app(Widget child, {double width = 800, bool reduced = false, TextDirection direction = TextDirection.ltr}) => frostTestApp(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 600), devicePixelRatio: 2, disableAnimations: reduced),
      child: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: 500, child: child),
        ),
      ),
    ),
  );
  Finder handle(String value) => find.byWidgetPredicate((w) => w is Semantics && w.properties.value == value);

  testWidgets('wide geometry, drag clamp, semantic and keyboard resize without pane rebuilds', (tester) async {
    var builds = 0;
    final primary = Builder(
      builder: (_) {
        builds++;
        return const ColoredBox(key: ValueKey('primary'), color: Colors.red);
      },
    );
    await tester.pumpWidget(app(FrostSplitView(primary: primary, secondary: const SizedBox(), onCloseSecondary: null)));
    expect(tester.getSize(find.byKey(const ValueKey('primary'))).width, 320);
    expect(tester.getSize(find.byType(FrostDivider)).width, .5);
    final region = find.byType(MouseRegion).last;
    expect(tester.getSize(region).width, 8);
    final before = builds;
    await tester.drag(region, const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('primary'))).width, 480);
    expect(builds, before);
    await tester.drag(find.byType(MouseRegion).last, const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('primary'))).width, 240);
    final focus = find.descendant(of: handle('240'), matching: find.byType(Focus)).first;
    tester.widget<Focus>(focus).focusNode?.requestFocus();
    // Focus creates its own node when the public node is omitted.
    Focus.of(tester.element(find.byType(MouseRegion).last)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(handle('256'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(handle('480'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(handle('240'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(handle('240')).getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    semantics.dispose();
  });

  testWidgets('RTL resize directions, read-only separator and PageStorage restoration', (tester) async {
    final bucket = PageStorageBucket();
    Widget split({bool resizable = true}) => PageStorage(
      bucket: bucket,
      child: FrostSplitView(
        key: const ValueKey('saved'),
        primary: const SizedBox(key: ValueKey('pane')),
        secondary: null,
        onCloseSecondary: null,
        resizable: resizable,
      ),
    );
    await tester.pumpWidget(app(split(), direction: TextDirection.rtl));
    await tester.drag(find.byType(MouseRegion).last, const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('pane'))).width, 400);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(split(resizable: false)));
    expect(tester.getSize(find.byKey(const ValueKey('pane'))).width, 400);
    expect(find.byType(FrostDivider), findsOneWidget);
    expect(handle('400'), findsNothing);
  });

  for (final method in ['header', 'system', 'escape']) {
    testWidgets('compact controlled detail back via $method, even under shell navigation scope', (tester) async {
      var detail = false, calls = 0;
      late StateSetter update;
      final reselection = ValueNotifier<({int index, int sequence})>((index: 0, sequence: 0));
      addTearDown(reselection.dispose);
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return FrostShellNavigationScope(
                ownsBackControl: false,
                canGoBack: false,
                goBack: () {},
                primaryReselection: reselection,
                child: FrostSplitView(
                  primary: const Text('master'),
                  secondary: detail
                      ? Column(
                          children: [
                            FrostPageHeader(title: const Text('detail')),
                            const Expanded(child: Text('body')),
                          ],
                        )
                      : null,
                  onCloseSecondary: () {
                    calls++;
                    update(() => detail = false);
                  },
                ),
              );
            },
          ),
          width: 390,
        ),
      );
      expect(find.text('master'), findsOneWidget);
      update(() => detail = true);
      await tester.pumpAndSettle();
      expect(findFrostTooltip(testLabels(tester.element(find.text('detail'))).back), findsOneWidget);
      switch (method) {
        case 'header':
          await tester.tap(find.byType(FrostCompactBackButton));
        case 'system':
          await tester.binding.handlePopRoute();
        case 'escape':
          FocusScope.of(tester.element(find.text('body'))).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('master'), findsOneWidget);
      expect(find.text('body'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('size-class transfers preserve secondary State and primary scroll', (tester) async {
    var width = 800.0;
    late StateSetter update;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return app(
            FrostSplitView(
              primary: ListView.builder(
                controller: scroll,
                itemCount: 100,
                itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
              ),
              secondary: const _Counter(),
              onCloseSecondary: () {},
            ),
            width: width,
          );
        },
      ),
    );
    scroll.jumpTo(400);
    await tester.tap(find.text('count 0'));
    await tester.pump();
    final original = tester.state(find.byType(_Counter));
    for (final next in [390.0, 800.0, 390.0, 800.0]) {
      update(() => width = next);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_Counter)), same(original));
      expect(find.text('count 1'), findsOneWidget);
      expect(scroll.offset, 400);
    }
  });

  testWidgets('local width reserves detail space without overwriting the requested width', (tester) async {
    var local = 500.0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: local,
                child: FrostSplitView(
                  key: const PageStorageKey('local'),
                  initialPrimaryWidth: 400,
                  primary: const SizedBox(key: ValueKey('local-primary')),
                  secondary: const SizedBox(key: ValueKey('local-secondary')),
                  onCloseSecondary: null,
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('local-primary'))).width, 259.5);
    expect(tester.getSize(find.byKey(const ValueKey('local-secondary'))).width, 240);
    update(() => local = 150);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('local-primary'))).width, 0);
    expect(tester.takeException(), isNull);
    update(() => local = 800);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('local-primary'))).width, 400);
  });
  testWidgets('drag interrupts an in-flight keyboard spring at its visible width', (tester) async {
    await tester.pumpWidget(app(FrostSplitView(primary: const SizedBox(key: ValueKey('moving-primary')), secondary: null, onCloseSecondary: null)));
    final region = find.descendant(of: find.byType(FrostSplitView), matching: find.byType(MouseRegion)).last;
    Focus.of(tester.element(region)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final before = tester.getSize(find.byKey(const ValueKey('moving-primary'))).width;
    expect(before, inExclusiveRange(320, 480));
    final gesture = await tester.startGesture(tester.getCenter(region));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('moving-primary'))).width, closeTo(before + 20, .01));
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('moving-primary'))).width, closeTo(before + 30, .01));
    await gesture.up();
  });
  testWidgets('Tab visits only the resize handle and skips a read-only divider', (tester) async {
    final before = FocusNode(), after = FocusNode();
    addTearDown(before.dispose);
    addTearDown(after.dispose);
    for (final resizable in [true, false]) {
      await tester.pumpWidget(
        app(
          Row(
            children: [
              TextButton(focusNode: before, onPressed: () {}, child: const Text('before')),
              Expanded(
                child: FrostSplitView(primary: const SizedBox(), secondary: null, onCloseSecondary: null, resizable: resizable),
              ),
              TextButton(focusNode: after, onPressed: () {}, child: const Text('after')),
            ],
          ),
        ),
      );
      before.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (resizable) {
        expect(Focus.of(tester.element(find.descendant(of: find.byType(FrostSplitView), matching: find.byType(MouseRegion)).last)).hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(after.hasPrimaryFocus, isTrue);
    }
  });
  testWidgets('Pages API updates same-key detail child rather than capturing stale widget', (tester) async {
    var title = 'old';
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Navigator(
              pages: [FrostDetailPage<void>(key: const ValueKey('page'), child: Text(title))],
              onDidRemovePage: (_) {},
            );
          },
        ),
      ),
    );
    update(() => title = 'new');
    await tester.pump();
    expect(find.text('new'), findsOneWidget);
    expect(find.text('old'), findsNothing);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => count++), child: Text('count $count'));
}
