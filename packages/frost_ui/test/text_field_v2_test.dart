import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Finder get _chrome => find.descendant(of: find.byType(FrostTextField), matching: find.byType(AnimatedContainer)).first;
ShapeDecoration _outline(WidgetTester tester) =>
    tester
            .renderObject<RenderDecoratedBox>(
              find.descendant(of: _chrome, matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.position == DecorationPosition.foreground)).first,
            )
            .decoration
        as ShapeDecoration;
Color _stroke(WidgetTester tester) => (_outline(tester).shape as OutlinedBorder).side.color;

void main() {
  for (final density in FrostDensity.values) {
    for (final size in FrostControlSize.values) {
      testWidgets('input keeps equal constant vertical padding: $size $density', (tester) async {
        double? padding;
        double? unscaledLine;
        for (final scale in [1.0, 1.5, 2.0]) {
          await tester.pumpWidget(
            frostTestApp(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: SizedBox(
                    width: 320,
                    child: FrostTextField(size: size, placeholder: 'Input'),
                  ),
                ),
              ),
              density: density,
            ),
          );
          await tester.pumpAndSettle();
          final frame = tester.getRect(_chrome);
          final text = tester.getRect(find.byType(EditableText));
          final top = text.top - frame.top, bottom = frame.bottom - text.bottom;
          expect(top, closeTo(bottom, .001));
          padding ??= top;
          unscaledLine ??= text.height;
          expect(top, closeTo(padding, .001));
          expect(frame.height, closeTo(size.visualHeight(touch: density == FrostDensity.comfortable) + text.height - unscaledLine, .001));
          final radius = (_outline(tester).shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x;
          expect(radius, FrostRadius.forHeight(frame.height));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('field idle pixels, external keyboard ring and error ink: $brightness', (tester) async {
      final focus = FocusNode();
      final boundary = GlobalKey();
      late StateSetter update;
      late FrostThemeTokens tokens;
      var error = false;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return RepaintBoundary(
                key: boundary,
                child: ColoredBox(
                  color: tokens.surface,
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      child: StatefulBuilder(
                        builder: (context, set) {
                          update = set;
                          return FrostTextField(focusNode: focus, label: 'Label', help: 'Help', error: error ? 'Error' : null, placeholder: 'Input');
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      expect(_stroke(tester).a, 0);
      final frame = tester.getRect(_chrome);
      Future<Color> pixel(Offset position) async {
        final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final offset = (position.dy.floor() * image.width + position.dx.floor()) * 4;
        final color = Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
        image.dispose();
        return color;
      }

      expect((await tester.runAsync(() => pixel(frame.centerLeft - const Offset(1, 0))))!.toARGB32(), tokens.surface.toARGB32());
      expect((await tester.runAsync(() => pixel(frame.centerLeft + const Offset(1, 0))))!.toARGB32(), Color.alphaBlend(tokens.fill, tokens.surface).toARGB32());
      TextStyle style(String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!;
      expect(style('Label').fontSize, 13);
      expect(style('Label').color, tokens.textSecondary);
      expect(style('Help').fontSize, 12);
      expect(style('Help').color, tokens.textSecondary);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 70));
      expect(_stroke(tester).a, 0);
      expect(frostFocusRings(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(_stroke(tester).a, 0);
      expect((_outline(tester).shape as OutlinedBorder).side.width, FrostMetrics.fieldFocusWidth);
      expect((_outline(tester).shape as OutlinedBorder).side.strokeAlign, BorderSide.strokeAlignInside);
      update(() => error = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_stroke(tester), isNot(tokens.fieldFocus));
      expect(_stroke(tester), isNot(tokens.negativeInk));
      final fade = tester
          .renderObject<RenderFrostContentFade>(find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostContentFade)).first)
          .opacity;
      expect(fade, greaterThan(0));
      expect(fade, lessThan(1));
      await tester.pumpAndSettle();
      expect(_stroke(tester), tokens.negativeInk);
      expect(find.text('Help'), findsNothing);
      expect(style('Error').color, tokens.negativeInk);
      focus.unfocus();
      await tester.pumpAndSettle();
      expect(_stroke(tester), tokens.negativeInk);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('clear expands continuously, preserves field height and notifies change', (tester) async {
    final controller = TextEditingController();
    final changes = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 320,
            child: FrostTextField(controller: controller, clearable: true, size: FrostControlSize.compact, onChanged: changes.add),
          ),
        ),
      ),
    );
    final width = tester.getSize(find.byType(EditableText)).width;
    final height = tester.getSize(_chrome).height;
    controller.text = 'Text';
    await tester.pump();
    expect(tester.getSize(find.byType(EditableText)).width, width);
    await tester.pump(const Duration(milliseconds: 110));
    final middle = tester.getSize(find.byType(EditableText)).width;
    expect(middle, lessThan(width));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(EditableText)).width, lessThan(middle));
    expect(tester.getSize(_chrome).height, height);
    await tester.tap(findFrostTooltip('L.clearText'));
    await tester.pump();
    final full = tester.getSize(find.byType(EditableText)).width;
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(find.byType(EditableText)).width, greaterThan(full));
    expect(tester.getSize(find.byType(EditableText)).width, lessThan(width));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(EditableText)).width, width);
    expect(controller.text, isEmpty);
    expect(changes, ['']);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiline keeps top padding and disabled content, reduced focus settles immediately', (tester) async {
    final focus = FocusNode();
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2), disableAnimations: true),
          child: Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return Center(
                child: SizedBox(
                  width: 320,
                  child: FrostTextField(
                    focusNode: focus,
                    label: 'A long label that must wrap at large text size',
                    minLines: 3,
                    maxLines: 5,
                    enabled: false,
                    error: 'Error',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(tester.getSize(_chrome).height, greaterThan(100));
    expect(_stroke(tester), tokens.negativeInk);
    expect(find.byWidgetPredicate((w) => w is FrostAnimatedMaterialReveal && w.opacity == .38), findsNWidgets(3));
    expect(tester.getSize(find.text('A long label that must wrap at large text size')).height, greaterThan(30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: SizedBox(width: 320, child: FrostTextField(focusNode: focus)),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(_stroke(tester).a, 0);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });

  testWidgets('supporting text height animates and multiline keeps the same padding', (tester) async {
    late StateSetter update;
    var error = false;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 180,
            child: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return FrostTextField(
                  label: 'Label',
                  help: 'Help',
                  error: error ? 'An error message that wraps over several lines at this field width' : null,
                  minLines: 3,
                  maxLines: 5,
                );
              },
            ),
          ),
        ),
      ),
    );
    final original = tester.getSize(find.byType(FrostTextField)).height;
    final chrome = tester.getRect(_chrome), text = tester.getRect(find.byType(EditableText));
    expect(text.top - chrome.top, closeTo(chrome.bottom - text.bottom, .001));
    update(() => error = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 90));
    final middle = tester.getSize(find.byType(FrostTextField)).height;
    expect(middle, greaterThan(original));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostTextField)).height, greaterThan(middle));
    expect(tester.takeException(), isNull);
  });

  test('monospace family, CJK fallback and role metrics are independent of numeric figures', () {
    for (final platform in TargetPlatform.values) {
      for (final custom in [null, 'App Mono']) {
        final typography = FrostTypography(
          platform: platform,
          base: const TextStyle(fontFamily: 'JP', fontFamilyFallback: ['SC']),
          monospace: custom,
        );
        for (final role in FrostTextRole.values) {
          final normal = typography.style(role), mono = typography.style(role, monospace: true, numeric: true);
          expect(
            mono.fontFamily,
            custom ??
                switch (platform) {
                  TargetPlatform.windows => 'Consolas',
                  TargetPlatform.macOS || TargetPlatform.iOS => 'Menlo',
                  _ => 'monospace',
                },
          );
          expect(mono.fontFamilyFallback, containsAll(['JP', 'SC']));
          expect(mono.fontSize, normal.fontSize);
          expect(mono.height, normal.height);
          expect(mono.fontWeight, normal.fontWeight);
          expect(mono.fontFeatures, contains(const FontFeature.tabularFigures()));
        }
      }
    }
    final theme = FrostTheme.build(
      config: testConfig.copyWith(
        fonts: const FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', monospace: 'Configured Mono'),
      ),
      brightness: Brightness.light,
      platform: TargetPlatform.windows,
      locale: const Locale('en'),
    );
    expect(theme.extension<FrostTypography>()!.style(FrostTextRole.body, monospace: true).fontFamily, 'Configured Mono');
  });
}
