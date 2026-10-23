import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';
import 'support.dart';

void main() {
  testWidgets('Cupertino owns edge swipe; media Hero cancels then returns into a visible card', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1, sourceRadius: BorderRadius.zero);
    var shown = false;
    late StateSetter set;
    const card = ValueKey('ios card');
    Widget picture(bool detail) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox.square(
        dimension: detail ? 300 : 80,
        child: FrostMediaHero(
          tag: tag,
          radius: BorderRadius.zero,
          child: ColoredBox(key: detail ? null : card, color: Colors.red),
        ),
      ),
    );
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, update) {
            set = update;
            return Navigator(
              key: nav,
              observers: [HeroController()],
              onDidRemovePage: (_) => set(() => shown = false),
              pages: [
                MaterialPage<void>(child: Scaffold(body: picture(false))),
                if (shown)
                  FrostDetailPage<void>.media(
                    key: const ValueKey('ios detail'),
                    child: Scaffold(body: picture(true)),
                  ),
              ],
            );
          },
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    set(() => shown = true);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPageTransition), findsWidgets);
    final first = await tester.startGesture(const Offset(1, 400));
    await first.moveBy(const Offset(100, 0), timeStamp: const Duration(milliseconds: 400));
    await tester.pump();
    expect(nav.currentState!.userGestureInProgress, isTrue);
    expect(find.byType(Image), findsOneWidget);
    await first.moveBy(const Offset(-85, 0), timeStamp: const Duration(milliseconds: 800));
    await first.up(timeStamp: const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(nav.currentState!.canPop(), isTrue);
    expect(find.byType(Image), findsNothing);
    final second = await tester.startGesture(const Offset(1, 400));
    await second.moveBy(const Offset(320, 0), timeStamp: const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await second.up(timeStamp: const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(nav.currentState!.canPop(), isFalse);
    expect(find.byKey(card).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
