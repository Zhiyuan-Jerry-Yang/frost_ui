import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'display_badges_v2_test.dart' show display;
import 'token_search_test.dart' show renderedSpan;

FrostTokenEditingController tokenController(String text, int offset) => FrostTokenEditingController(
  text: text,
  rules: [FrostTokenRule(pattern: RegExp(r'^#'), tone: FrostTokenTone.accent)],
)..selection = TextSelection.collapsed(offset: offset);

void main() {
  testWidgets('completed token takes two hardware backspaces and undo restores its body', (tester) async {
    final controller = tokenController('#token ', 6), focus = FocusNode();
    final changes = <String>[];
    await display(tester, FrostTokenField(controller: controller, focusNode: focus, onChanged: changes.add), width: 400);
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, '#token ');
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 6));
    expect(changes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, ' ');
    expect(controller.selection, const TextSelection.collapsed(offset: 0));
    expect(changes, [' ']);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.text, '#token ');
    expect(renderedSpan(tester).children!.whereType<TextSpan>().any((span) => span.text == '#token' && span.style?.color != null), true);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('search token controller handles platform backspaces without another controller', (tester) async {
    final controller = tokenController('plain #token tail', 12), focus = FocusNode();
    await display(tester, FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}), width: 400);
    focus.requestFocus();
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'plain #toke tail', selection: TextSelection.collapsed(offset: 11)));
    await tester.pump();
    expect(controller.text, 'plain #token tail');
    expect(controller.selection, const TextSelection(baseOffset: 6, extentOffset: 12));
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'plain  tail', selection: TextSelection.collapsed(offset: 6)));
    await tester.pump();
    expect(controller.text, 'plain  tail');
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller, same(controller));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
    expect(tester.takeException(), isNull);
  });
  for (final testCase in [
    ('unfinished', '#token', 6, '#toke'),
    ('inside token', '#token ', 3, '#tken '),
    ('unmatched', 'plain ', 5, 'plai '),
    ('whitespace', '#token ', 7, '#token'),
  ]) {
    testWidgets('ordinary backspace is preserved ${testCase.$1}', (tester) async {
      final controller = tokenController(testCase.$2, testCase.$3), focus = FocusNode();
      await display(tester, FrostTokenField(controller: controller, focusNode: focus));
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(controller.text, testCase.$4);
      expect(controller.selection.isCollapsed, true);
      if (testCase.$1 == 'whitespace') {
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();
        expect(controller.text, '#toke');
        expect(controller.selection.isCollapsed, true);
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  test('composing, existing selections and word deletions bypass whole-token interception', () {
    final controller = tokenController('#token ', 6);
    controller.value = controller.value.copyWith(composing: const TextRange(start: 0, end: 6));
    controller.value = const TextEditingValue(text: '#toke ', selection: TextSelection.collapsed(offset: 5), composing: TextRange(start: 0, end: 5));
    expect(controller.text, '#toke ');
    expect(controller.value.composing, const TextRange(start: 0, end: 5));
    final before = controller.value;
    controller.rules = [FrostTokenRule(pattern: RegExp(r'^#'), tone: FrostTokenTone.negative)];
    expect(controller.value, before);
    controller.value = const TextEditingValue(text: '#token ', selection: TextSelection(baseOffset: 2, extentOffset: 6));
    controller.value = const TextEditingValue(text: '#t ', selection: TextSelection.collapsed(offset: 2));
    expect(controller.text, '#t ');
    controller.value = const TextEditingValue(text: '#token ', selection: TextSelection.collapsed(offset: 6));
    controller.value = const TextEditingValue(text: ' ', selection: TextSelection.collapsed(offset: 0));
    expect(controller.text, ' ');
    controller.dispose();
  });
  test('completed token deletion uses graphemes and the current rule source', () {
    final controller = tokenController('#😀 ', 3);
    controller.value = const TextEditingValue(text: '# ', selection: TextSelection.collapsed(offset: 1));
    expect(controller.text, '#😀 ');
    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
    controller.selection = const TextSelection.collapsed(offset: 3);
    controller.rules = [];
    controller.value = const TextEditingValue(text: '# ', selection: TextSelection.collapsed(offset: 1));
    expect(controller.text, '# ');
    controller.dispose();
  });
  for (final density in FrostDensity.values) {
    for (final direction in TextDirection.values) {
      testWidgets('search empty uses supplied labels, search icon and clear action $density $direction', (tester) async {
        var cleared = 0;
        await display(
          tester,
          SizedBox(
            height: 260,
            child: FrostEmptyState.search(query: 'frost', onClear: () => cleared++),
          ),
          width: 300,
          scale: 2,
          density: density,
          direction: direction,
        );
        final context = tester.element(find.byType(FrostButton)), labels = FrostScope.labelsOf(context), tokens = FrostThemeTokens.of(context);
        final text = tester.renderObject<RenderParagraph>(find.text(labels.noResults('frost')));
        expect(text.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.title2).fontSize);
        expect(text.text.style!.color, tokens.textPrimary);
        final icon = tester.widget<FrostIcon>(find.byType(FrostIcon));
        expect(icon.icon, FrostIconSet.of(context).search);
        expect(icon.size, 28);
        final button = tester.widget<FrostButton>(find.byType(FrostButton));
        expect(button.label, labels.clearSearch);
        expect(button.variant, FrostButtonVariant.standard);
        await tester.ensureVisible(find.byType(FrostButton));
        await tester.tap(find.byType(FrostButton));
        await tester.pumpAndSettle();
        expect(cleared, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
