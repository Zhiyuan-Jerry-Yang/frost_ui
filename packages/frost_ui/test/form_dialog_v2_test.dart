import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'dialog_sheet_v2_test.dart' show launch, action;
import 'support.dart';

void main() {
  testWidgets('forwarded close control cancels and discards an in-flight result', (tester) async {
    final pending = Completer<bool>();
    bool? result;
    await launch(tester, (context) async {
      result = await showFrostFormDialog(
        context: context,
        title: 'Form',
        sections: const [],
        submitLabel: 'Save',
        showsCloseButton: true,
        onSubmit: () => pending.future,
      );
    });
    expect(tester.widget<FrostDialog>(find.byType(FrostDialog)).showsCloseButton, true);
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(findFrostTooltip('L.close'));
    await tester.pumpAndSettle();
    expect(result, false);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(result, false);
    expect(find.byType(FrostDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('summary controller notifies only changed values and remains caller-owned', () {
    final controller = FrostFormDialogController(errorSummary: 'initial');
    var calls = 0;
    controller.addListener(() => calls++);
    controller.errorSummary = 'initial';
    expect(calls, 0);
    controller.errorSummary = 'updated';
    expect(calls, 1);
    expect(controller.errorSummary, 'updated');
    controller.errorSummary = null;
    expect(calls, 2);
    controller.dispose();
  });

  for (final method in ['button', 'enter', 'done']) {
    testWidgets('successful $method uses default action and closes true', (tester) async {
      bool? result;
      var calls = 0;
      await launch(tester, (context) async {
        result = await showFrostFormDialog(
          context: context,
          title: 'Form',
          sections: const [
            FrostFormSection(
              title: 'Section',
              children: [FrostTextField(label: 'Name')],
            ),
          ],
          submitLabel: 'Save',
          onSubmit: () {
            calls++;
            return true;
          },
        );
      });
      if (method == 'button') {
        await tester.tap(find.text('Save'));
      } else if (method == 'enter') {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      }
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(result, true);
      expect(find.byType(FrostDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed submission updates sole summary, focuses first error and animates removal', (tester) async {
    final summary = FrostFormDialogController();
    final first = FocusNode(), second = FocusNode();
    var invalid = false;
    late StateSetter fields;
    await launch(
      tester,
      (context) => showFrostFormDialog(
        context: context,
        title: 'Form',
        controller: summary,
        errorSummary: 'ignored',
        submitLabel: 'Save',
        sections: [
          StatefulBuilder(
            builder: (_, update) {
              fields = update;
              return FrostFormSection(
                children: [
                  FrostTextField(label: 'First', focusNode: first, error: invalid ? 'Required first' : null),
                  FrostTextField(label: 'Second', focusNode: second, error: invalid ? 'Required second' : null),
                ],
              );
            },
          ),
        ],
        onSubmit: () {
          fields(() => invalid = true);
          summary.errorSummary = 'Correct the fields';
          return false;
        },
      ),
    );
    expect(find.text('ignored'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostDialog), findsOneWidget);
    expect(find.text('Correct the fields'), findsOneWidget);
    expect(first.hasPrimaryFocus, isTrue);
    expect(second.hasPrimaryFocus, isFalse);
    final before = tester.getSize(find.byType(FrostForm)).height;
    summary.errorSummary = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(find.byType(FrostForm)).height, lessThan(before));
    await tester.pumpAndSettle();
    expect(find.text('Correct the fields'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    summary.errorSummary = 'after close';
    expect(summary.errorSummary, 'after close');
    summary.dispose();
    first.dispose();
    second.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final method in ['cancel', 'escape', 'barrier']) {
    testWidgets('$method returns false with shared dialog dismissal', (tester) async {
      bool? result;
      await launch(tester, (context) async {
        result = await showFrostFormDialog(context: context, title: 'Form', sections: const [], submitLabel: 'Save', onSubmit: () => true);
      });
      switch (method) {
        case 'cancel':
          await tester.tap(find.text(testLabels(tester.element(find.byType(FrostDialog))).cancel));
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();
      expect(result, false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('IME done shares busy gate, repeated Enter submits once and cancellation discards result', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    bool? result;
    await launch(tester, (context) async {
      result = await showFrostFormDialog(
        context: context,
        title: 'Form',
        sections: const [FrostTextField(label: 'Name')],
        submitLabel: 'Save',
        onSubmit: () {
          calls++;
          return pending.future;
        },
      );
    });
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 310));
    expect(action(tester, 'Save').loading, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.tap(find.text(testLabels(tester.element(find.byType(FrostDialog))).cancel));
    await tester.pumpAndSettle();
    expect(result, false);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(result, false);
    expect(find.byType(FrostDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller rejects simultaneous dialogs and can be reused after disposal of route', (tester) async {
    final controller = FrostFormDialogController();
    late BuildContext origin;
    Future<bool> open() =>
        showFrostFormDialog(context: origin, title: 'Form', controller: controller, sections: const [], submitLabel: 'Save', onSubmit: () => true);
    await launch(tester, (context) {
      origin = context;
      open();
    });
    final second = open();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isAssertionError);
    Navigator.of(origin).pop();
    await tester.pumpAndSettle();
    expect(await second, false);
    Navigator.of(origin).pop();
    await tester.pumpAndSettle();
    final third = open();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await third, true);
    controller.dispose();
  });

  testWidgets('summary setter used during a field build defers notifications safely', (tester) async {
    final controller = FrostFormDialogController();
    await launch(
      tester,
      (context) => showFrostFormDialog(
        context: context,
        title: 'Form',
        controller: controller,
        submitLabel: 'Save',
        onSubmit: () => false,
        sections: [
          Builder(
            builder: (_) {
              controller.errorSummary = 'Build discovered error';
              return const FrostTextField(label: 'Name');
            },
          ),
        ],
      ),
    );
    expect(find.text('Build discovered error'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    controller.dispose();
  });
}
