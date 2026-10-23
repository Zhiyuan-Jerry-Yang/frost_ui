import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';
import 'support.dart';

void main() {
  testWidgets('button return canvas follows its rendered endpoints', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    final heroes = HeroController();
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 2935 / 4096, sourceRadius: BorderRadius.zero);
    var detail = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return TweenAnimationBuilder<double>(
              tween: Tween(end: detail ? 900 : 820),
              duration: const Duration(milliseconds: 140),
              builder: (context, height, child) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(height: height, child: child),
              ),
              child: Navigator(
                key: nav,
                observers: [heroes],
                onDidRemovePage: (_) => update(() => detail = false),
                pages: [
                  MaterialPage<void>(
                    key: const ValueKey('home'),
                    child: Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.only(top: 140, left: 200),
                        child: SizedBox(
                          width: 180,
                          height: 180 * 4096 / 2935,
                          child: FrostMediaHero(
                            tag: tag,
                            radius: BorderRadius.zero,
                            child: const ColoredBox(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (detail)
                    FrostDetailPage<void>(
                      key: const ValueKey('page'),
                      child: Scaffold(
                        body: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 400,
                            height: 400 * 4096 / 2935,
                            child: FrostMediaHero(
                              tag: tag,
                              radius: BorderRadius.zero,
                              fit: BoxFit.contain,
                              child: const ColoredBox(key: ValueKey('stage'), color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    update(() => detail = true);
    await tester.pumpAndSettle();
    final origin = tester.getRect(find.byKey(const ValueKey('stage')));
    nav.currentState!.pop();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 8));
    expect(find.byType(Image), findsOneWidget);
    var previous = origin.top;
    for (var frame = 0; frame < 30 && find.byType(Image).evaluate().isNotEmpty; frame++) {
      final rect = tester.getRect(find.byType(Image));
      final clip = find.ancestor(of: find.byType(Image), matching: find.byType(ClipRRect)).first;
      expect(tester.getSize(clip).height, closeTo(rect.height, .001), reason: 'Resizing the Navigator must not crop the flying image.');
      expect(rect.top, greaterThanOrEqualTo(previous - .001));
      previous = rect.top;
      await tester.pump(const Duration(milliseconds: 8));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
