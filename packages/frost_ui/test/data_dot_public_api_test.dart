import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  Color color(WidgetTester tester, Finder dot) =>
      (tester.widget<Container>(find.descendant(of: dot, matching: find.byType(Container))).decoration! as BoxDecoration).color!;
  testWidgets('categorical dot skeleton paints the configured bone color, not category ink', (tester) async {
    final capture = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => FrostScope(
            config: testConfig.copyWith(
              skeleton: FrostSkeletonStyle(effect: FrostSkeletonEffect.solid, color: (tokens) => tokens.infoInk),
            ),
            child: RepaintBoundary(
              key: capture,
              child: SizedBox.square(dimension: 20, child: const Center(child: FrostDataDot(0)).frostSkeleton(true)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(() => image.toByteData()))!.buffer.asUint8List();
    final expected = FrostThemeTokens.of(tester.element(find.byType(FrostDataDot))).infoInk.toARGB32();
    final point = boundary.globalToLocal(tester.getCenter(find.byType(FrostDataDot)));
    final pixel = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    expect(data.sublist(pixel, pixel + 4), [(expected >> 16) & 255, (expected >> 8) & 255, expected & 255, (expected >> 24) & 255]);
    expect(tester.getSize(find.byType(FrostDataDot)), const Size(6, 6));
    image.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('public categorical dot shares tag geometry and theme color, without its own label', (tester) async {
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        frostTestApp(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostDataDot(2, key: ValueKey('standalone')),
              FrostTag(label: 'Category label', dataColor: 2),
            ],
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final standalone = find.byKey(const ValueKey('standalone'));
      final tag = find.descendant(of: find.byType(FrostTag), matching: find.byType(FrostDataDot));
      expect(tester.getSize(standalone), const Size(6, 6));
      expect(tester.getSize(tag), const Size(6, 6));
      final tokens = FrostThemeTokens.of(tester.element(standalone));
      expect(color(tester, standalone), tokens.categorical[2]);
      expect(color(tester, tag), color(tester, standalone));
      expect(find.bySemanticsLabel('Category label'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });
  testWidgets('themed index changes preserve geometry through intermediate color frames', (tester) async {
    const dot = FrostDataDot(1, key: ValueKey('dot'));
    await tester.pumpWidget(frostTestApp(const Center(child: dot)));
    await tester.pumpAndSettle();
    final finder = find.byKey(const ValueKey('dot'));
    final rect = tester.getRect(finder);
    final before = color(tester, finder);
    await tester.pumpWidget(
      frostTestApp(
        const Center(child: FrostDataDot(2, key: ValueKey('dot'))),
        brightness: Brightness.dark,
      ),
    );
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.getRect(finder), rect);
    final current = color(tester, finder);
    final after = FrostThemeTokens.of(tester.element(finder)).categorical[2];
    for (final channel in [current.r, current.g, current.b]) {
      expect(channel, inInclusiveRange(0, 1));
    }
    final tween = tester.widget<TweenAnimationBuilder<Color?>>(find.descendant(of: finder, matching: find.byType(TweenAnimationBuilder<Color?>)));
    expect(tween.duration, FrostMotion.hover);
    expect(current, Color.lerp(before, after, .5));
    await tester.pumpAndSettle();
    expect(color(tester, finder), FrostThemeTokens.of(tester.element(finder)).categorical[2]);
    expect(tester.takeException(), isNull);
  });
}
