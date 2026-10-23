import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'support.dart';

void main() {
  for (final dpr in [1.0, 1.5, 2.625]) {
    for (final continuous in [false, true]) {
      testWidgets('rounded feedback retains antialias coverage dpr=$dpr continuous=$continuous', (tester) async {
        final key = GlobalKey();
        final shape = continuous
            ? const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(16)))
            : const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)));
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: RepaintBoundary(
                key: key,
                child: FrostClickFeedbackVisual(shape: shape, states: const {WidgetState.hovered}, child: const SizedBox(width: 120, height: 48)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image = (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImageSync(pixelRatio: dpr);
        final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        final centerAlpha = data.getUint8(((image.height ~/ 2) * image.width + image.width ~/ 2) * 4 + 3);
        expect(centerAlpha, greaterThan(0));
        var fractionalCoverage = false;
        for (var y = 0; y < (16 * dpr).ceil(); y++) {
          for (var x = 0; x < (16 * dpr).ceil(); x++) {
            final alpha = data.getUint8((y * image.width + x) * 4 + 3);
            if (alpha > 0 && alpha < centerAlpha) fractionalCoverage = true;
          }
        }
        image.dispose();
        expect(fractionalCoverage, isTrue, reason: 'Curved edges must have partial coverage, rather than a binary stair-step mask.');
        final clip = tester.widget<ClipPath>(find.descendant(of: find.byType(FrostClickFeedbackVisual), matching: find.byType(ClipPath)));
        expect(clip.clipBehavior, Clip.antiAlias);
        expect((clip.clipper! as ShapeBorderClipper).shape, shape);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
