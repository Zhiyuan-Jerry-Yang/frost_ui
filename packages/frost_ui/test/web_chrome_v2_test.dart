import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_dynamic_icon_button.dart';

import 'support.dart';

Widget web({
  bool loading = false,
  double? progress,
  bool back = true,
  bool forward = true,
  VoidCallback? onBack,
  VoidCallback? onForward,
  VoidCallback? reload,
  VoidCallback? stop,
  VoidCallback? open,
}) => FrostWebChrome(
  web: const ColoredBox(key: ValueKey('web'), color: Colors.white),
  title: 'Page title',
  url: Uri.parse('https://example.test/private/path?q=secret'),
  loading: loading,
  progress: progress,
  canGoBack: back,
  canGoForward: forward,
  onBack: onBack ?? () {},
  onForward: onForward ?? () {},
  onReload: reload ?? () {},
  onStop: stop ?? () {},
  onOpenInBrowser: open,
);
Widget view(Widget child, {double width = 800, double scale = 1}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: Size(width, 600), textScaler: TextScaler.linear(scale)),
    child: Center(
      child: SizedBox(width: width, height: 400, child: child),
    ),
  ),
);
Finder action(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label && w.properties.button == true).hitTestable();
Future<void> mount(WidgetTester tester, Widget child) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
  await tester.pumpWidget(child);
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('application action shares one header and preserves browser content at $width', (tester) async {
      var calls = 0, enabled = true;
      late StateSetter update;
      await mount(
        tester,
        view(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostWebChrome(
                web: const SizedBox.expand(key: ValueKey('app-web')),
                actions: [
                  FrostToolbarItem.action(
                    label: 'Finish',
                    icon: testIcons.check,
                    priority: FrostToolbarPriority.high,
                    onPressed: enabled ? () => calls++ : null,
                  ),
                ],
              );
            },
          ),
          width: width,
          scale: 2,
        ),
      );
      final body = tester.renderObject(find.byKey(const ValueKey('app-web')));
      expect(find.byType(FrostPageHeader), findsOneWidget);
      await tester.tap(action('Finish'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      expect(identical(tester.renderObject(find.byKey(const ValueKey('app-web'))), body), true);
      await tester.tap(action('Finish'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('shared header title/domain and web fills remaining height', (tester) async {
    await mount(tester, view(web(open: () {})));
    expect(find.byType(FrostPageHeader), findsOneWidget);
    expect(find.text('Page title'), findsOneWidget);
    expect(find.text('example.test'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    expect(tester.getSize(find.byType(FrostPageHeader)).height, 52);
    final header = tester.getRect(find.byType(FrostPageHeader)), body = tester.getRect(find.byKey(const ValueKey('web')));
    expect(body.top, header.bottom);
    expect(body.height, 348);
    expect(action('L.close'), findsNothing);
    expect(action('L.back'), findsOneWidget);
    expect(action('L.forward'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('availability disables both navigation buttons without hiding them', (tester) async {
    var back = 0, forward = 0;
    await mount(tester, view(web(back: false, forward: false, onBack: () => back++, onForward: () => forward++)));
    final semantics = tester.ensureSemantics();
    for (final label in ['L.back', 'L.forward']) {
      final node = tester.getSemantics(action(label));
      expect(node.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    }
    await tester.tapAt(tester.getCenter(action('L.back')));
    await tester.tapAt(tester.getCenter(action('L.forward')));
    expect(back, 0);
    expect(forward, 0);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('known progress follows 300/400 gate without moving the web', (tester) async {
    var loading = true;
    StateSetter? update;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return web(loading: loading, progress: .6);
          },
        ),
      ),
    );
    final top = tester.getTopLeft(find.byKey(const ValueKey('web')));
    expect(find.byType(FrostProgressBar), findsNothing);
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.byType(FrostProgressBar), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FrostProgressBar), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('web'))), top);
    update!(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 349));
    expect(find.byType(FrostProgressBar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FrostProgressBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fast load has no indicator; unknown loading still allows stop', (tester) async {
    var loading = true, stops = 0;
    StateSetter? update;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return web(loading: loading, stop: () => stops++);
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    update!(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FrostActivityIndicator).evaluate().where((element) => TickerMode.valuesOf(element).enabled), isEmpty);
    update!(() => loading = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FrostActivityIndicator).evaluate().where((element) => TickerMode.valuesOf(element).enabled), hasLength(1));
    final stop = tester.widget<FrostDynamicIconButton>(find.byWidgetPredicate((w) => w is FrostDynamicIconButton && w.label == 'L.stop'));
    expect(stop.onPressed, isNotNull);
    await tester.tap(action('L.stop'));
    expect(stops, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('close is route close, browser back is independent', (tester) async {
    var backs = 0;
    await mount(
      tester,
      frostTestApp(
        Builder(
          builder: (context) => FrostButton(
            label: 'Push',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => web(onBack: () => backs++))),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(action('L.close'), findsOneWidget);
    expect(action('L.back'), findsOneWidget);
    await tester.tap(action('L.back'));
    expect(backs, 1);
    expect(find.byType(FrostWebChrome), findsOneWidget);
    await tester.tap(action('L.close'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostWebChrome), findsNothing);
  });
  testWidgets('narrow header folds open first then forward and restores in order', (tester) async {
    var width = 800.0;
    StateSetter? update;
    await mount(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return view(web(open: () {}), width: width);
        },
      ),
    );
    expect(action('L.openInBrowser'), findsOneWidget);
    update!(() => width = 220);
    await tester.pump();
    expect(action('L.openInBrowser'), findsNothing);
    expect(action('L.more'), findsOneWidget);
    await tester.pumpAndSettle(); // Keep the first-frame geometry assertion; interact after the layout fade.
    await tester.tap(action('L.more'));
    await tester.pumpAndSettle();
    expect(find.text('L.openInBrowser'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    update!(() => width = 140);
    await tester.pump();
    expect(action('L.forward'), findsNothing);
    update!(() => width = 800);
    await tester.pumpAndSettle();
    expect(action('L.forward'), findsOneWidget);
    expect(action('L.openInBrowser'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text grows shared header and nullable action stays disabled', (tester) async {
    await mount(tester, view(const FrostWebChrome(web: SizedBox(), title: 'Title', canGoBack: true, canGoForward: true), width: 390, scale: 2));
    expect(tester.getSize(find.byType(FrostPageHeader)).height, greaterThan(48));
    final semantics = tester.ensureSemantics();
    for (final label in ['L.back', 'L.forward', 'L.reload']) {
      expect(tester.getSemantics(action(label)).getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    }
    expect(action('L.openInBrowser'), findsNothing);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
