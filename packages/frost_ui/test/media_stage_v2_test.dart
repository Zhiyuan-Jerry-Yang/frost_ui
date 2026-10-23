import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';
import 'support.dart';

void main() {
  const mediaKey = ValueKey('pixels');
  Widget stage(double ratio) => FrostMediaStage(
    aspectRatio: ratio,
    child: const SizedBox.expand(key: mediaKey),
  );
  for (final ratio in [2.0, .75, 1080 / 1915, .2]) {
    testWidgets('finite stage fills an axis for $ratio without extra surfaces', (tester) async {
      await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 600, height: 400, child: stage(ratio)))));
      final rect = tester.getRect(find.byKey(mediaKey));
      expect(rect.width / rect.height, closeTo(ratio, .00001));
      expect(rect.width == 600 || rect.height == 400, isTrue);
      expect(find.byType(FrostMediaFrame), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('unbounded natural stage preserves full height for $ratio', (tester) async {
      await tester.pumpWidget(frostTestApp(SizedBox(width: 390, child: SingleChildScrollView(child: stage(ratio)))));
      final size = tester.getSize(find.byKey(mediaKey));
      expect(size.height, closeTo(size.width / ratio, .00001));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('one media stroke also owns nested placeholder and skeleton radius forwards', (tester) async {
    const nested = FrostMediaFrame(radius: 0, child: FrostMediaFrame(radius: 0, child: SizedBox.expand()));
    await tester.pumpWidget(frostTestApp(const Center(child: SizedBox(width: 200, height: 300, child: nested))));
    final strokes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<ShapeDecoration>()
        .where((d) => d.shape is OutlinedBorder && (d.shape as OutlinedBorder).side.style == BorderStyle.solid);
    expect(strokes, hasLength(1));
    final skeleton = FrostMediaFrame.skeleton(aspectRatio: null, radius: 0);
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 200, height: 300, child: skeleton))));
    final frames = tester.widgetList<FrostMediaFrame>(find.byType(FrostMediaFrame));
    expect(frames.every((frame) => frame.radius == 0), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('invalid aspect ratios assert', () {
    for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => stage(ratio), throwsAssertionError);
    }
  });
  testWidgets('decoded ratio redirects the standard spring and retains child state', (tester) async {
    Widget app(double ratio, {bool reduced = false}) => frostTestApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(child: SizedBox(width: 400, height: 500, child: stage(ratio))),
      ),
    );
    await tester.pumpWidget(app(2));
    final element = tester.element(find.byKey(mediaKey));
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 200));
    await tester.pumpWidget(app(.8));
    await tester.pump(const Duration(milliseconds: 80));
    final intermediate = tester.getSize(find.byKey(mediaKey)).height;
    expect(intermediate, greaterThan(200));
    expect(intermediate, lessThan(500));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 500));
    expect(tester.element(find.byKey(mediaKey)), same(element));
    await tester.pumpWidget(app(2, reduced: true));
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 200));
  });
  testWidgets('Hero follows stage ratio instead of stale source metadata', (tester) async {
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 2, sourceRadius: BorderRadius.zero);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            height: 500,
            child: FrostMediaStage(
              aspectRatio: .8,
              child: FrostMediaHero(
                tag: tag,
                radius: BorderRadius.zero,
                fit: BoxFit.contain,
                child: const SizedBox.expand(key: mediaKey),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 500));
    expect(tag.aspectRatio, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('natural detail stage scrolls with information and survives sizing changes', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget app(FrostDetailStageSizing sizing) =>
        frostTestApp(FrostDetailLayout(compactStageSizing: sizing, header: const SizedBox(height: 48), stage: stage(.2), primary: const Text('Information')));
    await tester.pumpWidget(app(FrostDetailStageSizing.natural));
    expect(tester.getSize(find.byKey(mediaKey)), const Size(390, 1950));
    final retained = tester.element(find.byKey(mediaKey));
    final scroll = find.byType(CustomScrollView);
    await tester.drag(scroll, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(mediaKey)).dy, lessThan(0));
    await tester.pumpWidget(app(FrostDetailStageSizing.viewport));
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(mediaKey)), same(retained));
    expect(tester.getSize(find.byKey(mediaKey)).height, lessThanOrEqualTo(800 * .6));
    expect(tester.takeException(), isNull);
  });
}
