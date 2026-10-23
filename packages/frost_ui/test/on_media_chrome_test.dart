import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/foundation/_media_contrast.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart';
import 'package:frost_ui/src/surface/_window_background.dart';

import 'r2_material_reveal_test.dart' show expectSafeLayers, parameters, filter;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const mediaKey = ValueKey('media chrome');

void main() {
  for (final brightness in Brightness.values) {
    for (final solid in [false, true]) {
      testWidgets('square media bands have no rim or shadow $brightness solid=$solid', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            const FrostSurface(key: mediaKey, role: FrostSurfaceRole.onMediaChrome, borderRadius: BorderRadius.zero, child: SizedBox(height: 48)),
            brightness: brightness,
            reduceTransparency: solid,
          ),
        );
        final actual = parameters(tester, mediaKey);
        expect(actual.edge, BorderSide.none);
        expect(actual.shadows, isEmpty);
        final foreground = tester
            .widgetList<DecoratedBox>(find.descendant(of: find.byKey(mediaKey), matching: find.byType(DecoratedBox)))
            .where((w) => w.position == DecorationPosition.foreground);
        expect(foreground, isEmpty);
        expectSafeLayers(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    for (final solid in [false, true]) {
      testWidgets('readable media material and ink $brightness solid=$solid', (tester) async {
        late FrostThemeTokens tokens;
        late FrostSurfaceScope scope;
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) {
                tokens = FrostThemeTokens.of(context);
                return Center(
                  child: FrostSurface(
                    key: mediaKey,
                    role: FrostSurfaceRole.onMediaChrome,
                    child: Builder(
                      builder: (context) {
                        scope = FrostSurfaceScope.maybeOf(context)!;
                        return const SizedBox(
                          width: 240,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FrostText('Media title'),
                              FrostText('Media detail', tone: FrostTextTone.secondary),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            brightness: brightness,
            reduceTransparency: solid,
          ),
        );
        final fill = parameters(tester, mediaKey).fill;
        expect(fill, frostOnMediaChromeBase(tokens).withValues(alpha: solid ? 1 : frostOnMediaChromeOpacity(tokens)));
        expect(filter(tester, mediaKey).enabled, !solid);
        expect(scope.isGlass, !solid);
        for (final label in ['Media title', 'Media detail']) {
          final ink = tester.renderObject<RenderParagraph>(find.text(label)).text.style!.color!;
          expect(ink, tokens.onMediaInk);
          final background = Color.alphaBlend(fill, Colors.white);
          expect(colorContrast(ink, background), greaterThanOrEqualTo(4.5));
          expect(colorContrast(ink, Color(background.toARGB32())), greaterThanOrEqualTo(4.5));
        }
        // Media foreground inheritance does not replace the page's palette.
        expect(FrostThemeTokens.of(tester.element(find.text('Media detail'))).textPrimary, tokens.textPrimary);
        expectSafeLayers(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('scope gives automatic back, actions and overflow the same circular media scrim $brightness', (tester) async {
      late FrostThemeTokens tokens;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 240,
                  child: FrostOnMediaChromeScope(
                    child: FrostPageHeader(
                      onBack: () {},
                      actions: [
                        FrostToolbarItem.action(label: 'Download', icon: testIcons.download, priority: FrostToolbarPriority.high, onPressed: () {}),
                        for (var i = 0; i < 4; i++)
                          FrostToolbarItem.action(label: 'Other $i', icon: testIcons.play, priority: FrostToolbarPriority.low, onPressed: () {}),
                        FrostToolbarItem.action(
                          label: 'Overflow action with a long label',
                          icon: testIcons.play,
                          showsLabel: true,
                          priority: FrostToolbarPriority.low,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final controls = find.byType(FrostButtonControl);
      final labels = tester.widgetList<FrostButtonControl>(controls).map((w) => w.label);
      final context = tester.element(find.byType(FrostPageHeader));
      final more = FrostScope.labelsOf(context).more;
      expect(labels, containsAll([FrostScope.labelsOf(context).back, 'Download', more]));
      for (final control in controls.evaluate()) {
        final button = control.widget as FrostButtonControl;
        if (button.showsLabel && button.iconStyle == null) continue;
        final surface = find.descendant(
          of: find.byWidget(button),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is ShapeDecoration && (w.decoration as ShapeDecoration).shape is CircleBorder,
          ),
        );
        expect(surface, findsWidgets, reason: button.label);
        final painted = surface.hitTestable();
        final glyphs = find.descendant(of: find.byWidget(button), matching: find.byType(FrostIcon)).hitTestable();
        if (painted.evaluate().isNotEmpty && glyphs.evaluate().isNotEmpty) {
          expect(
            (tester.getCenter(painted.first) - tester.getCenter(glyphs.first)).distance,
            lessThan(.01),
            reason: '${button.label} must be centered in its plate',
          );
        }
        final decorations = tester.widgetList<DecoratedBox>(surface).map((w) => w.decoration as ShapeDecoration);
        expect(decorations.any((d) => d.color == tokens.onMediaScrim), isTrue, reason: button.label);
        for (final glyph in tester.widgetList<FrostIcon>(find.descendant(of: find.byWidget(button), matching: find.byType(FrostIcon)))) {
          expect(glyph.color, tokens.onMediaInk, reason: button.label);
        }
      }
      await tester.tap(findFrostTooltip(more).hitTestable());
      await tester.pumpAndSettle();
      final entries = find.byType(FrostMenuItem).hitTestable();
      expect(entries, findsWidgets);
      expect(FrostOnMediaChromeScope.inkOf(tester.element(entries.first)), isNull, reason: 'an opened menu keeps its own surface and ink');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('caption foregrounds follow media ink without changing their native geometry', (tester) async {
    final window = FakeWindow();
    addTearDown(window.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: window,
          child: const Center(
            child: FrostSurface(
              role: FrostSurfaceRole.onMediaChrome,
              child: SizedBox(
                height: 40,
                child: Row(mainAxisSize: MainAxisSize.min, children: [FrostCaptionButtons()]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostSurface)));
    for (final button in tester.widgetList<IconButton>(find.byType(IconButton))) {
      expect(button.style!.foregroundColor!.resolve({}), tokens.onMediaInk);
      expect(button.style!.side!.resolve({WidgetState.focused})!.color, tokens.onMediaInk);
    }
    for (final glyph in tester.widgetList<FrostCaptionGlyph>(find.byType(FrostCaptionGlyph))) {
      expect(glyph.color, tokens.onMediaInk);
    }
    for (final button in find.byType(IconButton).evaluate()) {
      expect(tester.getSize(find.byWidget(button.widget)), const Size(FrostCaptionMetrics.buttonWidth, 40));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('media recovery buttons remain readable over an ambient window in either theme', (tester) async {
    for (final brightness in Brightness.values) {
      late FrostThemeTokens tokens;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return FrostWindowBackgroundScope(
                hasAmbient: true,
                background: tokens.canvas,
                child: Center(
                  child: FrostSurface(
                    role: FrostSurfaceRole.onMediaChrome,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FrostButton(label: 'Retry original', onPressed: () {}),
                        FrostButton(label: 'Error details', variant: FrostButtonVariant.plain, onPressed: () {}),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      final surface = Color.alphaBlend(frostOnMediaChromeColor(tokens), Colors.white);
      for (final label in ['Retry original', 'Error details']) {
        final ink = tester.renderObject<RenderParagraph>(find.text(label)).text.style!.color!;
        expect(ink, tokens.onMediaInk);
        final button = find.ancestor(of: find.text(label), matching: find.byType(FrostButton));
        final fills = tester
            .widgetList<DecoratedBox>(find.descendant(of: button, matching: find.byType(DecoratedBox)))
            .map((w) => w.decoration)
            .whereType<ShapeDecoration>()
            .where((d) => d.color != null);
        final fill = fills.first.color!;
        expect(fill, label == 'Retry original' ? tokens.onMediaScrim : tokens.onMediaScrim.withValues(alpha: 0));
        expect(colorContrast(ink, Color.alphaBlend(fill, surface)), greaterThanOrEqualTo(4.5));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('media band remains visible across a black viewer $brightness', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          const ColoredBox(
            color: Colors.black,
            child: FrostSurface(key: mediaKey, role: FrostSurfaceRole.onMediaChrome, borderRadius: BorderRadius.zero, child: SizedBox(height: 48)),
          ),
          brightness: brightness,
        ),
      );
      final fill = parameters(tester, mediaKey).fill;
      final background = Color.alphaBlend(fill, Colors.black);
      expect(background.computeLuminance(), greaterThan(Colors.black.computeLuminance()));
      final tokens = FrostThemeTokens.of(tester.element(find.byKey(mediaKey)));
      expect(colorContrast(tokens.onMediaInk, background), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('scrim uses configured media colors and their alpha floor', (tester) async {
    late FrostThemeTokens configured;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            configured = FrostThemeTokens.of(context).copyWith(onMediaScrim: const Color(0xD9101115), onMediaInk: Colors.white);
            final theme = Theme.of(context);
            return Theme(
              data: theme.copyWith(
                extensions: [
                  for (final item in theme.extensions.values)
                    if (item is! FrostThemeTokens) item,
                  configured,
                ],
              ),
              child: const Center(
                child: FrostSurface(key: mediaKey, role: FrostSurfaceRole.onMediaChrome, child: SizedBox(width: 200, height: 60)),
              ),
            );
          },
        ),
      ),
    );
    expect(parameters(tester, mediaKey).fill, frostOnMediaChromeBase(configured).withValues(alpha: configured.onMediaScrim.a));
    expect(frostOnMediaChromeOpacity(configured), configured.onMediaScrim.a);
  });

  testWidgets('media reveal scales material without an opacity ancestor on the sampler', (tester) async {
    var progress = 0.0;
    late StateSetter update;
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            tokens = FrostThemeTokens.of(context);
            return Center(
              child: FrostMaterialReveal(
                opacity: progress,
                child: const FrostSurface(
                  key: mediaKey,
                  role: FrostSurfaceRole.onMediaChrome,
                  child: SizedBox(width: 200, height: 60, child: FrostText('Revealed')),
                ),
              ),
            );
          },
        ),
      ),
    );
    for (final p in [0.0, .25, .5, 1.0, .5, 0.0]) {
      update(() => progress = p);
      await tester.pump();
      final alpha = frostOnMediaChromeOpacity(tokens);
      expect(parameters(tester, mediaKey).fill.a, closeTo(alpha * p, 1e-9));
      expect(filter(tester, mediaKey).filter, frostGlassFilter(sigma: 18, opacity: frostGlassFilterOpacity(p, alpha)));
      expect(filter(tester, mediaKey).enabled, p > 0);
      expectSafeLayers(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('onMedia buttons retain hover, press, keyboard focus and disabled feedback', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Center(
              child: FrostSurface(
                role: FrostSurfaceRole.onMediaChrome,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrostButton.icon(key: const ValueKey('enabled'), label: 'Media action', icon: testIcons.play, onPressed: () => calls++),
                    FrostButton.icon(key: const ValueKey('disabled'), label: 'Unavailable action', icon: testIcons.forward),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    final enabled = find.byKey(const ValueKey('enabled'));
    List<ShapeDecoration> decorations() => tester
        .widgetList<DecoratedBox>(find.descendant(of: enabled, matching: find.byType(DecoratedBox)))
        .map((w) => w.decoration)
        .whereType<ShapeDecoration>()
        .where((d) => d.color != null)
        .toList();
    final normal = decorations().map((d) => d.color).toList();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(0, 0));
    await mouse.moveTo(tester.getCenter(enabled));
    await tester.pumpAndSettle();
    final hovered = decorations().map((d) => d.color).toList();
    expect(hovered, isNot(normal));
    await mouse.down(tester.getCenter(enabled));
    await tester.pumpAndSettle();
    expect(decorations().map((d) => d.color).toList(), isNot(hovered));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(calls, 1);
    await mouse.removePointer();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    final focus = tester.widget<Focus>(find.descendant(of: enabled, matching: find.byType(Focus)).first);
    focus.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    final focusPaint = tester
        .widgetList<CustomPaint>(find.descendant(of: enabled, matching: find.byType(CustomPaint)))
        .singleWhere((paint) => paint.foregroundPainter != null);
    expect(
      (Canvas canvas) => focusPaint.foregroundPainter!.paint(canvas, const Size(32, 32)),
      paints..path(color: tokens.onMediaInk, style: PaintingStyle.stroke),
    );
    final disabled = find.byKey(const ValueKey('disabled'));
    expect(tester.getSemantics(disabled).getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    final opacity = tester.renderObjectList<RenderAnimatedOpacity>(find.descendant(of: disabled, matching: find.byType(FadeTransition)));
    expect(opacity.any((w) => w.opacity.value == .38), isTrue);
    await tester.tap(disabled);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
