import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Future<void> mount(
  WidgetTester tester,
  Widget row, {
  double width = 260,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  FrostDensity density = FrostDensity.compact,
}) => tester.pumpWidget(
  frostTestApp(
    MediaQuery(
      data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox(width: width, child: row),
        ),
      ),
    ),
    density: density,
  ),
);
RenderParagraph paragraph(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text));

void main() {
  for (final direction in TextDirection.values) {
    for (final density in FrostDensity.values) {
      testWidgets('inline translation first frame, baseline, count and full semantics $direction $density', (tester) async {
        const detail = 'A complete translated name which cannot fit';
        final semantics = tester.ensureSemantics();
        await mount(
          tester,
          const FrostListRow(title: 'landscape', subtitle: detail, inlineSubtitle: true, value: '98K'),
          direction: direction,
          density: density,
        );
        final title = paragraph(tester, 'landscape'), translation = paragraph(tester, detail);
        final count = tester.getRect(find.text('98K'));
        expect(title.didExceedMaxLines, false);
        expect(translation.maxLines, 1);
        expect(translation.overflow, TextOverflow.ellipsis);
        expect(translation.didExceedMaxLines, true);
        final titleBaseline = tester.getTopLeft(find.text('landscape')).dy + title.getDryBaseline(title.constraints, TextBaseline.alphabetic)!;
        final detailBaseline = tester.getTopLeft(find.text(detail)).dy + translation.getDryBaseline(translation.constraints, TextBaseline.alphabetic)!;
        expect(detailBaseline, closeTo(titleBaseline, .01));
        expect(tester.getSize(find.byType(FrostClickSurface)).height, density == FrostDensity.compact ? 40 : 44);
        final value = tester.getSemantics(find.byType(FrostListRow)).getSemanticsData().value;
        expect(value, contains(detail));
        expect(value, contains('98K'));
        if (direction == TextDirection.ltr) {
          expect(count.left, greaterThan(tester.getRect(find.text(detail)).right));
        } else {
          expect(count.right, lessThan(tester.getRect(find.text(detail)).left));
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets('only canonical title wraps at $scale; metadata remains inline', (tester) async {
      const title = 'A canonical name that requires several full lines';
      const detail = 'Translation must never stack';
      await mount(
        tester,
        const FrostListRow(title: title, subtitle: detail, inlineSubtitle: true, value: '1,234'),
        width: 160,
        scale: scale,
      );
      final canonical = paragraph(tester, title), translated = paragraph(tester, detail);
      expect(canonical.maxLines, isNull);
      expect(canonical.overflow, isNot(TextOverflow.ellipsis));
      expect(canonical.size.height, greaterThan(30 * scale));
      expect(translated.size.width, 0);
      expect(tester.getRect(find.text('1,234')).center.dy, closeTo(tester.getRect(find.byType(FrostClickSurface)).center.dy, .01));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('short translation does not increase row height and default remains stacked', (tester) async {
    await mount(tester, const FrostListRow(title: 'sky', subtitle: 'blue', inlineSubtitle: true));
    expect(tester.getSize(find.byType(FrostClickSurface)).height, 40);
    expect(paragraph(tester, 'blue').didExceedMaxLines, false);
    await mount(tester, const FrostListRow(title: 'sky', subtitle: 'blue'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('blue')).dy, greaterThan(tester.getBottomLeft(find.text('sky')).dy));
  });
  testWidgets('inline translated list retains lazy construction', (tester) async {
    final built = <int>{};
    await mount(
      tester,
      SizedBox(
        height: 200,
        child: FrostList<int>(
          items: List.generate(1000, (i) => i),
          itemBuilder: (_, item, _) {
            built.add(item);
            return FrostListRow(title: 'tag $item', subtitle: 'Full translated name', inlineSubtitle: true, value: '$item');
          },
        ),
      ),
    );
    expect(built.length, lessThan(30));
    expect(built, contains(0));
    expect(tester.takeException(), isNull);
  });
  testWidgets('search shares inline layout and announces complete translated detail', (tester) async {
    final controller = TextEditingController(text: 'sky'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final semantics = tester.ensureSemantics();
    const detail = 'Full translated detail for accessibility';
    await mount(
      tester,
      SizedBox(
        height: 300,
        child: FrostSearchInput(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: (_) {},
          suggestions: [
            FrostSearchSuggestionGroup(
              items: [FrostSearchSuggestion(label: 'sky', detail: detail, inlineDetail: true, value: '98K', onSelected: () {})],
            ),
          ],
          layoutBuilder: (_, field, list) => Column(
            children: [
              field,
              Expanded(child: list ?? const SizedBox()),
            ],
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final row = tester.widget<FrostListRow>(find.byType(FrostListRow));
    expect(row.inlineSubtitle, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final inputSemantics = tester.getSemantics(find.byType(EditableText)).getSemanticsData();
    expect(inputSemantics.hint, contains(detail));
    expect(inputSemantics.hint, contains('1 / 1'));
    expect(focus.hasPrimaryFocus, true);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
