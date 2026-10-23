import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/surface/_window_background.dart';
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

Future<void> resolveImage(WidgetTester tester, ControlledImage provider, Color color) async {
  final picture = ui.PictureRecorder();
  Canvas(picture).drawColor(color, BlendMode.src);
  final recording = picture.endRecording();
  final image = (await tester.runAsync(() => recording.toImage(48, 32)))!;
  recording.dispose();
  provider.completer.complete(ImageInfo(image: image));
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  test('default preserves original artwork paint and intensity has explicit bounds', () {
    expect(FrostAmbientBackdropHost(image: null, child: const SizedBox()).intensity, 1);
    expect(frostAmbientDarkArtworkOpacity, .34);
    expect(frostAmbientLightArtworkOpacity, .40);
    expect(frostAmbientArtworkSaturation, .7);
    expect(() => FrostAmbientBackdropHost(image: null, intensity: -0.1, child: const SizedBox()), throwsAssertionError);
    expect(() => FrostAmbientBackdropHost(image: null, intensity: 1.1, child: const SizedBox()), throwsAssertionError);
    for (var i = 0; i < 20; i++) {
      expect(frostAmbientDarkArtworkOpacity * i / 20, lessThan(frostAmbientDarkArtworkOpacity * (i + 1) / 20));
    }
  });

  test('actual bright and dark blocks preserve inks and local materials in all palettes', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final tokens = FrostPalettes.pink.palette(brightness, tone, const Color(0xFFFC619D));
        for (final art in [Colors.white, Colors.black, const Color(0xFF7499B2)]) {
          final sample = FrostAmbientSample(8, 8, List.filled(64, art));
          for (final intensity in [0.0, .5, 1.0]) {
            final material = sample.resolve(tokens, intensity, 1.5);
            for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
              expect(colorContrast(ink, material.background), greaterThanOrEqualTo(4.5), reason: '$brightness $tone $art $intensity');
            }
            final panel = frostReadableWindowFill(tokens, frostWindowLayerFill(tokens.isDark), material.background, tokens.textSecondary);
            final panelBackground = Color.alphaBlend(panel, material.background);
            final card = frostReadableWindowFill(tokens, frostWindowCardFill(tokens.isDark), panelBackground, tokens.textSecondary);
            final cardBackground = Color.alphaBlend(card, panelBackground);
            expect(panel.a, greaterThanOrEqualTo(frostWindowLayerFill(tokens.isDark).a));
            expect(card.a, greaterThanOrEqualTo(frostWindowCardFill(tokens.isDark).a));
            expect(colorContrast(tokens.textSecondary, panelBackground), greaterThanOrEqualTo(4.5));
            expect(colorContrast(tokens.textSecondary, cardBackground), greaterThanOrEqualTo(4.5));
            final pressed = frostReadableWindowFill(tokens, Color.alphaBlend(tokens.fillStrong, tokens.fill), cardBackground, tokens.textPrimary);
            expect(colorContrast(tokens.textPrimary, Color.alphaBlend(pressed, cardBackground)), greaterThanOrEqualTo(4.5));
          }
        }
      }
    }
  });

  test('ordinary readable artwork has no extra mask and same bucket reuses analysis', () {
    for (final tokens in [FrostPalettes.pink.lightNeutral, FrostPalettes.pink.darkNeutral]) {
      final color = tokens.isDark ? const Color(0xFF203848) : const Color(0xFFDDE8F2);
      final sample = FrostAmbientSample(8, 8, List.filled(64, color));
      final first = sample.resolve(tokens, .51, 1.5);
      expect(first.mask, 0);
      expect(identical(first, sample.resolve(tokens.copyWith(), .54, 1.5)), true);
      expect(sample.resolutions, 1);
      sample.resolve(tokens, .56, 1.5);
      expect(sample.resolutions, 2);
    }
    // A white island must survive block reduction; a whole-image mean hides it.
    final colors = List.filled(64, Colors.black)..[0] = Colors.white;
    expect(FrostAmbientSample(8, 8, colors).resolve(FrostPalettes.pink.darkNeutral, 1, 1.5).mask, greaterThan(0));
  });

  testWidgets('intensity zero is solid with Mica, transitions have intermediate pixels and stable page', (tester) async {
    final provider = ControlledImage();
    final boundary = GlobalKey();
    var strength = 1.0, builds = 0;
    late StateSetter update;
    final page = Builder(
      builder: (_) {
        builds++;
        return const SizedBox.expand();
      },
    );
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Center(
              child: SizedBox(
                width: 180,
                height: 120,
                child: RepaintBoundary(
                  key: boundary,
                  child: FrostWindowCaptionScope(
                    systemBackdropActive: true,
                    child: FrostAmbientBackdropHost(image: provider, intensity: strength, child: page),
                  ),
                ),
              ),
            );
          },
        ),
        brightness: Brightness.dark,
      ),
    );
    await resolveImage(tester, provider, const Color(0xFF203848));
    final count = builds;
    Future<Color> pixel() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => render.toImage()))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      image.dispose();
      final at = (40 * 180 + 40) * 4;
      return Color.fromARGB(bytes.getUint8(at + 3), bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2));
    }

    final before = await pixel();
    update(() => strength = 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final middle = await pixel();
    expect(middle, isNot(before));
    expect(middle, isNot(FrostPalettes.pink.darkNeutral.canvas));
    // Retarget during the fade; the first frame preserves the visible mixture.
    update(() => strength = .5);
    await tester.pump();
    expect(await pixel(), middle);
    await tester.pumpAndSettle();
    update(() => strength = 0);
    await tester.pumpAndSettle();
    expect(await pixel(), FrostPalettes.pink.darkNeutral.canvas);
    expect(frostHasTranslucentWindowBase(tester.element(find.byType(FrostAmbientBackdrop))), false);
    expect(builds, count);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual card paragraph and pressed button ink remain readable over resolved art', (tester) async {
    for (final brightness in Brightness.values) {
      for (final art in [Colors.white, Colors.black, const Color(0xFF7499B2)]) {
        final provider = ControlledImage();
        await tester.pumpWidget(
          frostTestApp(
            FrostAmbientBackdropHost(
              image: provider,
              child: Center(
                child: FrostSurface(
                  role: FrostSurfaceRole.panel,
                  child: SizedBox(
                    width: 300,
                    child: FrostSurface(
                      role: FrostSurfaceRole.module,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FrostText('Secondary', role: FrostTextRole.footnote),
                          FrostButton(label: 'Action', onPressed: () {}),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        await resolveImage(tester, provider, art);
        final text = tester.renderObject<RenderParagraph>(find.text('Secondary'));
        final cardBackground = FrostSurfaceScope.maybeOf(tester.element(find.text('Secondary')))!.background;
        expect(colorContrast(text.text.style!.color!, cardBackground), greaterThanOrEqualTo(4.5));
        final gesture = await tester.startGesture(tester.getCenter(find.text('Action')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        final ink = tester.renderObject<RenderParagraph>(find.text('Action')).text.style!.color!;
        final decorations = tester
            .renderObjectList<RenderDecoratedBox>(find.descendant(of: find.byType(FrostButton), matching: find.byType(DecoratedBox)))
            .map((r) => r.decoration)
            .whereType<ShapeDecoration>()
            .where((d) => d.color != null)
            .toList();
        var background = cardBackground;
        for (final decoration in decorations) {
          background = Color.alphaBlend(decoration.color!, background);
        }
        expect(colorContrast(ink, background), greaterThanOrEqualTo(4.5), reason: '$brightness $art');
        await gesture.up();
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('image change blends readable endpoints without a first-frame jump', (tester) async {
    for (final brightness in Brightness.values) {
      final first = ControlledImage(), second = ControlledImage();
      var provider = first;
      late StateSetter update;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, set) {
              update = set;
              return Center(
                child: SizedBox(
                  width: 180,
                  height: 120,
                  child: RepaintBoundary(
                    key: boundary,
                    child: FrostAmbientBackdropHost(image: provider, child: const SizedBox.expand()),
                  ),
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      await resolveImage(tester, first, Colors.black);
      Future<Color> pixel() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => render.toImage()))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        image.dispose();
        final at = (40 * 180 + 40) * 4;
        return Color.fromARGB(bytes.getUint8(at + 3), bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2));
      }

      final before = await pixel();
      update(() => provider = second);
      await tester.pump();
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.white, BlendMode.src);
      final recording = recorder.endRecording();
      final image = (await tester.runAsync(() => recording.toImage(48, 32)))!;
      recording.dispose();
      second.completer.complete(ImageInfo(image: image));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
      expect(await pixel(), before);
      await tester.pump(const Duration(milliseconds: 210));
      final middle = await pixel();
      final tokens = brightness == Brightness.dark ? FrostPalettes.pink.darkNeutral : FrostPalettes.pink.lightNeutral;
      expect(colorContrast(tokens.textPrimary, middle), greaterThanOrEqualTo(4.5));
      expect(colorContrast(tokens.textSecondary, middle), greaterThanOrEqualTo(4.5));
      expect(middle, isNot(before));
      await tester.pumpAndSettle();
      expect(await pixel(), isNot(middle));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('zero intensity without artwork also suppresses native Mica', (tester) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 80,
            height: 60,
            child: RepaintBoundary(
              key: boundary,
              child: const FrostWindowCaptionScope(
                systemBackdropActive: true,
                child: FrostAmbientBackdropHost(image: null, intensity: 0, child: SizedBox.expand()),
              ),
            ),
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => render.toImage()))!;
    final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    image.dispose();
    expect(bytes.getUint8(3), 255);
    expect(Color.fromARGB(bytes.getUint8(3), bytes.getUint8(0), bytes.getUint8(1), bytes.getUint8(2)), FrostPalettes.pink.darkNeutral.canvas);
    expect(frostHasTranslucentWindowBase(tester.element(find.byType(FrostAmbientBackdrop))), false);
  });
}
