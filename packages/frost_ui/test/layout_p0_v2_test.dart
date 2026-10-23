import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Future<void> pumpLayout(WidgetTester tester, Widget child, {double width = 500, bool rtl = false, bool reduced = false, bool loose = false}) =>
    tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: loose ? Align(alignment: Alignment.topLeft, child: child) : child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
void main() {
  testWidgets('Grid column formula, equal widths, row maxima and RTL are cold-frame exact', (tester) async {
    for (final width in [90.0, 208.0, 316.0, 500.0]) {
      for (final rtl in [false, true]) {
        final heights = [30.0, 70.0, 45.0, 20.0, 90.0];
        await pumpLayout(
          tester,
          FrostGrid(
            minItemWidth: 100,
            children: [for (var i = 0; i < heights.length; i++) SizedBox(key: ValueKey(i), height: heights[i])],
          ),
          width: width,
          rtl: rtl,
        );
        final count = ((width + 8) / 108).floor().clamp(1, 100), cell = (width - 8 * (count - 1)) / count;
        for (var i = 0; i < heights.length; i++) {
          final row = i ~/ count, start = row * count, end = (start + count).clamp(0, heights.length);
          final height = heights.sublist(start, end).reduce((a, b) => a > b ? a : b);
          expect(tester.getSize(find.byKey(ValueKey(i))), Size(cell, height));
          final x = (i % count) * (cell + 8);
          expect(tester.getTopLeft(find.byKey(ValueKey(i))).dx, closeTo(rtl ? width - x - cell : x, .01));
          if (i >= count) expect(tester.getTopLeft(find.byKey(ValueKey(i))).dy, greaterThan(tester.getBottomLeft(find.byKey(ValueKey(i - count))).dy));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('Grid fixed ratio, empty result and argument assertions', (tester) async {
    await pumpLayout(
      tester,
      FrostGrid(minItemWidth: 100, aspectRatio: 2, children: List.generate(5, (i) => SizedBox(key: ValueKey(i), height: 99))),
      width: 316,
    );
    expect(tester.getSize(find.byKey(const ValueKey(0))), const Size(100, 50));
    expect(tester.getTopLeft(find.byKey(const ValueKey(3))).dy, 58);
    await pumpLayout(tester, const FrostGrid(minItemWidth: 100, children: []));
    expect(tester.getSize(find.byType(FrostGrid)).height, 0);
    expect(() => FrostGrid(minItemWidth: 0, children: const []), throwsAssertionError);
    expect(() => FrostGrid(minItemWidth: 100, aspectRatio: 0, children: const []), throwsAssertionError);
    expect(() => FrostSliverGrid(minItemWidth: 100, itemCount: 1, itemBuilder: (_, _) => const SizedBox()), throwsAssertionError);
  });
  testWidgets('SliverGrid builds visible items lazily and mirrors RTL', (tester) async {
    for (final rtl in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      final built = <int>{};
      await pumpLayout(
        tester,
        SizedBox(
          height: 220,
          child: CustomScrollView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            slivers: [
              FrostSliverGrid(
                minItemWidth: 100,
                aspectRatio: 1,
                itemCount: 1000,
                itemBuilder: (context, index) {
                  built.add(index);
                  return SizedBox(key: ValueKey(index));
                },
              ),
            ],
          ),
        ),
        width: 316,
        rtl: rtl,
      );
      expect(built.length, lessThan(20));
      expect(built, contains(0));
      expect(built, isNot(contains(999)));
      expect(tester.getSize(find.byKey(const ValueKey(0))), const Size(100, 100));
      expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dx, rtl ? 216 : 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(built.any((i) => i >= 9), isTrue);
    }
  });
  testWidgets('Wrap applies inline/related gaps on both axes and RTL start', (tester) async {
    for (final compact in [false, true]) {
      for (final rtl in [false, true]) {
        await pumpLayout(
          tester,
          FrostWrap(
            compact: compact,
            children: [for (var i = 0; i < 3; i++) SizedBox(key: ValueKey(i), width: 40, height: 20)],
          ),
          width: 100,
          rtl: rtl,
        );
        final gap = compact ? 4.0 : 8.0;
        expect((tester.getTopLeft(find.byKey(const ValueKey(1))).dx - tester.getTopLeft(find.byKey(const ValueKey(0))).dx).abs(), 40 + gap);
        expect(tester.getTopLeft(find.byKey(const ValueKey(2))).dy, 20 + gap);
        expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dx, rtl ? 60 : 0);
      }
    }
  });
  testWidgets('Fit chooses first fitting candidate on one pump and uses the final fallback', (tester) async {
    Widget candidate(String name, double width) => Semantics(
      label: name,
      child: SizedBox(width: width, height: 40, child: Text(name)),
    );
    for (final (width, name) in [(350.0, 'Full'), (250.0, 'Icons'), (150.0, 'More'), (50.0, 'More')]) {
      await pumpLayout(
        tester,
        FrostFit(candidates: [(_) => candidate('Full', 300), (_) => candidate('Icons', 200), (_) => candidate('More', 100)]),
        width: width,
      );
      expect(find.text(name).hitTestable(), findsOneWidget);
      for (final hidden in ['Full', 'Icons', 'More'].where((value) => value != name)) {
        expect(find.text(hidden).hitTestable(), findsNothing);
      }
      expect(find.byType(FrostLayoutCrossfade), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(() => FrostFit(candidates: const []), throwsAssertionError);
  });
  testWidgets('Fit isolates inactive focus/semantics and keeps active focus on unchanged selection', (tester) async {
    final semantics = tester.ensureSemantics(), nodes = List.generate(3, (_) => FocusNode());
    late StateSetter update;
    var width = 350.0;
    await pumpLayout(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return SizedBox(
            width: width,
            child: FrostFit(
              candidates: [
                for (var i = 0; i < 3; i++)
                  (_) => Focus(
                    focusNode: nodes[i],
                    child: Semantics(
                      label: 'Candidate $i',
                      child: SizedBox(width: [300.0, 200.0, 100.0][i], height: 40, child: Text('Value $i')),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      loose: true,
    );
    nodes[1].requestFocus();
    await tester.pump();
    expect(nodes[1].hasFocus, isFalse);
    expect(find.semantics.byLabel(RegExp('Candidate 1')), findsNothing);
    nodes[0].requestFocus();
    await tester.pump();
    expect(nodes[0].hasPrimaryFocus, isTrue);
    update(() => width = 340);
    await tester.pump();
    expect(nodes[0].hasPrimaryFocus, isTrue);
    update(() => width = 250);
    await tester.pump();
    expect(find.semantics.byLabel(RegExp('Candidate 0')), findsNothing);
    expect(find.semantics.byLabel(RegExp('Candidate 1')), findsOne);
    expect(nodes[0].hasFocus, isFalse);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    for (final node in nodes) {
      node.dispose();
    }
  });
  testWidgets('Fit crossfades replacement pixels and reduced motion skips the transition', (tester) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      late StateSetter update;
      var width = 350.0;
      await pumpLayout(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: width,
              child: FrostFit(
                candidates: [
                  (_) => const SizedBox(width: 300, height: 40, child: ColoredBox(color: Colors.red)),
                  (_) => const SizedBox(width: 100, height: 40, child: ColoredBox(color: Colors.blue)),
                ],
              ),
            );
          },
        ),
        reduced: reduced,
        loose: true,
      );
      await tester.pumpAndSettle();
      update(() => width = 150);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 60));
      final opacities = tester.widgetList<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).map((w) => w.opacity.value);
      if (reduced) {
        expect(opacities.every((value) => value == 1), isTrue);
      } else {
        expect(opacities.any((value) => value > 0 && value < 1), isTrue);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
