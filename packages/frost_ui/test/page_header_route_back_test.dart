import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('a retained root header never gains back or moves while detail enters and returns', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var detail = false;
    late StateSetter update;
    final nav = GlobalKey<NavigatorState>();
    const rootHeader = ValueKey('root header');
    const title = ValueKey('root title');
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostShell(
              showsMobileNavigation: !detail,
              destinations: [FrostNavDestination(icon: testIcons.image, label: 'Home')],
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              canGoBack: detail,
              onBack: () => nav.currentState!.maybePop(),
              atDestinationRoot: !detail,
              child: Navigator(
                key: nav,
                onDidRemovePage: (_) => update(() => detail = false),
                pages: [
                  const MaterialPage<void>(
                    child: Scaffold(
                      body: FrostPageHeader(
                        key: rootHeader,
                        title: Text('Root', key: title),
                      ),
                    ),
                  ),
                  if (detail)
                    const FrostDetailPage<void>(
                      key: ValueKey('detail'),
                      child: Scaffold(body: FrostPageHeader(title: Text('Detail'))),
                    ),
                ],
              ),
            );
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    final root = find.byKey(rootHeader, skipOffstage: false);
    final before = tester.getTopLeft(find.byKey(title));
    update(() => detail = true);
    await tester.pumpAndSettle();
    expect(find.descendant(of: root, matching: find.byType(FrostCompactBackButton, skipOffstage: false), skipOffstage: false), findsNothing);
    nav.currentState!.pop();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      expect(find.descendant(of: root, matching: find.byType(FrostCompactBackButton, skipOffstage: false), skipOffstage: false), findsNothing);
      final visible = find.byKey(title);
      if (visible.evaluate().isNotEmpty) expect(tester.getTopLeft(visible), before);
    }
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(title)), before);
    expect(tester.takeException(), isNull);
  });
}
