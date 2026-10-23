import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/_data_track.dart';
import 'display_badges_v2_test.dart' show display;

Finder get trackPaint => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FrostDataTrackPainter);
FrostDataTrackPainter painter(WidgetTester tester) => tester.widget<CustomPaint>(trackPaint).painter! as FrostDataTrackPainter;

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets('meter paint, marks, modulo and clamp $direction $brightness', (tester) async {
        final handle = tester.ensureSemantics();
        await display(
          tester,
          const FrostMeter(value: 20, min: 0, max: 10, dataColor: -1, marks: [-1, 5, 15], semanticLabel: 'Level'),
          width: 200,
          direction: direction,
          brightness: brightness,
          scale: 2,
        );
        final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostMeter)));
        final x = direction == TextDirection.ltr ? 195.0 : 5.0;
        expect(tester.getSize(find.byType(FrostMeter)), const Size(200, 17));
        expect(
          tester.renderObject<RenderCustomPaint>(trackPaint),
          paints
            ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(5, 3, 190, 4), const Radius.circular(2)), color: tokens.fillStrong)
            ..circle(x: x, y: 5, radius: 5, color: tokens.surface)
            ..circle(x: x, y: 5, radius: 4, color: tokens.categorical.last, strokeWidth: 2, style: PaintingStyle.stroke)
            ..rect(rect: Rect.fromLTWH((direction == TextDirection.ltr ? 5 : 195) - .5, 11, 1, 6), color: tokens.textTertiary),
        );
        final data = tester.getSemantics(find.byType(FrostMeter)).getSemanticsData();
        expect(data.label, 'Level');
        expect(data.value, '10.0');
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
    testWidgets('range side labels and first-frame below fallback $direction', (tester) async {
      Widget range(double width) =>
          FrostRangeBar(key: ValueKey(width), low: 2, high: 8, min: 0, max: 10, lowLabel: '2', highLabel: '8', semanticLabel: 'Range');
      await display(tester, range(500), width: 500, direction: direction);
      final low = tester.getRect(find.text('2')), high = tester.getRect(find.text('8')), track = tester.getRect(trackPaint);
      expect(low.center.dy, track.center.dy);
      expect(high.center.dy, track.center.dy);
      expect(direction == TextDirection.ltr ? track.left - low.right : low.left - track.right, 8);
      expect(direction == TextDirection.ltr ? high.left - track.right : track.left - high.right, 8);
      final threshold = low.width + high.width + 16 + 48;
      await display(tester, range(threshold), width: threshold, direction: direction);
      expect(tester.getSize(trackPaint).width, closeTo(48, .001));
      await display(tester, range(threshold - .1), width: threshold - .1, direction: direction);
      final a = tester.getRect(find.text('2')), b = tester.getRect(find.text('8')), t = tester.getRect(trackPaint);
      expect(a.top - t.bottom, 4);
      expect(b.top - t.bottom, 4);
      expect(a.overlaps(b), false);
      expect(t.width, closeTo(threshold - .1, .001));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('range sorted actual paint, modulo and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await display(tester, const FrostRangeBar(low: 8, high: -2, min: 0, max: 10, dataColor: 99, semanticLabel: 'Range'), width: 200);
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostRangeBar)));
    expect(tester.getSize(find.byType(FrostRangeBar)), const Size(200, 4));
    expect(
      tester.renderObject<RenderCustomPaint>(trackPaint),
      paints
        ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 200, 4), const Radius.circular(2)), color: tokens.fillStrong)
        ..rrect(
          rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 160, 4), const Radius.circular(2)),
          color: tokens.categorical[99 % tokens.categorical.length],
        ),
    );
    final data = tester.getSemantics(find.byType(FrostRangeBar)).getSemanticsData();
    expect(data.label, 'Range');
    expect(data.value, '0.0 – 8.0');
    expect(() => FrostRangeBar(low: 0, high: 1, min: 1, max: 1, semanticLabel: 'Invalid'), throwsAssertionError);
    expect(() => FrostMeter(value: 0, min: double.negativeInfinity, semanticLabel: 'Invalid'), throwsAssertionError);
    handle.dispose();
  });
  testWidgets('range large labels wrap completely without overlap', (tester) async {
    await display(
      tester,
      const FrostRangeBar(low: .2, high: .8, lowLabel: '12.345 low', highLabel: '98.765 high', semanticLabel: 'Range'),
      width: 150,
      scale: 2,
      direction: TextDirection.rtl,
    );
    final a = tester.getRect(find.text('12.345 low')), b = tester.getRect(find.text('98.765 high'));
    expect(a.overlaps(b), false);
    expect(a.top, b.top);
    for (final text in ['12.345 low', '98.765 high']) {
      final p = tester.renderObject<RenderParagraph>(find.text(text));
      expect(p.maxLines, isNull);
      expect(p.didExceedMaxLines, false);
      expect(p.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(p.text.style!.fontSize, FrostTypography.of(tester.element(find.text(text))).style(FrostTextRole.caption).fontSize);
    }
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('data track spring intermediate frames reduced=$reduced', (tester) async {
      var value = .2;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostMeter(value: value, semanticLabel: 'Level');
          },
        ),
        width: 200,
        reduced: reduced,
      );
      update(() => value = .8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(painter(tester).marker, reduced ? .8 : inExclusiveRange(.2, .8));
      await tester.pumpAndSettle();
      expect(painter(tester).marker, .8);
      var low = .1, high = .4;
      late StateSetter setRange;
      await display(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            setRange = set;
            return FrostRangeBar(low: low, high: high, semanticLabel: 'Range');
          },
        ),
        width: 200,
        reduced: reduced,
      );
      setRange(() {
        low = .3;
        high = .9;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(painter(tester).low, reduced ? .3 : inExclusiveRange(.1, .3));
      expect(painter(tester).high, reduced ? .9 : inExclusiveRange(.4, .9));
      await tester.pumpAndSettle();
      expect(painter(tester).low, .3);
      expect(painter(tester).high, .9);
      expect(tester.takeException(), isNull);
    });
  }
}
