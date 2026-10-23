import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'support.dart';

void main() {
  test('icon-only menu requires an icon in both public entry points', () {
    expect(() => FrostToolbarMenuButton(label: 'Menu', entries: const [], showsLabel: false), throwsAssertionError);
    expect(() => FrostToolbarItem.menu(label: 'Menu', entries: const [], showsLabel: false), throwsAssertionError);
  });
  testWidgets('menu forms retain label semantics and icon-only action geometry', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final showsLabel in [true, false]) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 500,
              child: FrostToolbar(
                trailing: [
                  FrostToolbarItem.menu(
                    label: 'Task menu',
                    icon: testIcons.more,
                    showsLabel: showsLabel,
                    entries: [FrostMenuAction('Open task', onSelected: () {})],
                  ),
                  FrostToolbarItem.action(label: 'Action', icon: testIcons.add, onPressed: () {}),
                ],
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final trigger = find.byType(FrostToolbarMenuButton).hitTestable();
      final control = find.descendant(of: trigger, matching: find.byType(FrostButtonControl));
      expect(tester.widget<FrostButtonControl>(control).chevron, showsLabel ? FrostButtonChevron.down : FrostButtonChevron.none);
      expect(find.descendant(of: trigger, matching: find.text('Task menu')), showsLabel ? findsOneWidget : findsNothing);
      expect(find.bySemanticsLabel('Task menu').hitTestable(), findsOneWidget);
      if (!showsLabel) {
        expect(findFrostTooltip('Task menu').hitTestable(), findsOneWidget);
        expect(tester.getSize(control), tester.getSize(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'Action').hitTestable()));
      }
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('Open task').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Open task').hitTestable());
      await tester.pumpAndSettle();
    }
    semantics.dispose();
  });
  testWidgets('icon-only menu folds to the same labelled submenu', (tester) async {
    var called = false;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: FrostDensity.compact.targetHeight * 2 + FrostGap.related - 1,
            child: FrostToolbar(
              trailing: [
                FrostToolbarItem.menu(
                  label: 'Task menu',
                  icon: testIcons.more,
                  showsLabel: false,
                  entries: [FrostMenuAction('Open task', onSelected: () => called = true)],
                ),
                FrostToolbarItem.action(label: 'Always', icon: testIcons.add, priority: FrostToolbarPriority.high, onPressed: () {}),
              ],
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    expect(find.byType(FrostToolbarMenuButton).hitTestable(), findsNothing);
    await tester.tap(findFrostTooltip('L.more').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Task menu').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Task menu').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open task').hitTestable());
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(tester.takeException(), isNull);
  });
}
