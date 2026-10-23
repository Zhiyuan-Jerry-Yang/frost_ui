import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/sort_menu.dart' show frostSortMenuEntries;
import 'package:frost_ui/src/primitives/_scroll_edge_fade.dart';
import 'support.dart';

const fields = [
  FrostPickerOption(value: 1, label: 'Newest'),
  FrostPickerOption(value: 2, label: 'Popular'),
  FrostPickerOption(value: 3, label: 'Disabled', enabled: false),
];
Widget view(Widget child, {double width = 500}) => frostTestApp(
  Center(
    child: SizedBox(width: width, child: child),
  ),
);
void main() {
  testWidgets('empty filters mount collapsed and retain outgoing height during dismissal', (tester) async {
    var chips = <FrostFilterChip>[];
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostFilterBar(chips: chips);
          },
        ),
      ),
    );
    expect(tester.getSize(find.byType(FrostFilterBar)).height, 0);
    update!(() => chips = [FrostFilterChip(label: 'Rating', value: 'Safe', onClear: () {})]);
    await tester.pumpAndSettle();
    final height = tester.getSize(find.byType(FrostFilterBar)).height;
    expect(height, greaterThan(0));
    update!(() => chips = []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(find.byType(FrostFilterBar)).height, inExclusiveRange(0, height));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostFilterBar)).height, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('filters scroll horizontally through shared two-edge fade and clear independently', (tester) async {
    var clear = 0, chipClear = 0;
    await tester.pumpWidget(
      view(
        FrostFilterBar(
          chips: [for (var i = 0; i < 10; i++) FrostFilterChip(label: 'Filter $i', value: 'Long value', onClear: () => chipClear++)],
          onClearAll: () => clear++,
        ),
        width: 340,
      ),
    );
    final fade = tester.widget<FrostScrollEdgeFade>(find.byType(FrostScrollEdgeFade));
    final position = fade.controller.position;
    expect(position.axis, Axis.horizontal);
    expect(position.extentAfter, greaterThan(0));
    fade.controller.jumpTo(position.maxScrollExtent / 2);
    await tester.pump();
    expect(position.extentBefore, greaterThan(0));
    expect(position.extentAfter, greaterThan(0));
    expect(find.descendant(of: find.byType(FrostScrollEdgeFade), matching: find.byType(ShaderMask)), findsOneWidget);
    await tester.tap(find.text('L.clearAll'));
    expect(clear, 1);
    expect(chipClear, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sort entries have independent checked groups and preserve the other dimension', (tester) async {
    final calls = <(int, bool)>[];
    late List<FrostMenuEntry> entries;
    await tester.pumpWidget(
      view(
        Builder(
          builder: (context) {
            entries = frostSortMenuEntries(context, fields: fields, value: 2, ascending: false, onChanged: (field, asc) => calls.add((field, asc)));
            return FrostSortMenu(fields: fields, value: 2, ascending: false, onChanged: (field, asc) => calls.add((field, asc)), label: 'Sort');
          },
        ),
      ),
    );
    expect(find.text('Popular'), findsOneWidget);
    expect(entries[3], isA<FrostMenuDivider>());
    final actions = entries.whereType<FrostMenuAction>().toList();
    expect(actions.map((e) => e.checked), [false, true, false, false, true]);
    expect(actions[2].onSelected, isNull);
    actions[0].onSelected!();
    actions[3].onSelected!();
    expect(calls, [(1, false), (2, true)]);
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(find.text('L.sortAscending'), findsOneWidget);
    expect(find.text('L.sortDescending'), findsOneWidget);
    await tester.tap(find.text('L.sortAscending'));
    await tester.pumpAndSettle();
    expect(calls.last, (2, true));
  });
  testWidgets('unmatched field shows label with no checked field and constructors validate values', (tester) async {
    late List<FrostMenuEntry> entries;
    await tester.pumpWidget(
      view(
        Builder(
          builder: (context) {
            entries = frostSortMenuEntries(context, fields: fields, value: 9, ascending: true, onChanged: (_, _) {});
            return FrostSortMenu(fields: fields, value: 9, ascending: true, onChanged: (_, _) {}, label: 'Sort');
          },
        ),
      ),
    );
    expect(find.text('Sort'), findsOneWidget);
    expect(entries.take(3).cast<FrostMenuAction>().every((e) => e.checked == false), isTrue);
    expect(() => FrostSortMenu<int>(fields: [], value: 0, ascending: true, onChanged: (_, _) {}, label: 'Sort'), throwsAssertionError);
    expect(
      () => FrostToolbarItem.sortMenu<int>(fields: [fields.first, fields.first], value: 1, ascending: true, onChanged: (_, _) {}, label: 'Sort'),
      throwsAssertionError,
    );
  });
  testWidgets('toolbar sort factory renders same trigger and folds to a label-titled submenu', (tester) async {
    var width = 600.0;
    StateSetter? update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return view(
            FrostToolbar(
              leading: const [Text('A long toolbar title')],
              trailing: [FrostToolbarItem.sortMenu(fields: fields, value: 1, ascending: true, onChanged: (_, _) {}, label: 'Sort')],
            ),
            width: width,
          );
        },
      ),
    );
    expect(find.byType(FrostSortMenu<int>).hitTestable(), findsOneWidget);
    expect(find.text('Newest').hitTestable(), findsOneWidget);
    update!(() => width = 160);
    await tester.pumpAndSettle();
    expect(find.text('Newest').hitTestable(), findsNothing);
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'L.more' && w.properties.button == true).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Sort · Newest'), findsOneWidget);
    await tester.tap(find.text('Sort · Newest'));
    await tester.pumpAndSettle();
    expect(find.text('L.sortAscending'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    update!(() => width = 600);
    await tester.pumpAndSettle();
    expect(find.text('Newest').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
