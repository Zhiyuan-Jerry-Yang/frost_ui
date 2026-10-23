import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class ControlledImage extends ImageProvider<ControlledImage> {
  final completer = ControlledCompleter();
  @override
  Future<ControlledImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(ControlledImage key, ImageDecoderCallback decode) => completer;
}

class ControlledCompleter extends ImageStreamCompleter {
  void chunk(int loaded, int? total) => reportImageChunkEvent(ImageChunkEvent(cumulativeBytesLoaded: loaded, expectedTotalBytes: total));
  void fail(Object error) => reportError(exception: error, silent: true);
  void complete(ImageInfo image) => setImage(image);
}

void main() {
  testWidgets('media child has configurable clip, aspect, physical inner stroke and semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final continuous in [true, false]) {
      await tester.pumpWidget(
        frostTestApp(
          FrostScope(
            config: testConfig.copyWith(continuousCorners: continuous),
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 200, child: FrostMediaFrame(aspectRatio: 2, child: Text('decorative child'))),
            ),
          ),
        ),
      );
      final frame = find.byType(FrostMediaFrame);
      expect(tester.getSize(frame), const Size(200, 100));
      expect(find.descendant(of: frame, matching: find.byType(continuous ? ClipRSuperellipse : ClipRRect)), findsOneWidget);
      final decoration = tester.renderObject<RenderDecoratedBox>(find.descendant(of: frame, matching: find.byType(DecoratedBox))).decoration as ShapeDecoration;
      final tokens = FrostThemeTokens.of(tester.element(frame));
      final side = (decoration.shape as OutlinedBorder).side;
      expect(side.color, tokens.mediaInnerStroke);
      expect(side.width, 1 / tester.view.devicePixelRatio);
      expect(side.strokeAlign, BorderSide.strokeAlignInside);
      expect(find.bySemanticsLabel('decorative child'), findsOneWidget);
      expect(find.descendant(of: frame, matching: find.byType(TweenAnimationBuilder<double>)), findsNothing);
    }
    await tester.pumpWidget(frostTestApp(const FrostMediaFrame(semanticLabel: 'Artwork', child: Text('ignored inner label'))));
    expect(find.bySemanticsLabel('Artwork'), findsOneWidget);
    expect(find.bySemanticsLabel('ignored inner label'), findsNothing);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('image mode renders progress, default errors, then fades in actual pixels', (tester) async {
    final image = ControlledImage();
    double? lastProgress;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 100,
          height: 80,
          child: FrostMediaFrame(
            image: image,
            placeholderBuilder: (context, progress) {
              lastProgress = progress;
              return const Text('loading');
            },
          ),
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    expect(lastProgress, isNull);
    image.completer.chunk(1, 4);
    await tester.pump();
    expect(lastProgress, .25);
    image.completer.chunk(2, null);
    await tester.pump();
    expect(lastProgress, isNull);
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    expect(find.text('loading'), findsNothing);
    final fade = find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity));
    expect(tester.renderObject<RenderOpacity>(fade).opacity, 0);
    await tester.pump(FrostMotion.imageFade ~/ 2);
    expect(tester.renderObject<RenderOpacity>(fade).opacity, allOf(greaterThan(0), lessThan(1)));
    await tester.pump(FrostMotion.imageFade);
    expect(tester.renderObject<RenderOpacity>(fade).opacity, 1);
    final error = ControlledImage();
    await tester.pumpWidget(frostTestApp(SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: error))));
    error.completer.fail(StateError('test image failure'));
    await tester.pump();
    expect(find.byType(FrostIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows loaded image without a fade and custom error receives object', (tester) async {
    final image = ControlledImage();
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: image)),
          ),
        ),
      ),
    );
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(RawImage)), findsOneWidget);
    final error = ControlledImage();
    final failure = StateError('failure');
    Object? received;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 100,
          height: 80,
          child: FrostMediaFrame(
            image: error,
            errorBuilder: (context, value) {
              received = value;
              return const Text('custom error');
            },
          ),
        ),
      ),
    );
    error.completer.fail(failure);
    await tester.pump();
    expect(received, same(failure));
    expect(find.text('custom error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warm cached frames are opaque immediately after remount', (tester) async {
    final image = ControlledImage();
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    Future<void> mount() => tester.pumpWidget(frostTestApp(SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: image))));
    await mount();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(PaintingBinding.instance.imageCache.statusForKey(image).keepAlive, isTrue);
    await mount();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    final pixels = tester.widget<RawImage>(find.byType(RawImage));
    expect(pixels.image, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
  });

  test('media modes enforce exclusive sources and child-owned state', () {
    expect(() => FrostMediaFrame(), throwsAssertionError);
    expect(() => FrostMediaFrame(image: ControlledImage(), child: const SizedBox()), throwsAssertionError);
    expect(() => FrostMediaFrame(placeholderBuilder: (_, _) => const SizedBox(), child: const SizedBox()), throwsAssertionError);
    expect(() => FrostMediaFrame(errorBuilder: (_, _) => const SizedBox(), child: const SizedBox()), throwsAssertionError);
  });
}
