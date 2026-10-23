import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Finder get _switch => find.byType(FrostSwitch);
List<RenderDecoratedBox> _boxes(WidgetTester tester) =>
    tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: _switch, matching: find.byType(DecoratedBox))).toList();
RenderDecoratedBox _track(WidgetTester tester) => _boxes(tester).first;
RenderDecoratedBox _thumb(WidgetTester tester) => _boxes(tester).last;
Rect _thumbRect(WidgetTester tester) {
  final thumb = _thumb(tester);
  return thumb.localToGlobal(Offset.zero, ancestor: _track(tester)) & thumb.size;
}

void main() {
  testWidgets('touch platforms keep touch switch geometry in either density', (tester) async {
    for (final density in FrostDensity.values) {
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => Theme(
              data: FrostTheme.build(
                config: testConfig,
                brightness: Brightness.light,
                platform: TargetPlatform.android,
                locale: const Locale('en'),
                density: density,
              ),
              child: const Center(child: FrostSwitch(value: false, onChanged: null, semanticLabel: null)),
            ),
          ),
          density: density,
        ),
      );
      expect(_track(tester).size, const Size(48, 28));
      expect(_thumb(tester).size, const Size(24, 24));
      expect(tester.getSize(_switch).height, 44);
      expect(tester.takeException(), isNull);
    }
  });
  for (final density in FrostDensity.values) {
    for (final direction in TextDirection.values) {
      testWidgets('switch geometry, press direction, spring, colour and focus $density $direction', (tester) async {
        late StateSetter update;
        late FrostThemeTokens tokens;
        var value = false;
        final touch = density == FrostDensity.comfortable;
        final width = touch ? 48.0 : 40.0, height = touch ? 28.0 : 24.0, diameter = touch ? 24.0 : 20.0;
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    tokens = FrostThemeTokens.of(context);
                    return FrostSwitch(value: value, onChanged: (v) => update(() => value = v), semanticLabel: 'Switch');
                  },
                ),
              ),
            ),
            density: density,
          ),
        );
        expect(_track(tester).size, Size(width, height));
        expect(_thumb(tester).size, Size.square(diameter));
        expect(tester.getSize(_switch).height, density.targetHeight);
        expect((_track(tester).decoration as BoxDecoration).color, tokens.fillStrong);
        expect((_track(tester).decoration as BoxDecoration).border, isNull);
        expect((_thumb(tester).decoration as BoxDecoration).color, Colors.white);
        expect(tokens.controlThumbFill, Colors.white);
        expect(tokens.copyWith(onMediaInk: Colors.red).controlThumbFill, Colors.white);
        expect((_thumb(tester).decoration as BoxDecoration).boxShadow, tokens.shadowContact);
        final idle = _thumbRect(tester);
        expect(idle.left, direction == TextDirection.ltr ? 2 : width - diameter - 2);
        final gesture = await tester.startGesture(tester.getCenter(_switch));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final pressed = _thumbRect(tester);
        expect(pressed.width, closeTo(diameter + 6, .01));
        expect(direction == TextDirection.ltr ? pressed.left : pressed.right, direction == TextDirection.ltr ? idle.left : idle.right);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final moving = _thumbRect(tester);
        expect(moving.center.dx, inExclusiveRange(diameter / 2 + 2, width - diameter / 2 - 2));
        final colour = (_track(tester).decoration as BoxDecoration).color!;
        expect(colour, isNot(tokens.fillStrong));
        expect(colour, isNot(tokens.actionFill));
        await tester.pumpAndSettle();
        expect((_track(tester).decoration as BoxDecoration).color, tokens.actionFill);
        expect(_thumb(tester).size, Size.square(diameter));
        final onIdle = _thumbRect(tester);
        final onPress = await tester.startGesture(tester.getCenter(_switch));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final onPressed = _thumbRect(tester);
        expect(onPressed.width, closeTo(diameter + 6, .01));
        expect(direction == TextDirection.ltr ? onPressed.right : onPressed.left, direction == TextDirection.ltr ? onIdle.right : onIdle.left);
        await onPress.cancel();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(value, false);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(value, true);
        final paint = find.descendant(of: _switch, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null));
        expect(
          (Canvas canvas) => tester.widget<CustomPaint>(paint).foregroundPainter!.paint(canvas, Size(width, height)),
          paints..rrect(
            rrect: RRect.fromRectAndRadius(Rect.fromLTWH(-3, -3, width + 6, height + 6), Radius.circular(height / 2 + 3)),
            color: tokens.focus,
            strokeWidth: 2,
            style: PaintingStyle.stroke,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('drag follows the thumb, uses velocity and mirrors RTL; disabled drag returns silently', (tester) async {
    for (final direction in TextDirection.values) {
      for (final mode in ['slow-before-half', 'slow-past-half', 'fast', 'disable']) {
        var value = false, enabled = true;
        var calls = 0;
        late StateSetter update;
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: StatefulBuilder(
                  builder: (_, set) {
                    update = set;
                    return FrostSwitch(
                      value: value,
                      onChanged: enabled
                          ? (v) {
                              calls++;
                              update(() => value = v);
                            }
                          : null,
                      semanticLabel: 'Switch',
                    );
                  },
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        final sign = direction == TextDirection.ltr ? 1.0 : -1.0;
        final gesture = await tester.startGesture(tester.getCenter(_switch), kind: PointerDeviceKind.mouse);
        // Enter the horizontal arena, then reverse to the requested position.
        await gesture.moveBy(Offset(sign * 24, 0));
        await tester.pump();
        final progress = mode == 'slow-past-half' ? .7 : .4;
        await gesture.moveBy(Offset(sign * (16 * progress - 24), 0));
        await tester.pump();
        final x = direction == TextDirection.ltr ? _thumbRect(tester).left : 40 - _thumbRect(tester).right;
        expect(x, closeTo(2 + 16 * progress, .01));
        if (mode == 'disable') {
          update(() => enabled = false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 70));
          final x2 = direction == TextDirection.ltr ? _thumbRect(tester).left : 40 - _thumbRect(tester).right;
          expect(x2, lessThan(x));
          update(() => enabled = true);
          await tester.pump();
        }
        if (mode == 'fast') {
          // Short samples produce a fast release while the position stays < .5.
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 1));
            await gesture.moveBy(Offset(sign * .4, 0), timeStamp: Duration(milliseconds: 100 + i));
          }
          await gesture.up(timeStamp: const Duration(milliseconds: 103));
        } else {
          await tester.pump(const Duration(milliseconds: 300));
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(value, mode == 'fast' || mode == 'slow-past-half', reason: '$mode $direction');
        expect(calls, value ? 1 : 0);
        expect(_thumb(tester).size.width, 20);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('disabled switch opacity and off-track pixels have no outline', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: RepaintBoundary(key: key, child: const FrostSwitch(value: false, onChanged: null, semanticLabel: null)),
        ),
        density: FrostDensity.compact,
      ),
    );
    final fade = tester.renderObject<RenderAnimatedOpacity>(find.descendant(of: _switch, matching: find.byType(FadeTransition)));
    expect(fade.opacity.value, .38);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 4);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      // Far from the thumb/shadow: an outline would raise alpha above the fill.
      final alpha = bytes.getUint8(((18 * 4) * image.width + 39 * 4) * 4 + 3);
      expect(alpha, lessThanOrEqualTo((.12 * .38 * 255).ceil()));
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fast spring can be interrupted and dragged back from its visible endpoint', (tester) async {
    var value = false;
    late StateSetter update;
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: StatefulBuilder(
            builder: (context, set) {
              update = set;
              tokens = FrostThemeTokens.of(context);
              return FrostSwitch(value: value, onChanged: (v) => update(() => value = v), semanticLabel: 'Switch');
            },
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    final first = await tester.startGesture(tester.getCenter(_switch), kind: PointerDeviceKind.mouse);
    await first.moveBy(const Offset(24, 0));
    await first.moveBy(const Offset(-17.6, 0));
    for (var i = 0; i < 3; i++) {
      await first.moveBy(const Offset(.8, 0), timeStamp: Duration(milliseconds: 100 + i));
    }
    await first.up(timeStamp: const Duration(milliseconds: 103));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(value, true);
    final beforeReverse = (_track(tester).decoration as BoxDecoration).color;
    expect(beforeReverse, isNot(tokens.actionFill), reason: 'Bounded release speed approaches the endpoint without crossing it.');
    final reverse = await tester.startGesture(tester.getCenter(_switch), kind: PointerDeviceKind.mouse);
    await reverse.moveBy(const Offset(-3, 0));
    await tester.pump();
    expect((_track(tester).decoration as BoxDecoration).color, isNot(beforeReverse));
    await reverse.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switch row is one toggled node, grows with content and handles row tap and keyboard', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 230,
            child: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return FrostListRow.toggle(
                  value: value,
                  onChanged: (v) => update(() => value = v),
                  title: 'A long title that wraps over lines',
                  subtitle: 'A long secondary explanation that also wraps',
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ListTile), findsNothing);
    expect(tester.getSize(find.byType(FrostListRow)).height, greaterThan(44));
    final node = tester.getSemantics(find.byType(FrostListRow));
    expect(node.getSemanticsData().flagsCollection.isToggled, ui.Tristate.isFalse);
    expect(node.childrenCount, 0);
    await tester.tap(find.text('A long title that wraps over lines'));
    await tester.pumpAndSettle();
    expect(value, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, false);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
