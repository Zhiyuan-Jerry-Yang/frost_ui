import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'display_badges_v2_test.dart' show display, decorations;
import 'support.dart';

void main() {
  testWidgets('clickable module owns pointer activation throughout its content', (tester) async {
    var module = 0, child = 0;
    await display(
      tester,
      FrostModule(
        title: 'Module',
        onPressed: () => module++,
        content: FrostButton(label: 'Decorative child', onPressed: () => child++),
      ),
    );
    await tester.tapAt(tester.getCenter(find.text('Decorative child')));
    expect(module, 1);
    expect(child, 0);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    for (final direction in TextDirection.values) {
      testWidgets('module surface and role geometry $brightness $direction', (tester) async {
        await display(
          tester,
          FrostModule(
            title: 'Header 24',
            icon: testIcons.info,
            value: '42',
            note: 'A complete note',
            content: const FrostTag(label: 'A tag'),
          ),
          width: 250,
          scale: 2,
          direction: direction,
          brightness: brightness,
        );
        final module = find.byType(FrostModule), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostModule)));
        final paint = decorations(
          tester,
          find.byType(FrostSurface),
        ).map((box) => box.decoration).whereType<ShapeDecoration>().firstWhere((paint) => paint.color != null);
        expect(paint.color, Color.alphaBlend(tokens.fillSubtle, tokens.canvas));
        final shape = paint.shape as RoundedSuperellipseBorder;
        expect(shape.borderRadius.resolve(direction).topLeft.x, 12);
        expect(shape.side, BorderSide.none);
        final outer = tester.getRect(module), title = tester.getRect(find.text('Header 24'));
        final icon = tester.getRect(find.byType(FrostIcon));
        expect(direction == TextDirection.ltr ? icon.left - outer.left : outer.right - icon.right, 16);
        expect(icon.width, 14);
        expect(tester.renderObject<RenderParagraph>(find.text('Header 24')).text.style!.color, tokens.textTertiary);
        expect(tester.renderObject<RenderParagraph>(find.text('A complete note')).text.style!.color, tokens.textSecondary);
        expect(
          tester.renderObject<RenderParagraph>(find.text('4')).text.style!.fontSize,
          FrostTypography.of(tester.element(module)).style(FrostTextRole.title2).fontSize,
        );
        expect(title.top, greaterThanOrEqualTo(outer.top + 16));
        final keyline = tester.widget<FrostKeyline>(find.descendant(of: module, matching: find.byType(FrostKeyline)).last);
        expect(keyline.insideContainer, true);
        expect(keyline.leadingRoom, 16);
        expect(keyline.trailingRoom, 16);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('module resets inherited bleed and confines row feedback', (tester) async {
    await display(
      tester,
      FrostKeyline(
        leadingRoom: 24,
        trailingRoom: 24,
        edgeDistanceStart: 24,
        edgeDistanceEnd: 24,
        insideContainer: false,
        contentStart: 0,
        child: FrostModule(
          title: 'Info',
          content: FrostListRow(title: 'Nested row', onPressed: () {}),
        ),
      ),
      width: 250,
    );
    final module = tester.getRect(find.byType(FrostModule));
    final row = find.byType(FrostListRow), rowRect = tester.getRect(row);
    expect(rowRect.left - module.left, 16);
    expect(module.right - rowRect.right, 16);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(row));
    await tester.pumpAndSettle();
    final feedback = find.descendant(of: row, matching: find.byType(FrostClickFeedbackVisual));
    final rect = tester.getRect(feedback);
    expect(rect, rowRect);
    expect(module.contains(rect.topLeft), true);
    expect(module.contains(rect.bottomRight), true);
    expect((decorations(tester, feedback).first.decoration as ShapeDecoration).color!.a, greaterThan(0));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('clickable module single button, keyboard and feedback reduced=$reduced', (tester) async {
      final semantics = tester.ensureSemantics();
      var calls = 0;
      await display(
        tester,
        FrostModule(title: 'Open module', value: '42', content: const Text('Decorative child'), onPressed: () => calls++),
        reduced: reduced,
      );
      final data = tester.getSemantics(find.byType(FrostModule)).getSemanticsData();
      expect(data.flagsCollection.isButton, true);
      expect(data.label, 'Open module');
      expect(data.value, '42');
      expect(find.bySemanticsLabel('Decorative child'), findsNothing);
      final icon = tester.widget<FrostIcon>(find.byType(FrostIcon));
      expect(icon.icon, testIcons.chevronRight);
      final surface = find.byType(FrostClickSurface);
      tester.widget<Focus>(find.descendant(of: surface, matching: find.byType(Focus)).first).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, 1);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(surface));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final feedback = find.byType(FrostClickFeedbackVisual);
      expect((decorations(tester, feedback).first.decoration as ShapeDecoration).color!.a, greaterThan(0));
      await mouse.down(tester.getCenter(surface));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final scale = tester.widget<Transform>(find.descendant(of: feedback, matching: find.byType(Transform)).first).transform.entry(0, 0);
      final target = FrostMetrics.pressedScale(tester.element(surface));
      expect(scale, reduced ? closeTo(target, .0001) : inExclusiveRange(target, 1));
      await mouse.up();
      expect(calls, 2);
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  for (final direction in TextDirection.values) {
    for (final width in [331.0, 332.0, 800.0]) {
      testWidgets('grid cold threshold, equal height and unmatched half $direction $width', (tester) async {
        await display(
          tester,
          const FrostModuleGrid(
            items: [
              FrostModuleGridItem(child: SizedBox(key: ValueKey('a'), height: 30)),
              FrostModuleGridItem(child: SizedBox(key: ValueKey('b'), height: 70)),
              FrostModuleGridItem(
                span: FrostModuleSpan.full,
                child: SizedBox(key: ValueKey('c'), height: 20),
              ),
              FrostModuleGridItem(child: SizedBox(key: ValueKey('d'), height: 40)),
            ],
          ),
          width: width,
          direction: direction,
        );
        Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
        final a = rect('a'), b = rect('b'), c = rect('c'), d = rect('d'), grid = tester.getRect(find.byType(FrostModuleGrid));
        if (width >= 332) {
          expect(a.width, (width - 12) / 2);
          expect(a.height, 70);
          expect(b.height, 70);
          expect(a.top, b.top);
          expect(c.top - a.bottom, 12);
          expect(d.width, a.width);
          expect(direction == TextDirection.ltr ? d.left : d.right, direction == TextDirection.ltr ? grid.left : grid.right);
        } else {
          expect(a.width, width);
          expect(b.width, width);
          expect(b.top - a.bottom, 12);
          expect(d.width, width);
        }
        expect(c.width, width);
        expect(d.top - c.bottom, 12);
        expect(tester.hasRunningAnimations, false);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('real modules equalize with large text and preserve source order', (tester) async {
    await display(
      tester,
      const FrostModuleGrid(
        items: [
          FrostModuleGridItem(
            child: FrostModule(title: 'Short', value: '42'),
          ),
          FrostModuleGridItem(
            child: FrostModule(title: 'Long', note: 'A long complete note that wraps across several lines at large text scaling.'),
          ),
        ],
      ),
      width: 332,
      scale: 2,
    );
    final modules = find.byType(FrostModule);
    expect(tester.getSize(modules.first), tester.getSize(modules.last));
    expect(tester.getTopLeft(modules.first).dy, tester.getTopLeft(modules.last).dy);
    expect(tester.takeException(), isNull);
  });
}
