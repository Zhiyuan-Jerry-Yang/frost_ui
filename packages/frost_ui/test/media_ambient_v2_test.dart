import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';

import 'support.dart';

class _CountedImage extends ImageProvider<_CountedImage> {
  _CountedImage(this.bytes);
  final Uint8List bytes;
  var loads = 0;
  Size? decodedSize;
  @override
  Future<_CountedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_CountedImage key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(_load(decode));
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    try {
      final frame = await codec.getNextFrame();
      decodedSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
    }
  }
}

Future<_CountedImage> _solid(WidgetTester tester, Color color) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return _CountedImage(bytes);
}))!;
Future<void> settleImage(WidgetTester tester) async {
  for (var index = 0; index < 5; index++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pump(FrostMotion.reveal);
}

Finder get ambient => find.byType(FrostAmbientBackdrop);
Color opaqueBackground(WidgetTester tester) => tester.widgetList<ColoredBox>(find.descendant(of: ambient, matching: find.byType(ColoredBox))).single.color;

void main() {
  test('all six palettes, brightnesses and tones meet worst-case media contrast', () {
    final palettes = FrostPalettes.pink;
    for (final accent in palettes.accentPresets) {
      for (final brightness in Brightness.values) {
        for (final tone in FrostTone.values) {
          final tokens = palettes.palette(brightness, tone, accent);
          final opacity = frostMediaScrimOpacity(tokens);
          expect(opacity, greaterThanOrEqualTo(tokens.isDark ? .88 : .6));
          final worst = tokens.isDark ? Colors.white : Colors.black;
          final background = Color.alphaBlend(tokens.surface.withValues(alpha: opacity), worst);
          expect(colorContrast(tokens.textPrimary, background), greaterThanOrEqualTo(4.5));
          expect(colorContrast(tokens.textPrimary, Color(background.toARGB32())), greaterThanOrEqualTo(4.5));
          expect(frostMediaScrimOpacity(tokens), opacity);
        }
      }
    }
  });
  testWidgets('media ambient preblurs sigma 80 and keeps scrim and source crossfades', (tester) async {
    final first = await _solid(tester, Colors.red), second = await _solid(tester, Colors.blue);
    late StateSetter update;
    ImageProvider provider = first;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 300,
          height: 200,
          child: StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostAmbientBackdrop.fromImage(image: provider, child: const Text('Foreground'));
            },
          ),
        ),
      ),
    );
    await settleImage(tester);
    expect(find.byType(ImageFiltered), findsNothing);
    final prepared = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(prepared.width, 48);
    expect(prepared.height, lessThanOrEqualTo(128));
    final tokens = FrostThemeTokens.of(tester.element(ambient));
    final scrim = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).last.color;
    expect(scrim, tokens.surface.withValues(alpha: frostMediaScrimOpacity(tokens)));
    final initialImage = tester.widget<RawImage>(find.byType(RawImage)).image;
    update(() => provider = second);
    await tester.pump();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(initialImage));
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (find.byType(RawImage).evaluate().length == 2) break;
    }
    await tester.pump();
    await tester.pump(FrostMotion.reveal ~/ 2);
    final opacity = tester.renderObjectList<RenderOpacity>(find.descendant(of: ambient, matching: find.byType(Opacity))).map((r) => r.opacity);
    expect(opacity, everyElement(inExclusiveRange(0, 1)));
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsOneWidget);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNot(same(initialImage)));
    expect(find.text('Foreground'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final color in [Colors.white, Colors.black]) {
      testWidgets('opaque average composes scrim and passes text contrast $brightness $color', (tester) async {
        final provider = await _solid(tester, color);
        await tester.pumpWidget(
          frostTestApp(
            SizedBox(
              width: 300,
              height: 200,
              child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
            ),
            brightness: brightness,
            reduceTransparency: true,
          ),
        );
        final tokens = FrostThemeTokens.of(tester.element(ambient));
        expect(opaqueBackground(tester), tokens.surface);
        await settleImage(tester);
        final background = opaqueBackground(tester);
        final expected = Color.alphaBlend(tokens.surface.withValues(alpha: frostMediaScrimOpacity(tokens)), color);
        expect(background, expected.withValues(alpha: 1));
        expect(background.a, 1);
        expect(colorContrast(tokens.textPrimary, background), greaterThanOrEqualTo(4.5));
        expect(provider.decodedSize, const Size(16, 16));
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(RawImage), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('average cache survives theme changes and remounts without decoding again', (tester) async {
    final provider = await _solid(tester, Colors.white);
    for (final brightness in [Brightness.light, Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        frostTestApp(
          FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
          brightness: brightness,
          reduceTransparency: true,
        ),
      );
      await settleImage(tester);
      expect(provider.loads, 1);
      final tokens = FrostThemeTokens.of(tester.element(ambient));
      expect(colorContrast(tokens.textPrimary, opaqueBackground(tester)), greaterThanOrEqualTo(4.5));
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('average transitions from surface to computed color while foreground stays opaque', (tester) async {
    final provider = await _solid(tester, Colors.red);
    await tester.pumpWidget(frostTestApp(FrostAmbientBackdrop.fromImage(image: provider, child: const Text('Opaque foreground')), reduceTransparency: true));
    final before = opaqueBackground(tester);
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (provider.decodedSize != null) break;
    }
    await tester.pump(FrostMotion.reveal ~/ 2);
    final middle = opaqueBackground(tester);
    await tester.pumpAndSettle();
    final after = opaqueBackground(tester);
    expect(middle, isNot(before));
    expect(middle, isNot(after));
    expect(
      find.descendant(
        of: ambient,
        matching: find.ancestor(of: find.text('Opaque foreground'), matching: find.byType(Opacity)),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('prepared blur is reused while the page moves, and resizes without decoding its source again', (tester) async {
    final provider = await _solid(tester, Colors.red);
    late StateSetter update;
    var width = 200.0, shift = 0.0;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return Center(
              child: Transform.translate(
                offset: Offset(shift, 0),
                child: SizedBox(
                  width: width,
                  height: 200,
                  child: FrostAmbientBackdrop.fromImage(image: provider, child: const Text('Foreground')),
                ),
              ),
            );
          },
        ),
      ),
    );
    await settleImage(tester);
    final first = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(Size(first.width.toDouble(), first.height.toDouble()), const Size(48, 48));
    for (var index = 1; index <= 10; index++) {
      update(() => shift = index.toDouble());
      await tester.pump(const Duration(milliseconds: 8));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(first));
    }
    expect(provider.loads, 1);
    update(() => width = 100);
    await tester.pump();
    await settleImage(tester);
    final resized = tester.widgetList<RawImage>(find.byType(RawImage)).last.image!;
    expect(Size(resized.width.toDouble(), resized.height.toDouble()), const Size(48, 96));
    expect(provider.loads, 1);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prepared pixels retain the broad blur across a sharp two-colour edge', (tester) async {
    final provider = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 64), Paint()..color = Colors.red);
      canvas.drawRect(const Rect.fromLTWH(32, 0, 32, 64), Paint()..color = Colors.blue);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      return _CountedImage(bytes);
    }))!;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
          ),
        ),
      ),
    );
    await settleImage(tester);
    final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
    final pixels = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final left = (24 * image.width + 1) * 4, right = (24 * image.width + 46) * 4;
    expect(pixels.getUint8(left), greaterThan(pixels.getUint8(right)));
    expect(pixels.getUint8(left + 2), greaterThan(10), reason: 'sigma 80 reaches into the red side; downsampling alone would stay pure red');
    expect(pixels.getUint8(right), greaterThan(10));
    expect(pixels.getUint8(left + 3), 255);
  });

  testWidgets('zero-sized and removed backdrops do not publish late prepared images', (tester) async {
    final provider = await _solid(tester, Colors.red);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox.shrink(
            child: FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox()),
          ),
        ),
      ),
    );
    await settleImage(tester);
    expect(provider.loads, 0);
    await tester.pumpWidget(frostTestApp(FrostAmbientBackdrop.fromImage(image: provider, child: const SizedBox())));
    await tester.pumpWidget(const SizedBox());
    await settleImage(tester);
    expect(tester.takeException(), isNull);
  });
}
