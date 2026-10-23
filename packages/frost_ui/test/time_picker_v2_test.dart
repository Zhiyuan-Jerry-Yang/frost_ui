import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';

import 'calendar_date_v2_test.dart' show calendarApp;
import 'calendar_test_localizations.dart';

Finder segment(String name) => find.byKey(ValueKey(name));
Finder editor(String name) => find.descendant(of: segment(name), matching: find.byType(TextField));
FocusNode focus(WidgetTester tester, String name) => name == 'period'
    ? tester.widget<Focus>(find.descendant(of: segment(name), matching: find.byType(Focus)).first).focusNode!
    : tester.widget<TextField>(editor(name)).focusNode!;
String text(WidgetTester tester, String name) => tester.widget<TextField>(editor(name)).controller!.text;
Future<void> app(WidgetTester tester, Widget child, {bool twentyFour = false, Locale? locale, double scale = 1, double width = 350, bool rtl = false}) =>
    calendarApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: twentyFour),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
      locale: locale,
      scale: scale,
    );
Future<void> key(WidgetTester tester, LogicalKeyboardKey value) async {
  await tester.sendKeyEvent(value);
  await tester.pumpAndSettle();
}

void main() {
  for (final rtl in [false, true]) {
    testWidgets('one-digit hour hugs the separator at first frame rtl=$rtl', (tester) async {
      double edge() {
        final state = tester.state<EditableTextState>(find.descendant(of: segment('hour'), matching: find.byType(EditableText)));
        final box = state.renderEditable.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: state.textEditingValue.text.length)).single;
        expect(state.renderEditable.offset.pixels, 0);
        return state.renderEditable.localToGlobal(Offset(rtl ? box.left : box.right, 0)).dx;
      }

      await app(
        tester,
        FrostTimePicker(value: const TimeOfDay(hour: 2, minute: 20), onChanged: (_) {}, label: 'Time'),
        rtl: rtl,
      );
      expect(text(tester, 'hour'), '2');
      final one = edge();
      await app(
        tester,
        FrostTimePicker(value: const TimeOfDay(hour: 11, minute: 20), onChanged: (_) {}, label: 'Time'),
        rtl: rtl,
      );
      expect(edge(), closeTo(one, .01));
      expect(text(tester, 'hour'), '11');
    });
  }

  testWidgets('time segments do not restore the enclosing page scroll offset', (tester) async {
    final bucket = PageStorageBucket();
    late BuildContext pageContext;
    Widget page(Widget child) => PageStorage(
      bucket: bucket,
      child: Container(
        key: const PageStorageKey('fields page'),
        child: Builder(
          builder: (context) {
            pageContext = context;
            return child;
          },
        ),
      ),
    );
    await app(tester, page(const SizedBox()));
    bucket.writeState(pageContext, 600.0);
    await app(tester, page(FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 20), onChanged: (_) {}, label: 'Time')));
    for (final name in ['hour', 'minute']) {
      final state = tester.state<EditableTextState>(find.descendant(of: segment(name), matching: find.byType(EditableText)));
      expect(state.renderEditable.offset.pixels, 0);
      final boxes = state.renderEditable.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: state.textEditingValue.text.length));
      expect(boxes.first.left, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('time digits are complete at the first frame without an entrance offset', (tester) async {
    for (final density in FrostDensity.values) {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(const SizedBox());
        await calendarApp(
          tester,
          SizedBox(
            width: 400,
            child: FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 20), onChanged: (_) {}, label: 'Time'),
          ),
          density: density,
          scale: scale,
        );
        for (final name in ['hour', 'minute']) {
          final state = tester.state<EditableTextState>(find.descendant(of: segment(name), matching: find.byType(EditableText)));
          final render = state.renderEditable;
          final value = state.textEditingValue.text;
          expect(value, name == 'hour' ? '2' : '20');
          final boxes = render.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: value.length));
          expect(boxes, isNotEmpty);
          expect(boxes.first.left, greaterThanOrEqualTo(0));
          expect(boxes.last.right, lessThanOrEqualTo(render.size.width));
          expect(render.offset.pixels, 0);
          expect(render.text!.style!.color!.a, 1);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('Both digits fit without editable scrolling at rest and focus in both densities', (tester) async {
    for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
      for (final scale in [1.0, 2.0]) {
        await calendarApp(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: SizedBox(
                width: 400,
                child: FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 20), onChanged: (_) {}, label: 'Time'),
              ),
            ),
          ),
          density: density,
          scale: scale,
        );
        final elements = ['hour', 'minute'];
        for (final name in elements) {
          for (final focused in [false, true]) {
            if (focused) {
              focus(tester, name).requestFocus();
            } else {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            await tester.pumpAndSettle();
            final state = tester.state<EditableTextState>(find.descendant(of: segment(name), matching: find.byType(EditableText)));
            final render = state.renderEditable;
            final value = state.textEditingValue.text;
            expect(value, name == 'minute' ? '20' : '14');
            final boxes = render.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: value.length));
            expect(boxes, isNotEmpty);
            for (final box in boxes) {
              expect(box.left, greaterThanOrEqualTo(-.001));
              expect(box.right, lessThanOrEqualTo(render.size.width + .001));
            }
            // RenderEditable's own intrinsic width includes the configured
            // cursor and its framework caret gap, independent of font metrics.
            expect(render.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(render.size.width + .001));
            expect((render.offset as ScrollPosition).maxScrollExtent, closeTo(0, .001));
            expect(render.offset.pixels, closeTo(0, .001));
            expect(tester.widget<TextField>(editor(name)).cursorWidth, render.cursorWidth);
          }
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('TimePicker reads 12/24 formats, AM/PM placement and system override', (tester) async {
    for (final locale in [null, const Locale('zh', 'CN'), const Locale('en', 'GB')]) {
      for (final twentyFour in [false, true]) {
        await app(
          tester,
          FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: (_) {}, label: 'Time'),
          locale: locale,
          twentyFour: twentyFour,
        );
        final is24 = twentyFour || locale?.countryCode == 'GB';
        expect(text(tester, 'hour'), is24 ? '14' : '2');
        expect(text(tester, 'minute'), '15');
        expect(segment('period'), is24 ? findsNothing : findsOneWidget);
        if (!is24) expect(tester.getTopLeft(segment('period')).dx < tester.getTopLeft(segment('hour')).dx, locale?.languageCode == 'zh');
      }
    }
  });
  testWidgets('All six Material time formats supply separator and period order', (tester) async {
    for (final format in TimeOfDayFormat.values) {
      await app(
        tester,
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            delegates: [_FormatDelegate(format)],
            child: FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: (_) {}, label: 'Time'),
          ),
        ),
      );
      final separator = format == TimeOfDayFormat.HH_dot_mm
          ? '.'
          : format == TimeOfDayFormat.frenchCanadian
          ? 'h'
          : ':';
      expect(find.text(separator), findsOneWidget);
      final twelve = format == TimeOfDayFormat.h_colon_mm_space_a || format == TimeOfDayFormat.a_space_h_colon_mm;
      expect(segment('period'), twelve ? findsOneWidget : findsNothing);
    }
  });
  testWidgets('Time frame preserves regular height and text growth in both densities', (tester) async {
    for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
      for (final scale in [1.0, 2.0]) {
        await calendarApp(
          tester,
          SizedBox(
            width: 400,
            child: FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: (_) {}, label: 'Time'),
          ),
          density: density,
          scale: scale,
        );
        final frame = tester.getSize(find.byType(FrostFieldFrame));
        final base = density == FrostDensity.compact ? 40 : 44;
        expect(frame.height, scale == 1 ? base : greaterThan(base));
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('Native numeric input auto-advances, keeps last focus, and is not step snapped', (tester) async {
    final changes = <TimeOfDay?>[];
    await app(tester, FrostTimePicker(value: null, onChanged: changes.add, label: 'Time', minuteStep: 15), twentyFour: true);
    expect(find.text('--'), findsNWidgets(2));
    await tester.enterText(editor('hour'), '2');
    await tester.pump();
    expect(focus(tester, 'hour').hasPrimaryFocus, isTrue);
    await tester.enterText(editor('hour'), '23');
    await tester.pump();
    expect(focus(tester, 'minute').hasPrimaryFocus, isTrue);
    await tester.enterText(editor('minute'), '17');
    await tester.pump();
    expect(changes.last, const TimeOfDay(hour: 23, minute: 17));
    expect(focus(tester, 'minute').hasPrimaryFocus, isTrue);
    await tester.enterText(editor('hour'), '3');
    await tester.pump();
    expect(focus(tester, 'minute').hasPrimaryFocus, isTrue);
    expect(changes.last!.hour, 3);
    await tester.enterText(editor('minute'), '6');
    await tester.pump();
    expect(changes.last!.minute, 6);
  });
  testWidgets('Each segment wraps independently; minuteStep has no hour carry', (tester) async {
    final changes = <TimeOfDay?>[];
    await app(tester, FrostTimePicker(value: const TimeOfDay(hour: 23, minute: 50), onChanged: changes.add, label: 'Time', minuteStep: 15), twentyFour: true);
    focus(tester, 'minute').requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(changes.last, const TimeOfDay(hour: 23, minute: 5));
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(changes.last, const TimeOfDay(hour: 23, minute: 50));
    focus(tester, 'hour').requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(changes.last!.hour, 0);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(changes.last!.hour, 23);
    await app(tester, FrostTimePicker(value: const TimeOfDay(hour: 11, minute: 0), onChanged: changes.add, label: 'Time'));
    focus(tester, 'hour').requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(text(tester, 'hour'), '12');
    expect(changes.last!.hour, 0);
  });
  testWidgets('Empty segments use min/max; clearing returns null and own null echo preserves partial editing', (tester) async {
    TimeOfDay? value = const TimeOfDay(hour: 14, minute: 15);
    final changes = <TimeOfDay?>[];
    await app(
      tester,
      StatefulBuilder(
        builder: (context, setState) => FrostTimePicker(
          value: value,
          label: 'Time',
          onChanged: (next) {
            changes.add(next);
            setState(() => value = next);
          },
        ),
      ),
      twentyFour: true,
    );
    focus(tester, 'minute').requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.backspace);
    expect(changes.last, isNull);
    expect(text(tester, 'hour'), '14');
    expect(text(tester, 'minute'), '');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(changes.last, const TimeOfDay(hour: 14, minute: 59));
    await key(tester, LogicalKeyboardKey.backspace);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(changes.last, const TimeOfDay(hour: 14, minute: 0));
  });
  testWidgets('Period toggles with four keys, null defaults AM/PM and digits do not edit it', (tester) async {
    final changes = <TimeOfDay?>[];
    await app(tester, FrostTimePicker(value: null, onChanged: changes.add, label: 'Time'));
    focus(tester, 'period').requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('PM'), findsOneWidget);
    expect(changes, isEmpty);
    for (final logicalKey in [LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.space, LogicalKeyboardKey.enter, LogicalKeyboardKey.arrowDown]) {
      final before = find.text('PM').evaluate().isNotEmpty;
      await key(tester, logicalKey);
      expect(find.text(before ? 'AM' : 'PM'), findsOneWidget);
    }
    await key(tester, LogicalKeyboardKey.backspace);
    expect(find.text('--'), findsNWidgets(3));
    await key(tester, LogicalKeyboardKey.space);
    expect(find.text('AM'), findsOneWidget);
    final count = changes.length;
    await key(tester, LogicalKeyboardKey.digit5);
    expect(changes, hasLength(count));
  });
  testWidgets('Left/right follow physical order including RTL and prefix period', (tester) async {
    for (final rtl in [false, true]) {
      await app(
        tester,
        FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: (_) {}, label: 'Time'),
        locale: const Locale('zh', 'CN'),
        rtl: rtl,
      );
      focus(tester, 'period').requestFocus();
      await tester.pump();
      await key(tester, rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
      expect(focus(tester, 'hour').hasPrimaryFocus, isTrue);
      await key(tester, rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
      expect(focus(tester, 'minute').hasPrimaryFocus, isTrue);
      await key(tester, rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
      expect(focus(tester, 'hour').hasPrimaryFocus, isTrue);
    }
  });
  testWidgets('Time field is one semantic node with localized value and active-segment actions', (tester) async {
    final semantics = tester.ensureSemantics();
    final changes = <TimeOfDay?>[];
    await app(tester, FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: changes.add, label: 'Time'), twentyFour: true);
    focus(tester, 'minute').requestFocus();
    await tester.pumpAndSettle();
    final finder = find.bySemanticsLabel('Time');
    expect(finder, findsOneWidget);
    final node = tester.getSemantics(finder);
    expect(node.getSemanticsData().value, '14:15');
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(changes.last, const TimeOfDay(hour: 14, minute: 16));
    final tokens = FrostThemeTokens.of(tester.element(segment('minute')));
    final decoration =
        tester.widget<DecoratedBox>(find.descendant(of: segment('minute'), matching: find.byType(DecoratedBox)).first).decoration as ShapeDecoration;
    expect(decoration.color, tokens.selectionFill);
    expect((decoration.shape as RoundedSuperellipseBorder).borderRadius, FrostRadius.borderRadius(FrostRadius.xs));
    expect(tester.widget<TextField>(editor('minute')).style!.color, tokens.selectionInk);
    semantics.dispose();
  });
  testWidgets('Narrow big-text time wraps on its first frame without clipping or scrolling', (tester) async {
    await app(tester, FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: (_) {}, label: 'Time'), width: 95, scale: 2);
    expect(tester.getTopLeft(segment('minute')).dy, greaterThan(tester.getTopLeft(segment('hour')).dy));
    expect(tester.getSize(find.byType(FrostFieldFrame)).height, greaterThan(44));
    expect(find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Composing numeric input is preserved and only commits after composition', (tester) async {
    final changes = <TimeOfDay?>[];
    await app(tester, FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 15), onChanged: changes.add, label: 'Time'), twentyFour: true);
    await tester.showKeyboard(editor('minute'));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: '37', selection: TextSelection.collapsed(offset: 2), composing: TextRange(start: 0, end: 2)),
    );
    await tester.pump();
    expect(changes, isEmpty);
    expect(tester.widget<TextField>(editor('minute')).controller!.value.composing, const TextRange(start: 0, end: 2));
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: '37', selection: TextSelection.collapsed(offset: 2)));
    await tester.pump();
    expect(changes, [const TimeOfDay(hour: 14, minute: 37)]);
  });
  testWidgets('Form targets localized visual first segment; error shares supporting text', (tester) async {
    final controller = FrostFormController();
    addTearDown(controller.dispose);
    await app(
      tester,
      FrostForm(
        controller: controller,
        onSubmit: () => false,
        children: [FrostTimePicker(value: null, onChanged: (_) {}, label: 'Time', error: 'Invalid')],
      ),
      locale: const Locale('zh', 'CN'),
    );
    final submission = controller.submit();
    await tester.pumpAndSettle();
    expect(await submission, isFalse);
    expect(focus(tester, 'period').hasPrimaryFocus, isTrue);
    expect(find.text('Invalid'), findsOneWidget);
  });
  testWidgets('External value reset replaces segments, disabled editors stay inert and minuteStep asserts', (tester) async {
    var value = const TimeOfDay(hour: 14, minute: 15);
    var enabled = true;
    late StateSetter update;
    var calls = 0;
    await app(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return FrostTimePicker(value: value, onChanged: enabled ? (_) => calls++ : null, label: 'Time');
        },
      ),
    );
    update(() => value = const TimeOfDay(hour: 7, minute: 40));
    await tester.pump();
    expect(text(tester, 'hour'), '7');
    expect(text(tester, 'minute'), '40');
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor('hour')).enabled, isFalse);
    await tester.tap(segment('period'));
    expect(calls, 0);
    expect(() => FrostTimePicker(value: null, onChanged: null, label: 'Bad', minuteStep: 0), throwsAssertionError);
    expect(() => FrostTimePicker(value: null, onChanged: null, label: 'Bad', minuteStep: 60), throwsAssertionError);
  });
}

