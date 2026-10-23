import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';

import 'dialog_sheet_v2_test.dart' show launch;
import 'display_badges_v2_test.dart' show display;
import 'picker_v2_test.dart' show options, colors;

void main() {
  test('unattached controller returns a failed Future', () async {
    final controller = FrostFormController();
    await expectLater(controller.submit(), throwsStateError);
    controller.dispose();
  });

  testWidgets('one controller cannot bind two forms', (tester) async {
    final controller = FrostFormController();
    var duplicate = false;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, state) {
          update = state;
          return Column(
            children: [
              SizedBox(
                height: 40,
                child: FrostForm(controller: duplicate ? controller : null, onSubmit: () => true, children: const []),
              ),
              FrostForm(controller: controller, onSubmit: () => true, children: const []),
            ],
          );
        },
      ),
    );
    update(() => duplicate = true);
    await tester.pump();
    expect(tester.takeException(), isStateError);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('cold frame next/done follows fields across sections and Enter submits only the last', (tester) async {
    var calls = 0;
    await display(
      tester,
      FrostForm(
        onSubmit: () {
          calls++;
          return true;
        },
        children: const [
          FrostFormSection(
            title: 'First section',
            children: [
              FrostTextField(label: 'One'),
              FrostTextField(enabled: false, label: 'Disabled'),
            ],
          ),
          FrostFormSection(
            title: 'Second section',
            children: [
              FrostTextField.secure(label: 'Password'),
              FrostTextField(label: 'Last'),
            ],
          ),
        ],
      ),
    );
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].textInputAction, TextInputAction.next);
    expect(fields[2].textInputAction, TextInputAction.next);
    expect(fields[3].textInputAction, TextInputAction.done);
    fields[0].focusNode!.requestFocus();
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(fields[2].focusNode!.hasFocus, true);
    expect(calls, 0);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(fields[3].focusNode!.hasFocus, true);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit actions are preserved and TextArea/TokenField inherit registration', (tester) async {
    var calls = 0;
    final token = FrostTokenEditingController();
    await display(
      tester,
      FrostForm(
        onSubmit: () {
          calls++;
          return true;
        },
        children: [
          const FrostTextField(label: 'Explicit', textInputAction: TextInputAction.search),
          const FrostTextArea(label: 'Notes'),
          FrostTokenField(controller: token, label: 'Tags'),
        ],
      ),
    );
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].textInputAction, TextInputAction.search);
    expect(fields[1].textInputAction, TextInputAction.newline);
    expect(fields[2].textInputAction, TextInputAction.done);
    await tester.enterText(find.byType(TextField).at(1), 'Line one\nLine two');
    expect(fields[1].controller!.text, 'Line one\nLine two');
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    token.dispose();
  });

  testWidgets('failure waits for app errors then focuses first error and scrolls it into view', (tester) async {
    final controller = FrostFormController(), first = FocusNode(), second = FocusNode(), scroll = ScrollController();
    var invalid = false;
    await display(
      tester,
      SizedBox(
        height: 200,
        child: SingleChildScrollView(
          controller: scroll,
          child: StatefulBuilder(
            builder: (_, update) => FrostForm(
              controller: controller,
              onSubmit: () {
                update(() => invalid = true);
                return false;
              },
              children: [
                const SizedBox(height: 400),
                FrostTextField(label: 'First', focusNode: first, error: invalid ? 'First error' : null),
                FrostTextField(label: 'Second', focusNode: second, error: invalid ? 'Second error' : null),
              ],
            ),
          ),
        ),
      ),
    );
    final pending = controller.submit();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(await pending, false);
    expect(first.hasPrimaryFocus, true);
    expect(second.hasFocus, false);
    expect(scroll.offset, greaterThan(0));
    expect(tester.getRect(find.byType(FrostTextField).first).top, greaterThanOrEqualTo(tester.getRect(find.byType(SingleChildScrollView)).top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    first.dispose();
    second.dispose();
    scroll.dispose();
  });

  for (final style in [FrostPickerStyle.menu, FrostPickerStyle.segmented, FrostPickerStyle.inline, FrostPickerStyle.palette]) {
    testWidgets('Picker $style error keeps its style and focuses its Tab target on failure', (tester) async {
      final controller = FrostFormController();
      var invalid = false;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, update) => FrostForm(
            controller: controller,
            onSubmit: () {
              update(() => invalid = true);
              return false;
            },
            children: [
              FrostPicker(
                style: style,
                options: style == FrostPickerStyle.palette ? colors : options,
                value: 0,
                onChanged: (_) {},
                label: 'Mode',
                error: invalid ? 'Choose a value' : null,
              ),
              const FrostTextField(label: 'After'),
            ],
          ),
        ),
      );
      final pending = controller.submit();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(await pending, false);
      expect(find.text('Choose a value'), findsOneWidget);
      expect(tester.widget<FrostPicker<int>>(find.byType(FrostPicker<int>)).style, style);
      final primary = FocusManager.instance.primaryFocus!.context!;
      expect(primary.findAncestorWidgetOfExactType<FrostPicker<int>>(), isNotNull);
      final error = tester.widget<Text>(find.text('Choose a value'));
      expect(
        DefaultTextStyle.of(tester.element(find.text('Choose a value'))).style.color,
        FrostThemeTokens.of(tester.element(find.text('Choose a value'))).negativeInk,
      );
      expect(error.maxLines, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('NumberField app error replaces help and can be the first error target', (tester) async {
    final controller = FrostFormController();
    await display(
      tester,
      FrostForm(
        controller: controller,
        onSubmit: () => false,
        children: [FrostNumberField(value: 1, onChanged: (_) {}, label: 'Number', help: 'Help', error: 'Invalid number')],
      ),
    );
    expect(find.text('Help'), findsNothing);
    expect(find.text('Invalid number'), findsOneWidget);
    final pending = controller.submit();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(await pending, false);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, true);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('auto keeps cold next/done correct and error changes keep its fitted style', (tester) async {
    var invalid = false;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, state) {
          update = state;
          return FrostForm(
            onSubmit: () => true,
            children: [
              const FrostTextField(label: 'Before'),
              FrostPicker(options: options, value: 0, onChanged: (_) {}, label: 'Mode', error: invalid ? 'Error' : null),
            ],
          );
        },
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).textInputAction, TextInputAction.next);
    final original = tester.getSize(find.byType(FrostPicker<int>)).height;
    update(() => invalid = true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Error'), findsOneWidget);
    expect(find.byType(FrostButtonControl), findsNothing);
    expect(tester.getSize(find.byType(FrostPicker<int>)).height, greaterThan(original));
    update(() => invalid = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(find.byType(FrostPicker<int>)).height, greaterThan(original));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostPicker<int>)).height, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate submission shares the same Future and exceptions propagate unchanged', (tester) async {
    final controller = FrostFormController(), result = Completer<bool>();
    var calls = 0;
    await display(
      tester,
      FrostForm(
        controller: controller,
        children: const [],
        onSubmit: () {
          calls++;
          return result.future;
        },
      ),
    );
    final a = controller.submit(), b = controller.submit();
    expect(identical(a, b), true);
    expect(calls, 1);
    result.complete(true);
    expect(await a, true);
    final error = StateError('App error');
    await display(tester, FrostForm(controller: controller, children: const [], onSubmit: () => throw error));
    await expectLater(controller.submit(), throwsA(same(error)));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('error summary expands and collapses, section and field gaps are exact', (tester) async {
    var invalid = false;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, state) {
          update = state;
          return FrostForm(
            errorSummary: invalid ? 'Fix the fields' : null,
            onSubmit: () => true,
            children: const [
              FrostFormSection(
                title: 'Details',
                children: [
                  FrostTextField(label: 'One'),
                  FrostTextField(label: 'Two'),
                ],
              ),
              FrostFormSection(
                title: 'Other',
                children: [FrostTextField(label: 'Three')],
              ),
            ],
          );
        },
      ),
    );
    final fields = find.byType(FrostTextField);
    expect(tester.getTopLeft(fields.at(1)).dy - tester.getBottomLeft(fields.at(0)).dy, 12);
    expect(tester.getTopLeft(find.text('Other')).dy - tester.getBottomLeft(fields.at(1)).dy, 24);
    expect(tester.getTopLeft(fields.at(0)).dy - tester.getBottomLeft(find.text('Details')).dy, 8);
    final height = tester.getSize(find.byType(FrostForm)).height;
    update(() => invalid = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getSize(find.byType(FrostForm)).height;
    await tester.pumpAndSettle();
    expect(middle, allOf(greaterThan(height), lessThan(tester.getSize(find.byType(FrostForm)).height)));
    expect(tester.widget<FrostInlineBanner>(find.byType(FrostInlineBanner)).tone, FrostBannerTone.negative);
    update(() => invalid = false);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostForm)).height, height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending numeric correction flushes before onSubmit and never fires late', (tester) async {
    final controller = FrostFormController();
    num value = 2, submitted = -1;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, update) => FrostForm(
          controller: controller,
          onSubmit: () {
            submitted = value;
            return true;
          },
          children: [FrostNumberField(value: value, max: 10, onChanged: (v) => update(() => value = v))],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '99');
    final editor = tester.widget<TextField>(find.byType(TextField));
    editor.onEditingComplete!();
    final pending = controller.submit();
    await tester.pump();
    expect(await pending, true);
    expect(submitted, 10);
    expect(editor.controller!.text, '10');
    await tester.pump(const Duration(milliseconds: 400));
    expect(value, 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('composing submission waits, shares its Future and normalizes only after composition ends', (tester) async {
    final controller = FrostFormController();
    num value = 1, submitted = -1;
    var calls = 0;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, update) => FrostForm(
          controller: controller,
          onSubmit: () {
            submitted = value;
            calls++;
            return true;
          },
          children: [FrostNumberField(value: value, max: 10, onChanged: (v) => update(() => value = v))],
        ),
      ),
    );
    final editing = tester.widget<TextField>(find.byType(TextField)).controller!;
    editing.value = const TextEditingValue(text: '99', selection: TextSelection.collapsed(offset: 2), composing: TextRange(start: 0, end: 2));
    final a = controller.submit(), b = controller.submit();
    expect(identical(a, b), true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 0);
    expect(editing.text, '99');
    expect(editing.value.composing, const TextRange(start: 0, end: 2));
    editing.value = editing.value.copyWith(composing: TextRange.empty);
    await tester.pump();
    expect(await a, true);
    expect(calls, 1);
    expect(submitted, 10);
    expect(editing.text, '10');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('unmount while composing cancels submission and unmount after false never moves focus', (tester) async {
    final controller = FrostFormController();
    var calls = 0;
    await display(
      tester,
      FrostForm(
        controller: controller,
        onSubmit: () {
          calls++;
          return true;
        },
        children: [FrostNumberField(value: 1, onChanged: (_) {})],
      ),
    );
    tester.widget<TextField>(find.byType(TextField)).controller!.value = const TextEditingValue(text: '2', composing: TextRange(start: 0, end: 1));
    final pending = controller.submit();
    await tester.pumpWidget(const SizedBox());
    expect(await pending, false);
    expect(calls, 0);
    final result = Completer<bool>();
    await display(
      tester,
      FrostForm(
        controller: controller,
        onSubmit: () => result.future,
        children: const [FrostTextField(error: 'Error')],
      ),
    );
    final second = controller.submit();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    result.complete(false);
    expect(await second, false);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('dialog action can directly return controller.submit and false keeps the dialog open', (tester) async {
    final controller = FrostFormController();
    var accepted = false;
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Form',
          content: FrostForm(
            controller: controller,
            children: const [FrostTextField(label: 'Name')],
            onSubmit: () => accepted,
          ),
          actions: [FrostDialogAction(label: 'Save', isDefault: true, onPressed: () => controller.submit())],
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostDialog), findsOneWidget);
    expect(tester.widget<FrostButtonControl>(find.ancestor(of: find.text('Save'), matching: find.byType(FrostButtonControl))).loading, false);
    accepted = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostDialog), findsNothing);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
