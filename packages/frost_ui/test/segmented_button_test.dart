import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

void main() {
  testWidgets('whole-control dimming includes track and thumb without dimming a disabled segment twice', (tester) async {
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: ValueListenableBuilder(
            valueListenable: enabled,
            builder: (context, active, _) => FrostPicker<int>.segmented(
              options: const [
                FrostPickerOption(value: 0, label: 'One'),
                FrostPickerOption(value: 1, label: 'Two', enabled: false),
              ],
              value: 0,
              onChanged: active ? (_) {} : null,
              label: 'Choice',
            ),
          ),
        ),
      ),
    );
    final boxes = find.descendant(of: find.byType(FrostPicker<int>), matching: find.byType(DecoratedBox));
    final thumb = boxes.evaluate().singleWhere((element) => ((element.widget as DecoratedBox).decoration as ShapeDecoration).shadows?.isNotEmpty ?? false);
    final track = boxes.evaluate().first;
    double actualOpacity(RenderObject object) {
      var opacity = 1.0;
      for (RenderObject? ancestor = object; ancestor != null; ancestor = ancestor.parent) {
        if (ancestor is RenderOpacity) opacity *= ancestor.opacity;
        if (ancestor is RenderFrostContentFade) opacity *= ancestor.opacity;
        if (ancestor is RenderAnimatedOpacity) opacity *= ancestor.opacity.value;
      }
      return opacity;
    }

    expect(actualOpacity(thumb.renderObject!), 1);
    expect(actualOpacity(tester.renderObject(find.text('Two'))), closeTo(.38, .0001));
    enabled.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(actualOpacity(thumb.renderObject!), inExclusiveRange(.38, 1));
    expect(actualOpacity(tester.renderObject(find.text('Two'))), closeTo(.38, .0001));
    await tester.pumpAndSettle();
    expect(actualOpacity(track.renderObject!), closeTo(.38, .0001));
    expect(actualOpacity(thumb.renderObject!), closeTo(.38, .0001));
    for (final label in ['One', 'Two']) {
      expect(actualOpacity(tester.renderObject(find.text(label))), closeTo(.38, .0001));
    }
    enabled.value = true;
    await tester.pumpAndSettle();
    expect(actualOpacity(thumb.renderObject!), 1);
    expect(actualOpacity(tester.renderObject(find.text('One'))), 1);
    expect(actualOpacity(tester.renderObject(find.text('Two'))), closeTo(.38, .0001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    enabled.dispose();
  });

  for (final density in FrostDensity.values) {
    for (final size in FrostControlSize.values) {
      testWidgets('segment height follows $size $density', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: FrostPicker<int>.segmented(
                options: const [
                  FrostPickerOption(value: 0, label: 'One'),
                  FrostPickerOption(value: 1, label: 'Two'),
                ],
                value: 0,
                onChanged: (_) {},
                size: size,
                label: 'Choice',
              ),
            ),
            density: density,
          ),
        );
        expect(tester.getSize(find.byType(FrostPicker<int>)).height, size.visualHeight(touch: density == FrostDensity.comfortable));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final reduced in [false, true]) {
    testWidgets('segment ink interpolates without accent, reduced=$reduced', (tester) async {
      late FrostThemeTokens tokens;
      var selected = 0;
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Center(
              child: StatefulBuilder(
                builder: (context, set) {
                  tokens = FrostThemeTokens.of(context);
                  return FrostPicker<int>.segmented(
                    options: const [
                      FrostPickerOption(value: 0, label: 'One'),
                      FrostPickerOption(value: 1, label: 'Two'),
                    ],
                    value: selected,
                    onChanged: (value) => set(() => selected = value),
                    label: 'Choice',
                  );
                },
              ),
            ),
          ),
        ),
      );
      TextStyle style(String label) => tester.renderObject<RenderParagraph>(find.text(label)).text.style!;
      expect(style('One').color, tokens.textPrimary);
      expect(style('One').fontWeight, FontWeight.w500);
      expect(style('Two').color, tokens.textSecondary);
      expect(style('Two').fontWeight, FontWeight.w400);
      final width = tester.getSize(find.byType(FrostPicker<int>)).width;
      await tester.tap(find.text('Two'));
      await tester.pump();
      if (reduced) {
        expect(style('Two').color, tokens.textPrimary);
      } else {
        expect(style('Two').color, tokens.textSecondary);
        await tester.pump(const Duration(milliseconds: 70));
        expect(style('Two').color, Color.lerp(tokens.textSecondary, tokens.textPrimary, FrostMotion.hoverCurve.transform(.5)));
      }
      await tester.pumpAndSettle();
      expect(style('Two').color, tokens.textPrimary);
      expect(style('One').color, tokens.textSecondary);
      expect(tester.getSize(find.byType(FrostPicker<int>)).width, width);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('icon-only segment tooltip, semantics and disabled input', (tester) async {
    final handle = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostPicker<int>.segmented(
            options: [
              FrostPickerOption(value: 0, icon: testIcons.image, label: 'Images'),
              FrostPickerOption(value: 1, icon: testIcons.add, label: 'Unavailable', enabled: false),
            ],
            value: 0,
            onChanged: (_) => calls++,
            label: 'Choice',
            iconOnly: true,
          ),
        ),
      ),
    );
    expect(find.byType(FrostTooltip), findsNWidgets(2));
    expect(tester.getSemantics(find.bySemanticsLabel('Images')).getSemanticsData().label, 'Images');
    final disabled = tester.getSemantics(find.bySemanticsLabel('Unavailable')).getSemanticsData();
    expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(findFrostTooltip('Unavailable'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('the composed selected thumb is brighter than its track on every palette', (tester) async {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final theme = FrostTheme.build(config: testConfig, brightness: brightness, platform: TargetPlatform.windows, locale: const Locale('en'), tone: tone);
        final tokens = theme.extension<FrostThemeTokens>()!;
        await tester.pumpWidget(
          FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: theme,
              home: Material(
                color: tokens.surface,
                child: Center(
                  child: FrostPicker<int>.segmented(
                    options: const [
                      FrostPickerOption(value: 1, label: 'One'),
                      FrostPickerOption(value: 2, label: 'Two'),
                    ],
                    value: 1,
                    onChanged: (_) {},
                    label: 'Choice',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final decorations = find
            .descendant(of: find.byType(FrostPicker<int>), matching: find.byType(DecoratedBox))
            .evaluate()
            .map((element) => (element.renderObject! as RenderDecoratedBox).decoration)
            .whereType<ShapeDecoration>();
        final track = decorations.first;
        final thumb = decorations.singleWhere((decoration) => decoration.shadows?.isNotEmpty ?? false);
        final actualTrack = Color.alphaBlend(track.color!, tokens.surface);
        final actualThumb = Color.alphaBlend(thumb.color!, actualTrack);
        expect(actualThumb.computeLuminance(), greaterThan(actualTrack.computeLuminance()), reason: '$brightness $tone');
        expect(thumb.color, tokens.isDark ? Color.alphaBlend(tokens.fillStrong, tokens.surfaceRaised) : tokens.surfaceRaised);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('selecting a segment never changes the control width', (tester) async {
    Future<double> widthWith(String selected, {bool icons = true}) async {
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: Center(
              child: FrostPicker<String>.segmented(
                options: [
                  FrostPickerOption(value: 'long', icon: icons ? testIcons.image : null, label: 'A much longer label'),
                  const FrostPickerOption(value: 'short', label: 'Short'),
                ],
                value: selected,
                onChanged: (_) {},
                label: 'Choice',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(FrostPicker<String>)).width;
    }

    expect(await widthWith('long'), await widthWith('short'));
    expect(await widthWith('short', icons: false), await widthWith('long', icons: false));
  });
}
