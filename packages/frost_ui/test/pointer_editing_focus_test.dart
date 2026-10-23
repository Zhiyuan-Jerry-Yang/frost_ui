import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('$kind actions retain editing focus and caret', (tester) async {
      final text = TextEditingController(text: 'sky '), focus = FocusNode();
      var calls = 0;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 400,
              child: TextFieldTapRegion(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrostTextField(controller: text, focusNode: focus),
                    FrostTag(
                      label: 'blue',
                      onPressed: () {
                        text.value = const TextEditingValue(text: 'sky blue ', selection: TextSelection.collapsed(offset: 9));
                        calls++;
                      },
                    ),
                    FrostButton(label: 'Act', onPressed: () => calls++),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      text.selection = const TextSelection.collapsed(offset: 2);
      tester.testTextInput.log.clear();
      for (final label in ['blue', 'Act']) {
        await tester.tap(find.text(label), kind: kind);
        await tester.pumpAndSettle();
        expect(focus.hasPrimaryFocus, isTrue);
        expect(text.selection, const TextSelection.collapsed(offset: 9));
      }
      expect(calls, 2);
      expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.hide'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      text.dispose();
      focus.dispose();
    });
  }
  testWidgets('Tab acquires button focus and keyboard activation is unchanged', (tester) async {
    var calls = 0;
    final focus = FocusNode();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostClickSurface(focusNode: focus, onTap: () => calls++, child: const Text('Act')),
        ),
      ),
    );
    await tester.tap(find.text('Act'));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });
  testWidgets('fixed search submit is disabled empty and submits without editing focus', (tester) async {
    final text = TextEditingController(), focus = FocusNode();
    final submissions = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            child: FrostSearchInput(controller: text, focusNode: focus, placeholder: 'Search', leadingIcon: true, onSubmitted: submissions.add),
          ),
        ),
      ),
    );
    final submit = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.search');
    expect(tester.widget<FrostButton>(submit).onPressed, isNull);
    text.text = 'sky blue';
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(submissions, ['sky blue']);
    expect(focus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    focus.requestFocus();
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submissions, ['sky blue', 'sky blue']);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    focus.dispose();
  });
}
