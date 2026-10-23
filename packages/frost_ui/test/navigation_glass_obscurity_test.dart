import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'support.dart';

void main() {
  test('navigation obscures black/white without relying on blur across every palette/tone', () {
    for (final accent in FrostPalettes.pink.accentPresets) {
      for (final brightness in Brightness.values) {
        for (final tone in FrostTone.values) {
          final tokens = FrostPalettes.pink.palette(brightness, tone, accent);
          final minimum = frostGlassFillOpacity(tokens.surface, tokens.textPrimary, tokens.isDark);
          final alpha = frostNavigationGlassFillOpacity(tokens.surface, minimum);
          expect(alpha, greaterThanOrEqualTo(minimum));
          final fill = tokens.surface.withValues(alpha: alpha);
          final a = Color.alphaBlend(fill, Colors.black), b = Color.alphaBlend(fill, Colors.white);
          expect(colorContrast(a, b), lessThanOrEqualTo(frostNavigationBackdropContrastMaximum));
          expect(colorContrast(Color(a.toARGB32()), Color(b.toARGB32())), lessThanOrEqualTo(frostNavigationBackdropContrastMaximum));
          expect(colorContrast(tokens.textPrimary, tokens.isDark ? b : a), greaterThanOrEqualTo(4.5));
        }
      }
    }
  });
  for (final brightness in Brightness.values) {
    for (final solid in [false, true]) {
      testWidgets('actual navigation pixels protect background with deferred blur: $brightness solid=$solid', (tester) async {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 160,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
                        children: [
                          for (final color in [Colors.black, Colors.white]) Expanded(child: ColoredBox(color: color)),
                        ],
                      ),
                      FrostContentRevealScope(
                        opacity: 1,
                        nestedProgress: 0,
                        handle: FrostRevealHandle(),
                        parent: null,
                        child: const FrostSurface(
                          role: FrostSurfaceRole.chrome,
                          elevated: false,
                          edge: FrostSurfaceEdge.none,
                          borderRadius: BorderRadius.zero,
                          child: SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            brightness: brightness,
            reduceTransparency: solid,
          ),
        );
        await tester.pumpAndSettle();
        final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
        expect(filter.enabled, false);
        final image = (await tester.runAsync(() => (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1)))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        Color pixel(int x) {
          final offset = (40 * image.width + x) * 4;
          return Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
        }

        expect(colorContrast(pixel(20), pixel(140)), lessThanOrEqualTo(solid ? 1 : frostNavigationBackdropContrastMaximum));
        image.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
