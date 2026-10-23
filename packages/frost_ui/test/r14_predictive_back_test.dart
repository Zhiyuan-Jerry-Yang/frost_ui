import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Future<void> gesture(WidgetTester tester, String method, [double? progress, int edge = 0]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(
        method,
        progress == null
            ? null
            : {
                'touchOffset': [20 + progress * 200, 100 + progress * 300],
                'progress': progress,
                'swipeEdge': edge,
              },
      ),
    ),
    (_) {},
  );
}

void main() {
  for (final enabled in [false, true]) {
    for (final edge in [0, 1]) {
      testWidgets('native preview cancel commit enabled=$enabled edge=$edge', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final navigator = GlobalKey<NavigatorState>();
        var shown = false;
        late StateSetter update;
        const content = ValueKey('page-content');
        await tester.pumpWidget(
          frostTestApp(
            FrostScope(
              config: testConfig.copyWith(predictiveBack: enabled),
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(end: shown ? 800 : 720),
                    duration: const Duration(milliseconds: 140),
                    builder: (context, height, child) => Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(height: height, child: child),
                    ),
                    child: NavigatorPopHandler<void>(
                      onPopWithResult: (_) => navigator.currentState!.pop(),
                      child: Navigator(
                        key: navigator,
                        onDidRemovePage: (_) => update(() => shown = false),
                        pages: [
                          const MaterialPage<void>(child: Scaffold(body: Text('Previous'))),
                          if (shown)
                            const FrostDetailPage<void>(
                              key: ValueKey('detail'),
                              child: ColoredBox(key: content, color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            platform: TargetPlatform.android,
          ),
        );
        update(() => shown = true);
        await tester.pumpAndSettle();
        final rest = tester.getRect(find.byKey(content));
        for (final progress in [.15, .6]) {
          await gesture(tester, 'startBackGesture', 0, edge);
          await tester.pump();
          await gesture(tester, 'updateBackGestureProgress', progress, edge);
          await tester.pump();
          final release = tester.getRect(find.byKey(content));
          if (enabled) {
            expect(release.width, lessThan(rest.width));
            expect(release.width, greaterThan(rest.width * .8));
          } else {
            expect(release, rest, reason: 'Disabled preview holds the page until release.');
          }
          await gesture(tester, 'cancelBackGesture');
          for (var frame = 0; frame < 45; frame++) {
            await tester.pump(const Duration(milliseconds: 8));
            final current = tester.getRect(find.byKey(content));
            expect(current.width, lessThanOrEqualTo(rest.width + .001));
          }
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byKey(content)), rest);
        }
        await gesture(tester, 'startBackGesture', 0, edge);
        await tester.pump();
        await gesture(tester, 'updateBackGestureProgress', .6, edge);
        await tester.pump();
        final release = tester.getRect(find.byKey(content));
        await gesture(tester, 'commitBackGesture');
        await tester.pump();
        // Native commit owns its geometry; R14's frozen 3% pose/right slide
        // is deliberately gone. Both edges must still finish and restore state.
        expect(release.width, greaterThan(0));
        await tester.pumpAndSettle();
        expect(find.byKey(content), findsNothing);
        expect(navigator.currentState!.userGestureInProgress, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
