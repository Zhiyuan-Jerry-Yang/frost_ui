import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Finder get _viewport => find.byType(FrostMediaViewport);
TransformationController transform(WidgetTester tester) => tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;
Future<void> host(
  WidgetTester tester, {
  bool reduced = false,
  ValueChanged<bool>? zoom,
  ValueChanged<double>? scale,
  VoidCallback? dismiss,
  FrostMediaViewportController? controller,
}) => tester.pumpWidget(
  frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: FrostMediaViewport(
              controller: controller,
              onZoomChanged: zoom,
              onScaleChanged: scale,
              onDismiss: dismiss,
              background: const ColoredBox(key: ValueKey('background'), color: Colors.blue),
              child: const ColoredBox(key: ValueKey('content'), color: Colors.red, child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    ),
  ),
);
Future<void> doubleTap(WidgetTester tester) async {
  final point = tester.getTopLeft(_viewport) + const Offset(100, 100);
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(point);
  await tester.pump();
}

Future<TestGesture> drag(WidgetTester tester, double distance, {Duration duration = const Duration(milliseconds: 500)}) async {
  final pointer = await tester.startGesture(tester.getTopLeft(_viewport) + const Offset(100, 60));
  await pointer.moveBy(Offset(0, distance), timeStamp: duration);
  await tester.pump();
  return pointer;
}

