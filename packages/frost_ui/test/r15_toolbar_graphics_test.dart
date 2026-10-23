import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/toolbar_menu_button.dart';
import 'support.dart';

void main() {
  testWidgets('media header keeps complete circular targets inside both edges and fixed height', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: FrostOnMediaChromeScope(
            child: FrostPageHeader(
              onBack: () {},
              actions: [FrostToolbarItem.action(icon: testIcons.more, label: 'More', onPressed: () {})],
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    expect(tester.getSize(find.byType(FrostPageHeader)).height, 48);
    for (final label in ['L.back', 'More']) {
      final rect = tester.getRect(find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == label).hitTestable());
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(rect.width, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final density in FrostDensity.values) {
      for (final direction in TextDirection.values) {
        testWidgets('toolbar graphics share centered square plates $platform $density $direction', (tester) async {
          tester.view.physicalSize = const Size(390, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var downloads = 0;
          await tester.pumpWidget(
            frostTestApp(
              Directionality(
                textDirection: direction,
                child: FrostPageHeader(
                  title: const Text('Source'),
                  actions: [
                    FrostToolbarItem.action(label: 'Filter', icon: testIcons.search, onPressed: () {}),
                    FrostToolbarItem.action(label: 'Download', icon: testIcons.download, onPressed: () => downloads++),
                    FrostToolbarItem.menu(
                      label: 'More',
                      icon: testIcons.more,
                      showsLabel: false,
                      entries: [FrostMenuAction('Choice', onSelected: () {})],
                    ),
                  ],
                ),
              ),
              density: density,
              platform: platform,
            ),
          );
          Rect plate(String label) => tester.getRect(
            find.descendant(
              of: find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == label).hitTestable(),
              matching: find.byType(FrostClickSurface),
            ),
          );
          Rect graphic(String label) => tester.getRect(
            find.descendant(of: find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == label).hitTestable(), matching: find.byType(FrostIcon)),
          );
          for (final label in ['Filter', 'Download', 'More']) {
            expect(graphic(label).center, plate(label).center, reason: 'The glyph must not change alignment at the last item.');
            expect(plate(label).width, plate(label).height, reason: 'Pure icon controls use the shared icon plate.');
          }
          expect(
            (graphic('Download').center.dx - graphic('Filter').center.dx).abs(),
            closeTo((graphic('More').center.dx - graphic('Download').center.dx).abs(), .001),
          );
          final gesture = await tester.startGesture(plate('Download').center);
          await tester.pump(const Duration(milliseconds: 700));
          expect(graphic('Download').center, plate('Download').center);
          expect(plate('Download').width, plate('Download').height);
          await gesture.cancel();
          await tester.pumpAndSettle();
          final target = tester.getRect(find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == 'Download').hitTestable());
          expect(target.width, greaterThanOrEqualTo(platform == TargetPlatform.android ? 44 : 36));
          for (final label in ['Filter', 'Download', 'More']) {
            final rect = tester.getRect(find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == label).hitTestable());
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(390));
          }
          for (final point in [
            target.topLeft + const Offset(1, 1),
            target.topRight + const Offset(-1, 1),
            target.bottomLeft + const Offset(1, -1),
            target.bottomRight - const Offset(1, 1),
          ]) {
            await tester.tapAt(point);
            await tester.pumpAndSettle();
          }
          expect(downloads, 4, reason: 'Every corner of the minimum target remains inside the scroll viewport.');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
