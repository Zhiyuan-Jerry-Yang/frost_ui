import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';
import 'support.dart';

void main() {
  testWidgets('content Hero remains below the caption throughout push and pop', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1, sourceRadius: FrostRadius.borderRadius(FrostRadius.lg));
    final boundary = GlobalKey();
    final navigator = GlobalKey<NavigatorState>();
    Widget caption() => const Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 40,
      child: ColoredBox(key: ValueKey('caption'), color: Colors.blue),
    );
    Widget image(double extent, BorderRadius radius) => SizedBox(
      width: extent,
      height: extent,
      child: FrostMediaHero(
        tag: tag,
        radius: radius,
        fit: BoxFit.contain,
        child: const ColoredBox(color: Colors.red),
      ),
    );
    await tester.pumpWidget(
      frostTestApp(
        RepaintBoundary(
          key: boundary,
          child: Stack(
            children: [
              Positioned.fill(
                top: 40,
                child: Navigator(
                  key: navigator,
                  observers: [HeroController()],
                  onGenerateRoute: (_) =>
                      PageRouteBuilder<void>(pageBuilder: (context, _, _) => Center(child: image(100, FrostRadius.borderRadius(FrostRadius.lg)))),
                ),
              ),
              caption(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => Stack(children: [Positioned.fill(child: image(400, BorderRadius.zero))]),
        transitionsBuilder: (_, _, _, child) => child,
      ),
    );
    Future<void> check() async {
      final box = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixels = await tester.runAsync(() async {
        final image = await box.toImage(pixelRatio: 1);
        try {
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      });
      final offset = (20 * 400 + 200) * 4;
      expect(pixels!.sublist(offset, offset + 3), [33, 150, 243]);
      expect(tester.takeException(), isNull);
    }

    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await check();
    }
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await check();
    }
    await tester.pumpAndSettle();
    expect(find.byType(FrostMediaHero), findsOneWidget);
  });
}