void main() {
  for (final velocity in [0.0, 1000.0, 10000.0]) {
    testWidgets('dismissal carries the release continuously to offscreen before callback velocity=$velocity', (tester) async {
      var calls = 0;
      await host(tester, dismiss: () => calls++);
      final pointer = await drag(tester, 160);
      await tester.pump(const Duration(milliseconds: 500));
      final interactive = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      final release = tester.getRect(find.byKey(const ValueKey('content')));
      interactive.onInteractionEnd!(ScaleEndDetails(velocity: Velocity(pixelsPerSecond: Offset(0, velocity))));
      await tester.pump();
      expect(tester.getRect(find.byKey(const ValueKey('content'))), release);
      expect(calls, 0);
      double alpha() => tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('content')), matching: find.byType(Opacity)).first).opacity;
      var previous = release.top;
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
        final rect = tester.getRect(find.byKey(const ValueKey('content')));
        expect(rect.top, greaterThan(previous));
        expect(rect.width, closeTo(release.width, .001), reason: 'The completed pull already reached the minimum visual scale.');
        expect(alpha(), closeTo(1 - (frame + 1) * 20 / FrostMotion.exit.inMilliseconds, .001));
        expect(calls, 0);
        previous = rect.top;
      }
      await tester.pump(const Duration(milliseconds: 20));
      expect(alpha(), 0);
      expect(tester.getRect(find.byKey(const ValueKey('content'))).top, greaterThanOrEqualTo(300));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await pointer.cancel();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unmount during dismissal never invokes navigation and reduced motion completes immediately', (tester) async {
    var calls = 0;
    await host(tester, dismiss: () => calls++);
    final pointer = await drag(tester, 160);
    await tester.pump(const Duration(milliseconds: 500));
    await pointer.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls, 0);
    await host(tester, reduced: true, dismiss: () => calls++);
    final reduced = await drag(tester, 160);
    await reduced.up();
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewer overlay stays fixed while media zooms, fades on drag and retains its own action', (tester) async {
    final controller = FrostMediaViewportController();
    var clicks = 0;
    const overlay = ValueKey('viewer overlay');
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 400,
          height: 300,
          child: FrostMediaViewport(
            controller: controller,
            onDismiss: () {},
            background: const ColoredBox(color: Colors.black),
            overlay: Align(
              alignment: Alignment.topRight,
              child: TextButton(key: overlay, onPressed: () => clicks++, child: const Text('Close')),
            ),
            child: const ColoredBox(color: Colors.red, child: SizedBox.expand()),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(overlay));
    controller.zoomTo(2);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(overlay)), rect);
    controller.reset();
    await tester.pumpAndSettle();
    final pointer = await drag(tester, 60);
    final reveal = tester.widget<FrostMaterialReveal>(find.ancestor(of: find.byKey(overlay), matching: find.byType(FrostMaterialReveal)).first);
    expect(reveal.opacity, closeTo(.5, .01));
    expect(tester.getRect(find.byKey(overlay)), rect);
    await tester.pump(const Duration(milliseconds: 500));
    await pointer.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(overlay));
    expect(clicks, 1);
    expect(tester.takeException(), isNull);
  });

  test('unbound zoom is harmless and validates requested scale', () {
    final controller = FrostMediaViewportController();
    controller.zoomTo(2);
    controller.reset();
    for (final value in [0.0, -1.0, double.infinity, double.nan]) {
      expect(() => controller.zoomTo(value), throwsAssertionError);
    }
  });
  for (final reduced in [false, true]) {
    testWidgets('center zoom clamps, retargets and reports actual frames reduced=$reduced', (tester) async {
      final controller = FrostMediaViewportController();
      final frames = <double>[];
      await host(tester, controller: controller, reduced: reduced, scale: frames.add);
      controller.zoomTo(2);
      await tester.pump();
      if (!reduced) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(transform(tester).value.getMaxScaleOnAxis(), inExclusiveRange(1, 2));
      }
      await tester.pumpAndSettle();
      expect(transform(tester).value.getMaxScaleOnAxis(), 2);
      expect(transform(tester).toScene(const Offset(200, 150)), const Offset(200, 150));
      expect(frames.last, 2);
      controller.zoomTo(20);
      await tester.pumpAndSettle();
      expect(transform(tester).value.getMaxScaleOnAxis(), 5);
      controller.zoomTo(.5);
      await tester.pumpAndSettle();
      expect(transform(tester).value, Matrix4.identity());
      expect(frames.last, 1);
      controller.zoomTo(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final before = transform(tester).value.clone();
      controller.zoomTo(1.5);
      if (!reduced) expect(transform(tester).value, before);
      await tester.pumpAndSettle();
      expect(transform(tester).value.getMaxScaleOnAxis(), 1.5);
      await tester.pumpWidget(const SizedBox());
      final count = frames.length;
      controller.zoomTo(2);
      await tester.pump();
      expect(frames.length, count);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('distance threshold is strict and subthreshold downward velocity rebounds', (tester) async {
    for (final distance in [119.0, 120.0, 121.0]) {
      var calls = 0;
      await host(tester, dismiss: () => calls++);
      final pointer = await drag(tester, distance);
      await tester.pump(const Duration(milliseconds: 500));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(calls, distance > 120 ? 1 : 0);
      await tester.pumpWidget(const SizedBox());
    }
    var calls = 0;
    await host(tester, dismiss: () => calls++);
    await tester.flingFrom(tester.getTopLeft(_viewport) + const Offset(100, 60), const Offset(0, 60), 650);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))), Offset.zero);
    expect(tester.takeException(), isNull);
  });
  testWidgets('two-finger framework zoom never dismisses and pending callback is discarded on unmount', (tester) async {
    var calls = 0;
    final changes = <bool>[];
    await host(tester, dismiss: () => calls++, zoom: changes.add);
    final first = await tester.startGesture(const Offset(100, 150), pointer: 1);
    final second = await tester.startGesture(const Offset(200, 150), pointer: 2);
    await first.moveTo(const Offset(60, 170));
    await second.moveTo(const Offset(240, 170));
    await tester.pump();
    expect(transform(tester).value.getMaxScaleOnAxis(), greaterThan(1));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(changes, [true]);
    transform(tester).value = Matrix4.identity();
    await tester.pumpWidget(const SizedBox());
    expect(changes, [true]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('double tap zooms at pointer and reset uses intermediate spring frames', (tester) async {
    final changes = <bool>[];
    final phases = <SchedulerPhase>[];
    final controller = FrostMediaViewportController();
    await host(
      tester,
      controller: controller,
      zoom: (value) {
        changes.add(value);
        phases.add(SchedulerBinding.instance.schedulerPhase);
      },
    );
    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 80));
    final mid = transform(tester).value.getMaxScaleOnAxis();
    expect(mid, inExclusiveRange(1, 2.5));
    await tester.pumpAndSettle();
    expect(transform(tester).value.getMaxScaleOnAxis(), 2.5);
    expect(transform(tester).value.storage[12], closeTo(-150, .0001));
    expect(changes, [true]);
    expect(phases, everyElement(SchedulerPhase.postFrameCallbacks));
    controller.reset();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(transform(tester).value.getMaxScaleOnAxis(), inExclusiveRange(1, 2.5));
    await tester.pumpAndSettle();
    expect(transform(tester).value, Matrix4.identity());
    expect(changes, [true, false]);
    await doubleTap(tester);
    await tester.pumpAndSettle();
    await doubleTap(tester);
    await tester.pumpAndSettle();
    expect(transform(tester).value, Matrix4.identity());
    await tester.pumpWidget(const SizedBox());
    controller.reset();
    expect(tester.takeException(), isNull);
  });

  testWidgets('downward drag maps distance to media scale and only fades background, then springs back', (tester) async {
    var dismisses = 0;
    await host(tester, dismiss: () => dismisses++);
    final pointer = await drag(tester, 60);
    final backgroundFade = find.descendant(
      of: _viewport,
      matching: find.ancestor(of: find.byKey(const ValueKey('background')), matching: find.byType(Opacity)),
    );
    final opacity = tester.renderObject<RenderOpacity>(backgroundFade).opacity;
    expect(opacity, closeTo(.5, .0001));
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dy, greaterThan(0));
    final imageOpacity = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('content')), matching: find.byType(Opacity)).first);
    expect(imageOpacity.opacity, 1, reason: 'Dragging fades only the background; the completed dismissal owns the later image fade.');
    final moved = tester.getTopLeft(find.byKey(const ValueKey('content'))).dy;
    await tester.pump(const Duration(milliseconds: 500));
    await pointer.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getTopLeft(find.byKey(const ValueKey('content'))).dy;
    expect(middle, inExclusiveRange(0, moved));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))), Offset.zero);
    expect(dismisses, 0);
  });

  testWidgets('dismiss has independent distance and downward velocity thresholds; zoomed and upward gestures never dismiss', (tester) async {
    for (final kind in ['distance', 'velocity', 'up', 'zoom']) {
      var calls = 0;
      await host(tester, dismiss: () => calls++);
      if (kind == 'zoom') {
        await doubleTap(tester);
        await tester.pumpAndSettle();
      }
      if (kind == 'velocity') {
        await tester.flingFrom(tester.getTopLeft(_viewport) + const Offset(100, 60), const Offset(0, 60), 1000);
      } else {
        final pointer = await drag(tester, kind == 'up' ? -150 : 160);
        await tester.pump(const Duration(milliseconds: 500));
        await pointer.up();
      }
      await tester.pumpAndSettle();
      expect(calls, kind == 'distance' || kind == 'velocity' ? 1 : 0, reason: kind);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('reduced programmatic zoom reset and dismissal rebound go straight to endpoints', (tester) async {
    final controller = FrostMediaViewportController();
    await host(tester, reduced: true, controller: controller, dismiss: () {});
    await doubleTap(tester);
    expect(transform(tester).value.getMaxScaleOnAxis(), 2.5);
    controller.reset();
    await tester.pump();
    expect(transform(tester).value, Matrix4.identity());
    final pointer = await drag(tester, 60);
    await tester.pump(const Duration(milliseconds: 500));
    await pointer.up();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))), Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('framework wheel zoom is preserved and zoom callback coalesces only state changes after frames', (tester) async {
    final values = <bool>[];
    await host(tester, zoom: values.add);
    final center = tester.getCenter(_viewport);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)));
    expect(values, isEmpty);
    await tester.pump();
    expect(values, [true]);
    transform(tester).value = Matrix4.diagonal3Values(3, 3, 1);
    await tester.pump();
    expect(values, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('actual scale coalesces per frame, ignores pan and cancels after disposal', (tester) async {
    final values = <double>[], phases = <SchedulerPhase>[];
    await host(
      tester,
      scale: (value) {
        values.add(value);
        phases.add(SchedulerBinding.instance.schedulerPhase);
      },
    );
    expect(values, isEmpty);
    transform(tester).value = Matrix4.diagonal3Values(2, 2, 1);
    transform(tester).value = Matrix4.diagonal3Values(3, 3, 1);
    expect(values, isEmpty);
    await tester.pump();
    expect(values, [3]);
    transform(tester).value = Matrix4.diagonal3Values(3, 3, 1)..setTranslationRaw(-10, -20, 0);
    await tester.pump();
    expect(values, [3]);
    transform(tester).value = Matrix4.diagonal3Values(4, 4, 1);
    transform(tester).value = Matrix4.diagonal3Values(3, 3, 1);
    await tester.pump();
    expect(values, [3]);
    expect(phases, everyElement(SchedulerPhase.postFrameCallbacks));
    transform(tester).value = Matrix4.identity();
    await tester.pumpWidget(const SizedBox());
    expect(values, [3]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scale reports real spring frames and final reset alongside legacy zoom state', (tester) async {
    final values = <double>[], zoom = <bool>[];
    final controller = FrostMediaViewportController();
    await host(tester, controller: controller, scale: values.add, zoom: zoom.add);
    await doubleTap(tester);
    await tester.pump(const Duration(milliseconds: 80));
    expect(values.last, transform(tester).value.getMaxScaleOnAxis());
    expect(values.last, inExclusiveRange(1, 2.5));
    await tester.pumpAndSettle();
    expect(values.last, 2.5);
    expect(zoom, [true]);
    controller.reset();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(values.last, inExclusiveRange(1, 2.5));
    await tester.pumpAndSettle();
    expect(values.last, 1);
    expect(zoom, [true, false]);
  });
  for (final pinch in [false, true]) {
    testWidgets('scale follows framework ${pinch ? 'pinch' : 'wheel'} input', (tester) async {
      final values = <double>[];
      await host(tester, scale: values.add);
      if (pinch) {
        final first = await tester.startGesture(const Offset(100, 150), pointer: 1), second = await tester.startGesture(const Offset(200, 150), pointer: 2);
        await first.moveTo(const Offset(60, 150));
        await second.moveTo(const Offset(240, 150));
        await tester.pump();
        expect(values.last, transform(tester).value.getMaxScaleOnAxis());
        expect(values.last, greaterThan(1));
        await first.up();
        await second.up();
      } else {
        tester.binding.handlePointerEvent(PointerScrollEvent(position: tester.getCenter(_viewport), scrollDelta: const Offset(0, -100)));
        expect(values, isEmpty);
        await tester.pump();
        expect(values.last, transform(tester).value.getMaxScaleOnAxis());
        expect(values.last, greaterThan(1));
      }
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('reduced scale reports endpoints without spring intermediate notices', (tester) async {
    final values = <double>[];
    final controller = FrostMediaViewportController();
    await host(tester, reduced: true, controller: controller, scale: values.add);
    await doubleTap(tester);
    expect(values, [2.5]);
    controller.reset();
    await tester.pump();
    expect(values, [2.5, 1]);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
