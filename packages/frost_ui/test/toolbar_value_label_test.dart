import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('selector trigger shows value but announces purpose and value', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostToolbarMenuButton(
            label: 'Time range',
            valueLabel: 'Today',
            entries: [FrostMenuAction('Choose week', onSelected: () {})],
          ),
        ),
      ),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Time range'), findsNothing);
    expect(find.bySemanticsLabel('Time range, Today'), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Choose week').hitTestable(), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('overflow retains purpose and current value for menu, picker and sort', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 180,
            child: FrostToolbar(
              leading: const [FrostText('Source')],
              controls: [
                FrostToolbarItem.menu(
                  label: 'Time range',
                  valueLabel: 'Today',
                  entries: [FrostMenuAction('Week', onSelected: () => selected = true)],
                ),
                FrostToolbarItem.picker<int>(
                  label: 'Mode',
                  value: 0,
                  choices: const [FrostPickerOption(value: 0, label: 'Latest')],
                  onChanged: (_) {},
                ),
                FrostToolbarItem.sortMenu<int>(
                  label: 'Sort',
                  value: 0,
                  fields: const [FrostPickerOption(value: 0, label: 'Score')],
                  ascending: true,
                  onChanged: (_, _) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(findFrostTooltip('L.more').last);
    await tester.tap(findFrostTooltip('L.more').hitTestable());
    await tester.pumpAndSettle();
    for (final label in ['Time range · Today', 'Mode · Latest', 'Sort · Score']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.text('Time range · Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week').hitTestable());
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
