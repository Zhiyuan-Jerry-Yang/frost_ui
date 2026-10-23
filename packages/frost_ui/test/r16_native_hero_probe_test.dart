import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'media_test_image.dart';
import 'r14_predictive_back_test.dart' show gesture;
import 'support.dart';

void main() {
  for (final progress in [.05, .2, .4, .5, .8]) {
    for (final cancel in [false, true]) {
      testWidgets('media Hero continuous commit/cancel progress=$progress cancel=$cancel', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final nav = GlobalKey<NavigatorState>();
        final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1, sourceRadius: BorderRadius.zero);
        const card = ValueKey('card');
        Widget hero({required bool detail}) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: detail ? 0 : 40, top: detail ? 0 : 400),
            child: SizedBox.square(
              dimension: detail ? 400 : 80,
              child: FrostMediaHero(
                tag: tag,
                radius: BorderRadius.zero,
                child: ColoredBox(key: detail ? null : card, color: Colors.red),
              ),
            ),
          ),
        );
        var shown = false;
        late StateSetter update;
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (context, set) {
                update = set;
                return Navigator(
                  key: nav,
                  observers: [HeroController()],
                  onDidRemovePage: (_) => update(() => shown = false),
                  pages: [
                    MaterialPage<void>(child: Scaffold(body: hero(detail: false))),
                    if (shown)
                      FrostDetailPage<void>.media(
                        key: const ValueKey('media page'),
                        child: Scaffold(body: hero(detail: true)),
                      ),
                  ],
                );
              },
            ),
            platform: TargetPlatform.android,
          ),
        );
        update(() => shown = true);
        await tester.pumpAndSettle();
        await gesture(tester, 'startBackGesture', 0);
        await tester.pump();
        await gesture(tester, 'updateBackGestureProgress', progress);
        await tester.pump();
        Rect flight() => tester.getRect(find.byType(Image));
        final release = flight();
        final content = tester.widget<FrostMaterialReveal>(find.ancestor(of: find.byType(Scaffold).last, matching: find.byType(FrostMaterialReveal)).first);
        expect(content.opacity, closeTo(1 - progress, .001), reason: 'A held gesture retains 80% content at 20% and half at 50%.');
        expect(release.width, lessThan(400));
        await gesture(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
        await tester.pump();
        expect(flight().width, closeTo(release.width, .001));
        expect(flight().top, closeTo(release.top, .001));
        expect(nav.currentState!.userGestureInProgress, isTrue);
        var previous = release;
        for (var frame = 0; frame < 150; frame++) {
          await tester.pump(const Duration(milliseconds: 4));
          if (find.byType(Image).evaluate().isEmpty) {
            if (!cancel) expect(find.byKey(card).hitTestable(), findsOneWidget, reason: 'The first landing frame must paint the card.');
            break;
          }
          final current = flight();
          expect(current.width, cancel ? greaterThanOrEqualTo(previous.width - .001) : lessThanOrEqualTo(previous.width + .001));
          expect(current.top, cancel ? lessThanOrEqualTo(previous.top + .001) : greaterThanOrEqualTo(previous.top - .001));
          previous = current;
        }
        await tester.pumpAndSettle();
        expect(nav.currentState!.canPop(), cancel);
        expect(nav.currentState!.userGestureInProgress, isFalse);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
