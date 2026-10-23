import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('tooltip widget and extension render explicit Frost text and material', (tester) async {
    for (final brightness in Brightness.values) {
      for (final extension in [false, true]) {
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: extension ? const Text('target').frostTooltip('help') : const FrostTooltip(message: 'help', child: Text('target')),
            ),
            brightness: brightness,
          ),
        );
        tester.state<RawTooltipState>(find.byType(RawTooltip)).ensureTooltipVisible();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: find.text('help'), matching: find.byType(RichText)));
        final context = tester.element(find.byType(FrostTooltip));
        expect(paragraph.text.style!.color, FrostThemeTokens.of(context).textPrimary);
        expect(paragraph.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.footnote).fontSize);
        final scope = tester.widget<FrostSurfaceScope>(find.byType(FrostSurfaceScope));
        final tokens = FrostThemeTokens.of(context);
        expect(scope.isGlass, false);
        expect(scope.background, tokens.surfaceRaised);
        expect(scope.background.a, 1);
        expect(find.byType(BackdropFilter), findsNothing);
        final fill = tester
            .renderObjectList<RenderDecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<ShapeDecoration>()
            .singleWhere((decoration) => decoration.color != null);
        expect(fill.color, tokens.surfaceRaised);
        expect(fill.color!.a, 1);
        final radius = switch (fill.shape) {
          RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
          RoundedRectangleBorder(:final borderRadius) => borderRadius,
          _ => null,
        };
        expect(radius, BorderRadius.circular(FrostRadius.xs));
        final textRect = tester.getRect(find.text('help')), panelRect = tester.getRect(find.byType(FrostSurfaceScope));
        expect(textRect.left - panelRect.left, 8);
        expect(textRect.top - panelRect.top, 4);
        final frame = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<ShapeDecoration>()
            .singleWhere((d) => d.shadows?.isNotEmpty ?? false);
        expect(frame.shadows, [...tokens.shadowAmbient, ...tokens.shadowContact]);
        final edge = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).singleWhere((box) => box.position == DecorationPosition.foreground);
        expect(((edge.decoration as ShapeDecoration).shape as OutlinedBorder).side.color, FrostThemeTokens.of(context).edgeHairline);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }
  });
}
