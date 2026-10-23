import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_calendar.dart';
import 'package:frost_ui/src/controls/_input_surface.dart';

import 'calendar_test_localizations.dart';
import 'support.dart';

Future<void> calendarApp(
  WidgetTester tester,
  Widget child, {
  Size viewport = const Size(1000, 850),
  double scale = 1,
  FrostDensity density = FrostDensity.compact,
  Locale? locale,
  bool reduced = false,
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget body = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduced),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) =>
            locale == null ? body : Localizations.override(context: context, locale: locale, delegates: const [CalendarTestDelegate()], child: body),
      ),
      density: density,
    ),
  );
}

Finder day(DateTime date) => find.byKey(ValueKey(date));
Finder circle(DateTime date) => find.byKey(ValueKey(('date-circle', date)));
FocusNode dayFocus(WidgetTester tester, DateTime date) =>
    tester.widget<FrostInputSurface>(find.descendant(of: day(date), matching: find.byType(FrostInputSurface))).focusNode!;
FrostCalendar calendar({
  DateTime? start,
  DateTime? end,
  DateTime? first,
  DateTime? last,
  bool range = false,
  bool dual = false,
  ValueChanged<DateTime>? onSelected,
}) => FrostCalendar(
  firstDate: first ?? DateTime(2026, 1, 1),
  lastDate: last ?? DateTime(2026, 12, 31),
  today: DateTime(2026, 10, 16),
  start: start,
  end: end,
  range: range,
  dualMonth: dual,
  onSelected: onSelected ?? (_) {},
);
Color actualColor(WidgetTester tester, Finder finder) {
  final decoration = tester.widget<DecoratedBox>(find.descendant(of: finder, matching: find.byType(DecoratedBox)).first).decoration;
  return decoration is ShapeDecoration ? decoration.color! : (decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('Calendar cells preserve squares in both densities and grow with callout', (tester) async {
    for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
      for (final scale in [1.0, 2.0]) {
        await calendarApp(
          tester,
          SizedBox(width: 800, child: calendar()),
          density: density,
          scale: scale,
        );
        final cell = tester.getSize(day(DateTime(2026, 10, 16)));
        expect(cell.width, cell.height);
        final style = FrostTypography.of(tester.element(day(DateTime(2026, 10, 16)))).style(FrostTextRole.callout);
        double line(double factor) {
          final painter = TextPainter(
            text: TextSpan(style: style),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(factor),
          )..layout();
          final height = painter.preferredLineHeight;
          painter.dispose();
          return height;
        }

        expect(cell.height, closeTo((density == FrostDensity.compact ? 40 : 44) + line(scale) - line(1), 1));
      }
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('Calendar actual paint is circle, range band, today ink and disabled ink', (tester) async {
    final semantics = tester.ensureSemantics();
    await calendarApp(
      tester,
      SizedBox(
        width: 600,
        child: calendar(start: DateTime(2026, 10, 14), end: DateTime(2026, 10, 17), range: true, first: DateTime(2026, 10, 10), last: DateTime(2026, 10, 20)),
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(day(DateTime(2026, 10, 16))));
    final selected = circle(DateTime(2026, 10, 14));
    final painted = tester.widget<DecoratedBox>(find.descendant(of: selected, matching: find.byType(DecoratedBox)).first).decoration as ShapeDecoration;
    expect(painted.shape, isA<CircleBorder>());
    expect(painted.color, tokens.actionFill);
    expect(tester.getSize(selected), const Size(36, 36));
    expect(actualColor(tester, find.byKey(ValueKey(('range-band', DateTime(2026, 10, 16))))), tokens.selectionFill);
    Text number(DateTime date) => tester.widget<Text>(find.descendant(of: day(date), matching: find.byType(Text)));
    expect(number(DateTime(2026, 10, 16)).style!.color, tokens.accentInk);
    expect(number(DateTime(2026, 10, 14)).style!.color, tokens.onAction);
    expect(number(DateTime(2026, 10, 9)).style!.color, tokens.textQuaternary);
    expect(
      tester.getSemantics(find.bySemanticsLabel(const DefaultMaterialLocalizations().formatFullDate(DateTime(2026, 10, 16)))).getSemanticsData().hint,
      'Today',
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(const DefaultMaterialLocalizations().formatFullDate(DateTime(2026, 10, 14)))).getSemanticsData().label,
      const DefaultMaterialLocalizations().formatFullDate(DateTime(2026, 10, 14)),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(const DefaultMaterialLocalizations().formatFullDate(DateTime(2026, 10, 14))))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });
  testWidgets('Controlled locales change weekday ordering and month/date labels', (tester) async {
    for (final locale in [const Locale('en', 'US'), const Locale('zh', 'CN'), const Locale('en', 'GB')]) {
      // en_US uses the framework implementation; the others are fixtures.
      await calendarApp(tester, SizedBox(width: 400, child: calendar()), locale: locale.countryCode == 'US' ? null : locale);
      final sunday = tester.getTopLeft(day(DateTime(2026, 10, 4))).dx;
      final monday = tester.getTopLeft(day(DateTime(2026, 10, 5))).dx;
      expect(monday > sunday, locale.countryCode == 'US');
      if (locale.languageCode == 'zh') expect(find.text('2026年10月'), findsOneWidget);
      if (locale.countryCode == 'GB') expect(find.text('GB October 2026'), findsOneWidget);
    }
  });
  testWidgets('Calendar first-frame dual/single/shrunk/scroll fallbacks', (tester) async {
    for (final width in [700.0, 500.0, 250.0, 50.0]) {
      await calendarApp(tester, SizedBox(width: width, child: calendar(dual: true)));
      expect(find.text('November 2026'), width >= 584 ? findsOneWidget : findsNothing);
      final cell = tester.getSize(day(DateTime(2026, 10, 16)));
      if (width == 250) expect(cell.width, closeTo(250 / 7, .01));
      if (width == 50) expect(find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Default final month keeps the wide second month, with its days disabled', (tester) async {
    await calendarApp(
      tester,
      SizedBox(
        width: 700,
        child: calendar(start: DateTime(9999, 12, 31), first: DateTime(1), last: DateTime(9999, 12, 31), range: true, dual: true),
      ),
    );
    expect(find.text('December 9999'), findsOneWidget);
    expect(find.text('January 10000'), findsOneWidget);
    expect(tester.widget<FrostInputSurface>(find.descendant(of: day(DateTime(10000, 1, 1)), matching: find.byType(FrostInputSurface))).onTap, isNull);
    expect(tester.widget<FrostButton>(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.next')).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Calendar arrows, week endpoints, month clamp and Enter keep real day focus', (tester) async {
    DateTime? picked;
    await calendarApp(
      tester,
      SizedBox(
        width: 400,
        child: calendar(start: DateTime(2026, 10, 16), onSelected: (value) => picked = value),
      ),
    );
    final moves = [
      (LogicalKeyboardKey.arrowLeft, DateTime(2026, 10, 15)),
      (LogicalKeyboardKey.arrowRight, DateTime(2026, 10, 16)),
      (LogicalKeyboardKey.arrowUp, DateTime(2026, 10, 9)),
      (LogicalKeyboardKey.arrowDown, DateTime(2026, 10, 16)),
      (LogicalKeyboardKey.home, DateTime(2026, 10, 11)),
      (LogicalKeyboardKey.end, DateTime(2026, 10, 17)),
      (LogicalKeyboardKey.pageUp, DateTime(2026, 9, 17)),
      (LogicalKeyboardKey.pageDown, DateTime(2026, 10, 17)),
    ];
    await tester.pump();
    for (final (key, target) in moves) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(dayFocus(tester, target).hasPrimaryFocus, isTrue, reason: '$key');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, DateTime(2026, 10, 17));
    dayFocus(tester, DateTime(2026, 10, 31)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(dayFocus(tester, DateTime(2026, 11, 30)).hasPrimaryFocus, isTrue);
    final focusedPaint = find.descendant(
      of: day(DateTime(2026, 11, 30)),
      matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null),
    );
    expect(focusedPaint, findsOneWidget);
  });
  testWidgets('Calendar horizontal safety fallback reveals the actual focused date', (tester) async {
    await calendarApp(tester, SizedBox(width: 50, child: calendar(start: DateTime(2026, 10, 16))));
    await tester.pumpAndSettle();
    final viewport = find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    for (final target in [DateTime(2026, 10, 16), DateTime(2026, 10, 17)]) {
      if (target.day == 17) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(dayFocus(tester, target).hasPrimaryFocus, isTrue);
      final visible = tester.getRect(viewport), cell = tester.getRect(day(target));
      expect(cell.left, greaterThanOrEqualTo(visible.left - .01));
      expect(cell.right, lessThanOrEqualTo(visible.right + .01));
    }
  });
  testWidgets('Boundaries disable navigation and days; RTL mirrors horizontal arrows', (tester) async {
    var calls = 0;
    await calendarApp(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: 400,
          child: calendar(start: DateTime(2026, 10, 16), first: DateTime(2026, 10, 15), last: DateTime(2026, 10, 17), onSelected: (_) => calls++),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(dayFocus(tester, DateTime(2026, 10, 17)).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(dayFocus(tester, DateTime(2026, 10, 17)).hasPrimaryFocus, isTrue);
    expect(tester.widget<FrostButton>(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.previous')).onPressed, isNull);
    expect(tester.widget<FrostButton>(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.next')).onPressed, isNull);
    await tester.tap(day(DateTime(2026, 10, 14)));
    expect(calls, 0);
  });
  testWidgets('Month motion slides one measured grid, reduced motion only fades', (tester) async {
    for (final reduced in [false, true]) {
      await calendarApp(tester, SizedBox(width: 400, child: calendar()), reduced: reduced);
      await tester.tap(find.text('October 2026')); // no effect; focus remains legal.
      await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final transform = tester.widget<Transform>(find.byKey(const ValueKey('calendar-month-slide'))).transform;
      expect(transform.storage[12], reduced ? 0 : greaterThan(0));
      if (!reduced) expect(transform.storage[12], lessThan(280));
      if (reduced) {
        expect(tester.widget<Opacity>(find.descendant(of: find.byType(FrostCalendar), matching: find.byType(Opacity)).last).opacity, inExclusiveRange(0, 1));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Transform>(find.byKey(const ValueKey('calendar-month-slide'))).transform.storage[12], 0);
    }
  });
  testWidgets('Hover previews the range using selectionFill without selecting', (tester) async {
    var calls = 0;
    await calendarApp(
      tester,
      SizedBox(
        width: 400,
        child: calendar(start: DateTime(2026, 10, 10), range: true, onSelected: (_) => calls++),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(day(DateTime(2026, 10, 15))));
    await tester.pumpAndSettle();
    final tokens = FrostThemeTokens.of(tester.element(day(DateTime(2026, 10, 12))));
    expect(actualColor(tester, find.byKey(ValueKey(('range-band', DateTime(2026, 10, 12))))), tokens.selectionFill);
    expect(calls, 0);
  });
  testWidgets('DatePicker uses Popover wide, fitted compact; selects midnight, cancels and clears', (tester) async {
    for (final viewport in [const Size(1000, 850), const Size(390, 800)]) {
      final changes = <DateTime?>[];
      await calendarApp(
        tester,
        FrostDateClock(
          today: DateTime(2026, 10, 16),
          child: SizedBox(
            width: 320,
            child: FrostDatePicker(value: DateTime.utc(2026, 10, 14, 19), onChanged: changes.add, label: 'Date', clearable: true),
          ),
        ),
        viewport: viewport,
      );
      await tester.tap(find.text(const DefaultMaterialLocalizations().formatMediumDate(DateTime(2026, 10, 14))));
      await tester.pumpAndSettle();
      final sheet = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet);
      expect(sheet, viewport.width < 600 ? findsOneWidget : findsNothing);
      if (viewport.width < 600) expect(tester.getSize(sheet).height, lessThan(400));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.tap(find.text(const DefaultMaterialLocalizations().formatMediumDate(DateTime(2026, 10, 14))));
      await tester.pumpAndSettle();
      await tester.tap(day(DateTime(2026, 10, 18)));
      await tester.pumpAndSettle();
      expect(changes, [DateTime(2026, 10, 18)]);
      expect(changes.single!.isUtc, isFalse);
      await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.clear'));
      await tester.pumpAndSettle();
      expect(changes.last, isNull);
    }
  });
  testWidgets('Legacy date displays but month clamps, bounds are date-only and error registers in form', (tester) async {
    final controller = FrostFormController();
    addTearDown(controller.dispose);
    await calendarApp(
      tester,
      SizedBox(
        width: 400,
        child: FrostForm(
          controller: controller,
          onSubmit: () async => false,
          children: [
            FrostDatePicker(
              value: DateTime(2025, 1, 1),
              firstDate: DateTime(2026, 10, 10, 18),
              lastDate: DateTime(2026, 10, 20, 1),
              onChanged: (_) {},
              label: 'Date',
              error: 'Invalid',
            ),
          ],
        ),
      ),
    );
    expect(find.text(const DefaultMaterialLocalizations().formatMediumDate(DateTime(2025, 1, 1))), findsOneWidget);
    final submission = controller.submit();
    await tester.pumpAndSettle();
    expect(await submission, isFalse);
    await tester.pumpAndSettle();
    final surface = tester.widget<FrostClickSurface>(find.descendant(of: find.byType(FrostDatePicker), matching: find.byType(FrostClickSurface)).first);
    expect(surface.focusNode!.hasFocus, isTrue);
    expect(find.text('Invalid'), findsOneWidget);
    await tester.tap(find.text(const DefaultMaterialLocalizations().formatMediumDate(DateTime(2025, 1, 1))));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(() => FrostDatePicker(value: null, onChanged: null, label: 'Bad', firstDate: DateTime(2026), lastDate: DateTime(2025)), throwsAssertionError);
  });
}
