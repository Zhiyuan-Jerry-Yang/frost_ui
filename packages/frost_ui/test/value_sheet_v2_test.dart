import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';

import 'support.dart';

Finder get sheet => find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.sheet);
Finder row(String label) => find.ancestor(of: find.text(label).last, matching: find.byType(FrostClickSurface)).first;

Future<void> pump(WidgetTester tester, Widget child, {double scale = 1, FrostDensity density = FrostDensity.compact}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
      density: density,
    ),
  );
}

void main() {
  testWidgets('Short fitted choices show both rows on the cold frame even when the last is selected', (tester) async {
    for (final selected in [0, 1]) {
      await pump(
        tester,
        FrostPicker<int>.menu(
          label: 'Choice',
          value: selected,
          options: const [
            FrostPickerOption(value: 0, label: 'One'),
            FrostPickerOption(value: 1, label: 'Two'),
          ],
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.text(selected == 0 ? 'One' : 'Two'));
      await tester.pump();
      final panel = tester.getRect(sheet);
      expect(tester.getRect(row('One')).top, greaterThan(panel.top));
      expect(tester.getRect(row('Two')).bottom, panel.bottom - 20);
      expect(tester.getRect(row('One')).bottom, lessThanOrEqualTo(tester.getRect(row('Two')).top));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact Select fits two rows, current focus, right check and checked semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      FrostPicker<int>.menu(
        label: 'Quality',
        value: 0,
        options: [
          FrostPickerOption(value: 0, label: 'One', icon: testIcons.image),
          const FrostPickerOption(value: 1, label: 'Two'),
        ],
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    final panel = tester.getRect(sheet);
    expect(panel.width, 390);
    expect(panel.bottom - tester.getBottomLeft(row('Two')).dy, 20);
    expect(panel.height, lessThan(400));
    final selected = tester.widget<FrostClickSurface>(row('One'));
    expect(selected.focusNode!.hasPrimaryFocus, isTrue);
    final text = tester.getRect(find.text('One').last);
    final check = find.descendant(
      of: row('One'),
      matching: find.byWidgetPredicate((widget) => widget is FrostIcon && widget.color == FrostThemeTokens.of(tester.element(row('One'))).selectionInk),
    );
    expect(tester.getTopLeft(check).dx, greaterThan(text.right));
    final selectedSemantics = tester.getSemantics(find.bySemanticsLabel('One').last).getSemanticsData();
    expect(selectedSemantics.flagsCollection.isChecked, CheckedState.isTrue);
    final otherSemantics = tester.getSemantics(find.bySemanticsLabel('Two')).getSemanticsData();
    expect(otherSemantics.flagsCollection.isChecked, CheckedState.isFalse);
    final column = find.ancestor(of: row('One'), matching: find.byType(Column)).first;
    final divider = find.descendant(of: column, matching: find.byType(FrostDivider));
    expect(tester.getTopLeft(divider).dx, text.left);
    semantics.dispose();
  });

  testWidgets('900 options use large in the cold frame and the current item stays visible and lazy', (tester) async {
    await pump(
      tester,
      FrostPicker<int>.menu(
        label: 'Choice',
        value: 899,
        options: [for (var index = 0; index < 900; index++) FrostPickerOption(value: index, label: 'Item $index')],
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('Item 899'));
    await tester.pump();
    final current = tester.getRect(row('Item 899'));
    final panel = tester.getRect(sheet);
    expect(panel.height, 792);
    expect(current.top, greaterThan(panel.top));
    expect(current.bottom, lessThan(panel.bottom));
    expect(find.text('Item 0'), findsNothing);
    expect(find.byType(FrostClickSurface).evaluate().length, lessThan(35));
    await tester.pumpAndSettle();
    expect(tester.widget<FrostClickSurface>(row('Item 899')).focusNode!.hasPrimaryFocus, isTrue);
    final scroll = tester.state<ScrollableState>(find.descendant(of: sheet, matching: find.byType(Scrollable)).first).position;
    expect(scroll.extentBefore, greaterThan(0));
  });

  testWidgets('Picking closes and returns the choice, restoring field focus', (tester) async {
    int? result;
    await pump(
      tester,
      FrostPicker<int>.menu(
        label: 'Quality',
        value: 0,
        options: const [
          FrostPickerOption(value: 0, label: 'One'),
          FrostPickerOption(value: 1, label: 'Two'),
        ],
        onChanged: (value) => result = value,
      ),
    );
    final trigger = tester.widget<FrostButtonControl>(find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == 'One'));
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(result, 1);
    expect(sheet, findsNothing);
    expect(trigger.focusNode!.hasPrimaryFocus, isTrue);
  });

  testWidgets('Compact settings row uses its title and preserves disabled behavior', (tester) async {
    int? result;
    await pump(
      tester,
      FrostSettingsSelectTile<int>(
        icon: testIcons.image,
        title: 'Quality',
        value: 0,
        items: const [
          FrostPickerOption(value: 0, label: 'One'),
          FrostPickerOption(value: 1, label: 'Two'),
        ],
        onChanged: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is FrostText && widget.data == 'Quality' && widget.role == FrostTextRole.headline), findsOneWidget);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(result, 1);
    await pump(
      tester,
      FrostSettingsSelectTile<int>(
        icon: testIcons.image,
        title: 'Disabled',
        value: 0,
        items: const [FrostPickerOption(value: 0, label: 'One')],
        enabled: false,
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('compact Picker anchors in toolbars and fits content menus', (tester) async {
    const items = [FrostPickerOption(value: 0, label: 'One'), FrostPickerOption(value: 1, label: 'Two')];
    for (final (index, child) in [
      FrostControlScope(
        toolbar: true,
        child: FrostPicker<int>.menu(value: 0, options: items, onChanged: (_) {}, label: "Choice"),
      ),
      FrostPicker<int>.menu(value: 0, options: items, onChanged: (_) {}, label: "Choice"),
      FrostControlScope(
        toolbar: true,
        child: FrostPicker<int>.menu(value: 0, options: items, onChanged: (_) {}, label: "Choice"),
      ),
    ].indexed) {
      await pump(tester, KeyedSubtree(key: ValueKey(index), child: child));
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.byType(FrostMenuPanel), index == 1 ? findsNothing : findsOneWidget);
      expect(sheet, index == 1 ? findsOneWidget : findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    testWidgets('Picker rows share density geometry and vertical insets as text scales $density', (tester) async {
      double? firstHeight, firstTextHeight, firstInset;
      for (final scale in [1.0, 2.0]) {
        await pump(
          tester,
          FrostPicker<int>.menu(
            value: 0,
            options: [
              FrostPickerOption(value: 0, label: 'One', icon: testIcons.image),
              const FrostPickerOption(value: 1, label: 'Two'),
            ],
            onChanged: (_) {},
            label: 'Choice',
          ),
          scale: scale,
          density: density,
        );
        await tester.tap(find.text('One'));
        await tester.pumpAndSettle();
        final rect = tester.getRect(row('One'));
        final text = tester.getRect(find.text('One').last);
        final inset = text.top - rect.top;
        final icon = find.descendant(of: row('One'), matching: find.byType(FrostIcon)).first;
        final rowInset = FrostGap.of(tester.element(row('One'))).rowInset;
        expect(text.left - tester.getTopLeft(icon).dx, 32);
        expect(tester.getTopLeft(icon).dx - rect.left, rowInset + 4);
        expect(text.left - rect.left, rowInset + 36);
        if (scale == 1) {
          expect(rect.height, density == FrostDensity.compact ? 40 : 44);
          firstHeight = rect.height;
          firstTextHeight = text.height;
          firstInset = inset;
        } else {
          expect(inset, closeTo(firstInset!, .01));
          expect(rect.height - firstHeight!, closeTo(text.height - firstTextHeight!, .01));
        }
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('Nullable selected values are distinct from cancelling the Sheet', (tester) async {
    var calls = 0;
    String? result = 'unchanged';
    await pump(
      tester,
      FrostPicker<String?>.menu(
        value: 'x',
        options: const [
          FrostPickerOption(value: 'x', label: 'Present'),
          FrostPickerOption(value: null, label: 'None'),
        ],
        onChanged: (value) {
          calls++;
          result = value;
        },
        label: 'Choice',
      ),
    );
    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(result, isNull);
  });
}
