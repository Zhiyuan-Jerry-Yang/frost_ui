import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

const _revealKey = ValueKey('reveal');
const _nextKey = ValueKey('following');

class _Fixture extends StatefulWidget {
  const _Fixture({super.key, this.count = 208, this.initiallyExpanded = true, this.headerExtent = 44});
  final int count;
  final double headerExtent;
  final bool initiallyExpanded;
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  final scroll = ScrollController();
  late bool expanded = widget.initiallyExpanded;
  late int count = widget.count;
  void toggle() => setState(() => expanded = !expanded);
  void replace(int value) => setState(() => count = value);
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: scroll,
    scrollCacheExtent: const ScrollCacheExtent.pixels(96),
    slivers: [
      SliverToBoxAdapter(
        child: SizedBox(height: widget.headerExtent, child: const Text('header')),
      ),
      FrostSliverExpand(
        key: _revealKey,
        expanded: expanded,
        sliver: SliverList.builder(
          itemCount: count,
          itemBuilder: (_, i) => _Row(key: ValueKey('row-$i'), index: i),
        ),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(key: _nextKey, height: 44, child: Text('following')),
      ),
      SliverFixedExtentList.builder(itemExtent: 48, itemCount: 50, itemBuilder: (_, i) => Text('next $i')),
    ],
  );
}

class _Row extends StatefulWidget {
  const _Row({required this.index, super.key});
  final int index;
  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  Widget build(BuildContext context) => SizedBox(height: 48, child: Text('row ${widget.index}'));
}

RenderProxySliver _render(WidgetTester tester) => tester.renderObject(find.byKey(_revealKey, skipOffstage: false));
void _continuous(WidgetTester tester) {
  final r = _render(tester), g = _render(tester).geometry!;
  final remaining = (g.scrollExtent - r.constraints.scrollOffset).clamp(0.0, r.constraints.remainingPaintExtent);
  expect(g.paintExtent, closeTo(remaining, .001));
  if (r.constraints.scrollOffset == 0 && g.scrollExtent < r.constraints.remainingPaintExtent) {
    expect(tester.getTopLeft(find.byKey(_nextKey)).dy, closeTo(44 + g.paintExtent, .001));
  }
  expect(find.byType(_Row).evaluate().length, lessThan(18));
  for (final e in find.byType(_Row).evaluate()) {
    expect(tester.getSize(find.byWidget(e.widget)).height, 48);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('visible reveal has no hole and following group touches paint, $direction', (tester) async {
      tester.view.physicalSize = const Size(700, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<_FixtureState>();
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: _Fixture(key: key),
          ),
        ),
      );
      final states = {for (final e in find.byType(_Row).evaluate()) e.widget.key: (e as StatefulElement).state};
      key.currentState!.toggle();
      await tester.pump();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        _continuous(tester);
        // A shrinking clip must not destroy the rows already in its cache.
        for (final entry in states.entries) {
          expect(tester.state(find.byKey(entry.key!)), same(entry.value));
        }
      }
      final before = _render(tester).geometry!.scrollExtent;
      key.currentState!.toggle();
      await tester.pump();
      expect(_render(tester).geometry!.scrollExtent, closeTo(before, .001));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        _continuous(tester);
      }
      await tester.pumpAndSettle();
      expect(_render(tester).geometry!.scrollExtent, 208 * 48);
      key.currentState!.toggle();
      await tester.pumpAndSettle();
      expect(_render(tester).geometry!.scrollExtent, 0);
      expect(tester.getTopLeft(find.byKey(_nextKey)).dy, 44);
    });
  }
  testWidgets('short groups reveal their actual height', (tester) async {
    tester.view.physicalSize = const Size(700, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<_FixtureState>();
    await tester.pumpWidget(frostTestApp(_Fixture(key: key, count: 3, initiallyExpanded: false)));
    key.currentState!.toggle();
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      _continuous(tester);
      expect(_render(tester).geometry!.scrollExtent, lessThanOrEqualTo(144));
    }
    await tester.pumpAndSettle();
    expect(_render(tester).geometry!.scrollExtent, 144);
  });
  testWidgets('resize and data replacement during reveal retain valid lazy geometry', (tester) async {
    tester.view.physicalSize = const Size(700, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<_FixtureState>();
    await tester.pumpWidget(frostTestApp(_Fixture(key: key)));
    key.currentState!.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));
    tester.view.physicalSize = const Size(500, 350);
    await tester.pump();
    _continuous(tester);
    key.currentState!.replace(3);
    await tester.pump();
    _continuous(tester);
    key.currentState!.toggle();
    await tester.pumpAndSettle();
    expect(_render(tester).geometry!.scrollExtent, 144);
    key.currentState!.replace(208);
    await tester.pump();
    key.currentState!.scroll.jumpTo(key.currentState!.scroll.position.maxScrollExtent);
    await tester.pump();
    key.currentState!.toggle();
    await tester.pump();
    for (var i = 0; i < 55; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final p = key.currentState!.scroll.position;
      expect(p.pixels, inInclusiveRange(0, p.maxScrollExtent));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('an offscreen toggle stays immediate if scrolled into view during the spring', (tester) async {
    tester.view.physicalSize = const Size(700, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<_FixtureState>();
    await tester.pumpWidget(frostTestApp(_Fixture(key: key, headerExtent: 900, initiallyExpanded: false)));
    key.currentState!.toggle();
    await tester.pump();
    key.currentState!.scroll.jumpTo(900);
    await tester.pump();
    final reveal = _render(tester);
    expect(reveal.geometry!.scrollExtent, 208 * 48);
    expect(reveal.geometry!.paintExtent, reveal.constraints.remainingPaintExtent);
    expect(reveal.geometry!.paintExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion changes extent at once', (tester) async {
    final key = GlobalKey<_FixtureState>();
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _Fixture(key: key),
        ),
      ),
    );
    key.currentState!.toggle();
    await tester.pump();
    expect(_render(tester).geometry!.scrollExtent, 0);
    key.currentState!.toggle();
    await tester.pump();
    expect(_render(tester).geometry!.scrollExtent, 208 * 48);
    expect(tester.takeException(), isNull);
  });
}
