import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'support.dart';

Finder row(String name) => find.byKey(ValueKey(name));
double offset(WidgetTester tester, String name) => tester
    .widget<Transform>(find.descendant(of: row(name), matching: find.byWidgetPredicate((w) => w is Transform && w.child is ConstrainedBox)))
    .transform
    .storage[12];
Widget swipe(String name, VoidCallback pressed, {bool rtl = false, bool showsPointerActions = true, List<FrostMenuEntry> context = const []}) => Directionality(
  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
  child: FrostSwipeActions(
    key: ValueKey(name),
    showsPointerActions: showsPointerActions,
    leading: [FrostSwipeAction(label: 'Pin', icon: testIcons.add, onPressed: pressed, tone: FrostSwipeTone.accent)],
    trailing: [FrostSwipeAction(label: 'Delete', icon: testIcons.delete, onPressed: pressed, tone: FrostSwipeTone.destructive)],
    child: FrostListRow(title: name, contextMenu: context, onPressed: () {}),
  ),
);
Future<TestGesture> drag(WidgetTester tester, String name, double dx) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text(name)), kind: PointerDeviceKind.touch);
  await gesture.moveBy(Offset(dx > 0 ? 20 : -20, 0));
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump(const Duration(milliseconds: 300));
  return gesture;
}

