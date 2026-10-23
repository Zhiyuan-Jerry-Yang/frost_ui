import 'dart:math' as math;
import 'dart:ui' show Tristate;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Finder get _surface => find.byType(FrostClickSurface);
List<RenderDecoratedBox> _paints(WidgetTester tester) =>
    tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: _surface, matching: find.byType(DecoratedBox))).toList();
Color _base(WidgetTester tester) => (_paints(tester).first.decoration as ShapeDecoration).color!;
Color _layer(WidgetTester tester) => (_paints(tester)[1].decoration as ShapeDecoration).color!;
double _scale(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .firstWhere((t) => t.transform.storage[0] != 1, orElse: () => Transform.scale(scale: 1))
    .transform
    .storage[0];
double _fade(WidgetTester tester, Finder ancestor, double target) {
  final node = find.descendant(of: ancestor, matching: find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity == target)).first;
  return tester.renderObject<RenderAnimatedOpacity>(find.descendant(of: node, matching: find.byType(FadeTransition)).first).opacity.value;
}

void main() {
  for (final density in FrostDensity.values) {
    for (final size in FrostControlSize.values) {
      testWidgets('button rendered matrix $density $size', (tester) async {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        for (final variant in FrostButtonVariant.values) {
          for (final role in FrostButtonRole.values) {
            late StateSetter update;
            late FrostThemeTokens tokens;
            var enabled = true, loading = false;
            await tester.pumpWidget(
              frostTestApp(
                Center(
                  child: StatefulBuilder(
                    builder: (context, set) {
                      update = set;
                      tokens = FrostThemeTokens.of(context);
                      return FrostButton(
                        label: 'Action',
                        icon: testIcons.add,
                        variant: variant,
                        role: role,
                        size: size,
                        onPressed: enabled ? () {} : null,
                        loading: loading,
                        tooltip: 'Help',
                      );
                    },
                  ),
                ),
                density: density,
              ),
            );
            await tester.pumpAndSettle();
            final height = size.visualHeight(touch: density == FrostDensity.comfortable);
            expect(tester.getSize(_surface).height, height);
            final expectedInset = switch (size) {
              FrostControlSize.compact => 12,
              FrostControlSize.regular => 16,
              FrostControlSize.large => 20,
            };
            expect(
              tester.getSize(_surface).width,
              closeTo(tester.getSize(find.text('Action')).width + size.iconSize + (size == FrostControlSize.compact ? 6 : 8) + expectedInset * 2, .001),
            );
            expect(tester.getSize(find.byType(FrostButton)).height, math.max(height, density.targetHeight));
            final shape = (_paints(tester).first.decoration as ShapeDecoration).shape as RoundedSuperellipseBorder;
            expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.forHeight(height));
            final destructive = role == FrostButtonRole.destructive;
            final fill = switch (variant) {
              FrostButtonVariant.prominent => destructive ? tokens.negativeFill : tokens.actionFill,
              FrostButtonVariant.standard => tokens.fill,
              FrostButtonVariant.plain => tokens.fillSubtle.withValues(alpha: 0),
            };
            final ink = variant == FrostButtonVariant.prominent
                ? destructive
                      ? tokens.onNegative
                      : tokens.onAction
                : destructive
                ? tokens.negativeInk
                : tokens.textPrimary;
            expect(_base(tester), fill);
            final paragraph = tester.renderObject<RenderParagraph>(find.text('Action'));
            expect(paragraph.text.style?.color, ink);
            expect(find.byType(FrostTooltip), findsOneWidget);
            await mouse.moveTo(tester.getCenter(_surface));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 70));
            expect(_layer(tester).a, greaterThan(0));
            await tester.pump(const Duration(milliseconds: 70));
            final hovered = _layer(tester).a;
            await mouse.down(tester.getCenter(_surface));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 140));
            expect(_layer(tester).a, greaterThan(hovered));
            expect(_scale(tester), 1);
            await mouse.up();
            await mouse.moveTo(Offset.zero);
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            // Pointer activation already focused this button; request focus via
            // its real node to keep the matrix independent of traversal order.
            final focus = tester.widget<Focus>(find.descendant(of: _surface, matching: find.byType(Focus)).first);
            focus.focusNode!.requestFocus();
            await tester.pumpAndSettle();
            final focusPaint = tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .singleWhere((w) => w.foregroundPainter?.runtimeType.toString() == '_ButtonFocusPainter');
            final visualSize = tester.getSize(_surface);
            expect(
              (Canvas canvas) => focusPaint.foregroundPainter!.paint(canvas, visualSize),
              paints..path(
                includes: [Offset(-2.9, visualSize.height / 2), Offset(visualSize.width + 2.9, visualSize.height / 2)],
                excludes: [Offset(-3.1, visualSize.height / 2), Offset(visualSize.width + 3.1, visualSize.height / 2)],
                color: tokens.focus,
                strokeWidth: 2,
                style: PaintingStyle.stroke,
              ),
            );
            update(() => enabled = false);
            await tester.pumpAndSettle();
            expect(_fade(tester, find.byType(FrostButton), .38), .38);
            expect(_base(tester), variant == FrostButtonVariant.prominent ? tokens.fill : fill);
            expect(_layer(tester).a, 0);
            expect(tester.renderObject<RenderParagraph>(find.text('Action')).text.style?.color, destructive ? tokens.negativeInk : tokens.textPrimary);
            update(() => loading = true);
            await tester.pump();
            expect(_fade(tester, find.byType(FrostButton), 1), .38);
            await tester.pump(const Duration(milliseconds: 200));
            expect(_fade(tester, find.byType(FrostButton), 1), 1);
            expect(_base(tester), fill);
            expect(tester.renderObject<RenderParagraph>(find.text('Action')).text.style?.color, ink);
            expect(tester.getSize(_surface).height, height);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
        await mouse.removePointer();
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('disabled prominent contrast matches standard: $brightness', (tester) async {
      late FrostThemeTokens tokens;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return ColoredBox(
                color: tokens.surface,
                child: Column(
                  children: [
                    for (final role in FrostButtonRole.values)
                      for (final variant in [FrostButtonVariant.prominent, FrostButtonVariant.standard])
                        FrostButton(label: '${variant.name} ${role.name}', variant: variant, role: role, onPressed: null),
                  ],
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      double renderedContrast(FrostButtonVariant variant, FrostButtonRole role) {
        final label = find.text('${variant.name} ${role.name}');
        final button = find.ancestor(of: label, matching: find.byType(FrostButton));
        final paint = tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: button, matching: find.byType(DecoratedBox))).first;
        final fill = (paint.decoration as ShapeDecoration).color!;
        final ink = tester.renderObject<RenderParagraph>(label).text.style!.color!;
        final opacity = _fade(tester, button, .38);
        expect(fill, tokens.fill);
        expect(opacity, .38);
        final background = Color.alphaBlend(fill, tokens.surface);
        final foreground = Color.alphaBlend(ink.withValues(alpha: ink.a * opacity), background);
        return colorContrast(foreground, background);
      }

      for (final role in FrostButtonRole.values) {
        expect(
          renderedContrast(FrostButtonVariant.prominent, role),
          greaterThanOrEqualTo(renderedContrast(FrostButtonVariant.standard, role)),
          reason: '$brightness $role: compare rendered ink after .38 opacity over the rendered fill',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('prominent ink interpolates for 140 ms when re-enabled', (tester) async {
    late StateSetter update;
    late FrostThemeTokens tokens;
    var enabled = false;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: StatefulBuilder(
            builder: (context, set) {
              update = set;
              tokens = FrostThemeTokens.of(context);
              return FrostButton(label: 'Enable action', variant: FrostButtonVariant.prominent, onPressed: enabled ? () {} : null);
            },
          ),
        ),
      ),
    );
    Color renderedInk() => tester.renderObject<RenderParagraph>(find.text('Enable action')).text.style!.color!;
    expect(renderedInk(), tokens.textPrimary);
    update(() => enabled = true);
    await tester.pump();
    expect(renderedInk(), tokens.textPrimary);
    await tester.pump(const Duration(milliseconds: 70));
    expect(renderedInk(), Color.lerp(tokens.textPrimary, tokens.onAction, FrostMotion.hoverCurve.transform(.5)));
    await tester.pump(const Duration(milliseconds: 70));
    expect(renderedInk(), tokens.onAction);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading crossfades in a stable slot and announces through the button', (tester) async {
    final handle = tester.ensureSemantics();
    late StateSetter update;
    var loading = false;
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostButton(label: 'Long action', icon: testIcons.add, onPressed: () => calls++, loading: loading);
            },
          ),
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(FrostButton));
    update(() => loading = true);
    await tester.pump();
    await tester.tap(_surface);
    await tester.pump(const Duration(milliseconds: 299));
    expect(calls, 0);
    expect(tester.getRect(find.byType(FrostButton)), bounds);
    expect(tester.getSemantics(find.byType(FrostButton)).getSemanticsData().value, 'L.loading');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 90));
    final opacities = tester
        .renderObjectList<RenderAnimatedOpacity>(find.descendant(of: find.byType(FrostButton), matching: find.byType(FadeTransition)))
        .map((r) => r.opacity.value)
        .toList();
    expect(opacities.where((v) => v > 0 && v < 1).length, 2);
    await tester.pump(const Duration(milliseconds: 310));
    update(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getRect(find.byType(FrostButton)), bounds);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('disabled and loading buttons mount at the app root without lifecycle writes', (tester) async {
    for (final loading in [false, true]) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostButton(label: 'Initial', onPressed: loading ? () {} : null, loading: loading),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selected icon colours, toggled semantics, pop, circle and square hit geometry', (tester) async {
    final handle = tester.ensureSemantics();
    for (final style in FrostIconButtonStyle.values) {
      for (final density in FrostDensity.values) {
        late StateSetter update;
        late FrostThemeTokens tokens;
        var selected = false;
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  tokens = FrostThemeTokens.of(context);
                  return FrostButton.icon(
                    icon: testIcons.add,
                    label: 'Toggle',
                    onPressed: () {},
                    style: style,
                    selected: selected,
                    size: FrostControlSize.compact,
                  );
                },
              ),
            ),
            density: density,
          ),
        );
        expect(tester.getSize(find.byType(FrostButton)), Size.square(density.targetHeight));
        final paint = (_paints(tester).first.decoration as ShapeDecoration);
        expect(paint.shape is CircleBorder, style == FrostIconButtonStyle.onMedia);
        expect(
          _base(tester),
          style == FrostIconButtonStyle.onMedia
              ? tokens.onMediaScrim
              : style == FrostIconButtonStyle.standard
              ? tokens.fill
              : tokens.fillSubtle.withValues(alpha: 0),
        );
        update(() => selected = true);
        await tester.pump();
        expect(_scale(tester), 1);
        await tester.pump(const Duration(milliseconds: 70));
        expect(_scale(tester), 1);
        await tester.pumpAndSettle();
        expect(_base(tester), tokens.selectionFill);
        expect(tester.widget<FrostIcon>(find.byType(FrostIcon)).color, tokens.selectionInk);
        expect(tester.getSemantics(find.byType(FrostButton)).getSemanticsData().flagsCollection.isToggled, Tristate.isTrue);
        update(() => selected = false);
        await tester.pump();
        expect(_scale(tester), 1);
        await tester.pump(const Duration(milliseconds: 70));
        expect(_scale(tester), 1);
        await tester.pumpAndSettle();
        expect(
          _base(tester),
          style == FrostIconButtonStyle.onMedia
              ? tokens.onMediaScrim
              : style == FrostIconButtonStyle.standard
              ? tokens.fill
              : tokens.fillSubtle.withValues(alpha: 0),
        );
        expect(tester.getSemantics(find.byType(FrostButton)).getSemanticsData().flagsCollection.isToggled, Tristate.isFalse);
        await tester.pumpWidget(const SizedBox());
      }
    }
    handle.dispose();
  });

  testWidgets('pressed disable, loading round trip, reenable and unmount cancel silently', (tester) async {
    for (final cancellation in ['disable', 'loading', 'reenable', 'unmount']) {
      late StateSetter update;
      var enabled = true, loading = false, present = true;
      var calls = 0;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return present ? FrostButton(label: 'Action', onPressed: enabled ? () => calls++ : null, loading: loading) : const SizedBox();
              },
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(_surface));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_scale(tester), 1);
      update(() {
        if (cancellation == 'unmount') {
          present = false;
        } else if (cancellation == 'loading') {
          loading = true;
        } else {
          enabled = false;
        }
      });
      await tester.pump();
      if (present) {
        final start = _layer(tester).a;
        await tester.pump(const Duration(milliseconds: 60));
        expect(_layer(tester).a, lessThan(start));
        expect(_scale(tester), 1);
        expect(_scale(tester), 1);
        if (cancellation == 'loading' || cancellation == 'reenable') {
          update(() {
            enabled = true;
            loading = false;
          });
          await tester.pump();
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 0, reason: cancellation);
      if (present) expect(_scale(tester), closeTo(1, .00001));
      expect(tester.takeException(), isNull, reason: cancellation);
    }
  });

  testWidgets('selected icon mount and both reduced-motion endpoints are settled', (tester) async {
    late StateSetter update;
    var selected = true;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Center(
              child: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return FrostButton.icon(icon: testIcons.add, label: 'Toggle', selected: selected, onPressed: () {});
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(_scale(tester), 1);
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostButton)));
    expect(_base(tester), tokens.selectionFill);
    update(() => selected = false);
    await tester.pump();
    expect(_scale(tester), 1);
    expect(_base(tester).a, 0);
    update(() => selected = true);
    await tester.pump();
    expect(_scale(tester), 1);
    expect(_base(tester), tokens.selectionFill);
    expect(tester.takeException(), isNull);
  });

  testWidgets('click surface only emits press notifications from input; lifecycle is silent', (tester) async {
    for (final unmount in [false, true]) {
      final changes = <bool>[];
      late StateSetter update;
      var enabled = true, present = true, calls = 0;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return present
                    ? FrostClickSurface(onTap: enabled ? () => calls++ : null, onPressedChange: changes.add, child: const SizedBox(width: 80, height: 40))
                    : const SizedBox();
              },
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(_surface));
      await tester.pump();
      expect(changes, [true]);
      update(() {
        if (unmount) {
          present = false;
        } else {
          enabled = false;
        }
      });
      await tester.pump();
      expect(changes, [true]);
      if (!unmount) {
        update(() => enabled = true);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(changes, [true]);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('click surface press events pair once for pointer, cancel and keyboard activation', (tester) async {
    final changes = <bool>[];
    final focus = FocusNode();
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostClickSurface(focusNode: focus, onTap: () => calls++, onPressedChange: changes.add, child: const SizedBox(width: 80, height: 40)),
        ),
      ),
    );
    await tester.tap(_surface);
    await tester.pump();
    expect(changes, [true, false]);
    expect(calls, 1);
    final pointer = await tester.startGesture(tester.getCenter(_surface));
    await pointer.cancel();
    await tester.pump();
    expect(changes, [true, false, true, false]);
    expect(calls, 1);
    focus.requestFocus();
    await tester.pump();
    for (final key in [LogicalKeyboardKey.space, LogicalKeyboardKey.enter]) {
      changes.clear();
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      expect(changes, [true]);
      await tester.sendKeyUpEvent(key);
      await tester.pump();
      expect(changes, [true, false]);
    }
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('gesture competition cancels input and a disabled keyboard press stays invalid', (tester) async {
    final changes = <bool>[];
    var calls = 0, enabled = true;
    late StateSetter update;
    final focus = FocusNode();
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return ListView(
              children: [
                FrostClickSurface(focusNode: focus, onTap: enabled ? () => calls++ : null, onPressedChange: changes.add, child: const SizedBox(height: 80)),
                const SizedBox(height: 1200),
              ],
            );
          },
        ),
      ),
    );
    final pointer = await tester.startGesture(tester.getCenter(_surface));
    await pointer.moveBy(const Offset(0, -50));
    await pointer.up();
    await tester.pumpAndSettle();
    expect(changes, [true, false]);
    expect(calls, 0);
    changes.clear();
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    update(() => enabled = false);
    await tester.pump();
    update(() => enabled = true);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(changes, [true]);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });

  testWidgets('unmatched synthesized key release leaves Escape available to modal parents', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var calls = 0;
    final presses = <bool>[];
    await tester.pumpWidget(frostTestApp(FrostClickSurface(focusNode: focus, onTap: () => calls++, onPressedChange: presses.add, child: const Text('Action'))));
    focus.requestFocus();
    await tester.pump();
    final events = <KeyEvent>[
      const KeyDownEvent(physicalKey: PhysicalKeyboardKey.escape, logicalKey: LogicalKeyboardKey.escape, timeStamp: Duration.zero),
      const KeyUpEvent(physicalKey: PhysicalKeyboardKey.space, logicalKey: LogicalKeyboardKey.space, timeStamp: Duration.zero, synthesized: true),
    ];
    expect(combineKeyEventResults(events.map((event) => focus.onKeyEvent!(focus, event))), KeyEventResult.ignored);
    expect(calls, 0);
    expect(presses, isEmpty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, [true]);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, [true, false]);
    expect(calls, 1);
  });

  test('negative solid token uses the negative hue and solid label rule', () {
    for (final brightness in Brightness.values) {
      final palette = FrostPalettes.pink.palette(brightness, FrostTone.neutral, FrostPalettes.pink.defaultAccent(brightness));
      expect(palette.negativeFill, const Color(0xFFE5484D));
      expect(palette.onNegative, solidLabelTone(palette.negativeFill));
    }
  });
}
