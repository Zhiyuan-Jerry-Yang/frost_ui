import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

TextSpan renderedSpan(WidgetTester tester) => tester.state<EditableTextState>(find.byType(EditableText)).renderEditable.text! as TextSpan;

void main() {
  testWidgets('token controller paints five semantic tones and preserves completed-word matching', (tester) async {
    final controller = FrostTokenEditingController(
      text: 'accent positive caution negative neutral plain unfinished',
      rules: [for (final tone in FrostTokenTone.values) FrostTokenRule(pattern: RegExp('^${tone.name}\$'), tone: tone)],
    );
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Center(
              child: SizedBox(width: 700, child: FrostTokenField(controller: controller)),
            );
          },
        ),
      ),
    );
    final span = renderedSpan(tester);
    final children = span.children!.cast<TextSpan>();
    for (final tone in FrostTokenTone.values) {
      final token = children.singleWhere((span) => span.text == tone.name);
      expect(token.style!.color, switch (tone) {
        FrostTokenTone.accent => tokens.accentInk,
        FrostTokenTone.positive => tokens.positiveInk,
        FrostTokenTone.caution => tokens.cautionInk,
        FrostTokenTone.negative => tokens.negativeInk,
        FrostTokenTone.neutral => tokens.textSecondary,
      });
      expect(token.style!.fontWeight, FontWeight.w500);
      expect(token.style!.backgroundColor, isNull);
    }
    expect(children.last.text, contains('unfinished'));
    expect(children.last.style, isNull);
    expect(span.toPlainText(), controller.text);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('search uses the supplied token controller and rule changes preserve composing', (tester) async {
    final controller = FrostTokenEditingController(
      text: 'token plain ',
      rules: [FrostTokenRule(pattern: RegExp('token'), tone: FrostTokenTone.accent)],
    );
    controller.value = controller.value.copyWith(selection: const TextSelection.collapsed(offset: 3), composing: const TextRange(start: 1, end: 4));
    final focus = FocusNode();
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Center(
              child: SizedBox(
                width: 400,
                child: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
              ),
            );
          },
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(find.byType(FrostTokenField), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller, same(controller));
    final before = controller.value;
    expect(renderedSpan(tester).children!.whereType<TextSpan>().any((span) => span.style?.color == tokens.accentInk), true);
    controller.rules = [FrostTokenRule(pattern: RegExp('token'), tone: FrostTokenTone.negative)];
    await tester.pump();
    expect(controller.value, before);
    expect(renderedSpan(tester).toPlainText(), before.text);
    final spans = renderedSpan(tester).children!.cast<TextSpan>();
    expect(spans.any((span) => span.style?.color == tokens.negativeInk), true);
    expect(spans.singleWhere((span) => span.text == 'oke').style!.decoration, TextDecoration.underline);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });

  test('token rule equality, notification and snapshots retain the original semantics', () {
    FrostTokenRule rule({bool caseSensitive = true, FrostTokenTone tone = FrostTokenTone.accent}) => FrostTokenRule(
      pattern: RegExp('token', caseSensitive: caseSensitive, multiLine: true, unicode: true, dotAll: true),
      tone: tone,
    );
    expect(rule(), rule());
    expect(rule().hashCode, rule().hashCode);
    expect(rule(), isNot(rule(caseSensitive: false)));
    expect(rule(), isNot(rule(tone: FrostTokenTone.negative)));
    final rules = [rule()];
    final controller = FrostTokenEditingController(rules: rules);
    var notifications = 0;
    controller.addListener(() => notifications++);
    rules.clear();
    expect(controller.rules, hasLength(1));
    controller.rules = [rule()];
    expect(notifications, 0);
    controller.rules = [rule(tone: FrostTokenTone.negative)];
    expect(notifications, 1);
    expect(() => controller.rules.clear(), throwsUnsupportedError);
    controller.dispose();
  });

  testWidgets('ordinary search shares the field fill, compact size, clear and submit behavior', (tester) async {
    final controller = TextEditingController(text: 'query');
    final focus = FocusNode();
    final submitted = <String>[];
    var cleared = 0;
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Center(
              child: SizedBox(
                width: 400,
                child: FrostControlScope(
                  size: FrostControlSize.compact,
                  toolbar: true,
                  child: FrostSearchInput(
                    controller: controller,
                    focusNode: focus,
                    placeholder: 'Search',
                    onSubmitted: submitted.add,
                    onClear: () {
                      cleared++;
                      controller.clear();
                    },
                  ),
                ),
              ),
            );
          },
        ),
        density: FrostDensity.compact,
      ),
    );
    expect(find.byType(FrostTextField), findsOneWidget);
    expect(find.byType(FrostTokenField), findsNothing);
    final chrome = find.descendant(of: find.byType(FrostTextField), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(chrome).height, 32);
    final boxes = tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: chrome, matching: find.byType(DecoratedBox)));
    expect(boxes.any((box) => box.decoration is ShapeDecoration && (box.decoration as ShapeDecoration).color == tokens.fill), true);
    final border =
        boxes.firstWhere((box) => box.decoration is ShapeDecoration && (box.decoration as ShapeDecoration).color == null).decoration as ShapeDecoration;
    expect((border.shape as OutlinedBorder).side.color.a, 0);
    await tester.tap(findFrostTooltip('L.search'));
    expect(submitted, ['query']);
    await tester.tap(findFrostTooltip('L.clearText'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(controller.text, isEmpty);
    expect(findFrostTooltip('L.clearText'), findsNothing);
    await tester.tap(findFrostTooltip('L.search'));
    expect(submitted, ['query']);
    expect(tester.getSize(chrome).height, 32);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
}
