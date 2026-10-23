import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('toolbar trigger opens the shared menu and respects compact visual and hit heights', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostToolbarMenuButton(
            label: 'Popular · Week',
            entries: [FrostMenuAction('Select', onSelected: () => calls++)],
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    expect(tester.getSize(find.byType(FrostClickSurface)).height, 32);
    expect(tester.getSize(find.byType(FrostToolbarMenuButton)).height, 36);
    await tester.tap(find.text('Popular · Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Select'), findsNothing);
  });

  testWidgets('title menu text starts on the content keyline and uses headline typography', (tester) async {
    final columnKey = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 700,
            child: FrostContentColumn(
              child: Column(
                key: columnKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  FrostTitleMenu(title: 'Source', entries: [FrostMenuAction('Choice')]),
                  FrostText('Aligned'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.text('Source')).dx, tester.getTopLeft(find.text('Aligned')).dx);
    final title = tester.widget<FrostText>(find.widgetWithText(FrostText, 'Source'));
    expect(title.role, FrostTextRole.headline);
    expect(tester.takeException(), isNull);
  });
}
