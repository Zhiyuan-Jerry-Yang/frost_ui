import 'dart:ui' show CheckedState;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_value_picker.dart';
import 'support.dart';

const home = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe001)), label: 'Home');
const settings = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe002)), label: 'Settings');
const about = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe003)), label: 'About');
Finder row(String text) => find.ancestor(of: find.text(text).last, matching: find.byType(FrostClickSurface)).first;
Finder get panel => find.ancestor(
  of: find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('_ValuePickerList<')),
  matching: find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet),
);
void main() {
  testWidgets('desktop More uses shared value rows, current focus/right check, closes and navigates', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final picked = <int>[];
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [home],
          selectedIndex: null,
          selectedSecondaryIndex: 1,
          secondaryDestinations: const [settings, about],
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          onSecondarySelected: picked.add,
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          child: const FrostShellDestination(child: Text('Page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final more = find.byWidgetPredicate((w) => w is FrostNavItem && w.label == 'L.more');
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('L.more'), findsWidgets);
    expect(tester.widget<FrostClickSurface>(row('About')).focusNode!.hasPrimaryFocus, true);
    expect(tester.getSemantics(find.bySemanticsLabel('About').last).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Settings').last).getSemanticsData().flagsCollection.isChecked, CheckedState.isFalse);
    final tokens = FrostThemeTokens.of(tester.element(row('About')));
    final check = find.descendant(of: row('About'), matching: find.byWidgetPredicate((w) => w is FrostIcon && w.color == tokens.selectionInk));
    expect(tester.getTopLeft(check).dx, greaterThan(tester.getRect(find.text('About').last).right));
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(picked, [0]);
    expect(panel, findsNothing);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(picked, [0]);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('shared overflow entry uses fitted height in compact presentation', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => FrostButton(
            label: 'Open',
            onPressed: () => showFrostValueSheet<int>(
              context: context,
              title: 'L.more',
              value: 1,
              items: const [
                FrostPickerOption(value: 0, label: 'Settings'),
                FrostPickerOption(value: 1, label: 'About'),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(tester.getSize(panel).height, lessThan(400));
    expect(tester.getRect(row('About')).bottom, tester.getRect(panel).bottom - 20);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone secondary destinations remain absent as explicitly requested', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [home],
          selectedIndex: 0,
          secondaryDestinations: const [settings],
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          child: const FrostShellDestination(child: Text('Page')),
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('L.more'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