class _FormatLocalizations extends CalendarTestLocalizations {
  const _FormatLocalizations(this.format) : super(const Locale('en', 'GB'));
  final TimeOfDayFormat format;
  bool get twelve => format == TimeOfDayFormat.h_colon_mm_space_a || format == TimeOfDayFormat.a_space_h_colon_mm;
  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) => alwaysUse24HourFormat ? TimeOfDayFormat.HH_colon_mm : format;
  @override
  String formatHour(TimeOfDay time, {bool alwaysUse24HourFormat = false}) => twelve && !alwaysUse24HourFormat
      ? '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}'
      : format == TimeOfDayFormat.H_colon_mm
      ? '${time.hour}'
      : time.hour.toString().padLeft(2, '0');
  @override
  String formatTimeOfDay(TimeOfDay time, {bool alwaysUse24HourFormat = false}) {
    final separator = format == TimeOfDayFormat.HH_dot_mm
        ? '.'
        : format == TimeOfDayFormat.frenchCanadian
        ? ' h '
        : ':';
    final text = '${formatHour(time, alwaysUse24HourFormat: alwaysUse24HourFormat)}$separator${formatMinute(time)}';
    final period = time.period == DayPeriod.am ? anteMeridiemAbbreviation : postMeridiemAbbreviation;
    return twelve && !alwaysUse24HourFormat
        ? format == TimeOfDayFormat.a_space_h_colon_mm
              ? '$period $text'
              : '$text $period'
        : text;
  }
}

class _FormatDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _FormatDelegate(this.format);
  final TimeOfDayFormat format;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(_FormatLocalizations(format));
  @override
  bool shouldReload(_FormatDelegate old) => format != old.format;
}
