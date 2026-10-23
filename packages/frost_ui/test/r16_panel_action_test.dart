import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/overlays/panel_action.dart';

import 'support.dart';

void main() {
  testWidgets('duplicate requests share closure, a removed owner discards navigation, and a covered panel can retry', (tester) async {
    final closing = Completer<bool>();
    late BuildContext panel, origin;
    var calls = 0, closes = 0;
    Future<void> host(Future<bool> Function() close) => tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            origin = context;
            return FrostPanelActionScope(
              origin: origin,
              close: close,
              child: Builder(
                builder: (context) {
                  panel = context;
                  return const Text('Panel');
                },
              ),
            );
          },
        ),
      ),
    );
    await host(() {
      closes++;
      return closing.future;
    });
    final first = closeFrostPanelThen(panel, (_) => calls++);
    final second = closeFrostPanelThen(panel, (_) => calls++);
    expect(identical(first, second), isTrue);
    closing.complete(true);
    await first;
    expect(closes, 1);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    final removed = Completer<bool>();
    await host(() => removed.future);
    final pending = closeFrostPanelThen(panel, (_) => calls++);
    await tester.pumpWidget(const SizedBox());
    removed.complete(true);
    await pending;
    expect(calls, 1);
    var available = false;
    await host(() async => available);
    await closeFrostPanelThen(panel, (_) => calls++);
    expect(calls, 1);
    available = true;
    await closeFrostPanelThen(panel, (_) => calls++);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  for (final nested in [false, true]) {
    testWidgets('an explicit panel action closes before page navigation nested=$nested', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      final nestedNavigator = GlobalKey<NavigatorState>();
      var closed = false;
      late BuildContext origin;
      final app = MaterialApp(
        navigatorKey: navigator,
        theme: FrostTheme.build(
          config: testConfig,
          brightness: Brightness.light,
          platform: TargetPlatform.android,
          locale: const Locale('en'),
          density: FrostDensity.comfortable,
        ),
        home: Builder(
          builder: (context) {
            origin = context;
            return nested
                ? Navigator(
                    key: nestedNavigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Text('Root')),
                  )
                : const Text('Root');
          },
        ),
      );
      await tester.pumpWidget(FrostScope(config: testConfig, child: app));
      await tester.pumpAndSettle();
      final future = showFrostSheet<void>(
        context: origin,
        detents: const [FrostSheetDetent.fitted],
        builder: (context) => FrostButton(
          label: 'Open page',
          onPressed: () {
            closeFrostPanelThen(context, (_) {
              (nested ? nestedNavigator : navigator).currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Incoming'))));
            });
          },
        ),
      ).then((_) => closed = true);
      await tester.pumpAndSettle();
      // A nested confirmation is still a popup and must not dismiss the panel.
      showFrostDialog<void>(
        context: tester.element(find.text('Open page')),
        builder: (_) => FrostDialog(title: 'Confirm', content: const Text('Question')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Question'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open page'), findsOneWidget);
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.text('Open page').hitTestable(), findsNothing);
      await future;
      await tester.pumpAndSettle();
      expect(find.text('Incoming'), findsOneWidget);
      (nested ? nestedNavigator : navigator).currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open page', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final inspector in [false, true]) {
    testWidgets('page navigation closes ${inspector ? 'inline Inspector' : 'anchored Popover'} without stealing incoming focus', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      final incomingFocus = FocusNode();
      addTearDown(incomingFocus.dispose);
      var open = true;
      var dismissals = 0;
      Widget action() => Builder(
        builder: (context) => FrostButton(
          label: 'Open page',
          onPressed: () => closeFrostPanelThen(context, (_) {
            navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: TextField(autofocus: true, focusNode: incomingFocus)),
              ),
            );
          }),
        ),
      );
      await tester.pumpWidget(
        FrostScope(
          config: testConfig,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) {
                  if (inspector) {
                    return FrostInspector(
                      open: open,
                      onOpenChanged: (value) => setState(() {
                        open = value;
                        dismissals++;
                      }),
                      inspector: action(),
                      child: const Text('Root'),
                    );
                  }
                  return Align(
                    alignment: Alignment.topLeft,
                    child: FrostPopover(
                      builder: (_, focus, toggle) => FrostButtonControl(label: 'Show', focusNode: focus, onPressed: toggle),
                      contentBuilder: (_, _) => action(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!inspector) {
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Open page'));
      await tester.pumpAndSettle();
      expect(incomingFocus.hasFocus, isTrue);
      if (inspector) {
        expect(open, isFalse);
        expect(dismissals, 1);
      }
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open page').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
