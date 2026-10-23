import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'package:frost_ui/src/overlays/menu_anchor.dart' show FrostMenuHost;
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'support.dart';

List<FrostMenuEntry> entries(String label) => [FrostMenuAction(label, onSelected: () {})];
Future<void> dismiss(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('context input preserves the child single rounded press surface', (tester) async {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostContextMenuRegion(
            entries: entries('Action'),
            child: FrostClickSurface(
              customBorder: shape,
              onTap: () {},
              child: const SizedBox(width: 200, height: 120, child: Text('Card')),
            ),
          ),
        ),
      ),
    );
    final feedback = find.descendant(of: find.byType(FrostContextMenuRegion), matching: find.byType(FrostClickFeedbackVisual));
    expect(feedback, findsOneWidget);
    expect(tester.widget<FrostClickFeedbackVisual>(feedback).shape, shape);
    final press = await tester.startGesture(tester.getCenter(find.text('Card')), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 150));
    expect(feedback, findsOneWidget, reason: 'Context input must not paint a second square plate during the hold.');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget);
    await press.up();
    await dismiss(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short context and submenu panels share the 160 minimum and stay inside the viewport', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final closed = showFrostContextMenu(
      context: context,
      globalPosition: const Offset(790, 200),
      entries: [
        FrostMenuAction('A', onSelected: () {}),
        FrostMenuSubmenu(
          'B',
          entries: [
            FrostMenuAction('C', onSelected: () {}),
            FrostMenuAction('D', onSelected: () {}),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostMenuPanel)).width, 160);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNWidgets(2));
    for (final panel in find.byType(FrostMenuPanel).evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((element) => element == panel));
      expect(rect.width, 160);
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.right, lessThanOrEqualTo(792));
    }
    await dismiss(tester);
    await dismiss(tester);
    await closed;
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary tap uses the shared host at the pointer and restores focus', (tester) async {
    final focus = FocusNode();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostContextMenuRegion(
            entries: entries('Action'),
            child: SizedBox(
              width: 240,
              height: 120,
              child: Focus(focusNode: focus, child: const Text('Region')),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    final point = tester.getCenter(find.text('Region'));
    await tester.tapAt(point, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuHost), findsOneWidget);
    expect(find.byType(FrostMenuItem), findsOneWidget);
    expect(tester.getTopLeft(find.byType(FrostMenuPanel)), point);
    await dismiss(tester);
    expect(focus.hasPrimaryFocus, true);
    expect(find.byType(FrostMenuHost), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });
  for (final key in [LogicalKeyboardKey.f10, LogicalKeyboardKey.contextMenu]) {
    testWidgets('keyboard $key anchors at the focused control bottom left', (tester) async {
      final focus = FocusNode();
      const target = ValueKey('target');
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostContextMenuRegion(
              entries: entries('Keyboard action'),
              child: Focus(
                focusNode: focus,
                child: const SizedBox(key: target, width: 160, height: 60),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      final point = tester.getBottomLeft(find.byKey(target));
      if (key == LogicalKeyboardKey.f10) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (key == LogicalKeyboardKey.f10) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(FrostMenuPanel)), point);
      await dismiss(tester);
      expect(focus.hasPrimaryFocus, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    });
  }
  testWidgets('touch long press shares feedback and opens only the inner menu', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostContextMenuRegion(
            entries: entries('Outer'),
            child: SizedBox(
              width: 280,
              height: 200,
              child: Center(
                child: FrostContextMenuRegion(
                  entries: entries('Inner'),
                  child: const SizedBox(key: ValueKey('inner'), width: 120, height: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('inner'))), kind: PointerDeviceKind.touch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widgetList<Transform>(find.byType(Transform)).where((w) => w.transform.storage[0] < 1), isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Inner'), findsOneWidget);
    expect(find.text('Outer'), findsNothing);
    expect(find.byType(FrostMenuPanel), findsOneWidget);
    await gesture.up();
    await dismiss(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('secondary input chooses the innermost enabled nonempty region', (tester) async {
    for (final mode in [0, 1, 2]) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostContextMenuRegion(
              entries: entries('Outer'),
              child: SizedBox(
                width: 280,
                height: 200,
                child: Center(
                  child: FrostContextMenuRegion(
                    entries: mode == 1 ? const [] : entries('Inner'),
                    enabled: mode != 0,
                    child: const SizedBox(key: ValueKey('inner'), width: 120, height: 80),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('inner'))), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text(mode == 2 ? 'Inner' : 'Outer'), findsOneWidget);
      expect(find.text(mode == 2 ? 'Outer' : 'Inner'), findsNothing);
      await dismiss(tester);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('point menu flips both axes, completes on close, and empty entries do not open', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    var closed = false;
    final future = showFrostContextMenu(
      context: context,
      globalPosition: const Offset(790, 590),
      entries: entries('An action with a wide label'),
    ).then((_) => closed = true);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(FrostMenuPanel));
    expect(rect.right, 790);
    expect(rect.bottom, 590);
    expect(rect.left, greaterThanOrEqualTo(8));
    expect(rect.top, greaterThanOrEqualTo(8));
    expect(closed, false);
    await dismiss(tester);
    await future;
    expect(closed, true);
    await showFrostContextMenu(context: context, globalPosition: Offset.zero, entries: const []);
    expect(find.byType(FrostMenuPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disabling and disposing a region remove its menu without stale callbacks', (tester) async {
    late StateSetter update;
    var enabled = true, visible = true;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: StatefulBuilder(
            builder: (context, set) {
              update = set;
              return visible ? const SizedBox(width: 200, height: 100).frostContextMenu(entries('Action'), enabled: enabled) : const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FrostContextMenuRegion), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    update(() => enabled = true);
    await tester.pump();
    await tester.tap(find.byType(FrostContextMenuRegion), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
