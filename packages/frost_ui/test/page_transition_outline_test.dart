import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';

import 'support.dart';

const _page = ValueKey('moving page');
const _deviceCorners = BorderRadius.all(Radius.circular(72));

class _Navigation {
  final navigator = GlobalKey<NavigatorState>();
  final boundary = GlobalKey();
  late StateSetter update;
  late BuildContext pageContext;
  bool shown = false;

  Future<void> mount(
    WidgetTester tester,
    TargetPlatform platform, {
    bool continuous = true,
    bool materialPage = false,
    bool media = false,
    bool panel = true,
    bool reducedMotion = false,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion).applyDisplayCornerRadii(_deviceCorners),
            child: Directionality(
              textDirection: direction,
              child: FrostScope(
                config: testConfig.copyWith(continuousCorners: continuous),
                child: RepaintBoundary(
                  key: boundary,
                  child: Builder(
                    builder: (context) {
                      final content = StatefulBuilder(
                        builder: (context, setState) {
                          update = setState;
                          final child = Builder(
                            builder: (context) {
                              pageContext = context;
                              return const ColoredBox(key: _page, color: Colors.red, child: _PageProbe());
                            },
                          );
                          return Navigator(
                            key: navigator,
                            pages: [
                              const MaterialPage<void>(child: ColoredBox(color: Color(0xff0000ff))),
                              if (shown)
                                if (materialPage)
                                  MaterialPage<void>(child: child)
                                else if (media)
                                  FrostDetailPage<void>.media(child: child)
                                else
                                  FrostDetailPage<void>(child: child),
                            ],
                            onDidRemovePage: (_) => update(() => shown = false),
                          );
                        },
                      );
                      return panel
                          ? FrostShell(
                              destinations: [FrostNavDestination(icon: testIcons.back, label: 'Home')],
                              selectedIndex: 0,
                              showsMobileNavigation: true,
                              atDestinationRoot: true,
                              canGoBack: true,
                              onBack: () => navigator.currentState!.pop(),
                              onDestinationSelected: (_) {},
                              child: content,
                            )
                          : content;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();
    update(() => shown = true);
    await tester.pump();
  }

  Future<void> expectMovingOutline(WidgetTester tester) async {
    final rect = tester.getRect(find.byKey(_page));
    final boundaryBox = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final origin = boundaryBox.globalToLocal(rect.topLeft);
    final samples = (await tester.runAsync(() async {
      final image = await boundaryBox.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int red(double x, double y) => bytes.getUint8(((origin.dy + y).round() * image.width + (origin.dx + x).round()) * 4);
      final rtl = Directionality.of(pageContext) == TextDirection.rtl;
      final edge = rect.width - FrostPageOutline.channelOf(pageContext);
      final corner = rtl ? edge - 2 : 1.0;
      final inside = rtl ? edge - 25 : 24.0;
      final values = [red(corner, 1), red(inside, 2), red(corner, rect.height - 2), red(inside, rect.height - 3)];
      image.dispose();
      return values;
    }))!;
    expect(samples[0], lessThan(10), reason: 'the upper moving corner must expose the underlay');
    expect(samples[1], greaterThan(15), reason: 'the panel edge must not be cut by the physical screen radius');
    expect(samples[2], lessThan(10), reason: 'the lower moving corner must expose the underlay');
    expect(samples[3], greaterThan(15));
    expect(MediaQuery.displayCornerRadiiOf(pageContext), _deviceCorners, reason: 'page content must retain real device geometry');
  }
}

Future<void> _androidGesture(WidgetTester tester, String method, [double? progress]) async {
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
  await tester.pump();
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final continuous in [true, false]) {
      for (final material in [true, false]) {
        testWidgets('$platform moving outline survives ordinary push/pop continuous=$continuous material=$material', (tester) async {
          final navigation = _Navigation();
          await navigation.mount(tester, platform, continuous: continuous, materialPage: material);
          await tester.pump(const Duration(milliseconds: 40));
          await navigation.expectMovingOutline(tester);
          await tester.pumpAndSettle();
          navigation.navigator.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
          await navigation.expectMovingOutline(tester);
          await tester.pumpAndSettle();
          expect(navigation.shown, isFalse);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final continuous in [true, false]) {
    testWidgets('Android native predictive cancel/commit keeps panel geometry continuous=$continuous', (tester) async {
      final navigation = _Navigation();
      await navigation.mount(tester, TargetPlatform.android, continuous: continuous);
      await tester.pumpAndSettle();
      for (final commit in [false, true]) {
        await _androidGesture(tester, 'startBackGesture', 0);
        await _androidGesture(tester, 'updateBackGestureProgress', .5);
        expect(navigation.navigator.currentState!.userGestureInProgress, isTrue);
        await navigation.expectMovingOutline(tester);
        await _androidGesture(tester, commit ? 'commitBackGesture' : 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(navigation.navigator.currentState!.userGestureInProgress, isFalse);
        expect(navigation.shown, !commit);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    testWidgets('iOS native edge swipe can cancel and commit $direction', (tester) async {
      final navigation = _Navigation();
      await navigation.mount(tester, TargetPlatform.iOS, media: true, direction: direction);
      await tester.pumpAndSettle();
      for (final commit in [false, true]) {
        final rect = tester.getRect(find.byKey(_page));
        final rtl = direction == TextDirection.rtl;
        final start = Offset(rtl ? rect.right - 1 : rect.left + 1, rect.center.dy);
        final gesture = await tester.startGesture(start);
        await gesture.moveBy(Offset((rtl ? -1 : 1) * rect.width * .3, 0));
        await tester.pump();
        expect(navigation.navigator.currentState!.userGestureInProgress, isTrue);
        await navigation.expectMovingOutline(tester);
        if (commit) {
          await gesture.moveBy(Offset((rtl ? -1 : 1) * rect.width * .4, 0));
        } else {
          await gesture.moveTo(start);
        }
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(navigation.navigator.currentState!.userGestureInProgress, isFalse);
        expect(navigation.shown, !commit);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform retains page state through wide/compact resizing', (tester) async {
      final navigation = _Navigation();
      await navigation.mount(tester, platform);
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(_PageProbe));
      for (final width in [500.0, 1024.0]) {
        tester.view.physicalSize = Size(width, 768);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(_PageProbe)), same(state));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fullscreen Android predictive back retains native display corners', (tester) async {
    final navigation = _Navigation();
    await navigation.mount(tester, TargetPlatform.android, panel: false);
    await tester.pumpAndSettle();
    await _androidGesture(tester, 'startBackGesture', 0);
    await _androidGesture(tester, 'updateBackGestureProgress', .5);
    final clips = tester.widgetList<ClipRRect>(find.ancestor(of: find.byKey(_page), matching: find.byType(ClipRRect)));
    expect(clips.any((clip) => clip.borderRadius == _deviceCorners), isTrue);
    await _androidGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(navigation.shown, isTrue);
  });

  testWidgets('reduced motion retains settled shell corners without a gesture transition', (tester) async {
    final navigation = _Navigation();
    await navigation.mount(tester, TargetPlatform.iOS, reducedMotion: true);
    await tester.pumpAndSettle();
    expect(ModalRoute.of(navigation.pageContext)!.animation!.value, 1);
    expect(FrostPageOutline.of(navigation.pageContext), isNot(BorderRadius.zero));
    navigation.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(navigation.shown, isFalse);
  });
}

class _PageProbe extends StatefulWidget {
  const _PageProbe();
  @override
  State<_PageProbe> createState() => _PageProbeState();
}

class _PageProbeState extends State<_PageProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
