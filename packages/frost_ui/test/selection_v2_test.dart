import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Widget list(FrostSelection<int> selection, {VoidCallback? pressed, int count = 20}) => Column(
  children: [
    Expanded(
      child: FrostContentColumn(
        child: FrostSelectableList<int>(
          selection: selection,
          items: List.generate(count, (i) => i),
          itemBuilder: (_, item, selected) => FrostListRow(title: 'Item $item', icon: testIcons.image, onPressed: pressed),
        ),
      ),
    ),
    FrostSelectionBar(
      selection: selection,
      allItems: List.generate(count, (i) => i),
      actions: [FrostSelectionAction(label: 'Delete', icon: testIcons.delete, onPressed: () {}, destructive: true)],
    ),
  ],
);

Future<void> modifiedTap(WidgetTester tester, String text, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.tap(find.text(text));
  await tester.sendKeyUpEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  test('controller notifications, immutable snapshots and additive all', () {
    final selection = FrostSelection<int>();
    var changes = 0;
    selection.addListener(() => changes++);
    expect(selection.active, isFalse);
    expect(selection.selected, isEmpty);
    selection.clear();
    selection.exit();
    expect(changes, 0);
    selection.enter();
    selection.enter();
    expect(changes, 1);
    selection.toggle(4);
    final snapshot = selection.selected;
    expect(() => snapshot.add(9), throwsUnsupportedError);
    selection.selectAll([1, 2]);
    expect(snapshot, {4});
    expect(selection.selected, {1, 2, 4});
    selection.selectAll([1, 2]);
    expect(changes, 3);
    selection.clear();
    expect(selection.active, isTrue);
    selection.exit();
    expect(selection.active, isFalse);
    expect(changes, 5);
    selection.dispose();
  });

  testWidgets('row keeps its action until selection; Ctrl, Shift and Esc share range state', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    var presses = 0;
    await tester.pumpWidget(frostTestApp(list(selection, pressed: () => presses++)));
    final before = tester.getTopLeft(find.text('Item 0')).dx;
    await tester.tap(find.text('Item 1'));
    expect(presses, 1);
    expect(selection.active, isFalse);
    await modifiedTap(tester, 'Item 4', LogicalKeyboardKey.shiftLeft);
    expect(selection.selected, {1, 2, 3, 4});
    expect(presses, 1);
    expect(tester.getTopLeft(find.text('Item 0')).dx - before, closeTo(36, .01));
    await modifiedTap(tester, 'Item 0', LogicalKeyboardKey.controlLeft);
    expect(selection.selected, {0, 1, 2, 3, 4});
    await modifiedTap(tester, 'Item 2', LogicalKeyboardKey.shiftLeft);
    expect(selection.selected, {0, 1, 2});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(selection.active, isFalse);
    expect(selection.selected, isEmpty);
    await modifiedTap(tester, 'Item 3', LogicalKeyboardKey.shiftLeft);
    expect(selection.selected, {3}, reason: 'exit also discards the range anchor');
  });

  testWidgets('grid automatically shows media selection and uses items order for Ctrl+Shift', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    var opened = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostSelectionScope<int>(
          selection: selection,
          items: const [4, 2, 7, 1],
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              for (final item in [4, 2, 7, 1])
                FrostSelectableItem<int>(
                  item: item,
                  child: FrostMediaCard(
                    semanticLabel: 'Media $item',
                    media: Center(child: Text('Media $item')),
                    onPressed: () => opened++,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await modifiedTap(tester, 'Media 2', LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await modifiedTap(tester, 'Media 1', LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(selection.selected, {2, 7, 1});
    expect(opened, 0);
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(find.text('Media 1')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press enters selection; disabled row stays disabled', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostSelectionScope<int>(
          selection: selection,
          items: const [1, 2],
          child: Column(
            children: const [
              FrostSelectableItem<int>(item: 1, child: FrostListRow(title: 'Enabled')),
              FrostSelectableItem<int>(item: 2, child: FrostListRow(title: 'Disabled', enabled: false)),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('Enabled')), kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selection.selected, {1});
    await tester.tapAt(tester.getCenter(find.text('Disabled')));
    await tester.pumpAndSettle();
    expect(selection.selected, {1});
  });

  testWidgets('bar clear/all/action state and live count', (tester) async {
    final selection = FrostSelection<int>()..enter();
    addTearDown(selection.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(list(selection, count: 3)));
    FrostButtonControl button(String label) => tester.widget<FrostButtonControl>(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == label));
    expect(button('Delete').onPressed, isNull);
    await tester.tap(find.text('L.selectAll'));
    await tester.pumpAndSettle();
    expect(selection.selected, {0, 1, 2});
    expect(button('L.selectAll').onPressed, isNull);
    expect(button('Delete').onPressed, isNotNull);
    expect(tester.getSemantics(find.bySemanticsLabel('Selected 3')).getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    selection.clear();
    await tester.pumpAndSettle();
    expect(button('Delete').onPressed, isNull);
    await tester.tap(find.text('L.done'));
    await tester.pumpAndSettle();
    expect(find.text('L.done'), findsNothing);
    semantics.dispose();
  });

  testWidgets('checkbox and bottom slot have intermediate frames, viewport offset survives', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(frostTestApp(list(selection, count: 100)));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(220);
    await tester.pump();
    final text = find.text('Item 6');
    final before = tester.getTopLeft(text).dx;
    final viewportBefore = scrollable.position.viewportDimension;
    selection.enter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final during = tester.getTopLeft(text).dx;
    expect(during, greaterThan(before));
    expect(during, lessThan(before + 36));
    expect(scrollable.position.pixels, 220);
    expect(scrollable.position.viewportDimension, lessThan(viewportBefore));
    final middleHeight = tester.getSize(find.byType(FrostSelectionBar<int>)).height;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(text).dx, closeTo(before + 36, .01));
    expect(tester.getSize(find.byType(FrostSelectionBar<int>)).height, greaterThan(middleHeight));
    expect(scrollable.position.pixels, 220);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Item 99')).dy, lessThanOrEqualTo(tester.getTopLeft(find.byType(FrostSelectionBar<int>)).dy));
  });

  testWidgets('narrow large text wraps bar actions on first frame without clipping', (tester) async {
    final selection = FrostSelection<int>()..toggle(1);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(size: Size(260, 600), textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 260,
                child: FrostSelectionBar(
                  selection: selection,
                  allItems: const [1, 2],
                  actions: [FrostSelectionAction(label: 'Long action', icon: testIcons.delete, onPressed: () {})],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('L.done')).dy,
      greaterThan(tester.getTopLeft(find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true && w.properties.label == 'Selected 1')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtering retains hidden selections and select-all checks current items', (tester) async {
    final selection = FrostSelection<int>()
      ..toggle(99)
      ..selectAll([1, 2]);
    addTearDown(selection.dispose);
    await tester.pumpWidget(frostTestApp(FrostSelectionBar(selection: selection, allItems: const [1, 2])));
    final button = tester.widget<FrostButtonControl>(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.selectAll'));
    expect(button.onPressed, isNull);
    expect(selection.selected, {99, 1, 2});
  });

  testWidgets('duplicate scope items and outside item assert', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(frostTestApp(FrostSelectionScope(selection: selection, items: const [1, 1], child: const SizedBox())));
    expect(tester.takeException(), isAssertionError);
    await tester.pumpWidget(
      frostTestApp(
        FrostSelectionScope(
          selection: selection,
          items: const [1],
          child: const FrostSelectableItem(item: 2, child: SizedBox()),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  for (final rtl in [false, true]) {
    testWidgets('divider follows checkbox text keyline including mid-frame rtl=$rtl', (tester) async {
      final selection = FrostSelection<int>();
      addTearDown(selection.dispose);
      await tester.pumpWidget(frostTestApp(Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: list(selection))));
      final leaf = find.descendant(of: find.byType(FrostDivider).first, matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget));
      final render = tester.renderObject<RenderBox>(leaf);
      double check() {
        final text = tester.getRect(find.text('Item 0'));
        final origin = render.localToGlobal(Offset.zero);
        final leading = rtl ? origin.dx + render.size.width - text.right : text.left - origin.dx;
        final dpr = tester.view.devicePixelRatio;
        expect(
          render,
          paints..line(p1: Offset(rtl ? 0 : leading, .5 / dpr), p2: Offset((rtl ? 0 : leading) + render.size.width - leading, .5 / dpr), strokeWidth: 0),
        );
        return leading;
      }

      final before = check();
      selection.enter();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final during = check();
      expect(during - before, inExclusiveRange(0, 36));
      await tester.pumpAndSettle();
      expect(check() - before, closeTo(36, .01));
      selection.exit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(check() - before, inExclusiveRange(0, 36));
      await tester.pumpAndSettle();
      expect(check(), closeTo(before, .01));
    });
  }

  testWidgets('reduced motion keeps bar fixed and only fades', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(frostTestApp(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: list(selection))));
    selection.enter();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final bar = find.byType(FrostSelectionBar<int>);
    final height = tester.getSize(bar).height;
    final translations = tester.widgetList<FractionalTranslation>(find.descendant(of: bar, matching: find.byType(FractionalTranslation)));
    expect(translations.every((widget) => widget.translation == Offset.zero), isTrue);
    final opacities = tester.widgetList<FrostMaterialReveal>(find.descendant(of: bar, matching: find.byType(FrostMaterialReveal)));
    expect(opacities.any((w) => w.opacity > 0 && w.opacity < 1), isTrue);
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, height);
  });

  testWidgets('scope filter keeps selections and nullable anchor works', (tester) async {
    final selection = FrostSelection<int?>();
    addTearDown(selection.dispose);
    Widget view(List<int?> items) => frostTestApp(
      FrostSelectionScope<int?>(
        selection: selection,
        items: items,
        child: Column(
          children: [
            for (final item in items)
              FrostSelectableItem<int?>(
                item: item,
                child: FrostListRow(title: '$item'),
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(view([null, 1, 2, 3]));
    await modifiedTap(tester, 'null', LogicalKeyboardKey.controlLeft);
    await modifiedTap(tester, '2', LogicalKeyboardKey.shiftLeft);
    expect(selection.selected, {null, 1, 2});
    await tester.pumpWidget(view([3]));
    await tester.pumpAndSettle();
    expect(selection.selected, {null, 1, 2});
    await tester.tap(find.text('3'));
    expect(selection.selected, {null, 1, 2, 3});
  });
  testWidgets('custom items enter by Ctrl click and Esc works without a child focus node', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostSelectionScope(
          selection: selection,
          items: const [1],
          child: const FrostSelectableItem(item: 1, child: Text('Custom')),
        ),
      ),
    );
    await modifiedTap(tester, 'Custom', LogicalKeyboardKey.controlLeft);
    expect(selection.selected, {1});
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(selection.active, isFalse);
    expect(selection.selected, isEmpty);
  });
  testWidgets('list stays lazy', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    var builds = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostSelectableList(
          selection: selection,
          items: List.generate(900, (i) => i),
          itemBuilder: (_, item, selected) {
            builds++;
            return FrostListRow(title: 'Item $item');
          },
        ),
      ),
    );
    expect(builds, lessThan(40));
  });
}
