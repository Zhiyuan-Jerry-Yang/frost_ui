import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'app_router_test.dart' show TestRouter;
import 'support.dart';

void main() {
  final palettes = FrostPalettes.pink;
  final black = FrostAppearance.initial(palettes).copyWith(mode: ThemeMode.system, darkModeColor: FrostDarkModeColor.black, darkTone: FrostTone.warm);

  test('old and invalid records retain gray, black round-trips all preferences', () {
    final record = black.toRecord();
    expect(FrostAppearance.fromRecord(record, palettes), black);
    for (final value in [null, 'unknown', true]) {
      final old = Map<String, Object?>.of(record)..['darkModeColor'] = value;
      final restored = FrostAppearance.fromRecord(old, palettes);
      expect(restored.darkModeColor, FrostDarkModeColor.darkGray);
      expect(restored.darkTone, FrostTone.warm);
      expect(restored.mode, ThemeMode.system);
    }
    final manual = black.copyWith(mode: ThemeMode.dark);
    expect(manual.effectiveToneFor(Brightness.dark), FrostTone.neutral);
    expect(manual.copyWith(darkModeColor: FrostDarkModeColor.darkGray).effectiveToneFor(Brightness.dark), FrostTone.warm);
  });

  test('black changes only dark palettes and retains readable ink and accents', () {
    for (final tone in FrostTone.values) {
      final ordinary = palettes.palette(Brightness.light, tone, black.lightAccent);
      final light = palettes.palette(Brightness.light, tone, black.lightAccent, darkModeColor: FrostDarkModeColor.black);
      expect(light.canvas, ordinary.canvas);
      expect(light.surface, ordinary.surface);
      expect(light.textPrimary, ordinary.textPrimary);
      expect(light.tone, tone);
      expect(light.isBlack, isFalse);
      final dark = palettes.palette(Brightness.dark, tone, black.darkAccent, darkModeColor: FrostDarkModeColor.black);
      expect(dark.canvas, Colors.black);
      expect(dark.surface, const Color(0xFF1C1C1E));
      expect(dark.surfaceRaised, const Color(0xFF2C2C2E));
      expect(dark.tone, FrostTone.neutral);
      expect(dark.accent, black.darkAccent);
      expect(dark.copyWith().isBlack, isTrue);
      expect(dark.lerp(dark, .5).isBlack, isTrue);
      for (final background in [dark.canvas, dark.surface, dark.surfaceRaised, dark.pressedSurface]) {
        expect(colorContrast(dark.textPrimary, background), greaterThanOrEqualTo(4.5));
        expect(colorContrast(dark.textSecondary, background), greaterThanOrEqualTo(4.5));
        expect(colorContrast(dark.accentInk, background), greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets('FrostApp follows system brightness and restores ordinary tone', (tester) async {
    final router = TestRouter(const SizedBox());
    addTearDown(router.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late FrostThemeTokens tokens;
    Future<void> mount(FrostAppearance appearance) async {
      await tester.pumpWidget(
        FrostApp.router(
          config: testConfig,
          title: 'Black appearance',
          routerConfig: RouterConfig<Object>(routerDelegate: router),
          appearance: appearance,
          builder: (context, child) {
            tokens = FrostThemeTokens.of(context);
            return child!;
          },
        ),
      );
      await tester.pumpAndSettle();
    }

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await mount(black);
    expect(tokens.isBlack, isFalse);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(tokens.isBlack, isTrue);
    expect(tokens.canvas, Colors.black);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(tokens.isBlack, isFalse);
    await mount(black.copyWith(mode: ThemeMode.dark, darkModeColor: FrostDarkModeColor.darkGray));
    expect(tokens.tone, FrostTone.warm);
    expect(tokens.canvas, palettes.darkWarm.canvas);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('media appearance changes retain foreground state and suppress artwork requests', (tester) async {
    final image = _CountedImage();
    final input = GlobalKey();
    var mode = FrostDarkModeColor.black;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: FrostTheme.build(
                config: testConfig,
                brightness: Brightness.dark,
                darkModeColor: mode,
                platform: TargetPlatform.iOS,
                locale: const Locale('en'),
              ),
              home: FrostAmbientBackdropHost(
                image: image,
                child: FrostAmbientBackdrop.fromImage(
                  image: image,
                  child: Material(child: TextField(key: input)),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(image.loads, 0);
    final state = tester.state(find.byKey(input));
    await tester.enterText(find.byKey(input), 'preserved');
    for (final color in [FrostDarkModeColor.darkGray, FrostDarkModeColor.black, FrostDarkModeColor.darkGray]) {
      update(() => mode = color);
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(input)), same(state));
      expect(find.text('preserved'), findsOneWidget);
    }
    expect(image.loads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final reduced in [false, true]) {
    testWidgets('rendered black bases reject ambient tint and retain gray layers, reduced=$reduced', (tester) async {
      final key = GlobalKey();
      // Invalid bytes also prove that a suppressed media backdrop isn't decoded.
      final image = MemoryImage(Uint8List.fromList([1, 2, 3]));
      await tester.pumpWidget(
        FrostScope(
          config: testConfig,
          reduceTransparency: reduced,
          child: MaterialApp(
            theme: FrostTheme.build(
              config: testConfig,
              brightness: Brightness.dark,
              darkModeColor: FrostDarkModeColor.black,
              platform: TargetPlatform.iOS,
              locale: const Locale('en'),
            ),
            home: Center(
              child: SizedBox(
                width: 300,
                height: 80,
                child: RepaintBoundary(
                  key: key,
                  child: FrostAmbientBackdropHost(
                    image: null,
                    fallback: FrostAmbientFallback.accentWash,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: FrostAmbientBackdrop()),
                        const Expanded(
                          child: FrostSurface(role: FrostSurfaceRole.panel, elevated: false, borderRadius: BorderRadius.zero, child: SizedBox.expand()),
                        ),
                        const Expanded(
                          child: FrostSurface(role: FrostSurfaceRole.module, elevated: false, borderRadius: BorderRadius.zero, child: SizedBox.expand()),
                        ),
                        const Expanded(
                          child: FrostSurface(role: FrostSurfaceRole.sheet, elevated: false, borderRadius: BorderRadius.zero, child: SizedBox.expand()),
                        ),
                        Expanded(
                          child: FrostAmbientBackdrop.fromImage(image: image, child: const SizedBox.expand()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final colors = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final rendered = await boundary.toImage(pixelRatio: 1);
        final data = (await rendered.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final result = [
          for (final x in [30, 90, 150, 210, 270]) _sample(data, rendered.width, x, 40),
        ];
        rendered.dispose();
        return result;
      });
      expect(colors, [Colors.black, Colors.black, const Color(0xFF1C1C1E), const Color(0xFF2C2C2E), Colors.black]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _CountedImage extends ImageProvider<_CountedImage> {
  int loads = 0;
  @override
  Future<_CountedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_CountedImage key, ImageDecoderCallback decode) {
    loads++;
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}

Color _sample(ByteData bytes, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
}
