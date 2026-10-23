import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  test('typography roles retain only inheritable font properties', () {
    final bases = [
      const TextStyle(
        inherit: false,
        fontFamily: 'Example',
        fontFamilyFallback: ['Fallback'],
        fontStyle: FontStyle.italic,
        fontFeatures: [FontFeature.tabularFigures()],
        color: Colors.red,
        backgroundColor: Colors.blue,
        decoration: TextDecoration.underline,
        decorationColor: Colors.green,
        decorationStyle: TextDecorationStyle.wavy,
        decorationThickness: 2,
        shadows: [Shadow(blurRadius: 2)],
      ),
      TextStyle(foreground: Paint()..color = Colors.red, background: Paint()..color = Colors.blue),
    ];
    for (final base in bases) {
      final typography = FrostTypography(platform: TargetPlatform.windows, base: base);
      for (final role in FrostTextRole.values) {
        for (final numeric in [false, true]) {
          final style = typography.style(role, numeric: numeric);
          expect(style.inherit, isTrue, reason: '$role');
          expect(style.color, isNull, reason: '$role');
          expect(style.backgroundColor, isNull);
          expect(style.foreground, isNull);
          expect(style.background, isNull);
          expect(style.decoration, isNull);
          expect(style.decorationColor, isNull);
          expect(style.decorationStyle, isNull);
          expect(style.decorationThickness, isNull);
          expect(style.shadows, isNull);
          expect(style.fontFamily, base.fontFamily);
          expect(style.fontFamilyFallback, base.fontFamilyFallback);
          expect(style.fontStyle, base.fontStyle);
          if (numeric) expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
        }
      }
    }
  });

  for (final brightness in Brightness.values) {
    for (final accent in FrostPalettes.pink.accentPresets.take(2)) {
      testWidgets('rendered button labels own their foreground: $brightness $accent', (tester) async {
        final enabled = ValueNotifier(true);
        addTearDown(enabled.dispose);
        final theme = FrostTheme.build(
          config: testConfig,
          brightness: brightness,
          platform: TargetPlatform.windows,
          locale: const Locale('en'),
          accent: accent,
        );
        final tokens = theme.extension<FrostThemeTokens>()!;
        await tester.pumpWidget(
          FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: ValueListenableBuilder(
                  valueListenable: enabled,
                  builder: (context, value, _) => Column(
                    children: [
                      for (final variant in FrostButtonVariant.values) FrostButton(label: variant.name, variant: variant, onPressed: value ? () {} : null),
                      FrostButton(label: 'destructive', role: FrostButtonRole.destructive, onPressed: value ? () {} : null),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Color? renderedColour(String name) {
          final label = find.text(name);
          return tester.renderObject<RenderParagraph>(label).text.style?.color;
        }

        expect(renderedColour('prominent'), tokens.onAction);
        expect(renderedColour('prominent'), Colors.white);
        expect(renderedColour('standard'), tokens.textPrimary);
        expect(renderedColour('plain'), tokens.textPrimary);
        expect(renderedColour('destructive'), tokens.negativeInk);
        expect(theme.textTheme.bodyMedium!.color, tokens.textPrimary);
        expect(theme.textTheme.titleLarge!.color, tokens.textPrimary);
        // Disabled prominent buttons use standard ink before dimming the content.
        enabled.value = false;
        await tester.pumpAndSettle();
        for (final variant in FrostButtonVariant.values) {
          expect(renderedColour(variant.name), tokens.textPrimary);
          final opacity = find.descendant(
            of: find.ancestor(of: find.text(variant.name), matching: find.byType(FrostButton)),
            matching: find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity == .38),
          );
          expect(opacity, findsOneWidget);
        }
        expect(renderedColour('destructive'), tokens.negativeInk);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
