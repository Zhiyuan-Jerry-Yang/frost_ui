import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_calendar.dart';
import 'calendar_date_v2_test.dart' show calendarApp, day, actualColor;

FrostButtonControl action(WidgetTester tester, String label) =>
    tester.widget<FrostButtonControl>(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.$label'));
Future<void> open(
  WidgetTester tester, {
  DateTimeRange? value,
  ValueChanged<DateTimeRange?>? onChanged,
  DateTime? first,
  DateTime? last,
  Size viewport = const Size(1100, 850),
  double scale = 1,
}) async {
  await calendarApp(
    tester,
    FrostDateClock(
      today: DateTime(2026, 10, 16),
      child: SizedBox(
        width: 400,
        child: FrostDateRangePicker(value: value, onChanged: onChanged ?? (_) {}, label: 'Range', placeholder: 'Pick range', firstDate: first, lastDate: last),
      ),
    ),
    viewport: viewport,
    scale: scale,
  );
  final trigger = find.descendant(of: find.byType(FrostDateRangePicker), matching: find.byType(FrostButtonControl)).first;
  await tester.tap(trigger);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.tap(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.$label'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Range uses two months wide and one month in fitted, with the same footer', (tester) async {
    for (final viewport in [const Size(1100, 850), const Size(390, 800)]) {
      await open(tester, viewport: viewport);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('November 2026'), viewport.width < 600 ? findsNothing : findsOneWidget);
      for (final name in ['clear', 'cancel', 'apply']) {
        expect(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.$name'), findsOneWidget);
      }
      final sheet = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet);
      expect(sheet, viewport.width < 600 ? findsOneWidget : findsNothing);
      if (viewport.width < 600) expect(tester.getSize(sheet).height, lessThan(500));
      expect(action(tester, 'apply').onPressed, isNotNull);
      await tap(tester, 'cancel');
    }
  });
  testWidgets('Range drafts two clicks, earlier replacement and complete-range restart until Apply', (tester) async {
    final changes = <DateTimeRange?>[];
    await open(tester, onChanged: changes.add);
    await tester.tap(day(DateTime(2026, 10, 15)));
    await tester.pump();
    expect(action(tester, 'apply').onPressed, isNull);
    expect(changes, isEmpty);
    await tester.tap(day(DateTime(2026, 10, 10)));
    await tester.pump();
    final calendar = tester.widget<FrostCalendar>(find.byType(FrostCalendar));
    expect(calendar.start, DateTime(2026, 10, 10));
    expect(calendar.end, isNull);
    await tester.tap(day(DateTime(2026, 10, 20)));
    await tester.pump();
    expect(action(tester, 'apply').onPressed, isNotNull);
    await tester.tap(day(DateTime(2026, 10, 22)));
    await tester.pump();
    expect(tester.widget<FrostCalendar>(find.byType(FrostCalendar)).end, isNull);
    expect(action(tester, 'apply').onPressed, isNull);
    await tester.tap(day(DateTime(2026, 10, 25)));
    await tester.pump();
    await tap(tester, 'apply');
    expect(changes, [DateTimeRange(start: DateTime(2026, 10, 22), end: DateTime(2026, 10, 25))]);
    expect(find.byType(FrostCalendar), findsNothing);
  });
  testWidgets('Range Cancel, Esc and outside click discard draft; Clear only applies on Apply', (tester) async {
    final changes = <DateTimeRange?>[];
    final value = DateTimeRange(start: DateTime(2026, 10, 10), end: DateTime(2026, 10, 15));
    for (final how in ['cancel', 'escape', 'outside']) {
      await open(tester, value: value, onChanged: changes.add);
      await tester.tap(day(DateTime(2026, 10, 20)));
      await tester.pump();
      if (how == 'cancel') {
        await tap(tester, 'cancel');
      } else if (how == 'escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      } else {
        await tester.tapAt(const Offset(1000, 750));
        await tester.pumpAndSettle();
      }
      expect(changes, isEmpty);
      expect(find.byType(FrostCalendar), findsNothing);
    }
    await open(tester, value: value, onChanged: changes.add);
    await tap(tester, 'clear');
    expect(changes, isEmpty);
    expect(action(tester, 'apply').onPressed, isNotNull);
    expect(tester.widget<FrostCalendar>(find.byType(FrostCalendar)).start, isNull);
    await tap(tester, 'apply');
    expect(changes, [null]);
    changes.clear();
    await open(tester, onChanged: changes.add);
    await tap(tester, 'apply');
    expect(changes, [null]);
  });
  testWidgets('Legacy out-of-bounds range displays, retains invalid draft and can clear or replace safely', (tester) async {
    final changes = <DateTimeRange?>[];
    final old = DateTimeRange(start: DateTime.utc(2025, 1, 1, 18), end: DateTime.utc(2025, 2, 2, 19));
    await open(tester, value: old, first: DateTime(2026, 10, 10, 18), last: DateTime(2026, 10, 20, 1), onChanged: changes.add);
    const localizations = DefaultMaterialLocalizations();
    expect(find.text('${localizations.formatMediumDate(old.start)} – ${localizations.formatMediumDate(old.end)}'), findsOneWidget);
    final calendar = tester.widget<FrostCalendar>(find.byType(FrostCalendar));
    expect(calendar.start, DateTime(2025, 1, 1));
    expect(calendar.end, DateTime(2025, 2, 2));
    expect(find.text('October 2026'), findsOneWidget);
    expect(action(tester, 'apply').onPressed, isNull);
    await tester.tap(day(DateTime(2026, 10, 9)));
    await tester.pump();
    expect(action(tester, 'apply').onPressed, isNull);
    expect(changes, isEmpty);
    await tester.tap(day(DateTime(2026, 10, 10)));
    await tester.pump();
    expect(action(tester, 'apply').onPressed, isNull);
    await tester.tap(day(DateTime(2026, 10, 20)));
    await tester.pump();
    await tap(tester, 'apply');
    expect(changes, [DateTimeRange(start: DateTime(2026, 10, 10), end: DateTime(2026, 10, 20))]);
    await open(tester, value: old, first: DateTime(2026), last: DateTime(2026, 12, 31), onChanged: changes.add);
    expect(action(tester, 'apply').onPressed, isNull);
    await tap(tester, 'clear');
    await tap(tester, 'apply');
    expect(changes.last, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Range hover previews actual band but never commits; responsive width falls back on cold layout', (tester) async {
    final changes = <DateTimeRange?>[];
    await open(tester, onChanged: changes.add, viewport: const Size(650, 800));
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(day(DateTime(2026, 10, 10)));
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(day(DateTime(2026, 10, 16))));
    await tester.pumpAndSettle();
    final tokens = FrostThemeTokens.of(tester.element(day(DateTime(2026, 10, 12))));
    expect(actualColor(tester, find.byKey(ValueKey(('range-band', DateTime(2026, 10, 12))))), tokens.selectionFill);
    expect(changes, isEmpty);
    expect(action(tester, 'apply').onPressed, isNull);
    await tap(tester, 'cancel');
    await open(tester, viewport: const Size(610, 800));
    expect(find.text('November 2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Range Form registers error on trigger and D4 nullable/boundary API stays safe', (tester) async {
    final controller = FrostFormController();
    addTearDown(controller.dispose);
    await calendarApp(
      tester,
      SizedBox(
        width: 400,
        child: FrostForm(
          controller: controller,
          onSubmit: () => false,
          children: [FrostDateRangePicker(value: null, onChanged: (_) {}, label: 'Range', error: 'Invalid')],
        ),
      ),
    );
    final pending = controller.submit();
    await tester.pumpAndSettle();
    expect(await pending, isFalse);
    final click = tester.widget<FrostClickSurface>(find.descendant(of: find.byType(FrostDateRangePicker), matching: find.byType(FrostClickSurface)).first);
    expect(click.focusNode!.hasPrimaryFocus, isTrue);
    expect(find.text('Invalid'), findsOneWidget);
    expect(
      () => FrostDateRangePicker(value: null, onChanged: null, label: 'Invalid', firstDate: DateTime(2027), lastDate: DateTime(2026)),
      throwsAssertionError,
    );
  });
  testWidgets('Disabled date field during an open panel cannot call a stale callback', (tester) async {
    var enabled = true;
    late StateSetter update;
    var calls = 0;
    await calendarApp(
      tester,
      SizedBox(
        width: 400,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return FrostDatePicker(value: DateTime(2026, 10, 16), onChanged: enabled ? (_) => calls++ : null, label: 'Date');
          },
        ),
      ),
    );
    await tester.tap(find.text(const DefaultMaterialLocalizations().formatMediumDate(DateTime(2026, 10, 16))));
    await tester.pumpAndSettle();
    update(() => enabled = false);
    await tester.pump();
    await tester.tap(day(DateTime(2026, 10, 20)));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
