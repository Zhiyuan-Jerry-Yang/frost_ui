import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';
import 'support.dart';

void main() {
  testWidgets('hero source identity is local to the card and stable across rebuilds', (tester) async {
    final tags = <FrostMediaHeroTag>[];
    late StateSetter update;
    var identity = 'one', ratio = 2.0;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostMediaHeroSource(
              image: mediaTestImage,
              aspectRatio: ratio,
              sourceRadius: FrostRadius.borderRadius(FrostRadius.lg),
              identity: identity,
              builder: (_, tag) {
                tags.add(tag);
                return const SizedBox();
              },
            );
          },
        ),
      ),
    );
    final initial = tags.last;
    update(() => ratio = 3);
    await tester.pump();
    expect(tags.last, same(initial));
    expect(initial.aspectRatio, 3);
    update(() => identity = 'two');
    await tester.pump();
    expect(tags.last, isNot(same(initial)));
    expect(FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 3, sourceRadius: BorderRadius.zero), isNot(tags.last));
  });

  Future<void> scene(WidgetTester tester, {bool reduced = false}) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: Scaffold(
              body: Row(
                children: [
                  for (var index = 0; index < 2; index++)
                    FrostMediaHeroSource(
                      image: mediaTestImage,
                      identity: 'same-work',
                      aspectRatio: 3,
                      sourceRadius: FrostRadius.borderRadius(FrostRadius.lg),
                      builder: (context, tag) => GestureDetector(
                        key: ValueKey('open-$index'),
                        onTap: () => Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            transitionDuration: FrostMotion.standardDuration,
                            pageBuilder: (context, _, _) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
                              child: Scaffold(
                                body: Center(
                                  child: SizedBox(
                                    width: 300,
                                    height: 240,
                                    child: FrostMediaHero(
                                      tag: tag,
                                      radius: BorderRadius.zero,
                                      fit: BoxFit.contain,
                                      child: ColoredBox(key: ValueKey('destination-$index'), color: Colors.blue),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            transitionsBuilder: (_, _, _, child) => child,
                          ),
                        ),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: FrostMediaHero(
                            tag: tag,
                            radius: FrostRadius.borderRadius(FrostRadius.lg),
                            child: ColoredBox(key: ValueKey('picture-$index'), color: index == 0 ? Colors.red : Colors.green),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('only tapped duplicate flies, with intermediate radius and continuous cover contain framing', (tester) async {
    await scene(tester);
    await tester.tap(find.byKey(const ValueKey('open-1')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.takeException(), isNull);
    final picture = find.byType(Image);
    expect(picture, findsOneWidget);
    expect(tester.widget<Image>(picture).image, same(mediaTestImage));
    expect(find.byKey(const ValueKey('picture-1')), findsNothing);
    final flightState = tester.state(picture);
    final clip = find.ancestor(of: picture, matching: find.byType(ClipRRect)).first;
    final radius = tester.widget<ClipRRect>(clip).borderRadius.resolve(TextDirection.ltr).topLeft.x;
    expect(radius, inExclusiveRange(0, 12));
    final frame = tester.getSize(clip);
    final canvas = tester.getSize(picture);
    final coverWidth = frame.height * 3;
    final containWidth = frame.width;
    expect(canvas.width, inExclusiveRange(containWidth, coverWidth));
    expect(canvas.width / canvas.height, closeTo(3, .0001));
    await tester.pump(const Duration(milliseconds: 15));
    expect(tester.state(picture), same(flightState));
    // The untapped duplicate never becomes a shuttle.
    final otherClip = find.ancestor(of: find.byKey(const ValueKey('picture-0')), matching: find.byType(ClipRSuperellipse)).first;
    expect(tester.widget<ClipRSuperellipse>(otherClip).borderRadius.resolve(TextDirection.ltr).topLeft.x, 12);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('destination-1'))), const Size(300, 100));
    Navigator.of(tester.element(find.byKey(const ValueKey('destination-1')))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('picture-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced hero has no flight and incoming media fades over reducedFade', (tester) async {
    await scene(tester, reduced: true);
    await tester.tap(find.byKey(const ValueKey('open-1')));
    await tester.pump();
    await tester.pump();
    final destinationHero = find.ancestor(of: find.byKey(const ValueKey('destination-1')), matching: find.byType(FrostMediaHero));
    final fade = find.descendant(of: destinationHero, matching: find.byType(FadeTransition));
    expect(tester.renderObject<RenderAnimatedOpacity>(fade).opacity.value, 0);
    await tester.pump(FrostMotion.reducedFade ~/ 2);
    expect(tester.renderObject<RenderAnimatedOpacity>(fade).opacity.value, inExclusiveRange(0, 1));
    expect(tester.getSize(find.byKey(const ValueKey('destination-1'))), const Size(300, 100));
    expect(tester.widget<HeroMode>(find.descendant(of: destinationHero, matching: find.byType(HeroMode))).enabled, isFalse);
    await tester.pumpAndSettle();
    expect(tester.renderObject<RenderAnimatedOpacity>(fade).opacity.value, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared media gesture continues its Hero and restores source on landing', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    final heroController = HeroController();
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1, sourceRadius: BorderRadius.zero);
    var shown = false;
    late StateSetter update;
    const source = ValueKey('predictive source');
    const detail = ValueKey('predictive detail');
    Widget picture(Key key, double extent) => SizedBox(
      width: extent,
      height: extent,
      child: FrostMediaHero(
        tag: tag,
        radius: BorderRadius.zero,
        fit: BoxFit.contain,
        child: ColoredBox(key: key, color: Colors.red),
      ),
    );
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Navigator(
              key: navigator,
              observers: [heroController],
              pages: [
                MaterialPage<void>(
                  child: Scaffold(
                    body: Align(alignment: Alignment.topLeft, child: picture(source, 100)),
                  ),
                ),
                if (shown)
                  FrostDetailPage<void>.media(
                    key: const ValueKey('detail page'),
                    child: Scaffold(body: Center(child: picture(detail, 300))),
                  ),
              ],
              onDidRemovePage: (_) => update(() => shown = false),
            );
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    update(() => shown = true);
    await tester.pumpAndSettle();
    Future<void> gesture(String method, [double? progress]) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(
            method,
            progress == null
                ? null
                : {
                    'touchOffset': [20 + progress * 200, 300.0],
                    'progress': progress,
                    'swipeEdge': 0,
                  },
          ),
        ),
        (_) {},
      );
    }

    await gesture('startBackGesture', 0);
    await tester.pump();
    await gesture('updateBackGestureProgress', .5);
    await tester.pump();
    expect(navigator.currentState!.userGestureInProgress, isTrue);
    await gesture('cancelBackGesture');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(detail)), const Size(300, 300));
    expect(navigator.currentState!.userGestureInProgress, isFalse);
    await gesture('startBackGesture', 0);
    await tester.pump();
    await gesture('updateBackGestureProgress', .5);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget, reason: 'Predictive back continues a single Hero shuttle.');
    final release = tester.getRect(find.byType(Image));
    await gesture('commitBackGesture');
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getRect(find.byType(Image)), release);
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(find.byType(Image)).width, lessThan(release.width));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(source)), const Size(100, 100));
    expect(tester.takeException(), isNull);
  });
}