void main() {
  testWidgets('pointer row hover and press share one surface while actions stay independent', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            child: FrostGroupedSection(
              children: [
                swipe('Row', () {}),
                const FrostListRow(title: 'Next'),
              ],
            ),
          ),
        ),
      ),
    );
    final rowSurface = find.descendant(of: find.byType(FrostListRow).first, matching: find.byType(FrostClickFeedbackVisual));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    expect(rowSurface, findsOneWidget);
    var hover = tester.widget<FrostClickFeedbackVisual>(rowSurface);
    expect(hover.states, contains(WidgetState.hovered));
    final bounds = tester.getRect(rowSurface);
    final shape = hover.shape;
    await mouse.down(tester.getCenter(find.text('Row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final press = tester.widget<FrostClickFeedbackVisual>(rowSurface);
    expect(press.states, contains(WidgetState.pressed));
    expect(press.shape, shape);
    expect(tester.getRect(rowSurface), bounds);
    final divider = find.byType(FrostDivider);
    expect(bounds.bottom, lessThanOrEqualTo(tester.getRect(divider).top));
    await mouse.cancel();
    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    final action = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Delete');
    await mouse.moveTo(tester.getCenter(action));
    await tester.pumpAndSettle();
    hover = tester.widget<FrostClickFeedbackVisual>(rowSurface);
    expect(hover.states, isNot(contains(WidgetState.hovered)));
    expect(find.ancestor(of: rowSurface, matching: find.byType(FrostClickFeedbackVisual)), findsNothing);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch follows finger and releases to action width with snappy intermediate frame', (tester) async {
    var calls = 0;
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 400, child: swipe('Row', () => calls++)))));
    final gesture = await drag(tester, 'Row', 80);
    expect(offset(tester, 'Row'), closeTo(80, .01));
    expect(calls, 0);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(offset(tester, 'Row'), inExclusiveRange(72, 80));
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), 72);
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(offset(tester, 'Row'), 0);
  });
  testWidgets('full swipe fires first action only on release; small swipe returns', (tester) async {
    var calls = 0;
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 400, child: swipe('Row', () => calls++)))));
    var gesture = await drag(tester, 'Row', -250);
    expect(calls, 0);
    await gesture.up();
    expect(calls, 1);
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), 0);
    gesture = await drag(tester, 'Row', 20);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), 0);
    expect(calls, 1);
  });
  testWidgets('only one row per view stays open', (tester) async {
    await tester.pumpWidget(frostTestApp(Column(children: [swipe('One', () {}), swipe('Two', () {})])));
    var gesture = await drag(tester, 'One', 80);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(offset(tester, 'One'), 72);
    gesture = await drag(tester, 'Two', -80);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(offset(tester, 'One'), 0);
    expect(offset(tester, 'Two'), -tester.getSize(find.ancestor(of: find.text('Delete'), matching: find.byType(FrostClickSurface)).first).width);
  });
  testWidgets('RTL leading is physically on the right', (tester) async {
    var calls = 0;
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 400, child: swipe('Row', () => calls++, rtl: true)))));
    final gesture = await drag(tester, 'Row', -80);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), -72);
    final surface = find
        .descendant(of: row('Row'), matching: find.byWidgetPredicate((w) => w is FrostClickSurface && w.borderRadius == BorderRadius.zero))
        .first;
    expect(tester.getRect(surface).right, closeTo(tester.getRect(row('Row')).right, .01));
    await tester.tap(find.text('Pin'));
    expect(calls, 1);
  });
  testWidgets('directional high velocity overrides half-width opening threshold', (tester) async {
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 400, child: swipe('Row', () {})))));
    await tester.fling(find.text('Row'), const Offset(-55, 0), 1000);
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), -tester.getSize(find.ancestor(of: find.text('Delete'), matching: find.byType(FrostClickSurface)).first).width);
    // Reverse velocity wins while displacement still exceeds half its width.
    await tester.flingFrom(tester.getCenter(row('Row')), const Offset(55, 0), 1000);
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), 0);
  });
  testWidgets('pointer ignores drag and exposes same actions on hover and merged context menu', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            child: swipe('Row', () => calls++, context: [FrostMenuAction('Own action', onSelected: () {})]),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Pin'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Delete'), findsOneWidget);
    await mouse.down(tester.getCenter(find.text('Row')));
    await mouse.moveBy(const Offset(150, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), 0);
    final region = tester.widgetList<FrostContextMenuRegion>(find.descendant(of: row('Row'), matching: find.byType(FrostContextMenuRegion))).last;
    expect(region.entries.whereType<FrostMenuAction>().map((a) => a.label), ['Own action', 'Pin', 'Delete']);
    expect(region.entries.whereType<FrostMenuAction>().last.destructive, isTrue);
    await tester.tapAt(tester.getCenter(row('Row')), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Own action'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    // Touch selection in the menu ends mouse hover; actual movement restores it.
    await mouse.moveBy(const Offset(1, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Delete'));
    expect(calls, 2);
    await mouse.removePointer();
  });
  testWidgets('large text gives actions enough height and narrow hover wraps safely', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(child: SizedBox(width: 70, child: swipe('Row', () {}))),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    final gesture = await drag(tester, 'Row', 20);
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
  });
  testWidgets('reduced motion snaps on release and empty actions preserve content', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(child: SizedBox(width: 400, child: swipe('Row', () {}))),
        ),
      ),
    );
    final gesture = await drag(tester, 'Row', 80);
    await gesture.up();
    await tester.pump();
    expect(offset(tester, 'Row'), 72);
    await tester.pumpWidget(frostTestApp(const FrostSwipeActions(child: Text('Empty'))));
    expect(find.text('Empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disabling scope during touch cancels without invoking the action', (tester) async {
    var enabled = true, calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostControlScope(
              enabled: enabled,
              child: Center(child: SizedBox(width: 400, child: swipe('Row', () => calls++))),
            );
          },
        ),
      ),
    );
    final gesture = await drag(tester, 'Row', 250);
    update(() => enabled = false);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(offset(tester, 'Row'), 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('custom pointer controls retain child width, touch and keyboard menu actions', (tester) async {
    var calls = 0;
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 400, child: swipe('Row', () => calls++, showsPointerActions: false)))));
    final original = tester.getRect(find.byType(FrostListRow));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    expect(find.byType(FrostButton), findsNothing);
    expect(tester.getRect(find.byType(FrostListRow)), original);
    await tester.tapAt(tester.getCenter(row('Row')), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsOneWidget);
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await mouse.removePointer();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    final gesture = await drag(tester, 'Row', 80);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(offset(tester, 'Row'), 72);
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(tester.takeException(), isNull);
  });
}
