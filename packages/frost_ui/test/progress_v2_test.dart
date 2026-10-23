import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/progress.dart' show FrostProgressPainter;

import 'display_badges_v2_test.dart' show display;

Finder get drawing => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FrostProgressPainter);
FrostProgressPainter painter(WidgetTester tester) => tester.widget<CustomPaint>(drawing).painter! as FrostProgressPainter;

void main() {
  test('progress APIs only require widgets.dart', () {
    expect(const FrostProgressBar(value: .5, semanticLabel: 'Download'), isA<Widget>());
    expect(const FrostProgressRing(value: .5, size: FrostControlSize.large, semanticLabel: 'Download'), isA<Widget>());
  });
  for (final direction in TextDirection.values) {
    testWidgets('progress bar geometry, tokens and clamping $direction', (tester) async {
      await display(tester, const FrostProgressBar(value: .4, semanticLabel: 'Download'), width: 200, direction: direction);
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostProgressBar)));
      expect(tester.getSize(drawing), const Size(200, 4));
      expect(
        tester.renderObject<RenderCustomPaint>(drawing),
        paints
          ..rrect(rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 200, 4), const Radius.circular(2)), color: tokens.fillStrong)
          ..rrect(
            rrect: RRect.fromRectAndRadius(Rect.fromLTWH(direction == TextDirection.ltr ? 0 : 120, 0, 80, 4), const Radius.circular(2)),
            color: tokens.actionFill,
          ),
      );
      await display(tester, const FrostProgressBar(value: -5, semanticLabel: 'Download'), width: 200);
      await tester.pumpAndSettle();
      expect(painter(tester).value, 0);
      await display(tester, const FrostProgressBar(value: 5, semanticLabel: 'Download'), width: 200);
      await tester.pumpAndSettle();
      expect(painter(tester).value, 1);
    });
    for (final size in FrostControlSize.values) {
      testWidgets('ring actual circular track and clockwise arc $size $direction', (tester) async {
        await display(
          tester,
          FrostProgressRing(value: .25, size: size, semanticLabel: 'Download'),
          direction: direction,
        );
        final (diameter, stroke) = switch (size) {
          FrostControlSize.compact => (16.0, 2.0),
          FrostControlSize.regular => (20.0, 2.0),
          FrostControlSize.large => (28.0, 3.0),
        };
        final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostProgressRing)));
        expect(tester.getSize(drawing), Size.square(diameter));
        expect(
          tester.renderObject<RenderCustomPaint>(drawing),
          paints
            ..circle(x: diameter / 2, y: diameter / 2, radius: (diameter - stroke) / 2, color: tokens.fillStrong, strokeWidth: stroke)
            ..arc(
              rect: Rect.fromLTWH(stroke / 2, stroke / 2, diameter - stroke, diameter - stroke),
              startAngle: -math.pi / 2,
              sweepAngle: math.pi / 2,
              useCenter: false,
              color: tokens.actionFill,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
            ),
        );
      });
    }
  }
  for (final ring in [false, true]) {
    for (final reduced in [false, true]) {
      testWidgets('progress spring and semantic target throttle ring=$ring reduced=$reduced', (tester) async {
        final handle = tester.ensureSemantics();
        var value = .2;
        late StateSetter update;
        await display(
          tester,
          StatefulBuilder(
            builder: (context, set) {
              update = set;
              return ring ? FrostProgressRing(value: value, semanticLabel: 'Progress') : FrostProgressBar(value: value, semanticLabel: 'Progress');
            },
          ),
          reduced: reduced,
        );
        String semantics() => tester.getSemantics(find.byType(ring ? FrostProgressRing : FrostProgressBar)).getSemanticsData().value;
        expect(semantics(), '20%');
        update(() => value = .24);
        await tester.pump();
        expect(semantics(), '20%');
        update(() => value = .25);
        await tester.pump();
        expect(semantics(), '25%');
        update(() => value = .8);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(painter(tester).value, reduced ? .8 : inExclusiveRange(.2, .8));
        expect(semantics(), '80%');
        await tester.pumpAndSettle();
        expect(painter(tester).value, .8);
        for (final target in [.97, 1.0, .03, 0.0]) {
          update(() => value = target);
          await tester.pump();
          expect(semantics(), '${(target * 100).round()}%');
        }
        handle.dispose();
      });
    }
  }
}
