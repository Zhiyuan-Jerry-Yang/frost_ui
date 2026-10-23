import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart' show FrostMenuItem;

import 'support.dart';

void main() {
  testWidgets('clicking a hovered desktop submenu keeps it open and selectable', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => Center(
            child: FrostMenuAnchor(
              entries: [
                FrostMenuSubmenu('Mode', entries: [FrostMenuAction('Popular', onSelected: () => selected = true)]),
              ],
              builder: (context, focus, toggle) => TextButton(focusNode: focus, onPressed: toggle, child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Mode')));
    await tester.pumpAndSettle();
    expect(find.text('Popular').hitTestable(), findsOneWidget);
    final trigger = find.ancestor(of: find.text('Mode'), matching: find.byType(FrostMenuItem));
    expect(tester.getRect(find.text('Popular')).left, greaterThanOrEqualTo(tester.getRect(trigger).right));
    await mouse.down(tester.getCenter(find.text('Mode')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Popular').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(selected, true);
    expect(find.text('Mode'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('submenu direction keys enter and leave the nested focus scope in LTR and RTL', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: Builder(
              builder: (context) => Center(
                child: FrostMenuAnchor(
                  entries: [
                    FrostMenuSubmenu('Mode', entries: [FrostMenuAction('Popular', onSelected: () {})]),
                  ],
                  builder: (context, focus, toggle) => TextButton(focusNode: focus, onPressed: toggle, child: const Text('Open')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final trigger = find.ancestor(of: find.text('Mode'), matching: find.byType(FrostMenuItem));
      tester.widget<FrostMenuItem>(trigger).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Popular').hitTestable(), findsOneWidget);
      final parent = tester.getRect(trigger);
      final child = tester.getRect(find.text('Popular'));
      expect(direction == TextDirection.ltr ? child.left >= parent.right : child.right <= parent.left, true);
      await tester.sendKeyEvent(direction == TextDirection.ltr ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Popular'), findsNothing);
      expect(tester.widget<FrostMenuItem>(trigger).focusNode!.hasFocus, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('entry menu renders sections, check, shortcut, disabled action and nested selection', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => Center(
            child: FrostMenuAnchor(
              entries: [
                FrostMenuSection(
                  header: 'Source',
                  entries: [
                    FrostMenuAction(
                      'Current',
                      checked: true,
                      shortcut: const FrostShortcut(LogicalKeyboardKey.digit1, primary: true),
                      onSelected: () => selected.add('current'),
                    ),
                    FrostMenuAction('Disabled', enabled: false, onSelected: () => selected.add('disabled')),
                  ],
                ),
                const FrostMenuDivider(),
                FrostMenuSubmenu('Period', entries: [FrostMenuAction('Week', onSelected: () => selected.add('week'))]),
              ],
              builder: (context, focus, toggle) => TextButton(focusNode: focus, onPressed: toggle, child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Ctrl+1'), findsOneWidget);
    expect(find.byType(FrostDivider), findsOneWidget);
    final checked = tester.widgetList<Semantics>(find.ancestor(of: find.text('Current'), matching: find.byType(Semantics)));
    expect(checked.any((node) => node.properties.checked == true), true);
    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text('Source'), findsOneWidget);
    await tester.tap(find.text('Period'));
    await tester.pumpAndSettle();
    expect(find.text('Week'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(selected, ['week']);
    expect(find.text('Source'), findsNothing);
    expect(find.text('Week'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
