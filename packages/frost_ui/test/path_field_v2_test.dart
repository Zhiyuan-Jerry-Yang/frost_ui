import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'display_badges_v2_test.dart' show display;

const path = 'V:/Pictures/very-long-directory/another-directory/🦊image.png';
Finder shownPath() => find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == path);
Finder choose() => find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.choose');
Finder reveal() => find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.showInFolder');

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('Path keeps its ends, tooltip, and cold-frame button fallback $direction', (tester) async {
      var choices = 0, reveals = 0;
      await display(
        tester,
        FrostPathField(path: path, label: 'Directory', onChoose: () async => choices++, onReveal: () => reveals++),
        width: 140,
        direction: direction,
      );
      final shown = tester.widget<Text>(shownPath()).data!;
      expect(shown, startsWith('V'));
      expect(shown, endsWith('g'));
      expect(shown, contains('…'));
      final field = tester.getRect(find.byType(FrostFieldFrame)), button = tester.getRect(choose());
      expect(button.top, greaterThanOrEqualTo(field.bottom + FrostGap.related));
      final actions = tester.getRect(find.byType(Wrap));
      expect(direction == TextDirection.ltr ? actions.right : actions.left, direction == TextDirection.ltr ? field.right : field.left);
      expect(tester.widget<FrostTooltip>(find.ancestor(of: shownPath(), matching: find.byType(FrostTooltip))).message, path);
      await tester.tap(choose());
      await tester.pump();
      expect(choices, 1);
      await tester.tap(reveal());
      expect(reveals, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('enough width keeps actions inline and an unelided short path', (tester) async {
    await display(tester, FrostPathField(path: 'V:/Images', label: 'Directory', onChoose: () async {}, onReveal: () {}), width: 700);
    final field = tester.getRect(find.byType(FrostFieldFrame)), button = tester.getRect(choose());
    expect(button.center.dy, field.center.dy);
    expect(button.left, field.right + FrostGap.related);
    expect(find.text('V:/Images'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final direction in TextDirection.values) {
    testWidgets('very narrow large-text actions wrap without clipping or changing order $direction', (tester) async {
      await display(
        tester,
        FrostPathField(path: path, label: 'Directory', onChoose: () async {}, onReveal: () {}),
        width: 120,
        scale: 2,
        direction: direction,
      );
      expect(tester.getTopLeft(reveal()).dy - tester.getBottomLeft(choose()).dy, FrostGap.related);
      expect(tester.widget<FrostButtonControl>(choose()).wrapsLabel, true);
      expect(tester.widget<FrostButtonControl>(choose()).truncates, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final node = tester.widget<FrostButtonControl>(choose()).focusNode!;
      // Selection text is also keyboard accessible; form targeting remains
      // the choose action regardless of this independent copy stop.
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<FrostButtonControl>()?.label, 'L.showInFolder');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('selection and keyboard copy return the full path, never the ellipsis', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await display(tester, FrostPathField(path: path, label: 'Directory', onChoose: () async {}), width: 200);
    final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
    area.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(clipboard, path);
    expect(tester.takeException(), isNull);
  });
  testWidgets('choose uses the existing loading gate and rejects duplicate requests', (tester) async {
    final result = Completer<void>();
    var calls = 0;
    await display(
      tester,
      FrostPathField(
        path: path,
        label: 'Directory',
        onChoose: () {
          calls++;
          return result.future;
        },
      ),
    );
    final size = tester.getSize(choose());
    await tester.tap(choose());
    await tester.pump();
    await tester.tap(choose(), warnIfMissed: false);
    expect(calls, 1);
    expect(tester.widget<FrostButtonControl>(choose()).loading, true);
    await tester.pump(const Duration(milliseconds: 301));
    expect(find.byType(FrostActivityIndicator), findsOneWidget);
    expect(tester.getSize(choose()), size);
    result.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.widget<FrostButtonControl>(choose()).loading, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('choose exceptions restore the button and unmount discards late errors', (tester) async {
    final error = StateError('App choose failure');
    await display(tester, FrostPathField(path: path, label: 'Directory', onChoose: () async => throw error));
    await tester.tap(choose());
    await tester.pump();
    expect(tester.takeException(), same(error));
    expect(tester.widget<FrostButtonControl>(choose()).loading, false);
    final result = Completer<void>();
    await display(tester, FrostPathField(path: path, label: 'Directory', onChoose: () => result.future));
    await tester.tap(choose());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    result.completeError(error);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reveal needs both path and callback, and error targets choose in a form', (tester) async {
    for (final (value, callback, visible) in [(path, () {}, true), (null, () {}, false), (path, null, false)]) {
      await display(tester, FrostPathField(path: value, label: 'Directory', onReveal: callback));
      expect(reveal(), visible ? findsOneWidget : findsNothing);
    }
    final form = FrostFormController();
    await display(
      tester,
      FrostForm(
        controller: form,
        onSubmit: () => false,
        children: [FrostPathField(path: path, label: 'Directory', help: 'Help', error: 'Error', onChoose: () async {})],
      ),
    );
    expect(find.text('Help'), findsNothing);
    expect(find.text('Error'), findsOneWidget);
    final pending = form.submit();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(await pending, false);
    expect(tester.widget<FrostButtonControl>(choose()).focusNode!.hasPrimaryFocus, true);
    await tester.pumpWidget(const SizedBox());
    form.dispose();
  });
  testWidgets('reflow has a middle frame and restores without changing callback ownership', (tester) async {
    final width = ValueNotifier(700.0);
    addTearDown(width.dispose);
    await display(
      tester,
      ValueListenableBuilder(
        valueListenable: width,
        builder: (_, w, _) => SizedBox(
          width: w,
          child: FrostPathField(path: path, label: 'Directory', onChoose: () async {}, onReveal: () {}),
        ),
      ),
      width: 750,
    );
    final initial = tester.getSize(find.byType(FrostPathField)).height;
    width.value = 140;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getSize(find.byType(FrostPathField)).height, greaterThan(initial));
    final middle = tester.getSize(find.byType(FrostPathField)).height;
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostPathField)).height, greaterThan(middle));
    width.value = 700;
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostPathField)).height, initial);
    expect(tester.takeException(), isNull);
  });
}
