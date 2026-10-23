import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_row_layout.dart';
import 'display_badges_v2_test.dart' show display;

void main() {
  for (final direction in TextDirection.values) {
    for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('labeled content shared cold flow $direction $density $scale', (tester) async {
          final handle = tester.ensureSemantics();
          await display(
            tester,
            const FrostLabeledContent(label: 'Source label', value: 'A long source value'),
            width: 160,
            scale: scale,
            density: density,
            direction: direction,
          );
          expect(find.byType(FrostRowLayout), findsOneWidget);
          final label = tester.getRect(find.text('Source label')), value = tester.getRect(find.text('A long source value'));
          expect(value.top - label.bottom, 2);
          expect(direction == TextDirection.ltr ? value.left : value.right, direction == TextDirection.ltr ? label.left : label.right);
          final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostLabeledContent)));
          for (final text in ['Source label', 'A long source value']) {
            final p = tester.renderObject<RenderParagraph>(find.text(text));
            expect(p.maxLines, isNull);
            expect(p.didExceedMaxLines, false);
            expect(p.text.style!.fontSize, FrostTypography.of(tester.element(find.text(text))).style(FrostTextRole.callout).fontSize);
            expect(p.text.style!.color, text == 'Source label' ? tokens.textSecondary : tokens.textPrimary);
            expect(p.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
          }
          final data = tester.getSemantics(find.byType(FrostLabeledContent)).getSemanticsData();
          expect(data.label, 'Source label');
          expect(data.value, 'A long source value');
          expect(tester.hasRunningAnimations, false);
          expect(tester.takeException(), isNull);
          handle.dispose();
        });
      }
    }
  }
  testWidgets('labeled content compact height, inline alignment and structural controls', (tester) async {
    for (final (density, height) in [(FrostDensity.compact, 32.0), (FrostDensity.comfortable, 36.0)]) {
      await display(
        tester,
        const FrostLabeledContent(label: 'Label', value: 'Value'),
        density: density,
        width: 400,
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostLabeledContent)).height, height);
      expect(tester.getCenter(find.text('Label')).dy, tester.getCenter(find.text('Value')).dy);
      expect(tester.getRect(find.text('Value')).right, tester.getRect(find.byType(FrostLabeledContent)).right);
    }
    var enabled = false;
    await display(
      tester,
      StatefulBuilder(
        builder: (context, set) => FrostLabeledContent(
          label: 'Setting',
          content: FrostSwitch(value: enabled, semanticLabel: 'Enabled', onChanged: (v) => set(() => enabled = v)),
        ),
      ),
    );
    await tester.tap(find.byType(FrostSwitch));
    expect(enabled, true);
    expect(() => FrostLabeledContent(label: 'Invalid'), throwsAssertionError);
    expect(() => FrostLabeledContent(label: 'Invalid', value: 'v', content: const SizedBox()), throwsAssertionError);
  });
  testWidgets('key value dividers start at the rendered text edge', (tester) async {
    await display(
      tester,
      const FrostKeyValueList(
        dividers: true,
        entries: [
          FrostKeyValue(label: 'Format', value: 'PNG'),
          FrostKeyValue(label: 'Resolution', value: '3840 × 2160'),
        ],
      ),
      width: 200,
      scale: 2,
      direction: TextDirection.rtl,
    );
    expect(find.byType(FrostRowLayout), findsNWidgets(2));
    expect(find.byType(FrostDivider), findsOneWidget);
    expect(tester.getRect(find.byType(FrostDivider)).right, tester.getRect(find.text('Format')).right);
    expect(tester.getSize(find.byType(FrostDivider)).height, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('meta line only breaks at separators and scrolls an indivisible item', (tester) async {
    final handle = tester.ensureSemantics();
    await display(
      tester,
      const FrostMetaLine(items: ['First item', '', 'Second item', 'An extraordinarily long indivisible item']),
      width: 140,
      scale: 2,
      direction: TextDirection.rtl,
    );
    final paragraphs = tester.renderObjectList<RenderParagraph>(find.descendant(of: find.byType(FrostMetaLine), matching: find.byType(RichText))).toList();
    expect(paragraphs, hasLength(3));
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostMetaLine)));
    for (final p in paragraphs) {
      expect(p.softWrap, false);
      expect(p.text.style!.color, tokens.textSecondary);
      expect(p.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
    final scrolls = tester.stateList<ScrollableState>(find.descendant(of: find.byType(FrostMetaLine), matching: find.byType(Scrollable)));
    expect(scrolls.any((s) => s.position.maxScrollExtent > 0), true);
    expect(tester.getSemantics(find.byType(FrostMetaLine)).getSemanticsData().label, 'First item · Second item · An extraordinarily long indivisible item');
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
  for (final direction in TextDirection.values) {
    for (final dpr in [1.0, 1.5]) {
      testWidgets('wide stat strip packs natural widths and paints full-height separators $direction dpr=$dpr', (tester) async {
        tester.view.physicalSize = const Size(2400, 800);
        addTearDown(tester.view.resetPhysicalSize);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const stats = [
          FrostStat(value: '128', caption: 'Saved'),
          FrostStat(value: '24', caption: 'Comments'),
          FrostStat(value: '12.8', unit: 'MB', caption: 'Size'),
        ];
        Widget withDpr(Widget child) => Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(devicePixelRatio: dpr),
            child: child,
          ),
        );
        await display(
          tester,
          withDpr(const Row(mainAxisSize: MainAxisSize.min, children: stats)),
          width: 2000,
          direction: direction,
        );
        final natural = [for (final stat in find.byType(FrostStat).evaluate()) tester.getSize(find.byWidget(stat.widget))];
        await display(tester, withDpr(const FrostStatStrip(stats: stats)), width: 2000, direction: direction);
        final strip = tester.getRect(find.byType(FrostStatStrip));
        final statBoxes = tester.renderObjectList<RenderBox>(find.byType(FrostStat)).toList();
        final dividers = tester.renderObjectList<RenderBox>(find.byType(FrostDivider)).toList();
        final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostStatStrip)));
        final layout = statBoxes.first.parent! as RenderBox;
        final origin = layout.localToGlobal(Offset.zero);
        final paint = paints;
        expect(strip.width, 2000);
        expect(dividers, hasLength(2));
        for (var index = 0; index < statBoxes.length; index++) {
          expect(statBoxes[index].size, natural[index]);
        }
        final first = tester.getRect(find.byType(FrostStat).first);
        expect(direction == TextDirection.ltr ? first.left : first.right, direction == TextDirection.ltr ? strip.left : strip.right);
        for (var index = 0; index < dividers.length; index++) {
          final previous = tester.getRect(find.byType(FrostStat).at(index)), next = tester.getRect(find.byType(FrostStat).at(index + 1));
          final divider = tester.getRect(find.byType(FrostDivider).at(index));
          expect(divider.width, closeTo(1 / dpr, .001));
          expect(divider.top, strip.top);
          expect(divider.height, strip.height);
          expect(direction == TextDirection.ltr ? divider.left - previous.right : previous.left - divider.right, closeTo(16, .001));
          expect(direction == TextDirection.ltr ? next.left - divider.right : divider.left - next.right, closeTo(16, .001));
          // Assert the shared physical hairline is painted at the slot center.
          final expectedX = divider.left - origin.dx + .5 / dpr;
          paint.something((method, arguments) {
            if (method != #drawLine) return false;
            final first = arguments[0] as Offset, last = arguments[1] as Offset, ink = arguments[2] as Paint;
            return (first.dx - expectedX).abs() < .001 &&
                first.dy == 0 &&
                last.dx == first.dx &&
                last.dy == strip.height &&
                ink.strokeWidth == 0 &&
                !ink.isAntiAlias &&
                ink.color.toARGB32() == tokens.separator.toARGB32();
          });
        }
        expect(tokens.separator.a, greaterThan(0));
        expect(layout, paint);
        expect(layout, paintsExactlyCountTimes(#drawLine, 2));
        expect(tester.takeException(), isNull);
      });
    }
    for (final scale in [1.0, 2.0]) {
      testWidgets('stat strip cold row and two columns $direction $scale', (tester) async {
        const stats = [
          FrostStat(value: '128', caption: 'Saved'),
          FrostStat(value: '24', caption: 'Comments'),
          FrostStat(value: '12.8', unit: 'MB', caption: 'Size'),
        ];
        for (final width in [750.0, 180.0]) {
          await display(
            tester,
            FrostStatStrip(key: ValueKey(width), stats: stats),
            width: width,
            scale: scale,
            direction: direction,
          );
          final boxes = find.byType(FrostStat);
          final first = tester.getRect(boxes.at(0)), second = tester.getRect(boxes.at(1)), third = tester.getRect(boxes.at(2));
          expect(first.top, second.top);
          if (width > 200) {
            expect(third.top, first.top);
            for (final divider in tester.renderObjectList<RenderBox>(find.byType(FrostDivider))) {
              expect(divider.size.width, 1);
              expect(divider.size.height, greaterThan(0));
            }
          } else {
            expect(third.top, greaterThan(first.bottom));
            expect(first.width, 84);
            expect(direction == TextDirection.ltr ? second.left - first.right : first.left - second.right, 12);
            for (final divider in tester.renderObjectList<RenderBox>(find.byType(FrostDivider))) {
              expect(divider.size, Size.zero);
            }
          }
          final text = tester.renderObject<RenderParagraph>(find.text('1').first).text.style!;
          final typography = FrostTypography.of(tester.element(find.byType(FrostStat).first));
          expect(text.fontSize, typography.style(FrostTextRole.value).fontSize);
          expect(text.fontFeatures, contains(const FontFeature.tabularFigures()));
          expect(tester.renderObject<RenderParagraph>(find.text('Saved')).text.style!.fontSize, typography.style(FrostTextRole.caption).fontSize);
          expect(
            tester.getSize(find.byType(FrostStatStrip)).height,
            closeTo(width > 200 ? first.height : (first.height > second.height ? first.height : second.height) + 12 + third.height, .01),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  for (final reduced in [false, true]) {
    testWidgets('shared labeled flow height transition reduced=$reduced', (tester) async {
      var value = 'Short';
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostLabeledContent(label: 'Label', value: value);
          },
        ),
        width: 160,
        reduced: reduced,
      );
      final before = tester.getSize(find.byType(FrostLabeledContent)).height;
      update(() => value = 'A much longer value that needs several complete lines');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 90));
      final middle = tester.getSize(find.byType(FrostLabeledContent)).height;
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byType(FrostLabeledContent)).height;
      expect(after, greaterThan(before));
      expect(middle, reduced ? after : inExclusiveRange(before, after));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('stat paint, semantics, numeric rolling and oversized values', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = '128';
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostStat(value: value, unit: 'MB', caption: 'Stored');
        },
      ),
    );
    final context = tester.element(find.byType(FrostStat)), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostStat)));
    expect(tester.renderObject<RenderParagraph>(find.text('1')).text.style!.color, tokens.textPrimary);
    expect(tester.renderObject<RenderParagraph>(find.text('MB')).text.style!.color, tokens.textSecondary);
    expect(tester.renderObject<RenderParagraph>(find.text('MB')).text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.subheadline).fontSize);
    expect(tester.renderObject<RenderParagraph>(find.text('Stored')).text.style!.color, tokens.textSecondary);
    expect(tester.getRect(find.text('MB')).left - tester.getRect(find.byType(FrostRollingText)).right, 4);
    expect(tester.getRect(find.text('Stored')).top - tester.getRect(find.byType(FrostRollingText)).bottom, 2);
    final data = tester.getSemantics(find.byType(FrostStat)).getSemanticsData();
    expect(data.label, 'Stored');
    expect(data.value, '128 MB');
    update(() => value = '129');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('8'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('8'), findsNothing);
    await display(
      tester,
      const FrostStat(value: '1234567890123456789', unit: 'MB', caption: 'Full caption at large scale'),
      width: 150,
      scale: 2,
      direction: TextDirection.rtl,
      reduced: true,
    );
    expect(
      tester
          .stateList<ScrollableState>(find.descendant(of: find.byType(FrostStat), matching: find.byType(Scrollable)))
          .any((s) => s.position.maxScrollExtent > 0),
      true,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
