import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Finder get _indicator => find.byWidgetPredicate((w) => w is CustomPaint && w.painter?.runtimeType.toString() == '_IndicatorPainter');
RRect mark(WidgetTester tester) {
  RRect? rect;
  final paint = tester.widget<CustomPaint>(_indicator);
  expect(
    (Canvas canvas) => paint.painter!.paint(canvas, tester.getSize(_indicator)),
    paints..something((method, arguments) {
      if (method == #drawRRect) {
        rect = arguments[0] as RRect;
        return true;
      }
      return false;
    }),
  );
  return rect!;
}

void main() {
  testWidgets('tab hover includes its label padding and keyboard focus uses shared ring', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Material(
          child: Center(
            child: FrostTabBar(
              controller: controller,
              tabs: const [
                FrostTab(label: 'First'),
                FrostTab(label: 'Second'),
              ],
            ),
          ),
        ),
      ),
    );
    final tab = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TabLabel').first;
    final box = tester.getRect(tab);
    expect(tester.getRect(find.text('First')).left - box.left, 12);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(box.left + 2, box.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final paint = tester.renderObject<RenderDecoratedBox>(find.descendant(of: tab, matching: find.byType(DecoratedBox)).first);
    final mid = (paint.decoration as ShapeDecoration).color!;
    final tokens = FrostThemeTokens.of(tester.element(tab));
    expect(mid.a, inExclusiveRange(0, tokens.fillSubtle.a));
    await tester.pumpAndSettle();
    expect((paint.decoration as ShapeDecoration).color, tokens.fillSubtle);
    await mouse.removePointer();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: tab,
        matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == 'FrostFocusOutlinePainter'),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  for (final density in FrostDensity.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('tab bar actual height, fixed mark and reserved labels $density $scale', (tester) async {
        final controller = TabController(length: 3, vsync: tester);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          frostTestApp(
            Material(
              child: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: FrostTabBar(
                    controller: controller,
                    tabs: [
                      const FrostTab(label: 'One'),
                      FrostTab(label: 'Longer title', icon: testIcons.info),
                      const FrostTab(label: 'Three'),
                    ],
                  ),
                ),
              ),
            ),
            density: density,
          ),
        );
        final bar = find.byType(FrostTabBar);
        final typography = FrostTypography.of(tester.element(bar));
        double line(double factor) {
          final p = TextPainter(
            text: TextSpan(style: typography.style(FrostTextRole.callout)),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(factor),
          )..layout();
          final result = p.preferredLineHeight;
          p.dispose();
          return result;
        }

        final base = density.heightFor(FrostControlSize.regular);
        expect(tester.getSize(bar).height, base + line(scale) - line(1));
        final widths = [
          for (final title in ['One', 'Longer title', 'Three']) tester.getSize(find.text(title)).width,
        ];
        final tokens = FrostThemeTokens.of(tester.element(bar));
        for (var i = 0; i < 3; i++) {
          controller.index = i;
          await tester.pumpAndSettle();
          final rect = mark(tester);
          expect(rect.width, 20);
          expect(rect.height, 3);
          final title = ['One', 'Longer title', 'Three'][i];
          final center = tester.getCenter(find.text(title)).dx - tester.getTopLeft(_indicator).dx;
          expect(rect.center.dx, closeTo(center, .001));
          expect(rect.bottom, tester.getSize(bar).height);
          final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
          expect(paragraph.text.style!.color, tokens.textPrimary);
          expect(paragraph.text.style!.fontWeight, FontWeight.w500);
          expect(tester.getSize(find.text(title)).width, widths[i]);
          final other = ['One', 'Longer title', 'Three'][(i + 1) % 3];
          expect(tester.renderObject<RenderParagraph>(find.text(other)).text.style!.color, tokens.textSecondary);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('mark springs without changing width; ink uses 140ms and reduced motion snaps', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    addTearDown(controller.dispose);
    Widget app(bool reduced) => frostTestApp(
      Material(
        child: Center(
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: FrostTabBar(
              controller: controller,
              tabs: const [
                FrostTab(label: 'First'),
                FrostTab(label: 'Second longer'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    final start = mark(tester).center.dx;
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostTabBar)));
    controller.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final mid = mark(tester);
    expect(mid.width, 20);
    final color = tester.renderObject<RenderParagraph>(find.text('Second longer')).text.style!.color;
    expect(color, isNot(tokens.textPrimary));
    expect(color, isNot(tokens.textSecondary));
    await tester.pumpAndSettle();
    final end = mark(tester).center.dx;
    expect(mid.center.dx, inExclusiveRange(start, end));
    await tester.pumpWidget(app(true));
    controller.index = 0;
    await tester.pump();
    expect(mark(tester).center.dx, start);
    expect(tester.renderObject<RenderParagraph>(find.text('First')).text.style!.color, tokens.textPrimary);
  });
  testWidgets('RTL and horizontal scrolling keep mark below icon tab text', (tester) async {
    final controller = TabController(length: 8, vsync: tester);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Material(
          child: Center(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: 300,
                child: FrostTabBar(
                  scrollable: true,
                  controller: controller,
                  tabs: [for (var i = 0; i < 8; i++) FrostTab(label: 'Long tab $i', icon: testIcons.info)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.index = 6;
    await tester.pumpAndSettle();
    final rect = mark(tester);
    expect(rect.center.dx, closeTo(tester.getCenter(find.text('Long tab 6')).dx - tester.getTopLeft(_indicator).dx, .001));
    expect(rect.width, 20);
    expect(tester.takeException(), isNull);
  });
}
