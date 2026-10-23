import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'display_badges_v2_test.dart' show display;
import 'picker_v2_test.dart' show colors;

void main() {
  const customIcon = FrostIconData.glyph(IconData(0xe123));
  for (final brightness in Brightness.values) {
    testWidgets('custom swatch neutral icon, configured fill, check contrast and repeat activation $brightness', (tester) async {
      var selected = false, calls = 0;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostColorSwatch(color: const Color(0xffffeeaa), label: 'Custom colour', icon: customIcon, selected: selected, onPressed: () => calls++);
          },
        ),
        brightness: brightness,
      );
      final swatch = find.bySemanticsLabel('Custom colour');
      expect(tester.getSize(swatch), const Size.square(24));
      final context = tester.element(swatch);
      final fill = tester
          .widgetList<DecoratedBox>(find.descendant(of: swatch, matching: find.byType(DecoratedBox)))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.shape == BoxShape.circle)
          .color;
      expect(fill, FrostThemeTokens.of(context).fill);
      expect(find.byWidgetPredicate((w) => w is FrostIcon && w.icon == customIcon), findsOneWidget);
      update(() => selected = true);
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is FrostIcon && w.icon == customIcon), findsNothing);
      final check = tester.widget<FrostIcon>(find.descendant(of: swatch, matching: find.byType(FrostIcon)));
      expect(colorContrast(check.color!, const Color(0xffffeeaa)), greaterThanOrEqualTo(4.5));
      for (var i = 0; i < 2; i++) {
        await tester.tap(swatch);
        await tester.pumpAndSettle();
      }
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
  for (final direction in TextDirection.values) {
    testWidgets('trailing swatch shares arrows, Tab and custom selection without activating on arrows $direction', (tester) async {
      int? value = 0;
      var custom = false, calls = 0;
      final focus = FocusNode(), after = FocusNode();
      addTearDown(focus.dispose);
      addTearDown(after.dispose);
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostPicker.palette(
                options: colors,
                value: value,
                label: 'Palette',
                onChanged: (v) => set(() {
                  value = v;
                  custom = false;
                }),
                trailingSwatch: FrostColorSwatch(
                  color: const Color(0xffffeeaa),
                  label: 'Custom',
                  selected: custom,
                  focusNode: focus,
                  onPressed: () {
                    calls++;
                    set(() {
                      value = null;
                      custom = true;
                    });
                  },
                ),
              ),
              Focus(focusNode: after, child: const Text('After')),
            ],
          ),
        ),
        direction: direction,
      );
      final forward = direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
      final backward = direction == TextDirection.ltr ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(forward);
      await tester.pumpAndSettle();
      expect(value, 2); // disabled preset skipped
      await tester.sendKeyEvent(forward);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(calls, 0); // focusing an action must not open its dialog
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(value, isNull);
      expect(tester.widgetList<FrostColorSwatch>(find.byType(FrostColorSwatch)).where((w) => w.selected).single.label, 'Custom');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasFocus, isTrue);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(backward);
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(custom, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
