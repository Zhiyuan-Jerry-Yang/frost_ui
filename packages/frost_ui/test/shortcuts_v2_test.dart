import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/shortcuts.dart' show frostShortcutLabel;
import 'support.dart';

Future<void> shortcutApp(WidgetTester tester, Widget child, {TargetPlatform platform = TargetPlatform.windows}) => tester.pumpWidget(
  frostTestApp(
    Builder(
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(platform: platform),
        child: Scaffold(body: child),
      ),
    ),
  ),
);
Future<void> chord(WidgetTester tester, LogicalKeyboardKey key, {bool primary = false, bool shift = false, bool alt = false, bool apple = false}) async {
  final modifiers = [
    if (primary) apple ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (alt) LogicalKeyboardKey.altLeft,
  ];
  for (final modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(key);
  for (final modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pump();
}

void main() {
  testWidgets('Shortcut notation uses platform primary key, modifier order and keyLabel for every combination', (tester) async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS, TargetPlatform.iOS]) {
      final apple = platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
      for (var bits = 0; bits < 8; bits++) {
        final shortcut = FrostShortcut(LogicalKeyboardKey.keyC, primary: bits & 1 != 0, shift: bits & 2 != 0, alt: bits & 4 != 0);
        await shortcutApp(tester, Builder(builder: (context) => Text(frostShortcutLabel(context, shortcut))), platform: platform);
        final expected = apple
            ? [if (shortcut.alt) '⌥', if (shortcut.shift) '⇧', if (shortcut.primary) '⌘', 'C'].join()
            : [if (shortcut.primary) 'Ctrl', if (shortcut.shift) 'Shift', if (shortcut.alt) 'Alt', 'C'].join('+');
        expect(find.text(expected), findsOneWidget);
      }
    }
    expect(const FrostShortcut(LogicalKeyboardKey.keyC, primary: true), const FrostShortcut(LogicalKeyboardKey.keyC, primary: true));
    expect(const FrostShortcut(LogicalKeyboardKey.keyC, primary: true).hashCode, const FrostShortcut(LogicalKeyboardKey.keyC, primary: true).hashCode);
  });
  testWidgets('FrostShortcuts triggers only inside the focused subtree on Windows and macOS', (tester) async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
      final inside = FocusNode(), outside = FocusNode();
      var calls = 0;
      await shortcutApp(
        tester,
        Column(
          children: [
            FrostShortcuts(
              bindings: {const FrostShortcut(LogicalKeyboardKey.keyK, primary: true, shift: true, alt: true): () => calls++},
              child: Focus(focusNode: inside, child: const Text('Inside')),
            ),
            Focus(focusNode: outside, child: const Text('Outside')),
          ],
        ),
        platform: platform,
      );
      inside.requestFocus();
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.keyK, primary: true, shift: true, alt: true, apple: platform == TargetPlatform.macOS);
      expect(calls, 1);
      outside.requestFocus();
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.keyK, primary: true, shift: true, alt: true, apple: platform == TargetPlatform.macOS);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      inside.dispose();
      outside.dispose();
    }
  });
  testWidgets('The shortcut extension applies only when its own component subtree has focus', (tester) async {
    final inside = FocusNode(), outside = FocusNode();
    var calls = 0;
    await shortcutApp(
      tester,
      Column(
        children: [
          Focus(focusNode: inside, child: const Text('Inside')).frostShortcut(const FrostShortcut(LogicalKeyboardKey.keyR, alt: true), () => calls++),
          Focus(focusNode: outside, child: const Text('Outside')),
        ],
      ),
    );
    outside.requestFocus();
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.keyR, alt: true);
    expect(calls, 0);
    inside.requestFocus();
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.keyR, alt: true);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    inside.dispose();
    outside.dispose();
  });
  testWidgets('Character and Shift-character shortcuts yield to focused text input; Primary and Alt remain available', (tester) async {
    final focus = FocusNode(), controller = TextEditingController();
    var plain = 0, modified = 0;
    await shortcutApp(
      tester,
      FrostShortcuts(
        bindings: {
          const FrostShortcut(LogicalKeyboardKey.keyA): () => plain++,
          const FrostShortcut(LogicalKeyboardKey.keyA, shift: true): () => plain++,
          const FrostShortcut(LogicalKeyboardKey.keyK, primary: true): () => modified++,
          const FrostShortcut(LogicalKeyboardKey.keyN, alt: true): () => modified++,
        },
        child: FrostTextField(focusNode: focus, controller: controller),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.keyA);
    await chord(tester, LogicalKeyboardKey.keyA, shift: true);
    expect(plain, 0);
    await tester.enterText(find.byType(TextField), 'aA');
    expect(controller.text, 'aA');
    await chord(tester, LogicalKeyboardKey.keyK, primary: true);
    await chord(tester, LogicalKeyboardKey.keyN, alt: true);
    expect(modified, 2);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    controller.dispose();
  });
  testWidgets('Menu shortcut column formats itself and exposes only a hint, without registering a binding', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
      var selected = 0;
      await shortcutApp(
        tester,
        Center(
          child: FrostMenuAnchor(
            entries: [
              FrostMenuAction(
                'Copy',
                shortcut: const FrostShortcut(LogicalKeyboardKey.keyC, primary: true, shift: true, alt: true),
                onSelected: () => selected++,
              ),
            ],
            builder: (context, focus, toggle) => Focus(
              focusNode: focus,
              child: FrostButton(label: 'Open', onPressed: toggle),
            ),
          ),
        ),
        platform: platform,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final expected = platform == TargetPlatform.macOS ? '⌥⇧⌘C' : 'Ctrl+Shift+Alt+C';
      expect(find.text(expected), findsOneWidget);
      final node = tester.getSemantics(find.text('Copy'));
      expect(node.getSemanticsData().hint, expected);
      expect(node.getSemanticsData().label, 'Copy');
      final tokens = FrostThemeTokens.of(tester.element(find.text(expected)));
      final paragraph = tester.widget<Text>(find.text(expected));
      expect(paragraph.style!.fontSize, 12);
      expect(DefaultTextStyle.of(tester.element(find.text(expected))).style.color, tokens.textTertiary);
      await chord(tester, LogicalKeyboardKey.keyC, primary: true, shift: true, alt: true, apple: platform == TargetPlatform.macOS);
      expect(selected, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
    semantics.dispose();
  });
}
