import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  for (final dpr in [1.0, 1.25, 1.5, 2.0]) {
    for (final kind in [FrostCaptionGlyphKind.minimize, FrostCaptionGlyphKind.maximize, FrostCaptionGlyphKind.restore, FrostCaptionGlyphKind.close]) {
      testWidgets('$kind has opaque strokes at fractional origin, DPR $dpr', (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(100 * dpr, 100 * dpr);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        const origin = Offset(5.3, 7.7);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(devicePixelRatio: dpr),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Stack(
                      children: [
                        Positioned(
                          left: origin.dx,
                          top: origin.dy,
                          child: FrostCaptionGlyph(kind, color: const Color(0xFFFFFFFF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: dpr);
          final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final result = (bytes: data!.buffer.asUint8List(), width: image.width, height: image.height);
          image.dispose();
          return result;
        });
        final probes = switch (kind) {
          FrostCaptionGlyphKind.minimize => [const Offset(5, 5)],
          FrostCaptionGlyphKind.maximize => [const Offset(5, .5), const Offset(.5, 5), const Offset(9.5, 5), const Offset(5, 9.5)],
          FrostCaptionGlyphKind.restore => [
            const Offset(5, .5),
            const Offset(9.5, 4),
            const Offset(5, 2.5),
            const Offset(.5, 6),
            const Offset(7.5, 6),
            const Offset(4, 9.5),
          ],
          FrostCaptionGlyphKind.close => [const Offset(2.5, 2.5), const Offset(7.5, 2.5), const Offset(2.5, 7.5), const Offset(7.5, 7.5)],
          _ => throw StateError('Unexpected glyph'),
        };
        for (final probe in probes) {
          final centre = (origin + probe) * dpr;
          var maximum = 0;
          for (var y = (centre.dy - 1.5 * dpr).floor(); y <= (centre.dy + 1.5 * dpr).ceil(); y++) {
            for (var x = (centre.dx - 1.5 * dpr).floor(); x <= (centre.dx + 1.5 * dpr).ceil(); x++) {
              if (x >= 0 && y >= 0 && x < pixels!.width && y < pixels.height) {
                final alpha = pixels.bytes[(y * pixels.width + x) * 4 + 3];
                if (alpha > maximum) maximum = alpha;
              }
            }
          }
          expect(maximum, greaterThanOrEqualTo(230), reason: 'stroke near $probe at DPR $dpr');
        }
      });
    }
  }
}
