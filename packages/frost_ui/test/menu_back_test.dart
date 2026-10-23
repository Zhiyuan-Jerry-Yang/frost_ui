import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'support.dart';

void main() {
  testWidgets('a root menu tells Android to dispatch system Back to Flutter', (tester) async {
    final backOwnership = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') backOwnership.add(call.arguments as bool);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      frostTestApp(
        FrostMenuAnchor(
          entries: [FrostMenuAction('Choice', onSelected: () {})],
          builder: (_, focus, toggle) => FrostButton(label: 'Open', onPressed: toggle),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(backOwnership.last, isTrue, reason: 'Local history alone does not publish Android frameworkHandlesBack.');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(backOwnership.last, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  for (final nested in [false, true]) {
    testWidgets('system Back consumes the anchored menu before its route nested=$nested', (tester) async {
      const trigger = ValueKey('menu trigger');
      var shown = true;
      late StateSetter update;
      Widget menu() => Center(
        child: FrostMenuAnchor(
          entries: [FrostMenuAction('Choice', onSelected: () {})],
          builder: (_, focus, toggle) => FrostButton(key: trigger, label: 'Open', onPressed: toggle),
        ),
      );
      await tester.pumpWidget(
        frostTestApp(
          nested
              ? StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    return Navigator(
                      onDidRemovePage: (_) => update(() => shown = false),
                      pages: [
                        const MaterialPage<void>(child: Text('Previous')),
                        if (shown) FrostDetailPage<void>(key: const ValueKey('detail'), child: menu()),
                      ],
                    );
                  },
                )
              : menu(),
        ),
      );
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.byKey(trigger)))!;
      await tester.tap(find.byKey(trigger));
      await tester.pumpAndSettle();
      expect(find.byType(FrostMenuPanel), findsOneWidget);
      expect(route.willHandlePopInternally, isTrue);
      if (!nested) expect(route.impliesAppBarDismissal, isFalse);
      expect(route.popGestureEnabled, isFalse);
      expect(await route.navigator!.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(FrostMenuPanel), findsNothing);
      expect(find.byKey(trigger), findsOneWidget);
      expect(route.isCurrent, isTrue);
      expect(route.willHandlePopInternally, isFalse);
      await tester.tap(find.byKey(trigger));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
