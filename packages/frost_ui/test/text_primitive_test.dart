import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Color? paragraphColor(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.descendant(of: find.text(label), matching: find.byType(RichText))).text.style?.color;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('text inherits real button foreground $brightness', (tester) async {
      for (final variant in FrostButtonVariant.values) {
        await tester.pumpWidget(
          frostTestApp(
            FrostButton(label: 'original', variant: variant, onPressed: () {}),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        final original = paragraphColor(tester, 'original');
        await tester.pumpWidget(
          frostTestApp(
            FrostButton(label: 'dynamic', variant: variant, onPressed: () {}, labelWidget: const FrostText('primitive')),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(paragraphColor(tester, 'primitive'), original);
        expect(tester.widget<Text>(find.text('primitive')).style!.color, isNull);
      }
    });

    testWidgets('text renders glass or solid tones from its nearest surface $brightness', (tester) async {
      for (final role in [FrostSurfaceRole.glassPanel, FrostSurfaceRole.sheet, FrostSurfaceRole.panel]) {
        for (final reduced in [false, true]) {
          late FrostThemeTokens tokens;
          await tester.pumpWidget(
            frostTestApp(
              Builder(
                builder: (context) {
                  tokens = FrostThemeTokens.of(context);
                  return FrostSurface(
                    role: role,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FrostText('secondary', tone: FrostTextTone.secondary),
                        FrostText.rich(TextSpan(text: 'tertiary'), tone: FrostTextTone.tertiary),
                      ],
                    ),
                  );
                },
              ),
              brightness: brightness,
              reduceTransparency: reduced,
            ),
          );
          await tester.pumpAndSettle();
          final glass = role == FrostSurfaceRole.glassPanel && !reduced;
          expect(paragraphColor(tester, 'secondary'), glass ? tokens.textSecondaryGlass : tokens.textSecondary);
          expect(paragraphColor(tester, 'tertiary'), glass ? tokens.textTertiaryGlass : tokens.textTertiary);
        }
      }
    });
  }

  testWidgets('all text roles render numeric features, scaling, alignment and semantics', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final role in FrostTextRole.values)
                  FrostText(role.name, role: role, numeric: true, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
              ],
            ),
          ),
        ),
      ),
    );
    for (final role in FrostTextRole.values) {
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: find.text(role.name), matching: find.byType(RichText)));
      expect(paragraph.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(paragraph.textAlign, TextAlign.end);
      expect(paragraph.maxLines, 1);
      expect(paragraph.textScaler.scale(10), 20);
      expect(paragraph.size.height, greaterThan(0));
    }
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(const FrostText.rich(TextSpan(text: 'selectable'), selectable: true, semanticsLabel: 'accessible')));
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.bySemanticsLabel('accessible'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('all explicit tones use the corresponding rendered ink', (tester) async {
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final tone in FrostTextTone.values) FrostText(tone.name, tone: tone)],
            );
          },
        ),
      ),
    );
    final colors = [
      tokens.textPrimary,
      tokens.textSecondary,
      tokens.textTertiary,
      tokens.textQuaternary,
      tokens.accentInk,
      tokens.positiveInk,
      tokens.cautionInk,
      tokens.negativeInk,
      tokens.infoInk,
    ];
    for (var i = 0; i < colors.length; i++) {
      expect(paragraphColor(tester, FrostTextTone.values[i].name), colors[i]);
    }
    expect(tester.takeException(), isNull);
  });
}
