import 'dart:ui' show Tristate;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

List<RenderDecoratedBox> paints(WidgetTester tester, Finder parent) =>
    tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: parent, matching: find.byType(DecoratedBox))).toList();
Color ink(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;
void main() {
  for (final brightness in Brightness.values) {
    for (final tone in FrostBadgeTone.values) {
      testWidgets('badge rendered tone $tone $brightness', (tester) async {
        final semantics = tester.ensureSemantics();
        late FrostThemeTokens tokens;
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: Builder(
                builder: (context) {
                  tokens = FrostThemeTokens.of(context);
                  return FrostBadge(label: 'Status', tone: tone, icon: testIcons.info);
                },
              ),
            ),
            brightness: brightness,
          ),
        );
        final (fill, foreground) = switch (tone) {
          FrostBadgeTone.neutral => (tokens.fill, tokens.textSecondary),
          FrostBadgeTone.accent => (tokens.selectionFill, tokens.accentInk),
          FrostBadgeTone.positive => (tokens.positiveTint, tokens.positiveInk),
          FrostBadgeTone.caution => (tokens.cautionTint, tokens.cautionInk),
          FrostBadgeTone.negative => (tokens.negativeTint, tokens.negativeInk),
          FrostBadgeTone.onMedia => (tokens.onMediaScrim, tokens.onMediaInk),
        };
        final decoration = paints(tester, find.byType(FrostBadge)).first.decoration as ShapeDecoration;
        expect(decoration.color, fill);
        expect(ink(tester, 'Status'), foreground);
        expect((decoration.shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.xs);
        expect(tester.getSize(find.byType(FrostBadge)).height, 20);
        final icon = tester.widget<FrostIcon>(find.byType(FrostIcon));
        expect(icon.size, 12);
        expect(icon.color, foreground);
        final data = tester.getSemantics(find.byType(FrostBadge)).getSemanticsData();
        expect(data.label, 'Status');
        expect(data.flagsCollection.isButton, false);
        semantics.dispose();
      });
    }
  }
  for (final density in FrostDensity.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('badge/tag height and shape $density scale $scale', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    FrostBadge(label: 'Status'),
                    FrostTag(label: 'Content'),
                  ],
                ),
              ),
            ),
            density: density,
          ),
        );
        final surface = find.descendant(of: find.byType(FrostTag), matching: find.byType(FrostClickSurface));
        final typography = FrostTypography.of(tester.element(find.byType(FrostBadge)));
        double increment(FrostTextRole role) {
          double line(double factor) {
            final p = TextPainter(
              text: TextSpan(style: typography.style(role)),
              textScaler: TextScaler.linear(factor),
              textDirection: TextDirection.ltr,
            )..layout();
            final result = p.preferredLineHeight;
            p.dispose();
            return result;
          }

          return line(scale) - line(1);
        }

        expect(tester.getSize(find.byType(FrostBadge)).height, 20 + increment(FrostTextRole.caption));
        final base = density == FrostDensity.compact ? 28 : 32;
        expect(tester.getSize(surface).height, base + increment(FrostTextRole.footnote));
        final shape = (paints(tester, surface).first.decoration as ShapeDecoration).shape as RoundedSuperellipseBorder;
        expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, 8);
        expect(shape.side, BorderSide.none);
      });
    }
  }
  testWidgets('tag selection animates, static text does not dim or focus', (tester) async {
    final semantics = tester.ensureSemantics();
    late StateSetter change;
    late FrostThemeTokens tokens;
    var selected = false;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: StatefulBuilder(
            builder: (context, set) {
              change = set;
              tokens = FrostThemeTokens.of(context);
              return FrostTag(label: 'Tag', selected: selected);
            },
          ),
        ),
      ),
    );
    expect(ink(tester, 'Tag'), tokens.textPrimary);
    final surface = find.byType(FrostClickSurface);
    final focus = tester.widget<Focus>(find.descendant(of: surface, matching: find.byType(Focus)).first);
    expect(focus.canRequestFocus, false);
    expect(tester.getSemantics(find.byType(FrostTag)).getSemanticsData().flagsCollection.isButton, false);
    change(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final mid = (paints(tester, surface).first.decoration as ShapeDecoration).color;
    expect(mid, isNot(tokens.fill));
    expect(mid, isNot(tokens.selectionFill));
    await tester.pumpAndSettle();
    expect((paints(tester, surface).first.decoration as ShapeDecoration).color, tokens.selectionFill);
    expect(ink(tester, 'Tag'), tokens.selectionInk);
    final data = tester.getSemantics(find.bySemanticsLabel('Tag')).getSemanticsData();
    expect(data.flagsCollection.isToggled, Tristate.isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });
  testWidgets('interactive tag hover/press uses interpolated shared feedback', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostTag(label: 'Tag', onPressed: () {}),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(FrostClickSurface)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final half = (paints(tester, find.byType(FrostClickSurface))[1].decoration as ShapeDecoration).color!.a;
    await tester.pump(const Duration(milliseconds: 70));
    final hovered = (paints(tester, find.byType(FrostClickSurface))[1].decoration as ShapeDecoration).color!.a;
    expect(half, inExclusiveRange(0, hovered));
    await mouse.down(tester.getCenter(find.byType(FrostClickSurface)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final transforms = tester.widgetList<Transform>(find.descendant(of: find.byType(FrostClickSurface), matching: find.byType(Transform)));
    expect(transforms.every((t) => t.transform.storage[0] == 1), isTrue, reason: 'Press must not scale the tag; no transform is also identity.');
    await tester.pump(const Duration(milliseconds: 140));
    expect((paints(tester, find.byType(FrostClickSurface))[1].decoration as ShapeDecoration).color!.a, greaterThan(hovered));
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('tag dot uses modulo; detail ellipsizes before label; width capped', (tester) async {
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return FrostTag(label: 'Primary', detail: 'Very long translated detail ' * 10, dataColor: tokens.categorical.length + 1);
            },
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FrostTag)).width, 240);
    final dot = paints(
      tester,
      find.byType(FrostTag),
    ).singleWhere((p) => p.decoration is BoxDecoration && (p.decoration as BoxDecoration).shape == BoxShape.circle);
    expect(dot.size, const Size(6, 6));
    expect((dot.decoration as BoxDecoration).color, tokens.categorical[1]);
    expect(tester.renderObject<RenderParagraph>(find.text('Primary')).didExceedMaxLines, false);
    expect(tester.renderObject<RenderParagraph>(find.text('Very long translated detail ' * 10)).didExceedMaxLines, true);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostTag(label: 'Long primary ' * 20, detail: 'Detail'),
        ),
      ),
    );
    expect(tester.renderObject<RenderParagraph>(find.text('Long primary ' * 20)).didExceedMaxLines, true);
    expect(tester.getSize(find.text('Detail')).width, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tag opens shared secondary-click menu and reduced motion snaps selection', (tester) async {
    late StateSetter change;
    var selected = false;
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, set) {
                change = set;
                tokens = FrostThemeTokens.of(context);
                return FrostTag(
                  label: 'Tag',
                  onPressed: () {},
                  selected: selected,
                  contextMenu: [FrostMenuAction('Inspect', onSelected: () {})],
                );
              },
            ),
          ),
        ),
      ),
    );
    change(() => selected = true);
    await tester.pump();
    expect(ink(tester, 'Tag'), tokens.selectionInk);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await mouse.down(tester.getCenter(find.byType(FrostTag)));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Inspect'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
