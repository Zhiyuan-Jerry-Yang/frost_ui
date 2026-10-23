import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final tone in FrostTone.values) {
      testWidgets('base paint separates the sheet and tints ambient: $brightness $tone', (tester) async {
        final tokens = FrostPalettes.pink.palette(brightness, tone, FrostPalettes.pink.defaultAccent(brightness));
        final boundaryKey = GlobalKey();
        late FrostSurfaceScope scope;
        Future<List<Color>> pixels({required bool ambient, required bool solid, bool paintBase = true}) async {
          final layers = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ColoredBox(color: tokens.canvas)),
              Expanded(
                child: paintBase
                    ? FrostSurface(
                        role: FrostSurfaceRole.base,
                        child: Builder(
                          builder: (context) {
                            scope = FrostSurfaceScope.maybeOf(context)!;
                            return const SizedBox.expand();
                          },
                        ),
                      )
                    : const FrostAmbientBackdrop(),
              ),
              const Expanded(
                child: FrostSurface(role: FrostSurfaceRole.sheet, elevated: false, child: SizedBox.expand()),
              ),
            ],
          );
          await tester.pumpWidget(
            frostTestApp(
              Theme(
                data: FrostTheme.build(config: testConfig, brightness: brightness, tone: tone, platform: TargetPlatform.windows, locale: const Locale('en')),
                child: FrostScope(
                  config: testConfig,
                  reduceTransparency: solid,
                  child: Center(
                    child: SizedBox(
                      width: 240,
                      height: 80,
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: ambient ? FrostAmbientBackdropHost(image: null, child: layers) : layers,
                      ),
                    ),
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          return tester
              .runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
                final image = await boundary.toImage(pixelRatio: 1);
                final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
                Color sample(int x) {
                  final offset = (40 * image.width + x) * 4;
                  return Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
                }

                final result = [sample(40), sample(120), sample(200)];
                image.dispose();
                return result;
              })
              .then((value) => value!);
        }

        // Sample the former canvas base, the new base, and the sheet itself.
        final [oldBase, base, sheet] = await pixels(ambient: false, solid: true);
        expect(oldBase, tokens.canvas);
        expect(sheet, tokens.surface);
        expect(scope.background, tokens.isDark ? tokens.canvas : Color.alphaBlend(tokens.fillSubtle, tokens.canvas));
        if (tokens.isDark) {
          expect(base, oldBase);
        } else {
          expect((base.computeLuminance() - sheet.computeLuminance()).abs(), greaterThan((oldBase.computeLuminance() - sheet.computeLuminance()).abs()));
        }

        for (final solid in [false, true]) {
          final backdrop = (await pixels(ambient: true, solid: solid, paintBase: false))[1];
          final tinted = (await pixels(ambient: true, solid: solid))[1];
          // Compare the same window position, including the ambient gradients.
          final expected = tokens.isDark ? backdrop : Color.alphaBlend(tokens.fillSubtle, backdrop);
          for (final (actual, target) in [(tinted.r, expected.r), (tinted.g, expected.g), (tinted.b, expected.b)]) {
            expect(actual, closeTo(target, 1 / 255));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
