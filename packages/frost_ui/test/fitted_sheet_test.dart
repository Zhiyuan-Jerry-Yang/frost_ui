import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_modal_frame.dart';

import 'dialog_sheet_v2_test.dart' show launch, modalSurface;
import 'support.dart';

void main() {
  testWidgets('Mouse release velocity stays global while the fitted header moves', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Fitted', detents: const [FrostSheetDetent.fitted], builder: (_) => const SizedBox(height: 200)),
      size: const Size(390, 800),
    );
    final resting = tester.getRect(modalSurface);
    await tester.fling(find.text('Fitted'), const Offset(0, -50), 500, deviceKind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.getRect(modalSurface), resting);
    await tester.fling(find.text('Fitted'), const Offset(0, 60), 500, deviceKind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Batched native mouse moves keep the completed layout valid for hit testing', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Fitted', detents: const [FrostSheetDetent.fitted], builder: (_) => const SizedBox(height: 100)),
      size: const Size(390, 800),
    );
    final resting = tester.getRect(modalSurface);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final start = tester.getCenter(find.text('Fitted'));
    await mouse.addPointer(location: start);
    await mouse.down(start);
    for (var index = 1; index <= 10; index++) {
      await mouse.moveTo(start + Offset(0, -index * 5));
      expect(tester.takeException(), isNull);
    }
    await tester.pump();
    expect(tester.getSize(modalSurface).height, resting.height + 10);
    expect(tester.getRect(modalSurface).bottom, resting.bottom);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(modalSurface), resting);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });

  testWidgets('Compact Confirm fits measured content and bottom safe area on the cold frame', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await launch(
      tester,
      (context) => showFrostConfirm(context: context, title: 'Confirm', message: 'Message', confirmLabel: 'Delete'),
      size: const Size(390, 800),
      settle: false,
    );
    final expected =
        6 +
        5 +
        8 +
        tester.getSize(find.text('Confirm')).height +
        8 +
        tester.getSize(find.text('Message')).height +
        20 +
        tester.getSize(find.byType(FrostModalActionBar)).height +
        20 +
        34;
    expect(tester.getSize(modalSurface).height, expected);
    expect(tester.widget<FrostText>(find.widgetWithText(FrostText, 'Confirm')).textAlign, TextAlign.center);
    expect(tester.widget<FrostText>(find.widgetWithText(FrostText, 'Message')).textAlign, TextAlign.center);
    await tester.pumpAndSettle();
    final cancel = find.ancestor(of: find.text('L.cancel'), matching: find.byType(FrostClickSurface));
    expect(tester.getRect(modalSurface).bottom - tester.getRect(cancel).bottom, 54);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fitted cannot mix with another detent', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final detents in [
      [FrostSheetDetent.fitted, FrostSheetDetent.medium],
      [FrostSheetDetent.large, FrostSheetDetent.fitted],
    ]) {
      expect(() => showFrostSheet(context: context, detents: detents, builder: (_) => const Text('Content')), throwsAssertionError);
    }
  });

  testWidgets('Fitted self-scrolling natural content fits while a lazy viewport falls back to large', (tester) async {
    final built = <int>{};
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Fitted',
        detents: const [FrostSheetDetent.fitted, FrostSheetDetent.fitted],
        scrollable: false,
        builder: (_) => const SizedBox(height: 120, child: Text('Content')),
      ),
      size: const Size(390, 800),
    );
    final content = find.byWidgetPredicate((widget) => widget is SizedBox && widget.height == 120);
    expect(tester.getRect(modalSurface).bottom - tester.getRect(content).bottom, 20);
    expect(tester.getSize(modalSurface).height, lessThan(400));
    await tester.tap(findFrostTooltip('L.close'));
    await tester.pumpAndSettle();
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Lazy',
        detents: const [FrostSheetDetent.fitted],
        scrollable: false,
        builder: (_) => ListView.builder(
          itemCount: 10000,
          itemExtent: 40,
          itemBuilder: (_, index) {
            built.add(index);
            return Text('Row $index');
          },
        ),
      ),
      size: const Size(390, 800),
    );
    expect(tester.getSize(modalSurface).height, 792);
    expect(built.length, lessThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fitted upward pulls stretch 0.2 up to 24 with fixed bottom and standard rebound', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Fitted', detents: const [FrostSheetDetent.fitted], builder: (_) => const SizedBox(height: 100)),
      size: const Size(390, 800),
    );
    final resting = tester.getRect(modalSurface);
    for (final (pull, stretch) in [(50.0, 10.0), (500.0, 24.0)]) {
      final gesture = await tester.startGesture(tester.getCenter(find.text('Fitted')));
      await gesture.moveBy(Offset(0, -pull));
      await tester.pump();
      expect(tester.getSize(modalSurface).height, resting.height + stretch);
      expect(tester.getRect(modalSurface).bottom, resting.bottom);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getSize(modalSurface).height, inExclusiveRange(resting.height, resting.height + stretch));
      expect(tester.getRect(modalSurface).bottom, resting.bottom);
      await tester.pumpAndSettle();
      expect(tester.getSize(modalSurface).height, resting.height);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fitted downward threshold and fling close without overflowing a short header', (tester) async {
    for (final fling in [false, true]) {
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'Fitted',
          detents: const [FrostSheetDetent.fitted],
          builder: (_) => SizedBox(height: fling ? 200 : 100),
        ),
        size: const Size(390, 800),
      );
      if (fling) {
        await tester.timedDrag(find.text('Fitted'), const Offset(0, 60), const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(modalSurface, findsOneWidget);
        await tester.fling(find.text('Fitted'), const Offset(0, 60), 500);
      } else {
        final gesture = await tester.startGesture(tester.getCenter(find.text('Fitted')));
        await gesture.moveBy(const Offset(0, 500));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(modalSurface, findsNothing, reason: 'fling=$fling');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Async content and keyboard constraints follow standard spring after a correct cold extent', (tester) async {
    late StateSetter update;
    var contentHeight = 80.0;
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Fitted',
        detents: const [FrostSheetDetent.fitted],
        builder: (_) => StatefulBuilder(
          builder: (_, set) {
            update = set;
            return SizedBox(height: contentHeight);
          },
        ),
      ),
      size: const Size(390, 800),
    );
    final initial = tester.getSize(modalSurface).height;
    update(() => contentHeight = 200);
    await tester.pump();
    expect(tester.getSize(modalSurface).height, initial);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(initial, initial + 120));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, initial + 120);
    update(() => contentHeight = 1000);
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 792);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getSize(modalSurface).height, 792);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(592, 792));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 592);
    expect(tester.getRect(modalSurface).bottom, 600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced fitted motion never stretches and content changes settle directly', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Fitted', detents: const [FrostSheetDetent.fitted], builder: (_) => const SizedBox(height: 100)),
      size: const Size(390, 800),
      reduced: true,
    );
    final resting = tester.getRect(modalSurface);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Fitted')));
    await gesture.moveBy(const Offset(0, -500));
    await tester.pump();
    expect(tester.getRect(modalSurface), resting);
    await gesture.up();
    await tester.pump();
    expect(tester.getRect(modalSurface), resting);
    expect(tester.takeException(), isNull);
  });
}
