import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

List<FrostTableColumn<int>> columns({double? width, bool long = false}) => [
  FrostTableColumn(
    label: 'Name',
    cell: (_, i) => Text(long ? 'Long wrapped item $i repeated repeated repeated' : 'Item $i'),
    text: (i) => 'Name $i',
    width: width,
    primary: true,
    sortKey: (i) => i,
  ),
  FrostTableColumn(label: 'Bytes', cell: (_, i) => Text((i + 100).toString()), text: (i) => (i + 100).toString(), numeric: true, sortKey: (i) => i),
];
Widget view(Widget child, {double width = 800, double scale = 1, TextDirection direction = TextDirection.ltr}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: Size(width, 600), textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(width: width, height: 300, child: child),
      ),
    ),
  ),
);
Future<void> modified(WidgetTester tester, String label, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.tap(find.text(label));
  await tester.sendKeyUpEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  test('column bounds and empty columns assert', () {
    expect(() => FrostTableColumn<int>(label: 'X', cell: (_, _) => const SizedBox(), minWidth: 0), throwsAssertionError);
    expect(() => FrostTableColumn<int>(label: 'X', cell: (_, _) => const SizedBox(), width: double.infinity), throwsAssertionError);
    expect(() => FrostTable<int>(columns: const [], rows: const []), throwsAssertionError);
  });
  testWidgets('pointer-down replacement, Ctrl, Shift, double tap and keyboard', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final activated = <int>[];
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: List.generate(8, (i) => i), selection: selection, onActivate: activated.add)));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Item 1')), kind: PointerDeviceKind.mouse);
    expect(selection.selected, {1}, reason: 'selection does not wait for double-tap timeout');
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item 4'));
    await tester.pumpAndSettle();
    expect(selection.selected, {4});
    await modified(tester, 'Item 2', LogicalKeyboardKey.controlLeft);
    expect(selection.selected, {2, 4});
    await modified(tester, 'Item 5', LogicalKeyboardKey.shiftLeft);
    expect(selection.selected, {2, 3, 4, 5});
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(selection.isSelected(4), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, [4]);
    await tester.tap(find.text('Item 0'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Item 0'));
    await tester.pumpAndSettle();
    expect(activated, [4, 0]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('ordinary activation and independent cell button retain their actions', (tester) async {
    var activated = 0, button = 0;
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    final cols = [
      ...columns(),
      FrostTableColumn<int>(
        label: 'Action',
        cell: (_, i) => FrostButton(label: 'Open $i', onPressed: () => button++),
      ),
    ];
    await tester.pumpWidget(view(FrostTable(columns: cols, rows: const [0, 1], selection: selection, onActivate: (_) => activated++)));
    await tester.tap(find.text('Open 1'));
    await tester.pumpAndSettle();
    expect(button, 1);
    expect(selection.selected, isEmpty);
    expect(activated, 0);
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: const [0, 1], onActivate: (_) => activated++)));
    await tester.tap(find.text('Item 0'));
    await tester.pumpAndSettle();
    expect(activated, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sort caller state and same arrow rotates through intermediate frame', (tester) async {
    var ascending = true;
    (int, bool)? last;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (context, setState) => FrostTable(
            columns: columns(),
            rows: const [0],
            sortColumn: 0,
            sortAscending: ascending,
            onSort: (value) {
              last = value;
              setState(() => ascending = value.$2);
            },
          ),
        ),
      ),
    );
    final iconBefore = tester.widget<FrostIcon>(find.byType(FrostIcon).first).icon;
    await tester.tap(find.text('Name'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(last, (0, false));
    final rotation = find.descendant(of: find.byType(AnimatedRotation).first, matching: find.byType(RotationTransition));
    expect(tester.widget<RotationTransition>(rotation).turns.value, inExclusiveRange(0, .5));
    await tester.pumpAndSettle();
    expect(tester.widget<RotationTransition>(rotation).turns.value, .5);
    expect(tester.widget<FrostIcon>(find.byType(FrostIcon).first).icon, iconBefore);
  });
  for (final direction in TextDirection.values) {
    testWidgets('resize, PageStorage, reset only one column direction=$direction', (tester) async {
      final bucket = PageStorageBucket();
      Widget table() => view(
        PageStorage(
          bucket: bucket,
          child: FrostTable(key: const PageStorageKey('table'), columns: columns(), rows: const [0]),
        ),
        direction: direction,
      );
      await tester.pumpWidget(table());
      final handles = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);
      final before = tester.getCenter(handles.first).dx;
      await tester.drag(handles.first, Offset(direction == TextDirection.ltr ? 80 : -80, 0));
      await tester.pumpAndSettle();
      final after = tester.getCenter(handles.first).dx;
      expect((after - before).abs(), greaterThan(20));
      final saved = bucket.readState(tester.element(find.byType(FrostTable<int>)), identifier: const PageStorageKey('table')) as Map<int, double>;
      expect(saved[0], greaterThan(400));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(table());
      expect(tester.getCenter(handles.first).dx, closeTo(after, .1));
      await tester.tap(handles.first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(handles.first);
      await tester.pumpAndSettle();
      expect(tester.getCenter(handles.first).dx, closeTo(before, .1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('explicit compact text, primary without text, first primary wins', (tester) async {
    final cols = [
      FrostTableColumn<int>(
        label: 'First',
        primary: true,
        text: (i) => 'Title $i',
        cell: (_, i) => Padding(padding: EdgeInsets.zero, child: Text('Wrapped $i')),
      ),
      FrostTableColumn<int>(label: 'Second', primary: true, text: (i) => 'Value $i', cell: (_, i) => Text('V $i')),
      FrostTableColumn<int>(label: 'Picture', cell: (_, i) => Text('Omitted $i')),
    ];
    await tester.pumpWidget(view(FrostTable(columns: cols, rows: const [1]), width: 350, scale: 2));
    expect(find.byType(FrostListRow), findsOneWidget);
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Value 1'), findsOneWidget);
    expect(find.text('Omitted 1'), findsNothing);
    await tester.pumpWidget(view(FrostTable(columns: [cols.last, cols[1]], rows: const [1]), width: 350));
    expect(find.text('Value 1'), findsOneWidget);
    await tester.pumpWidget(view(FrostTable(columns: [cols.last], rows: const [1]), width: 350));
    expect(find.text('Picture'), findsOneWidget);
    expect(find.text('Omitted 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact selection activates when inactive and toggles when active', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    var opened = 0;
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: const [0, 1], selection: selection, onActivate: (_) => opened++), width: 350));
    await tester.tap(find.text('Name 0'));
    expect(opened, 1);
    expect(selection.active, isFalse);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Name 1')), kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selection.selected, {1});
    await tester.tap(find.text('Name 0'));
    expect(selection.selected, {0, 1});
    expect(opened, 1);
  });
  testWidgets('table role tree, lazy full dimensions and explicit cell semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var built = 0;
    final cols = [
      FrostTableColumn<int>(
        label: 'Name',
        text: (i) => 'Semantic $i',
        cell: (_, i) {
          built++;
          return Text('Visual $i');
        },
      ),
      columns()[1],
    ];
    await tester.pumpWidget(view(FrostTable(columns: cols, rows: List.generate(900, (i) => i))));
    expect(built, lessThan(40));
    final table = find.byWidgetPredicate((w) => w is Semantics && w.properties.role == SemanticsRole.table);
    final node = tester.getSemantics(table);
    expect(node.getSemanticsData().label, '900 × 2');
    final roles = <SemanticsRole>[];
    node.visitChildren((child) {
      roles.add(child.getSemanticsData().role);
      return true;
    });
    expect(roles, isNotEmpty);
    expect(roles.every((role) => role == SemanticsRole.row), isTrue);
    expect(find.bySemanticsLabel('Semantic 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('numeric cell actual right edge and tabular figures; horizontal scrolling shares header', (tester) async {
    await tester.pumpWidget(view(FrostTable(columns: columns(width: 900), rows: const [0, 1])));
    final text = find.text('100');
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(tester.getRect(text).right, closeTo(990, .1));
    final before = tester.getTopLeft(find.text('Name')).dx;
    final horizontal = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => axisDirectionToAxis(s.position.axisDirection) == Axis.horizontal);
    horizontal.position.jumpTo(horizontal.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getTopLeft(find.text('Name')).dx, lessThan(before));
    expect(tester.getTopLeft(find.text('Item 0')).dx - tester.getTopLeft(find.text('Name')).dx, closeTo(0, .1));
  });
  for (final density in FrostDensity.values) {
    testWidgets('regular row height and role growth density=$density', (tester) async {
      double height() => tester.getSize(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'FrostTableCells').at(1)).height;
      Widget app(double scale) => frostTestApp(
        MediaQuery(
          data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
          child: FrostTable(columns: columns(), rows: const [0]),
        ),
        density: density,
      );
      await tester.pumpWidget(app(1));
      final base = height();
      expect(base, density == FrostDensity.compact ? 40 : 44);
      await tester.pumpWidget(app(2));
      expect(height(), greaterThan(base));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('local narrow width scrolls rather than overflowing and big text wraps', (tester) async {
    await tester.pumpWidget(
      view(
        Center(
          child: SizedBox(
            width: 120,
            child: FrostTable(columns: columns(long: true), rows: const [0, 1]),
          ),
        ),
        scale: 2,
        direction: TextDirection.rtl,
      ),
    );
    expect(find.textContaining('Long wrapped'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard reaches a lazy distant row and activates its actual item', (tester) async {
    int? opened;
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: List.generate(900, (i) => i), onActivate: (i) => opened = i)));
    await tester.tap(find.text('Item 0'));
    for (var i = 0; i < 25; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Item 25').hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 25);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty table remains valid with semantics and keys', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(view(FrostTable<int>(columns: columns(), rows: const [])));
    await tester.tap(find.text('Name'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(find.bySemanticsLabel('0 × 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('sortable header exposes a semantic tap action and sort state', (tester) async {
    final semantics = tester.ensureSemantics();
    (int, bool)? sorted;
    await tester.pumpWidget(view(FrostTable(columns: columns(), rows: const [0], sortColumn: 0, sortAscending: false, onSort: (value) => sorted = value)));
    final header = tester.getSemantics(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.role == SemanticsRole.columnHeader && w.properties.label == 'Name'),
    );
    expect(header.getSemanticsData().value, 'L.sortDescending');
    expect(header.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: header.id));
    expect(sorted, (0, true));
    semantics.dispose();
  });
}
