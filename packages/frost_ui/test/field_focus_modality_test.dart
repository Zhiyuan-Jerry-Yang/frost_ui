import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/primitives/_focus_outline.dart';

import 'support.dart';

Finder field() => find.byType(FrostFieldFrame).evaluate().isNotEmpty ? find.byType(FrostFieldFrame).first : find.byType(FrostButtonControl).first;
Finder rings() => find.descendant(of: field(), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is FrostFocusOutlinePainter));
Color stroke(WidgetTester tester) {
  final boxes = find.descendant(of: field(), matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.position == DecorationPosition.foreground));
  return ((tester.renderObject<RenderDecoratedBox>(boxes.first).decoration as ShapeDecoration).shape as OutlinedBorder).side.color;
}

void main() {
  for (final kind in ['text', 'secure', 'token', 'search', 'number', 'time', 'path', 'picker']) {
    for (final pointerKind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      for (final brightness in Brightness.values) {
        testWidgets('$kind preserves focus without pointer outline and reveals keyboard ring: $pointerKind $brightness', (tester) async {
          final previous = FocusManager.instance.highlightStrategy;
          FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
          addTearDown(() => FocusManager.instance.highlightStrategy = previous);
          final controller = FrostTokenEditingController(text: 'Existing text');
          final focus = FocusNode();
          var enabled = true;
          late StateSetter update;
          Widget input() => switch (kind) {
            'text' => FrostTextField(controller: controller, focusNode: focus),
            'secure' => FrostTextField.secure(controller: controller, focusNode: focus),
            'token' => FrostTokenField(controller: controller, focusNode: focus),
            'search' => FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
            'number' => FrostNumberField(value: 5, onChanged: (_) {}),
            'time' => FrostTimePicker(value: const TimeOfDay(hour: 12, minute: 34), label: 'Time', onChanged: (_) {}),
            'path' => const FrostPathField(path: '/fixture/image.png', label: 'Path'),
            _ => FrostPicker.menu(
              label: 'Value',
              value: 1,
              options: const [
                FrostPickerOption(value: 1, label: 'One'),
                FrostPickerOption(value: 2, label: 'Two'),
              ],
              onChanged: (_) {},
            ),
          };
          await tester.pumpWidget(
            frostTestApp(
              Center(
                child: SizedBox(
                  width: 320,
                  child: StatefulBuilder(
                    builder: (context, set) {
                      update = set;
                      return FrostControlScope(enabled: enabled, child: input());
                    },
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          expect(stroke(tester).a, 0);
          final gesture = await tester.createGesture(kind: pointerKind);
          await gesture.addPointer(location: const Offset(1, 1));
          await gesture.down(tester.getCenter(field()));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(stroke(tester).a, 0, reason: 'Pointer focus must not paint an accent border');
          expect(rings(), findsNothing);
          await tester.sendKeyEvent(kind == 'picker' ? LogicalKeyboardKey.escape : LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(rings(), findsOneWidget);
          final painter = tester.widget<CustomPaint>(rings()).foregroundPainter! as FrostFocusOutlinePainter;
          final tokens = FrostThemeTokens.of(tester.element(field()));
          expect(painter.color, tokens.focus);
          expect(painter.width, FrostMetrics.focusBorderWidth);
          expect(stroke(tester).a, 0, reason: 'Keyboard ring is outside the field, not its error stroke');
          await gesture.down(tester.getCenter(field()));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(rings(), findsNothing);
          if (kind == 'picker') {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }
          update(() => enabled = false);
          await tester.pumpAndSettle();
          expect(rings(), findsNothing);
          await gesture.removePointer();
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
          focus.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
