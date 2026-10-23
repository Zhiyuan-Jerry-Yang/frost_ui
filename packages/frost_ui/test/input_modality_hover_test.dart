import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_row_scope.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'support.dart';

Finder hoverFeedback() => find.byWidgetPredicate((w) => w is FrostClickFeedbackVisual && w.states.contains(WidgetState.hovered));

void main() {
  for (final pointerActions in [false, true]) {
    testWidgets('touch clears a stationary mouse hover across shared rows, pointerActions=$pointerActions', (tester) async {
      final focus = FocusNode(), text = TextEditingController();
      addTearDown(focus.dispose);
      addTearDown(text.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      var calls = 0;
      await tester.pumpWidget(
        frostTestApp(
          FrostContentColumn(
            child: Column(
              children: [
                FrostTextField(controller: text, focusNode: focus),
                FrostSwipeActions(
                  showsPointerActions: pointerActions,
                  trailing: [FrostSwipeAction(label: 'Delete', icon: testIcons.delete, onPressed: () {})],
                  child: FrostListRow(title: 'History', icon: testIcons.clock, onPressed: () => calls++),
                ),
                FrostListRow(title: 'Ordinary', icon: testIcons.clock, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      final history = tester.getCenter(find.text('History'));
      await mouse.moveTo(history);
      await tester.pumpAndSettle();
      expect(hoverFeedback(), findsWidgets);
      await tester.tap(find.byType(EditableText), kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(hoverFeedback(), findsNothing, reason: 'a stationary mouse cannot keep lighting a row after touch takes over');
      expect(calls, 0);
      await tester.tap(find.text('History'), kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();
      expect(hoverFeedback(), findsNothing);
      expect(calls, 1);
      await mouse.moveTo(history + const Offset(2, 0));
      await tester.pumpAndSettle();
      expect(hoverFeedback(), findsWidgets, reason: 'real mouse movement restores hover without requiring a click');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('touch activates a visible pointer action without retaining hover', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            child: FrostSwipeActions(
              trailing: [FrostSwipeAction(label: 'Delete', icon: testIcons.delete, onPressed: () => calls++)],
              child: FrostListRow(title: 'History', onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('History')));
    await tester.pumpAndSettle();
    final action = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Delete');
    await tester.tap(action, kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(hoverFeedback(), findsNothing);
    expect(action, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('touch ends keyboard suggestion highlight; arrows explicitly start it again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostList<int>(
          items: const [1, 2],
          onSelected: (_) => calls++,
          itemBuilder: (_, item, _) => FrostListRow(title: '$item'),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    Finder highlighted() => find.byWidgetPredicate((w) => w is FrostListItemScope && w.highlighted);
    expect(highlighted(), findsOneWidget);
    await tester.tapAt(const Offset(750, 500), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(highlighted(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(highlighted(), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
