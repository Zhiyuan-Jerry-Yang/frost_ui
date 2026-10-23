import 'dart:ui' show CheckedState;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_choice_mark.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'display_badges_v2_test.dart' show display, decorations;
import 'lists_v2_test.dart' show rowSurface, rowCorners;

Finder choicePaint([Finder? parent]) => find.descendant(
  of: parent ?? find.byType(FrostChoiceMark).first,
  matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FrostChoicePainter),
);
FrostChoicePainter choicePainter(WidgetTester tester, [Finder? parent]) => tester.widget<CustomPaint>(choicePaint(parent)).painter! as FrostChoicePainter;
double inputOpacity(RenderObject object) {
  var opacity = 1.0;
  for (RenderObject? ancestor = object; ancestor != null; ancestor = ancestor.parent) {
    if (ancestor is RenderOpacity) opacity *= ancestor.opacity;
    if (ancestor is RenderFrostContentFade) opacity *= ancestor.opacity;
    if (ancestor is RenderAnimatedOpacity) opacity *= ancestor.opacity.value;
  }
  return opacity;
}

void main() {
  test('checkbox asserts a non-null value outside tristate mode', () {
    expect(() => FrostCheckbox(value: null, onChanged: null, semanticLabel: null), throwsAssertionError);
    expect(() => FrostCheckboxRow(title: 'Invalid', value: null, onChanged: null), throwsAssertionError);
  });
  for (final density in FrostDensity.values) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('choice mark and shared row geometry $density $direction scale=$scale', (tester) async {
          await display(
            tester,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FrostCheckbox(value: false, onChanged: (_) {}, semanticLabel: 'Standalone'),
                FrostCheckboxRow(title: 'Checkbox row', subtitle: 'Complete subtitle', value: true, onChanged: (_) {}),
                FrostGroupedSection(
                  children: [
                    FrostPicker<int>.inline(
                      options: const [
                        FrostPickerOption(value: 1, label: 'One'),
                        FrostPickerOption(value: 2, label: 'Two', subtitle: 'Another choice'),
                      ],
                      value: 2,
                      onChanged: (_) {},
                      label: 'Choice',
                    ),
                  ],
                ),
              ],
            ),
            width: 340,
            density: density,
            direction: direction,
            scale: scale,
          );
          final checkbox = find.byType(FrostCheckbox), row = find.byType(FrostCheckboxRow);
          final context = tester.element(checkbox), tokens = FrostThemeTokens.of(context);
          expect(tester.getSize(checkbox), Size.square(FrostDensity.of(context).targetHeight));
          final mark = find.byType(FrostChoiceMark).first;
          expect(tester.getSize(mark), const Size.square(20));
          final surface = decorations(tester, mark).first;
          final decoration = surface.decoration as ShapeDecoration;
          expect(decoration.color, tokens.fillStrong);
          expect((decoration.shape as RoundedSuperellipseBorder).borderRadius, FrostRadius.borderRadius(FrostRadius.xs));
          expect(
            surface,
            paints..something((method, args) => method == #drawRSuperellipse && (args[1] as Paint).color.toARGB32() == tokens.fillStrong.toARGB32()),
          );
          final rowMark = find.descendant(of: row, matching: find.byType(FrostChoiceMark));
          expect(tester.getSize(rowMark), const Size.square(20));
          final markRect = tester.getRect(rowMark), title = tester.getRect(find.text('Checkbox row'));
          expect(direction == TextDirection.ltr ? title.left - markRect.left : markRect.right - title.right, 32);
          expect(find.descendant(of: row, matching: find.byType(FrostClickSurface)), findsOneWidget);
          final radioMark = find.byType(FrostChoiceMark).last;
          final radioSurface = decorations(tester, radioMark).first;
          expect((radioSurface.decoration as ShapeDecoration).shape, isA<CircleBorder>());
          expect((radioSurface.decoration as ShapeDecoration).color, tokens.actionFill);
          expect(tester.renderObject(choicePaint(radioMark)), paints..circle(radius: 4, color: tokens.onAction));
          for (final paragraph in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
            expect(paragraph.didExceedMaxLines, false);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final reduced in [false, true]) {
    testWidgets('checkbox stroke, mixed transition, pop and disabled ink reduced=$reduced', (tester) async {
      final semantics = tester.ensureSemantics();
      bool? value = false;
      var enabled = true;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostCheckbox(value: value, tristate: true, semanticLabel: 'Choice', onChanged: enabled ? (v) => set(() => value = v) : null);
          },
        ),
        reduced: reduced,
      );
      final checkbox = find.byType(FrostCheckbox), mark = find.byType(FrostChoiceMark);
      final tokens = FrostThemeTokens.of(tester.element(checkbox));
      Color fill() => (decorations(tester, mark).first.decoration as ShapeDecoration).color!;
      expect(tester.getSemantics(checkbox).getSemanticsData().flagsCollection.isChecked, CheckedState.isFalse);
      await tester.tap(checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(value, true);
      final mid = choicePainter(tester).check;
      expect(mid, inExclusiveRange(0, 1));
      expect(choicePainter(tester).fadeCheck, reduced);
      expect(fill(), reduced ? tokens.actionFill : isNot(isIn([tokens.fillStrong, tokens.actionFill])));
      double? strokeLength;
      expect(
        tester.renderObject(choicePaint()),
        paints..something((method, args) {
          if (method != #drawPath) return false;
          strokeLength = (args[0] as Path).computeMetrics().single.length;
          final paint = args[1] as Paint;
          return (paint.strokeWidth - 1.8).abs() < .000001 && paint.strokeCap == StrokeCap.round && paint.strokeJoin == StrokeJoin.round;
        }),
      );
      const start = Offset(4, 10), elbow = Offset(8, 14), end = Offset(16, 6);
      final fullLength = (elbow - start).distance + (end - elbow).distance;
      expect(strokeLength, reduced ? closeTo(fullLength, .001) : inExclusiveRange(0, fullLength));
      await tester.pumpAndSettle();
      expect(fill(), tokens.actionFill);
      expect(tester.getSemantics(checkbox).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(tester.getSemantics(checkbox).getSemanticsData().flagsCollection.isChecked, CheckedState.mixed);
      expect(tester.renderObject(choicePaint()), paints..line(p1: const Offset(6, 10), p2: const Offset(14, 10), strokeWidth: 2, color: tokens.onAction));
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(value, false);
      update(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(inputOpacity(tester.renderObject(choicePaint())), reduced ? closeTo(.38, .001) : inExclusiveRange(.38, 1));
      await tester.pumpAndSettle();
      expect(inputOpacity(tester.renderObject(choicePaint())), closeTo(.38, .001));
      await tester.tap(checkbox);
      expect(value, false);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  testWidgets('checkbox hover, press, keyboard focus and single row checked semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = false, calls = 0;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) => FrostCheckboxRow(
          title: 'One row',
          subtitle: 'One description',
          value: value,
          onChanged: (v) => set(() {
            value = v!;
            calls++;
          }),
        ),
      ),
    );
    final row = find.byType(FrostCheckboxRow);
    expect(tester.getSemantics(row).getSemanticsData().label, 'One row');
    expect(tester.getSemantics(row).getSemanticsData().value, 'One description');
    await tester.tap(find.text('One row'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.getSemantics(row).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await display(tester, FrostCheckbox(value: true, onChanged: (_) {}, semanticLabel: 'Focused'));
    final mark = find.byType(FrostChoiceMark);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(FrostCheckbox)));
    await tester.pumpAndSettle();
    final layer = decorations(tester, mark)[1].decoration as ShapeDecoration;
    expect(layer.color, FrostThemeTokens.of(tester.element(mark)).fillSubtle);
    final press = await tester.startGesture(tester.getCenter(find.byType(FrostCheckbox)), pointer: 7);
    await tester.pumpAndSettle();
    expect((decorations(tester, mark)[1].decoration as ShapeDecoration).color, FrostThemeTokens.of(tester.element(mark)).fillStrong);
    await press.cancel();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    final focus = find.descendant(of: mark, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null));
    expect(focus, findsOneWidget);
    final ring = tester.widget<CustomPaint>(focus).foregroundPainter!;
    final tokens = FrostThemeTokens.of(tester.element(mark));
    expect(
      (Canvas canvas) => ring.paint(canvas, const Size.square(20)),
      paints..something(
        (method, args) => method == #drawPath && (args[0] as Path).getBounds() == const Rect.fromLTWH(-3, -3, 26, 26) && (args[1] as Paint).strokeWidth == 2,
      ),
    );
    expect((Canvas canvas) => ring.paint(canvas, const Size.square(20)), paints..path(color: tokens.focus));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('a click surface without a long-press action stays pressed beyond the long-press deadline', (tester) async {
    final pressed = <bool>[];
    var calls = 0;
    await display(tester, FrostClickSurface(onTap: () => calls++, onPressedChange: pressed.add, child: const SizedBox(width: 60, height: 40)));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(FrostClickSurface)));
    await tester.pump(const Duration(milliseconds: 900));
    expect(pressed, [true]);
    expect(calls, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pressed, [true, false]);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('radio dot springs in and whole group dims once reduced=$reduced', (tester) async {
      var value = 1, enabled = true;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostPicker<int>.inline(
              options: const [
                FrostPickerOption(value: 1, label: 'First'),
                FrostPickerOption(value: 2, label: 'Second'),
              ],
              value: value,
              onChanged: enabled ? (v) => set(() => value = v) : null,
              label: 'Choice',
            );
          },
        ),
        reduced: reduced,
      );
      final second = find.ancestor(of: find.text('Second'), matching: find.byType(FrostListRow));
      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final dot = choicePainter(tester, second).dot;
      expect(dot, reduced ? 1 : inExclusiveRange(0, 1));
      expect(tester.renderObject(choicePaint(second)), paints..circle(radius: 4 * dot, color: FrostThemeTokens.of(tester.element(second)).onAction));
      await tester.pumpAndSettle();
      expect(choicePainter(tester, second).dot, 1);
      update(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(inputOpacity(tester.renderObject(choicePaint(second))), reduced ? closeTo(.38, .001) : inExclusiveRange(.38, 1));
      await tester.pumpAndSettle();
      expect(inputOpacity(tester.renderObject(choicePaint(second))), closeTo(.38, .001));
      await tester.tap(find.text('First'), warnIfMissed: false);
      expect(value, 2);
      expect(tester.takeException(), isNull);
    });
  }
  for (final direction in TextDirection.values) {
    testWidgets('radio group one Tab stop, wrap, skip disabled and direction $direction', (tester) async {
      final semantics = tester.ensureSemantics();
      var value = 2;
      final changes = <int>[];
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostButton(label: 'Before', onPressed: () {}),
              FrostPicker<int>.inline(
                options: const [
                  FrostPickerOption(value: 0, label: 'Zero'),
                  FrostPickerOption(value: 1, label: 'Disabled', enabled: false),
                  FrostPickerOption(value: 2, label: 'Two'),
                ],
                value: value,
                onChanged: (v) => set(() {
                  value = v;
                  changes.add(v);
                }),
                label: 'Choice',
              ),
              FrostButton(label: 'After', onPressed: () {}),
            ],
          ),
        ),
        direction: direction,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<FrostListRow>()!.title, 'Two');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<FrostListRow>(), isNull);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(value, 0);
      await tester.sendKeyEvent(direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(changes, [0, 2]);
      final node = tester.getSemantics(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Two' && w.properties.inMutuallyExclusiveGroup == true),
      );
      expect(node.getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
      expect(node.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup, true);
      final disabledRow = find.ancestor(of: find.text('Disabled'), matching: find.byType(FrostListRow));
      expect(inputOpacity(tester.renderObject(choicePaint(disabledRow))), closeTo(.38, .001));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  testWidgets('radio rows inherit section corners and exact text separators between surrounding rows', (tester) async {
    await display(
      tester,
      FrostGroupedSection(
        children: [
          FrostListRow(title: 'Before row', onPressed: () {}),
          FrostPicker<int>.inline(
            options: const [
              FrostPickerOption(value: 1, label: 'Radio first'),
              FrostPickerOption(value: 2, label: 'Radio last'),
            ],
            value: 1,
            onChanged: (_) {},
            label: 'Choice',
          ),
          FrostListRow(title: 'After row', onPressed: () {}),
        ],
      ),
      width: 400,
    );
    expect(find.byType(FrostSurface), findsOneWidget);
    expect(find.byType(FrostDivider), findsNWidgets(3));
    expect(rowCorners(tester, 'Before row').topLeft.x, FrostRadius.xl);
    expect(rowCorners(tester, 'Radio first'), BorderRadius.zero);
    expect(rowCorners(tester, 'Radio last'), BorderRadius.zero);
    expect(rowCorners(tester, 'After row').bottomLeft.x, FrostRadius.xl);
    final lastText = tester.getRect(find.text('Radio last'));
    final bottomDivider = find.byType(FrostDivider).last;
    final render = tester.renderObject<RenderBox>(bottomDivider), origin = render.localToGlobal(Offset.zero);
    final inset = lastText.left - origin.dx;
    expect(render, paints..line(p1: Offset(inset, .5), p2: Offset(render.size.width, .5), strokeWidth: 0));
    expect(tester.getSize(rowSurface('Radio first')).height, 40);
    expect(tester.takeException(), isNull);
  });
}
