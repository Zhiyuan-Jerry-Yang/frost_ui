import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('system protection paints over Navigator overlay and follows return', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    final capture = GlobalKey();
    await tester.pumpWidget(
      FrostScope(
        config: testConfig,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.android, locale: const Locale('en')),
          builder: (context, child) => RepaintBoundary(
            key: capture,
            child: FrostMediaSystemChromeHost(child: child!),
          ),
          home: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    double? initial;
    Future<double> sample() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final red = bytes.getUint8((10 * image.width + 195) * 4) / 255;
      image.dispose();
      return red;
    }

    initial = await sample();
    expect(initial, 1);
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const FrostMediaSystemChrome(child: ColoredBox(color: Colors.white)),
      ),
    );
    await tester.pumpAndSettle();
    final entry = OverlayEntry(
      builder: (_) => const Positioned.fill(child: ColoredBox(color: Colors.white)),
    );
    navigator.currentState!.overlay!.insert(entry);
    await tester.pump();
    final stable = await sample();
    expect(stable, lessThan(.4), reason: 'an opaque overlay cannot cover the host gradient');
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
    final annotation = boundary.debugLayer!.find<SystemUiOverlayStyle>(const Offset(195, 10));
    expect(annotation!.statusBarIconBrightness, Brightness.light);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final middle = await sample();
    expect(middle, greaterThan(stable));
    expect(middle, lessThan(initial));
    await tester.pumpAndSettle();
    expect(await sample(), 1);
    entry.remove();
    entry.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
