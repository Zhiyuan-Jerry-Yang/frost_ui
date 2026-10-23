import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'media_frame_test.dart' show ControlledImage;
import 'r3_ambient_material_test.dart' show resolveImage;
import 'support.dart';

Future<Color> pixel(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  image.dispose();
  final at = (20 * 180 + 20) * 4;
  return Color.fromARGB(bytes.getUint8(at + 3), bytes.getUint8(at), bytes.getUint8(at + 1), bytes.getUint8(at + 2));
}

void main() {
  testWidgets('replacement retains old artwork through loading, stale success and failure', (tester) async {
    final first = ControlledImage(), stale = ControlledImage(), latest = ControlledImage(), failed = ControlledImage();
    ImageProvider image = first;
    late StateSetter update;
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return Center(
              child: SizedBox(
                width: 180,
                height: 120,
                child: RepaintBoundary(
                  key: key,
                  child: FrostAmbientBackdropHost(image: image, fallback: FrostAmbientFallback.accentWash, child: const SizedBox.expand()),
                ),
              ),
            );
          },
        ),
      ),
    );
    await resolveImage(tester, first, const Color(0xff900010));
    final old = await pixel(tester, key);
    update(() => image = stale);
    await tester.pumpAndSettle();
    expect(await pixel(tester, key), old);
    update(() => image = latest);
    await tester.pumpAndSettle();
    await resolveImage(tester, stale, Colors.blue);
    expect(await pixel(tester, key), old);
    await resolveImage(tester, latest, Colors.green);
    final next = await pixel(tester, key);
    expect(next, isNot(old));
    update(() => image = failed);
    await tester.pumpAndSettle();
    expect(await pixel(tester, key), next);
    failed.completer.fail(StateError('artwork unavailable'));
    await tester.pumpAndSettle();
    expect(await pixel(tester, key), next);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    for (final mica in [false, true]) {
      testWidgets('explicit no-art fallback retains none, contrast and zero intensity $brightness mica=$mica', (tester) async {
        final key = GlobalKey();
        late StateSetter update;
        var fallback = FrostAmbientFallback.none;
        var intensity = 1.0;
        var childBuilds = 0;
        final page = Builder(
          builder: (_) {
            childBuilds++;
            return const SizedBox.expand();
          },
        );
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (_, set) {
                update = set;
                return Center(
                  child: SizedBox(
                    width: 180,
                    height: 120,
                    child: RepaintBoundary(
                      key: key,
                      child: FrostWindowCaptionScope(
                        systemBackdropActive: mica,
                        child: FrostAmbientBackdropHost(image: null, fallback: fallback, intensity: intensity, child: page),
                      ),
                    ),
                  ),
                );
              },
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostAmbientBackdrop)));
        final before = await pixel(tester, key);
        expect(before, mica ? Colors.transparent : tokens.canvas);
        final count = childBuilds;
        update(() => fallback = FrostAmbientFallback.accentWash);
        await tester.pumpAndSettle();
        final accent = await pixel(tester, key);
        expect(accent.a, 1);
        expect(accent, isNot(before));
        for (final ink in [tokens.textPrimary, tokens.textSecondary]) {
          expect(colorContrast(ink, accent), greaterThanOrEqualTo(4.5));
        }
        update(() => intensity = 0);
        await tester.pumpAndSettle();
        expect(await pixel(tester, key), tokens.canvas);
        update(() {
          intensity = 1;
          fallback = FrostAmbientFallback.none;
        });
        await tester.pumpAndSettle();
        expect(await pixel(tester, key), before);
        expect(childBuilds, count);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('fallback has no effect on resolved artwork $brightness', (tester) async {
      final image = ControlledImage();
      final key = GlobalKey();
      var fallback = FrostAmbientFallback.none;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return Center(
                child: SizedBox(
                  width: 180,
                  height: 120,
                  child: RepaintBoundary(
                    key: key,
                    child: FrostAmbientBackdropHost(image: image, fallback: fallback, child: const SizedBox.expand()),
                  ),
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      await resolveImage(tester, image, Colors.white);
      final before = await pixel(tester, key);
      update(() => fallback = FrostAmbientFallback.accentWash);
      await tester.pumpAndSettle();
      expect(await pixel(tester, key), before);
      expect(tester.takeException(), isNull);
    });
  }
}
