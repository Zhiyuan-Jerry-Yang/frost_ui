import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final maxWidth in [null, 800.0, double.infinity]) {
    testWidgets('browse header and slivers share first-frame width maxWidth=$maxWidth', (tester) async {
      tester.view.physicalSize = const Size(2200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const headerKey = ValueKey('header'), bodyKey = ValueKey('body');
      const header = SizedBox(key: headerKey, width: double.infinity, height: 52);
      const slivers = [
        SliverToBoxAdapter(
          child: SizedBox(key: bodyKey, width: double.infinity, height: 100),
        ),
      ];
      await tester.pumpWidget(
        frostTestApp(
          maxWidth == null
              ? const FrostBrowseLayout(header: header, slivers: slivers)
              : FrostBrowseLayout(header: header, slivers: slivers, maxWidth: maxWidth),
        ),
      );
      final heading = tester.getRect(find.byKey(headerKey));
      final body = tester.getRect(find.byKey(bodyKey));
      expect(body.left, heading.left);
      expect(body.right, heading.right);
      expect(body.top, heading.bottom);
      final outer = maxWidth ?? FrostMetrics.contentMaxWidth;
      expect(heading.width, (outer.isFinite ? outer : 2200) - 40);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [1024.0, 1440.0, 1920.0]) {
    for (final direction in TextDirection.values) {
      for (final inset in FrostBrowseContentInset.values) {
        testWidgets('media edge and text keyline remain distinct at $width/$direction/$inset', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          const header = ValueKey('edge-header'), filter = ValueKey('edge-filter'), media = ValueKey('edge-media');
          await tester.pumpWidget(
            frostTestApp(
              Directionality(
                textDirection: direction,
                child: FrostShell(
                  atDestinationRoot: true,
                  showsMobileNavigation: true,
                  canGoBack: false,
                  onBack: () {},
                  destinations: [FrostNavDestination(icon: testIcons.image, label: 'Home')],
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  sidebarStyle: const FrostSidebarStyle.inset(),
                  child: FrostBrowseLayout(
                    maxWidth: double.infinity,
                    contentInset: inset,
                    header: const SizedBox(key: header, height: 52, width: double.infinity),
                    filterBar: const SizedBox(key: filter, height: 32, width: double.infinity),
                    slivers: const [
                      SliverToBoxAdapter(
                        child: SizedBox(key: media, height: 1400, width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          final page = tester.getRect(find.byType(FrostContentViewport));
          final h = tester.getRect(find.byKey(header)), f = tester.getRect(find.byKey(filter)), m = tester.getRect(find.byKey(media));
          expect(page.right, width);
          expect(page.left - tester.getRect(find.byType(FrostNavItem).first).right, 8);
          expect(h.left, f.left);
          expect(h.right, f.right);
          expect(m.top, f.bottom);
          expect(m.left, inset == FrostBrowseContentInset.edge ? page.left : h.left);
          expect(m.right, inset == FrostBrowseContentInset.edge ? page.right - 8 : h.right);
          final panel = tester.widget<FrostSurface>(find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.panel));
          expect(panel.borderRadius, BorderRadius.circular(FrostRadius.lg));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('edge media retains a finite configured column cap', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        const FrostBrowseLayout(
          maxWidth: 800,
          contentInset: FrostBrowseContentInset.edge,
          header: SizedBox(height: 52),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(key: ValueKey('capped'), height: 100, width: double.infinity),
            ),
          ],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const ValueKey('capped'))).width, 800);
  });
  test('browse rejects nonpositive and NaN width limits', () {
    for (final width in [0.0, -1.0, double.nan]) {
      expect(() => FrostBrowseLayout(header: const SizedBox(), slivers: const [], maxWidth: width), throwsAssertionError);
    }
  });
}
