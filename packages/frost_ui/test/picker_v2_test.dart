import 'dart:io';
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_control_surfaces.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'display_badges_v2_test.dart' show display;
import 'selection_input_v2_test.dart' show inputOpacity;

const options = [FrostPickerOption(value: 0, label: 'First'), FrostPickerOption(value: 1, label: 'Second')];
const colors = [
  FrostPickerOption(value: 0, label: 'Bright', color: Color(0xffffeeaa)),
  FrostPickerOption(value: 1, label: 'Unavailable', color: Color(0xffcccccc), enabled: false),
  FrostPickerOption(value: 2, label: 'Dark', color: Color(0xff223344)),
];

Finder liveTrack() => find.byType(FrostControlTrack).hitTestable();
Finder field() => find.byType(FrostButtonControl).hitTestable();

void main() {
  testWidgets('auto resolves palettes, segments, subtitles and excess choices on the cold frame', (tester) async {
    for (final (items, palette, menu) in [
      (colors, true, false),
      (options, false, false),
      ([const FrostPickerOption(value: 0, label: 'First', subtitle: 'Detail')], false, true),
      ([for (var i = 0; i < 5; i++) FrostPickerOption(value: i, label: 'Value $i')], false, true),
    ]) {
      await display(tester, FrostPicker(options: items, value: 0, onChanged: (_) {}, label: 'Mode'));
      expect(field(), menu ? findsOneWidget : findsNothing);
      expect(liveTrack(), !palette && !menu ? findsOneWidget : findsNothing);
      if (palette) expect(tester.getSize(find.bySemanticsLabel('Bright')), const Size.square(24));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('auto measures real segment widths once, switches with a snapshot and restores', (tester) async {
    final width = ValueNotifier(400.0);
    addTearDown(width.dispose);
    await display(
      tester,
      ValueListenableBuilder(
        valueListenable: width,
        builder: (_, w, _) => SizedBox(
          width: w,
          child: FrostPicker(options: options, value: 0, onChanged: (_) {}, label: 'Mode'),
        ),
      ),
      width: 500,
    );
    expect(liveTrack(), findsOneWidget);
    width.value = 80;
    await tester.pump();
    expect(field(), findsOneWidget);
    expect(liveTrack(), findsNothing);
    final outgoing = find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_OutgoingFramePainter');
    final painter = tester.widget<CustomPaint>(outgoing.first).foregroundPainter!;
    expect((Canvas canvas) => painter.paint(canvas, tester.getSize(outgoing.first)), paintsExactlyCountTimes(#drawImageRect, 1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.widgetList<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).any((w) => w.opacity.value > 0 && w.opacity.value < 1),
      true,
    );
    await tester.pumpAndSettle();
    width.value = 400;
    await tester.pump();
    expect(liveTrack(), findsOneWidget);
    expect(field(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cold narrow auto and auto in ListRow use menu, including colored options', (tester) async {
    await display(tester, FrostPicker(options: options, value: 0, onChanged: (_) {}, label: 'Mode'), width: 70);
    expect(field(), findsOneWidget);
    await display(
      tester,
      FrostListRow(
        title: 'Setting',
        trailing: FrostPicker(options: colors, value: 0, onChanged: (_) {}, label: 'Mode'),
      ),
    );
    expect(field(), findsOneWidget);
    expect(liveTrack(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty auto is a disabled menu and unmatched segments fade their thumb away', (tester) async {
    await display(tester, FrostPicker<int>(options: const [], value: null, onChanged: (_) {}, label: 'Empty'));
    expect(tester.widget<FrostButtonControl>(field()).onPressed, isNull);
    var value = 0;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return FrostPicker.segmented(options: options, value: value, onChanged: (_) {}, label: 'Mode');
        },
      ),
    );
    Finder thumb() => find
        .descendant(
          of: liveTrack(),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is ShapeDecoration && (w.decoration as ShapeDecoration).shadows?.isNotEmpty == true,
          ),
        )
        .first;
    final before = tester.getRect(thumb());
    update(() => value = 99);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getRect(thumb()), before);
    expect(inputOpacity(tester.renderObject(thumb())), allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(inputOpacity(tester.renderObject(thumb())), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nullable option matches null and duplicate/iconOnly/palette contracts assert', (tester) async {
    await display(
      tester,
      FrostPicker<String?>.segmented(
        options: const [
          FrostPickerOption(value: null, label: 'None'),
          FrostPickerOption(value: 'x', label: 'Present'),
        ],
        value: null,
        onChanged: (_) {},
        label: 'Nullable',
      ),
    );
    expect(tester.getSemantics(find.text('None')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    for (final picker in [
      FrostPicker(
        options: const [
          FrostPickerOption(value: 0, label: 'A'),
          FrostPickerOption(value: 0, label: 'B'),
        ],
        value: 0,
        onChanged: (_) {},
        label: 'Duplicate',
      ),
      FrostPicker.segmented(options: options, value: 0, onChanged: (_) {}, label: 'Icons', iconOnly: true),
      FrostPicker.palette(options: options, value: 0, onChanged: (_) {}, label: 'Colors'),
    ]) {
      await display(tester, picker);
      expect(tester.takeException(), isAssertionError);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('palette geometry, exact ring and contrast in $brightness', (tester) async {
      await display(
        tester,
        FrostPicker.palette(options: colors, value: 0, onChanged: (_) {}, label: 'Palette'),
        brightness: brightness,
      );
      final bright = find.bySemanticsLabel('Bright'), dark = find.bySemanticsLabel('Dark');
      expect(tester.getSize(bright), const Size.square(24));
      expect(tester.getTopLeft(dark).dx - tester.getTopLeft(bright).dx, 64);
      final icon = tester.widget<FrostIcon>(find.descendant(of: bright, matching: find.byType(FrostIcon)));
      final context = tester.element(bright), tokens = FrostThemeTokens.of(context);
      final darkInk = FrostScope.configOf(context).palettes.palette(Brightness.light, tokens.tone, tokens.accent).textPrimary;
      expect(icon.size, 18);
      expect(icon.color, darkInk);
      expect(tester.widget<FrostIcon>(find.descendant(of: dark, matching: find.byType(FrostIcon))).color, Colors.white);
      final ring = tester.widget<CustomPaint>(
        find.descendant(
          of: bright,
          matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_SwatchRingPainter'),
        ),
      );
      expect(
        (Canvas canvas) => ring.foregroundPainter!.paint(canvas, const Size.square(24)),
        paints..circle(x: 12, y: 12, radius: 15, strokeWidth: 2, style: PaintingStyle.stroke, color: colors.first.color),
      );
      final data = tester.getSemantics(bright).getSemanticsData();
      expect(data.flagsCollection.isButton, true);
      expect(data.flagsCollection.isChecked, CheckedState.isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, true);
      expect(inputOpacity(tester.renderObject(find.descendant(of: find.bySemanticsLabel('Unavailable'), matching: find.byType(FrostClickSurface)))), .38);
    });
  }

  testWidgets('palette hover springs to 1.08, selection crossfades and disabled choices never invoke', (tester) async {
    var value = 0, calls = 0;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, update) => FrostPicker.palette(
          options: colors,
          value: value,
          label: 'Palette',
          onChanged: (v) => update(() {
            value = v;
            calls++;
          }),
        ),
      ),
    );
    final bright = find.bySemanticsLabel('Bright'), dark = find.bySemanticsLabel('Dark');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(bright));
    await tester.pumpAndSettle();
    final transform = find.descendant(of: bright, matching: find.byType(Transform)).first;
    expect(tester.widget<Transform>(transform).transform.storage[0], closeTo(1.08, .001));
    await tester.tap(find.bySemanticsLabel('Unavailable'), warnIfMissed: false);
    expect(calls, 0);
    await tester.tap(dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final check = find.descendant(of: dark, matching: find.byType(FrostIcon));
    expect(inputOpacity(tester.renderObject(check)), allOf(greaterThan(0), lessThan(1)));
    expect(tester.widget<ScaleTransition>(find.ancestor(of: check, matching: find.byType(ScaleTransition)).first).scale.value, 1);
    await tester.pumpAndSettle();
    expect(value, 2);
    expect(calls, 1);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets('palette has one Tab stop and skips disabled choices with mirrored arrows $direction', (tester) async {
      var value = 0;
      final after = FocusNode();
      await display(
        tester,
        StatefulBuilder(
          builder: (_, update) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostPicker.palette(options: colors, value: value, label: 'Palette', onChanged: (v) => update(() => value = v)),
              FrostButtonControl(label: 'After', focusNode: after, onPressed: () {}),
            ],
          ),
        ),
        direction: direction,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(value, 2);
      await tester.sendKeyEvent(direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(value, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasFocus, true);
      await tester.pumpWidget(const SizedBox());
      after.dispose();
    });
  }

  test('D1 retired classes are absent from library source and exports', () {
    final retired = RegExp(r'\bFrost(Select|SegmentedButton|RadioGroup|ValueMenuButton|SelectItem|Segment|RadioItem|ToolbarChoice)\b');
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(retired.hasMatch(file.readAsStringSync()), false, reason: file.path);
    }
  });
}
