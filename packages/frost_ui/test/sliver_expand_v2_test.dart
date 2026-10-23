import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('collapsed retained rows can rebuild before reopening or removal', (tester) async {
    late StateSetter update;
    var expanded = true, changed = false;
    Widget tree() => frostTestApp(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return CustomScrollView(
            slivers: [
              FrostSliverExpand(
                expanded: expanded,
                sliver: SliverList.builder(
                  itemCount: 208,
                  itemBuilder: (context, index) => FrostListRow(title: '${changed ? 'changed' : 'original'} $index', onPressed: () {}),
                ),
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpWidget(tree());
    update(() => expanded = false);
    await tester.pumpAndSettle();
    update(() => changed = true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    update(() => expanded = true);
    await tester.pumpAndSettle();
    expect(find.text('changed 0'), findsOneWidget);
    expect(find.byType(FrostListRow).evaluate().length, lessThan(30));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('3x208 reveal retains both granted row caps at rest and mid-flight $brightness', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      var expanded = true;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: Colors.purple,
                child: SizedBox(
                  width: 440,
                  height: 500,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return CustomScrollView(
                        slivers: [
                          FrostSliverContentColumn(
                            sliver: SliverMainAxisGroup(
                              slivers: [
                                const SliverToBoxAdapter(child: SizedBox(height: 44)),
                                for (var group = 0; group < 3; group++)
                                  FrostSliverExpand(
                                    expanded: group == 0 && expanded,
                                    sliver: SliverList.builder(
                                      itemCount: 208,
                                      itemBuilder: (context, index) =>
                                          FrostListRow(title: '$group/$index', selected: group == 0 && index == 0, onPressed: () {}),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      Future<void> caps() async {
        final selection = find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              w.decoration is ShapeDecoration &&
              (w.decoration! as ShapeDecoration).color == FrostThemeTokens.of(tester.element(find.text('0/0'))).selectionFill,
        );
        final rect = tester.getRect(selection), origin = tester.getTopLeft(find.byKey(boundary));
        await tester.runAsync(() async {
          final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary)).toImage();
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          int pixel(Offset point) {
            final p = point - origin;
            return bytes.getUint32((p.dy.floor() * image.width + p.dx.floor()) * 4);
          }

          final background = pixel(origin + const Offset(1, 1));
          expect(pixel(Offset(rect.left + 2, rect.center.dy)), isNot(background));
          expect(pixel(Offset(rect.right - 2, rect.center.dy)), isNot(background));
          expect(pixel(rect.topLeft + const Offset(1, 1)), background);
          expect(pixel(rect.topRight + const Offset(-2, 1)), background);
          image.dispose();
        });
        expect(find.byType(FrostListRow).evaluate().length, lessThan(20));
      }

      await caps();
      update(() => expanded = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await caps();
      update(() => expanded = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      await caps();
      await tester.pumpAndSettle();
      await caps();
      expect(tester.takeException(), isNull);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('lazy reveal retains row geometry through reversal reduced=$reduced', (tester) async {
      var expanded = false;
      late StateSetter update;
      var built = 0;
      // Match the retained child used by the actual batch owner.
      final sliver = SliverList.builder(
        itemCount: 208,
        itemBuilder: (context, index) {
          built++;
          return SizedBox(height: 48, child: Text('row $index'));
        },
      );
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: StatefulBuilder(
              builder: (context, state) {
                update = state;
                return SizedBox(
                  height: 500,
                  child: CustomScrollView(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(100),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 44, child: Text('header'))),
                      FrostSliverExpand(expanded: expanded, sliver: sliver),
                      const SliverToBoxAdapter(child: Text('following group')),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      // A closed SliverList lays out only its first item to keep its retained
      // render tree clean; it never lays out the other 207 rows.
      expect(built, 1);
      update(() => expanded = true);
      await tester.pump();
      for (var frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.textContaining('row ').evaluate().length, lessThan(16));
        for (final item in find.textContaining('row ').evaluate()) {
          expect(tester.getSize(find.ancestor(of: find.byWidget(item.widget), matching: find.byType(SizedBox)).first).height, 48);
        }
        if (frame == 4 && !reduced) update(() => expanded = false);
        if (frame == 8 && !reduced) update(() => expanded = true);
      }
      expect(built, lessThan(40));
      update(() => expanded = false);
      await tester.pumpAndSettle();
      expect(find.text('following group'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
