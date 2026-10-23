import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'media_frame_test.dart' show ControlledImage;
import 'r3_ambient_material_test.dart' show resolveImage;
import 'support.dart';

void main() {
  testWidgets('settled ambient paint needs no full-window opacity buffer', (tester) async {
    final provider = ControlledImage();
    var intensity = 1.0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostAmbientBackdropHost(image: provider, intensity: intensity, child: const SizedBox.expand());
          },
        ),
      ),
    );
    await resolveImage(tester, provider, const Color(0xff245898));
    RenderObject backdrop() => tester.renderObject(
      find.descendant(of: find.byType(FrostAmbientBackdropHost), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AmbientPaint')).first,
    );
    expect(backdrop(), paintsExactlyCountTimes(#saveLayer, 0));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    // The settled endpoint is now one physical-resolution image, with no
    // repeated wash gradients, scrim, or artwork color filter on route frames.
    expect(backdrop(), paintsExactlyCountTimes(#drawImageRect, 1));
    expect(backdrop(), paintsExactlyCountTimes(#drawRect, 1));
    update(() => intensity = .4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(backdrop(), paintsExactlyCountTimes(#saveLayer, 1));
    await tester.pumpAndSettle();
    expect(backdrop(), paintsExactlyCountTimes(#saveLayer, 0));
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('prepared ambient endpoint preserves physical pixels and window anchoring $brightness', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final provider = ControlledImage();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        frostTestApp(
          FrostAmbientBackdropHost(
            image: provider,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 180,
                height: 120,
                child: RepaintBoundary(key: boundary, child: const FrostAmbientBackdrop()),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await resolveImage(tester, provider, const Color(0xff245898));
      Future<List<int>> pixels() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => render.toImage(pixelRatio: 2)))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        image.dispose();
        return bytes.buffer.asUint8List().toList();
      }

      final live = await pixels();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      final cached = await pixels();
      expect(cached.length, live.length);
      // One extra 8-bit texture composite can round by one channel step.
      for (var i = 0; i < live.length; i++) {
        expect((live[i] - cached[i]).abs(), lessThanOrEqualTo(1), reason: 'channel $i');
      }
      final paint = find.descendant(of: find.byKey(boundary), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AmbientPaint'));
      expect(tester.renderObject(paint), paintsExactlyCountTimes(#drawRect, 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
