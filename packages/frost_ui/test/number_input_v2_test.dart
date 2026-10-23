import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_control_surfaces.dart';
import 'package:frost_ui/src/controls/stepper.dart' show FrostStepperControl;
import 'display_badges_v2_test.dart' show display, decorations;
import 'selection_input_v2_test.dart' show inputOpacity;

Finder stepButton(WidgetTester tester, int direction) {
  final labels = FrostScope.labelsOf(tester.element(find.byType(FrostStepperControl)));
  return find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.button == true && w.properties.label == (direction < 0 ? labels.decrement : labels.increment),
  );
}

TextEditingController numberController(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!;
Color numberBorder(WidgetTester tester) =>
    (tester
                .renderObjectList<RenderDecoratedBox>(find.byType(DecoratedBox))
                .map((box) => box.decoration)
                .whereType<ShapeDecoration>()
                .singleWhere(
                  (decoration) => decoration.shape is OutlinedBorder && (decoration.shape as OutlinedBorder).side.width == FrostMetrics.fieldFocusWidth,
                )
                .shape
            as OutlinedBorder)
        .side
        .color;

void main() {
  for (final density in FrostDensity.values) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('stepper and number field actual geometry and ink $density $direction scale=$scale', (tester) async {
          await display(
            tester,
            FrostStepper(value: 5, onChanged: (_) {}, semanticLabel: 'Quantity'),
            density: density,
            direction: direction,
            scale: scale,
          );
          final context = tester.element(find.byType(FrostStepper)), tokens = FrostThemeTokens.of(context);
          final visualHeight = FrostControlSize.compact.height(context), target = FrostDensity.of(context).targetHeight;
          expect(tester.getSize(find.byType(FrostStepper)), Size(target * 2 + 1, target));
          final track = find.byType(FrostControlTrack), frame = tester.getRect(track);
          expect(frame.height, visualHeight);
          expect(frame.center.dy, tester.getCenter(find.byType(FrostStepper)).dy);
          final decoration = decorations(tester, track).single.decoration as ShapeDecoration;
          expect(decoration.color, tokens.fill);
          expect((decoration.shape as RoundedSuperellipseBorder).borderRadius, FrostRadius.borderRadius(FrostRadius.forHeight(visualHeight)));
          final divider = tester.renderObject<RenderBox>(find.byType(FrostDivider));
          expect(divider.size, Size(1, visualHeight));
          expect(tester.getCenter(find.byType(FrostDivider)).dx, frame.center.dx);
          expect(divider, paints..line(color: tokens.separator, strokeWidth: 0));
          final decrement = tester.getRect(stepButton(tester, -1)), increment = tester.getRect(stepButton(tester, 1));
          expect(decrement.size, Size.square(target));
          expect(direction == TextDirection.ltr ? decrement.left < increment.left : decrement.left > increment.left, true);
          await display(
            tester,
            FrostNumberField(value: 12.5, decimals: 2, min: 0, max: 100, step: .25, unit: 'MB', label: 'Amount', help: 'Help', onChanged: (_) {}),
            width: 340,
            density: density,
            direction: direction,
            scale: scale,
          );
          expect(find.byType(FrostTextField), findsOneWidget);
          expect(numberController(tester).text, '12.50');
          final editable = tester.allRenderObjects.whereType<RenderEditable>().single;
          expect(editable.text!.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
          final unit = tester.renderObject<RenderParagraph>(find.text('MB'));
          expect(unit.text.style!.color, FrostThemeTokens.of(tester.element(find.text('MB'))).textSecondary);
          expect(unit.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
          expect(numberBorder(tester).a, 0);
          final field = tester.widget<TextField>(find.byType(TextField));
          expect(field.keyboardType, const TextInputType.numberWithOptions(decimal: true));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('stepper immediate press and exact 400/80 repeat timing; release does not add a step', (tester) async {
    num value = 0;
    final values = <num>[];
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) => FrostStepper(
          value: value,
          max: 20,
          onChanged: (v) => set(() {
            value = v;
            values.add(v);
          }),
          semanticLabel: 'Count',
        ),
      ),
    );
    final press = await tester.startGesture(tester.getCenter(stepButton(tester, 1)));
    expect(values, [1]);
    await tester.pump(const Duration(milliseconds: 399));
    expect(values, [1]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(values, [1, 2]);
    await tester.pump(const Duration(milliseconds: 79));
    expect(values, [1, 2]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(values, [1, 2, 3]);
    await tester.pump(const Duration(milliseconds: 160));
    expect(values.length, 5);
    await press.up();
    await tester.pump(const Duration(seconds: 1));
    expect(values.length, 5);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stepper shares hover, stable press geometry and concentric keyboard focus', (tester) async {
    num value = 5;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) => FrostStepper(value: value, max: 50, onChanged: (v) => set(() => value = v), semanticLabel: 'Count'),
      ),
    );
    final up = stepButton(tester, 1), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostStepper)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(up));
    await tester.pumpAndSettle();
    Color layer() => (decorations(tester, up).first.decoration as BoxDecoration).color!;
    expect(layer(), tokens.fillSubtle);
    final press = await tester.startGesture(tester.getCenter(up), pointer: 7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(layer(), isNot(isIn([tokens.fillSubtle, tokens.fillStrong])));
    expect(tester.widgetList<Transform>(find.descendant(of: up, matching: find.byType(Transform))).where((t) => t.transform.entry(0, 0) != 1), isEmpty);
    await press.cancel();
    Focus.of(tester.element(find.descendant(of: up, matching: find.byType(FrostIcon)).first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    final focus = find.descendant(of: up, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null));
    expect(focus, findsOneWidget);
    expect(tester.renderObject(focus), paints..path(color: tokens.focus, strokeWidth: 2));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  for (final unmount in [false, true]) {
    testWidgets('held stepper cancels silently on disable or unmount unmount=$unmount', (tester) async {
      num value = 0;
      var enabled = true, present = true, calls = 0;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return present
                ? FrostStepper(
                    value: value,
                    onChanged: enabled
                        ? (v) => set(() {
                            value = v;
                            calls++;
                          })
                        : null,
                    semanticLabel: 'Count',
                  )
                : const SizedBox();
          },
        ),
      );
      final press = await tester.startGesture(tester.getCenter(stepButton(tester, 1)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 1);
      update(() {
        if (unmount) {
          present = false;
        } else {
          enabled = false;
        }
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      if (!unmount) {
        update(() => enabled = true);
        await tester.pump();
      }
      await press.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('stepper boundary, keyboard, adjustable semantics and disabled transition reduced=$reduced', (tester) async {
      final semantics = tester.ensureSemantics();
      num value = 0;
      var enabled = true;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostStepper(value: value, min: 0, max: .3, step: .1, onChanged: enabled ? (v) => set(() => value = v) : null, semanticLabel: 'Fraction');
          },
        ),
        reduced: reduced,
      );
      final down = stepButton(tester, -1), up = stepButton(tester, 1);
      expect(tester.widget<Semantics>(down).properties.enabled, false);
      await tester.tap(up);
      await tester.pumpAndSettle();
      expect(value, .1);
      Focus.of(tester.element(find.descendant(of: up, matching: find.byType(FrostIcon)).first)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, .2);
      final node = tester.getSemantics(find.byType(FrostStepper));
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(value, .3);
      expect(tester.widget<Semantics>(up).properties.enabled, false);
      update(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final icon = find.descendant(of: down, matching: find.byType(FrostIcon));
      expect(inputOpacity(tester.renderObject(icon)), reduced ? closeTo(.38, .001) : inExclusiveRange(.38, 1));
      await tester.pumpAndSettle();
      expect(inputOpacity(tester.renderObject(icon)), closeTo(.38, .001));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('number field preserves editing, commits once, rounds from min and uses arrow steps', (tester) async {
    num value = .1;
    final changes = <num>[];
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) => FrostNumberField(
          value: value,
          min: .1,
          max: 5,
          step: .1,
          decimals: 2,
          onChanged: (v) => set(() {
            value = v;
            changes.add(v);
          }),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '.35');
    await tester.pump();
    expect(numberController(tester).text, '.35');
    expect(changes, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, .4);
    expect(numberController(tester).text, '0.40');
    expect(changes, [.4]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(value, .5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(value, .4);
    await tester.enterText(find.byType(TextField), '1.06');
    tester.widget<TextField>(find.byType(TextField)).focusNode!.unfocus();
    await tester.pump();
    expect(value, 1.1);
    expect(numberController(tester).text, '1.10');
    expect(tester.takeException(), isNull);
  });
  testWidgets('number field reuses all three base heights and preserves padding at 200 percent', (tester) async {
    for (final density in FrostDensity.values) {
      for (final size in FrostControlSize.values) {
        double? padding, initialLine;
        for (final scale in [1.0, 2.0]) {
          await display(
            tester,
            FrostNumberField(value: 4, size: size, onChanged: (_) {}),
            width: 320,
            density: density,
            scale: scale,
          );
          await tester.pumpAndSettle();
          final chrome = find.descendant(of: find.byType(FrostTextField), matching: find.byType(AnimatedContainer)).first;
          final frame = tester.getRect(chrome), text = tester.getRect(find.byType(EditableText));
          padding ??= text.top - frame.top;
          initialLine ??= text.height;
          expect(text.top - frame.top, closeTo(padding, .001));
          expect(frame.bottom - text.bottom, closeTo(padding, .001));
          expect(
            frame.height,
            closeTo(size.visualHeight(touch: density == FrostDensity.comfortable) + text.height - initialLine, .001),
            reason: '$density $size $scale',
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
  for (final reduced in [false, true]) {
    testWidgets('number invalid commit shows ink for 350ms then clamps or restores reduced=$reduced', (tester) async {
      num value = .7;
      final changes = <num>[];
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) => FrostNumberField(
            value: value,
            max: 1,
            step: .7,
            decimals: 1,
            help: 'Help stays',
            onChanged: (v) => set(() {
              value = v;
              changes.add(v);
            }),
          ),
        ),
        reduced: reduced,
      );
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostNumberField)));
      await tester.enterText(find.byType(TextField), '2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(numberBorder(tester), reduced ? tokens.negativeInk : isNot(isIn([tokens.fieldFocus, tokens.negativeInk])));
      await tester.pump(const Duration(milliseconds: 130));
      expect(numberBorder(tester), tokens.negativeInk);
      expect(find.text('Help stays'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 149));
      expect(changes, isEmpty);
      expect(numberController(tester).text, '2');
      await tester.pump(const Duration(milliseconds: 1));
      expect(value, 1);
      expect(changes, [1]);
      expect(numberController(tester).text, '1.0');
      await tester.pumpAndSettle();
      expect(numberBorder(tester).a, 0);
      await tester.enterText(find.byType(TextField), 'not a number');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 350));
      expect(numberController(tester).text, '1.0');
      expect(changes, [1]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('number decimal rounding, endpoint steps, stale corrections, composing and disabled opacity', (tester) async {
    num value = 1;
    var enabled = true;
    late StateSetter update;
    final changes = <num>[];
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return FrostNumberField(
            value: value,
            min: 0,
            max: 2,
            step: .001,
            decimals: 2,
            onChanged: enabled
                ? (v) => set(() {
                    value = v;
                    changes.add(v);
                  })
                : null,
          );
        },
      ),
    );
    await tester.enterText(find.byType(TextField), '1.005');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 1.01);
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '1.4');
    await tester.pump(const Duration(milliseconds: 350));
    expect(numberController(tester).text, '1.4');
    expect(value, 1.01);
    final controller = numberController(tester);
    controller.value = const TextEditingValue(text: '1.5', selection: TextSelection.collapsed(offset: 3), composing: TextRange(start: 0, end: 3));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // A later input may complete composition; controller edits never break it.
    expect(tester.takeException(), isNull);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(inputOpacity(tester.allRenderObjects.whereType<RenderEditable>().single), closeTo(.38, .001));
    final icon = find.descendant(of: stepButton(tester, 1), matching: find.byType(FrostIcon));
    expect(inputOpacity(tester.renderObject(icon)), closeTo(.38, .001));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
