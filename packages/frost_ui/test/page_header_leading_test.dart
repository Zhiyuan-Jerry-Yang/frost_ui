import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('source stays natural while legacy leading mode shrinks, retaining actions and descriptions $direction', (tester) async {
      var width = 780.0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: const MediaQueryData(size: Size(390, 844)),
                child: Directionality(
                  textDirection: direction,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: FrostContentColumn(
                        maxWidth: double.infinity,
                        child: FrostPageHeader(
                          leading: [
                            FrostTitleMenu(
                              title: 'SourceName',
                              entries: [FrostMenuAction('Other source', onSelected: () {})],
                            ),
                            FrostToolbarMenuButton(
                              label: 'Popular this week',
                              entries: [FrostMenuAction('Other mode', onSelected: () {})],
                            ),
                          ],
                          actions: [
                            FrostToolbarItem.action(icon: testIcons.more, label: 'Pinned action', priority: FrostToolbarPriority.high, onPressed: () {}),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          density: FrostDensity.compact,
        ),
      );
      final source = find.byType(FrostTitleMenu);
      final mode = find.byType(FrostToolbarMenuButton);
      final action = find.bySemanticsLabel('Pinned action');
      final sourceWidth = tester.getSize(source).width;
      final modeWidth = tester.getSize(mode).width;
      final actionWidth = tester.getSize(action).width;
      final baselineHeight = tester.getSize(find.byType(FrostPageHeader)).height;
      expect(baselineHeight, 48);
      update(() => width = sourceWidth + modeWidth + actionWidth + 16 - 40);
      await tester.pump();
      expect(tester.getSize(source).width, sourceWidth);
      expect(tester.getSize(mode).width, lessThan(modeWidth));
      expect(tester.renderObject<RenderParagraph>(find.text('Popular this week')).didExceedMaxLines, isTrue);
      expect(tester.renderObject<RenderParagraph>(find.text('SourceName')).didExceedMaxLines, isFalse);
      expect(tester.getSize(action).width, actionWidth);
      expect(tester.getSize(find.byType(FrostPageHeader)).height, baselineHeight);
      update(() => width = sourceWidth + actionWidth + 40 + 16 - 20);
      await tester.pump();
      expect(tester.getSize(source).width, sourceWidth);
      expect(tester.renderObject<RenderParagraph>(find.text('SourceName')).didExceedMaxLines, isFalse);
      expect(tester.getSize(action).width, actionWidth);
      expect(findFrostTooltip('SourceName'), findsOneWidget);
      expect(findFrostTooltip('Popular this week'), findsOneWidget);
      expect(find.bySemanticsLabel('SourceName'), findsWidgets);
      expect(find.bySemanticsLabel('Popular this week'), findsWidgets);
      update(() => width = 780);
      await tester.pumpAndSettle();
      expect(tester.getSize(source).width, sourceWidth);
      expect(tester.getSize(mode).width, modeWidth);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('back precedes natural controls; extreme widths remain one row with unchanged scaled header height', (tester) async {
    for (final scale in [1.0, 2.0]) {
      double? baseline;
      for (final width in [700.0, 390.0, 120.0, 60.0]) {
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: FrostPageHeader(
                    onBack: () {},
                    leading: [
                      FrostTitleMenu(title: 'Source', entries: const [FrostMenuAction('Other')]),
                      const FrostToolbarMenuButton(label: 'Long mode label', entries: [FrostMenuAction('Mode')]),
                    ],
                    actions: [FrostToolbarItem.action(icon: testIcons.more, label: 'Action', priority: FrostToolbarPriority.high, onPressed: () {})],
                  ),
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        final height = tester.getSize(find.byType(FrostPageHeader)).height;
        baseline ??= height;
        expect(height, baseline);
        final back = tester.getRect(find.byType(FrostCompactBackButton));
        final source = tester.getRect(find.byType(FrostTitleMenu));
        final mode = tester.getRect(find.byType(FrostToolbarMenuButton));
        expect(back.right, lessThanOrEqualTo(source.left));
        expect(source.right, lessThanOrEqualTo(mode.left));
        expect(back.center.dy, source.center.dy);
        expect(source.center.dy, mode.center.dy);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
