import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'shell_v2_test.dart' show shell;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _metrics = FrostNavigationMetrics(railWidth: 56, expandedWidth: 220, expandableMinWidth: 900, mobileMaxWidth: 600);

void main() {
  for (final sidebarStyle in [
    const FrostSidebarStyle.inset(),
    const FrostSidebarStyle.capsule(),
    const FrostSidebarStyle.flush(),
    const FrostSidebarStyle.flush(itemForm: FrostNavItemForm.indicator),
  ]) {
    for (final direction in TextDirection.values) {
      testWidgets('sidebar fixed expanded layout $sidebarStyle / $direction', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final window = FakeWindow();
        addTearDown(window.dispose);
        var initializations = 0;
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: FrostWindowCaptionScope(
                window: window,
                child: FrostShell(
                  metrics: _metrics,
                  sidebarStyle: sidebarStyle,
                  destinations: [FrostNavDestination(icon: testIcons.image, label: 'Browse destination')],
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  atDestinationRoot: true,
                  showsMobileNavigation: true,
                  canGoBack: false,
                  onBack: () {},
                  brand: const SizedBox(key: ValueKey('brand'), width: 120, height: 20),
                  child: _StateProbe(onInit: () => initializations++),
                ),
              ),
            ),
          ),
        );
        final nav = find.byType(FrostNavItem);
        final hit = find.descendant(of: nav, matching: find.byType(FrostClickSurface));
        final graphic = find.descendant(of: nav, matching: find.byType(FrostIcon)).first;
        final label = find.text('Browse destination');
        final samples = <Map<String, double>>[];
        Map<String, double> sample() {
          final pane = tester.getRect(find.byType(FrostContentViewport));
          final ink = tester.getRect(hit);
          return {
            'pane': pane.left - sidebarStyle.margin(tester.element(nav)).left - sidebarStyle.gutter,
            'inkX': ink.left,
            'inkWidth': ink.width,
            'iconX': tester.getCenter(graphic).dx,
            'toggleX': tester.getCenter(find.byType(FrostButton)).dx,
            'backX': tester.getCenter(find.byKey(const ValueKey('frost-shell-back'))).dx,
            'brandX': tester.getTopLeft(find.byKey(const ValueKey('brand'))).dx,
            if (label.evaluate().isNotEmpty) 'textX': tester.getTopLeft(label).dx,
            if (label.evaluate().isNotEmpty) 'textWidth': tester.getSize(label).width,
          };
        }

        await tester.tap(findFrostTooltip('L.expandNavigation'));
        await tester.pump();
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          samples.add(sample());
        }
        final expanded = sample();
        await tester.tap(findFrostTooltip('L.collapseNavigation'));
        await tester.pump();
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          samples.add(sample());
        }
        debugPrintSynchronously('R8 sidebar frame trace: ${jsonEncode(samples)}');
        for (var index = 0; index < samples.length; index++) {
          final current = samples[index];
          expect(current['toggleX'], closeTo(28 + sidebarStyle.margin(tester.element(nav)).left, .001));
          expect(current['backX'], expanded['backX']);
          expect(current['brandX'], expanded['brandX']);
          expect(current['iconX'], closeTo(28 + sidebarStyle.margin(tester.element(nav)).left, .001));
          if (index > 0 && index != 60) {
            expect(index < 60 ? current['pane']! >= samples[index - 1]['pane']! : current['pane']! <= samples[index - 1]['pane']!, isTrue);
          }
          if (current['pane']! > 56 && current['pane']! < 220) {
            expect(
              current['inkX'],
              closeTo(8 + sidebarStyle.margin(tester.element(nav)).left, .001),
              reason: 'The highlight must not shift sideways while the rail expands.',
            );
            expect(current['textX'], closeTo(expanded['textX']!, .001));
            expect(current['textWidth'], closeTo(expanded['textWidth']!, .001), reason: 'Clip the fixed expanded text layout instead of compressing it.');
          }
        }
        expect(initializations, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('reduced sidebar motion switches directly and preserves content', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var initializations = 0;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: shell(child: _StateProbe(onInit: () => initializations++)),
          ),
        ),
      ),
    );
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 176);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 176);
    await tester.tap(findFrostTooltip('L.collapseNavigation'));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 80);
    expect(initializations, 1);
    expect(tester.takeException(), isNull);
  });
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
