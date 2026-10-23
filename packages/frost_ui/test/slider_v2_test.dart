import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_control_surfaces.dart';
import 'package:frost_ui/src/feedback/progress.dart';
import 'package:frost_ui/src/layout/_labeled_track.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'display_badges_v2_test.dart' show display, decorations;
import 'selection_input_v2_test.dart' show inputOpacity;
import 'support.dart';

Finder get sliderTrack => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FrostProgressPainter);
FrostProgressPainter sliderPaint(WidgetTester tester) => tester.widget<CustomPaint>(sliderTrack).painter! as FrostProgressPainter;

void main() {
  for (final brightness in Brightness.values) {
    for (final value in [0.0, .5, 1.0]) {
      testWidgets('thumb boundary is visible without focus at $value $brightness', (tester) async {
        tester.view.physicalSize = const Size(900, 600);
        tester.view.devicePixelRatio = 1.5;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: SizedBox(
                width: 300,
                child: RepaintBoundary(
                  key: key,
                  child: FrostSlider(value: value, semanticLabel: 'Level', onChanged: (_) {}),
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final thumb = find.byType(FrostControlThumb);
        final tokens = FrostThemeTokens.of(tester.element(thumb));
        final material = decorations(tester, thumb).single.decoration as BoxDecoration;
        expect(material.border, Border.all(color: tokens.line, width: 1 / 1.5));
        expect(material.boxShadow, tokens.shadowContact);
        expect(tester.getSize(thumb), const Size.square(20));
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1.5)))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        final rect = tester.getRect(thumb).shift(-boundary.localToGlobal(Offset.zero));
        final x = (rect.left * 1.5).floor(), y = (rect.center.dy * 1.5).floor();
        int darkness(int atX) {
          final at = (y * image.width + atX) * 4;
          return 765 - bytes.getUint8(at) - bytes.getUint8(at + 1) - bytes.getUint8(at + 2);
        }

        final edge = [darkness(x), darkness(x + 1), darkness(x + 2)].reduce((a, b) => a > b ? a : b);
        expect(edge, greaterThanOrEqualTo(24), reason: 'A physical border must remain without hover or keyboard focus');
        expect(darkness((rect.center.dx * 1.5).floor()), lessThanOrEqualTo(3));
        image.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final density in FrostDensity.values) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('slider actual paint, target, thumb and numeric label $density $direction $scale', (tester) async {
          await display(
            tester,
            FrostSlider(value: .25, semanticLabel: 'Volume', valueLabel: (v) => '${(v * 100).round()}', onChanged: (_) {}),
            width: 340,
            density: density,
            direction: direction,
            scale: scale,
          );
          final context = tester.element(find.byType(FrostSlider)), tokens = FrostThemeTokens.of(context);
          final rect = tester.getRect(sliderTrack), thumb = tester.getRect(find.byType(FrostControlThumb));
          expect(rect.height, 4);
          expect(thumb.size, const Size.square(20));
          expect(thumb.center.dy, rect.center.dy);
          expect(thumb.center.dx, closeTo(direction == TextDirection.ltr ? rect.left + rect.width * .25 : rect.right - rect.width * .25, .001));
          final material = decorations(tester, find.byType(FrostControlThumb)).single.decoration as BoxDecoration;
          expect(material.color, Colors.white);
          expect(material.boxShadow, tokens.shadowContact);
          expect(material.borderRadius, BorderRadius.circular(10));
          expect(
            tester.renderObject(sliderTrack),
            paints
              ..rrect(color: tokens.fillStrong)
              ..rrect(color: tokens.actionFill),
          );
          final row = tester.getRect(find.byType(FrostLabeledTrackLayout));
          expect(row.height, greaterThanOrEqualTo(FrostDensity.of(context).targetHeight));
          final label = tester.getRect(find.byType(FrostRollingText));
          expect(direction == TextDirection.ltr ? label.left - (rect.right + 12) : rect.left - 12 - label.right, closeTo(8, .001));
          final text = tester.allRenderObjects.whereType<RenderParagraph>().first;
          expect(text.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.callout).fontSize);
          expect(text.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
          final semantics = tester.ensureSemantics();
          expect(tester.getSemantics(find.byType(FrostSlider)).getSemanticsData().value, '25');
          expect(tester.getSemantics(find.byType(FrostSlider)).flagsCollection.isSlider, true);
          semantics.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final direction in TextDirection.values) {
    testWidgets('slider drag follows pointer, snaps and ends once $direction', (tester) async {
      var value = .5;
      final ends = <double>[], changes = <double>[];
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) => FrostSlider(
            value: value,
            divisions: 10,
            semanticLabel: 'Level',
            onChanged: (v) => set(() {
              value = v;
              changes.add(v);
            }),
            onChangeEnd: ends.add,
          ),
        ),
        direction: direction,
      );
      final rect = tester.getRect(sliderTrack);
      final press = await tester.startGesture(rect.center);
      await press.moveBy(Offset(rect.width * .21 * (direction == TextDirection.ltr ? 1 : -1), 0));
      await tester.pump();
      expect(value, .7);
      expect(sliderPaint(tester).value, .7);
      expect(ends, isEmpty);
      await press.moveBy(Offset(rect.width * .1 * (direction == TextDirection.ltr ? 1 : -1), 0));
      await tester.pump();
      expect(value, .8);
      await press.up();
      await tester.pumpAndSettle();
      expect(ends, [.8]);
      expect(changes, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('slider all keyboard rules and adjustable semantics $direction', (tester) async {
      var value = .5;
      var endCalls = 0;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) => FrostSlider(value: value, semanticLabel: 'Level', onChanged: (v) => set(() => value = v), onChangeEnd: (_) => endCalls++),
        ),
        direction: direction,
      );
      await tester.tapAt(tester.getRect(sliderTrack).center);
      await tester.pumpAndSettle();
      Focus.of(tester.element(sliderTrack)).requestFocus();
      await tester.pump();
      endCalls = 0;
      final keys = [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
      ];
      final expected = [.51, .5, direction == TextDirection.ltr ? .51 : .49, .5, .6, .5, 0.0, 1.0];
      for (var i = 0; i < keys.length; i++) {
        await tester.sendKeyEvent(keys[i]);
        await tester.pumpAndSettle();
        expect(value, closeTo(expected[i], 1e-8));
      }
      expect(endCalls, keys.length);
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(FrostSlider));
      expect(node.getSemanticsData().value, '100%');
      node.owner!.performAction(node.id, SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(value, closeTo(.99, 1e-8));
      expect(endCalls, keys.length + 1);
      semantics.dispose();
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('slider click spring, pressed diameter, hover and focus reduced=$reduced', (tester) async {
      var value = .2;
      final ends = <double>[];
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) => FrostSlider(value: value, semanticLabel: 'Level', onChanged: (v) => set(() => value = v), onChangeEnd: ends.add),
        ),
        reduced: reduced,
      );
      final rect = tester.getRect(sliderTrack), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostSlider)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(rect.center);
      await tester.pumpAndSettle();
      final layer = decorations(tester, find.byType(FrostSlider)).where((r) => r.decoration is ShapeDecoration).first;
      expect((layer.decoration as ShapeDecoration).color, tokens.fillSubtle);
      final press = await tester.startGesture(Offset(rect.left + rect.width * .8, rect.center.dy), pointer: 7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getSize(find.byType(FrostControlThumb)).width, reduced ? 24 : inExclusiveRange(20, 24));
      await press.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(value, closeTo(.8, 1e-8));
      expect(sliderPaint(tester).value, reduced ? closeTo(.8, 1e-8) : inExclusiveRange(.2, .8));
      expect(ends, hasLength(1));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostControlThumb)), const Size.square(20));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final focus = find.descendant(
        of: find.byType(FrostClickFeedbackVisual),
        matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter != null),
      );
      expect(focus, findsOneWidget);
      expect(tester.renderObject(focus), paints..path(color: tokens.focus, strokeWidth: 2));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }
  for (final direction in TextDirection.values) {
    testWidgets('slider label moves below on first frame and remains complete $direction', (tester) async {
      for (final width in [70.0, 24.0]) {
        await display(
          tester,
          FrostSlider(key: ValueKey(width), value: .5, semanticLabel: 'Value', valueLabel: (_) => '1234567890', onChanged: (_) {}),
          width: width,
          scale: 2,
          direction: direction,
        );
        final track = tester.getRect(sliderTrack), label = tester.getRect(find.byType(FrostRollingText));
        expect(label.top, closeTo(track.center.dy + FrostDensity.of(tester.element(find.byType(FrostSlider))).targetHeight / 2 + 4, .001));
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        final row = tester.getRect(find.byType(FrostLabeledTrackLayout));
        expect(direction == TextDirection.ltr ? viewport.right : viewport.left, direction == TextDirection.ltr ? row.right : row.left);
        expect(tester.widget<FrostRollingText>(find.byType(FrostRollingText)).text, '1234567890');
        expect(tester.takeException(), isNull);
      }
      await display(
        tester,
        FrostSlider(value: .5, semanticLabel: 'Value', valueLabel: (_) => '50', onChanged: (_) {}),
        width: 500,
        direction: direction,
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byType(FrostRollingText)).dy, tester.getCenter(sliderTrack).dy);
    });
  }
  testWidgets('slider disabled during drag cancels without end and dims all paint', (tester) async {
    var value = .5, enabled = true;
    late StateSetter update;
    var endCalls = 0;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return FrostSlider(value: value, semanticLabel: 'Value', onChanged: enabled ? (v) => set(() => value = v) : null, onChangeEnd: (_) => endCalls++);
        },
      ),
    );
    final press = await tester.startGesture(tester.getRect(sliderTrack).center);
    await press.moveBy(const Offset(60, 0));
    await tester.pump();
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(inputOpacity(tester.renderObject(sliderTrack)), closeTo(.38, .001));
    expect(inputOpacity(tester.renderObject(find.byType(FrostControlThumb))), closeTo(.38, .001));
    expect(tester.getSize(find.byType(FrostControlThumb)), const Size.square(20));
    await press.up();
    await tester.pumpAndSettle();
    expect(endCalls, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('slider scope disable restores rejected drag and discrete keyboard uses one grid', (tester) async {
    var enabled = true, accept = false, value = .5;
    late StateSetter update;
    var ends = 0;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return FrostControlScope(
            enabled: enabled,
            child: FrostSlider(
              value: value,
              divisions: 10,
              semanticLabel: 'Discrete',
              onChanged: (v) {
                if (accept) set(() => value = v);
              },
              onChangeEnd: (_) => ends++,
            ),
          );
        },
      ),
    );
    final press = await tester.startGesture(tester.getRect(sliderTrack).center);
    await press.moveBy(const Offset(70, 0));
    await tester.pump();
    expect(sliderPaint(tester).value, greaterThan(.5));
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(sliderPaint(tester).value, .5);
    await press.up();
    await tester.pump();
    expect(ends, 0);
    update(() {
      enabled = true;
      accept = true;
    });
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(sliderTrack).center);
    await tester.pumpAndSettle();
    Focus.of(tester.element(sliderTrack)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(value, closeTo(.6, 1e-8));
    expect(tester.takeException(), isNull);
  });
}
