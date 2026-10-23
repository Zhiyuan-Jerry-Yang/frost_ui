import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_table_cells.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'support.dart';

Widget tableView(Widget child, {double scale = 1}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: const Size(900, 600), textScaler: TextScaler.linear(scale)),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 800, height: 300, child: child),
    ),
  ),
);

void main() {
  testWidgets('selection count has secondary callout ink and group gap to first button', (tester) async {
    final selection = FrostSelection<int>()..toggle(1);
    addTearDown(selection.dispose);
    await tester.pumpWidget(frostTestApp(FrostSelectionBar(selection: selection, allItems: const [1, 2])));
    final count = find.byType(FrostRollingText);
    final tokens = FrostThemeTokens.of(tester.element(count));
    expect(tester.widget<FrostRollingText>(count).style!.color, tokens.textSecondary);
    final amount = tester.getRect(count), all = tester.getRect(find.text('L.selectAll'));
    expect(all.left - amount.right, FrostGap.group);
    final start = tester.widgetList<Wrap>(find.descendant(of: find.byType(FrostSelectionBar<int>), matching: find.byType(Wrap))).first;
    expect(start.spacing, FrostGap.group);
  });
  testWidgets('continuous catalog-style detail/progress updates never fade the running title', (tester) async {
    var progress = .2;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostTaskRow(title: 'Running', status: FrostTaskStatus.running, progress: progress, detail: '${(progress * 100).round()}% downloading');
          },
        ),
      ),
    );
    final state = tester.state(find.byType(FrostListRow));
    void expectOpaque() {
      var opacity = 1.0;
      tester.element(find.text('Running')).visitAncestorElements((element) {
        final render = element.renderObject;
        if (render is RenderAnimatedOpacity) opacity *= render.opacity.value;
        if (render is RenderOpacity) opacity *= render.opacity;
        if (render is RenderFrostContentFade) opacity *= render.opacity;
        return true;
      });
      expect(opacity, 1);
      expect(tester.state(find.byType(FrostListRow)), same(state));
    }

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 700));
      update(() => progress += .025);
      await tester.pump();
      expectOpaque();
      await tester.pump(const Duration(milliseconds: 40));
      expectOpaque();
      await tester.pump(const Duration(milliseconds: 50));
      expectOpaque();
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('pointer actions keep their own feedback instead of a second row hover surface', (tester) async {
    var rowCalls = 0, actionCalls = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostContentColumn(
          child: FrostSwipeActions(
            trailing: [FrostSwipeAction(label: 'Delete', icon: testIcons.delete, onPressed: () => actionCalls++)],
            child: FrostListRow(title: 'Row', onPressed: () => rowCalls++),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Row')));
    await tester.pumpAndSettle();
    final feedback = find.descendant(of: find.byType(FrostListRow), matching: find.byType(FrostClickFeedbackVisual)).first;
    expect(tester.widget<FrostClickFeedbackVisual>(feedback).states, contains(WidgetState.hovered));
    final button = find.byType(FrostButton);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pumpAndSettle();
    expect(find.ancestor(of: button, matching: find.byType(FrostClickFeedbackVisual)), findsNothing);
    expect(tester.widget<FrostClickFeedbackVisual>(feedback).states, isNot(contains(WidgetState.hovered)));
    final paint = tester.widget<DecoratedBox>(find.descendant(of: feedback, matching: find.byType(DecoratedBox)).first).decoration as ShapeDecoration;
    expect(paint.color!.a, 0);
    final buttons = tester
        .widgetList<DecoratedBox>(find.descendant(of: button, matching: find.byType(DecoratedBox)))
        .map((w) => w.decoration)
        .whereType<ShapeDecoration>();
    expect(buttons.any((d) => (d.color?.a ?? 0) > 0), isTrue);
    await mouse.down(tester.getCenter(button));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(actionCalls, 1);
    expect(rowCalls, 0);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  for (final primary in [0, 1]) {
    testWidgets('automatic columns fit headers, primary takes surplus index=$primary', (tester) async {
      final cols = [
        FrostTableColumn<int>(label: 'Name', primary: primary == 0, cell: (_, i) => Text('Name $i')),
        FrostTableColumn<int>(label: 'Size', primary: primary == 1, numeric: true, cell: (_, i) => Text('$i')),
        FrostTableColumn<int>(label: 'Status', width: 100, cell: (_, i) => const Text('Ready')),
      ];
      await tester.pumpWidget(tableView(FrostTable(columns: cols, rows: const [1])));
      var cells = tester.widget<FrostTableCells>(find.byType(FrostTableCells).first);
      expect(cells.widths[2], 100);
      expect(cells.widths[1 - primary], 80);
      expect(cells.widths[primary], 620);
      await tester.pumpWidget(tableView(FrostTable(columns: cols, rows: const [1]), scale: 2));
      cells = tester.widget<FrostTableCells>(find.byType(FrostTableCells).first);
      final width = tester.getSize(find.text(primary == 0 ? 'Size' : 'Name')).width + FrostGap.related * 2;
      expect(cells.widths[1 - primary], closeTo(width, .01));
      expect(cells.widths.reduce((a, b) => a + b), 800);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('first column fallback, explicit widths and sort slots are stable', (tester) async {
    var sort = 0;
    late StateSetter update;
    final cols = [
      FrostTableColumn<int>(label: 'Name', cell: (_, i) => Text('$i')),
      FrostTableColumn<int>(label: 'Long sortable label', sortKey: (i) => i, cell: (_, i) => Text('$i')),
    ];
    await tester.pumpWidget(
      tableView(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostTable(columns: cols, rows: const [1], sortColumn: sort);
          },
        ),
      ),
    );
    final before = tester.widget<FrostTableCells>(find.byType(FrostTableCells).first).widths;
    final header = tester.getSize(find.text('Long sortable label')).width;
    expect(before[1], closeTo(header + 16 + 4 + 18, .01));
    expect(before[0], closeTo(800 - before[1], .01));
    update(() => sort = 1);
    await tester.pumpAndSettle();
    expect(tester.widget<FrostTableCells>(find.byType(FrostTableCells).first).widths, before);
    await tester.pumpWidget(
      tableView(
        FrostTable(
          columns: [
            FrostTableColumn<int>(label: 'Name', width: 240, primary: true, cell: (_, i) => Text('$i')),
            cols[1],
          ],
          rows: const [1],
        ),
      ),
    );
    expect(tester.widget<FrostTableCells>(find.byType(FrostTableCells).first).widths.first, 240);
  });
}
