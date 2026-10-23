import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('rendered placeholders use tertiary and disabled content dims: $brightness', (tester) async {
      final search = TextEditingController();
      final focus = FocusNode();
      addTearDown(search.dispose);
      addTearDown(focus.dispose);
      for (final tone in FrostTone.values) {
        final theme = FrostTheme.build(config: testConfig, brightness: brightness, platform: TargetPlatform.windows, locale: const Locale('en'), tone: tone);
        final tokens = theme.extension<FrostThemeTokens>()!;
        await tester.pumpWidget(
          FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Column(
                  children: [
                    const FrostTextField(placeholder: 'field-hint'),
                    const FrostTextField(readOnly: true, placeholder: 'readonly-hint'),
                    const FrostTextField(enabled: false, placeholder: 'disabled-hint'),
                    const TextField(decoration: InputDecoration(hintText: 'material-hint')),
                    FrostSearchInput(controller: search, focusNode: focus, placeholder: 'search-hint', onSubmitted: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final hint in ['field-hint', 'readonly-hint', 'material-hint', 'search-hint']) {
          expect(tester.renderObject<RenderParagraph>(find.text(hint)).text.style!.color, tokens.textTertiary, reason: '$brightness $tone $hint');
        }
        expect(tester.renderObject<RenderParagraph>(find.text('disabled-hint')).text.style!.color, tokens.textTertiary);
        final disabledField = tester.widget<TextField>(find.byWidgetPredicate((widget) => widget is TextField && widget.enabled == false));
        expect(disabledField.style!.color, tokens.textPrimary);
        final dim = find.ancestor(
          of: find.text('disabled-hint'),
          matching: find.byWidgetPredicate((w) => w is FrostAnimatedMaterialReveal && w.opacity == .38),
        );
        expect(dim, findsOneWidget);
        for (final surface in [tokens.surface, tokens.surfaceRaised, tokens.surfaceMuted, tokens.surfaceInset]) {
          expect(colorContrast(tokens.textTertiary, surface), greaterThanOrEqualTo(3));
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
}
