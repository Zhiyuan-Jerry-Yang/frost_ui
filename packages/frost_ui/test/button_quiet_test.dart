import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final density in FrostDensity.values) {
    testWidgets('quiet keeps secondary footnote, hit target and disabled feedback $density', (tester) async {
      var enabled = true;
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return FrostButton.quiet(label: 'Quiet', size: FrostControlSize.compact, onPressed: enabled ? () => calls++ : null);
              },
            ),
          ),
          density: density,
        ),
      );
      final button = find.byType(FrostButton);
      final tokens = FrostThemeTokens.of(tester.element(button));
      final typography = FrostTypography.of(tester.element(button));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Quiet'));
      expect(paragraph.text.style!.color, tokens.textSecondary);
      expect(paragraph.text.style!.fontSize, typography.style(FrostTextRole.footnote).fontSize);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(density == FrostDensity.compact ? 32 : 44));
      final paint = tester.renderObject<RenderDecoratedBox>(find.descendant(of: find.byType(FrostClickSurface), matching: find.byType(DecoratedBox)).first);
      expect((paint.decoration as ShapeDecoration).color!.a, 0);
      await tester.tap(button);
      expect(calls, 1);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(button);
      expect(calls, 1);
      expect(tester.getSemantics(button).getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
      expect(tester.takeException(), isNull);
    });
    testWidgets('section header action uses the same quiet typography $density', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 360,
              child: FrostSectionHeader(title: 'Section', actionLabel: 'Show all', onAction: () {}),
            ),
          ),
          density: density,
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Show all'));
      final context = tester.element(find.text('Show all'));
      expect(paragraph.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.footnote).fontSize);
      expect(paragraph.text.style!.color, FrostThemeTokens.of(context).textSecondary);
      expect(tester.getSize(find.byType(FrostButton)).height, greaterThanOrEqualTo(density.targetHeight));
    });
  }
}
