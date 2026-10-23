import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_close_control.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Future<void> display(
  WidgetTester tester,
  Widget child, {
  double width = 300,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  FrostDensity density = FrostDensity.compact,
  Brightness brightness = Brightness.light,
  bool reduced = false,
}) => tester.pumpWidget(
  frostTestApp(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale), disableAnimations: reduced),
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox(
            width: width,
            child: Align(alignment: AlignmentDirectional.centerStart, child: child),
          ),
        ),
      ),
    ),
    density: density,
    brightness: brightness,
  ),
);

List<RenderDecoratedBox> decorations(WidgetTester tester, Finder parent) =>
    tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: parent, matching: find.byType(DecoratedBox))).toList();

void main() {
  testWidgets('decorative badge lets taps reach the underlying control', (tester) async {
    var calls = 0;
    await display(tester, FrostClickSurface(onTap: () => calls++, child: const SizedBox(width: 100, height: 40)).frostBadge(5));
    final rect = tester.getRect(find.byType(FrostClickSurface));
    await tester.tapAt(Offset(rect.right - 6, rect.top + 6));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('filter body target reaches touch padding and clear stays independent', (tester) async {
    var body = 0, clear = 0;
    await display(
      tester,
      Theme(
        data: FrostTheme.build(
          config: testConfig,
          brightness: Brightness.light,
          platform: TargetPlatform.android,
          locale: const Locale('en'),
          density: FrostDensity.comfortable,
        ),
        child: FrostFilterChip(label: 'Type', value: 'Image', onPressed: () => body++, onClear: () => clear++),
      ),
      density: FrostDensity.comfortable,
    );
    final rect = tester.getRect(find.byType(FrostFilterChip));
    expect(rect.height, 44);
    final surface = find.descendant(of: find.byType(FrostFilterChip), matching: find.byType(FrostClickSurface)).first;
    expect(tester.getSize(surface).height, 32);
    await tester.tapAt(Offset(tester.getCenter(surface).dx, rect.top + 1));
    expect(body, 1);
    expect(clear, 0);
    await tester.tap(find.byType(FrostCloseControl));
    expect(body, 1);
    expect(clear, 1);
    expect(FocusManager.instance.primaryFocus!.canRequestFocus, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nonpositive counts hide and a zero cap remains a valid caller limit', (tester) async {
    await display(tester, const FrostCountBadge(count: -5));
    expect(find.byType(FrostRollingText), findsNothing);
    await display(tester, const FrostCountBadge(count: 1, max: 0));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    for (final tone in FrostCountBadgeTone.values) {
      testWidgets('count paint $brightness $tone', (tester) async {
        await display(tester, FrostCountBadge(count: 5, tone: tone), brightness: brightness);
        final badge = find.byType(FrostCountBadge);
        final tokens = FrostThemeTokens.of(tester.element(badge));
        final paint = decorations(tester, badge).first.decoration as ShapeDecoration;
        expect(tester.getSize(badge).height, 16);
        expect(tester.getSize(badge).width, greaterThanOrEqualTo(16));
        expect(paint.color, tone == FrostCountBadgeTone.accent ? tokens.actionFill : tokens.negativeFill);
        expect((paint.shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, 8);
        final text = tester.renderObject<RenderParagraph>(find.text('5')).text.style!;
        expect(text.fontSize, FrostTypography.of(tester.element(badge)).style(FrostTextRole.caption).fontSize);
        expect(text.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(text.color, tone == FrostCountBadgeTone.accent ? tokens.onAction : tokens.onNegative);
      });
    }
  }
  for (final direction in TextDirection.values) {
    testWidgets('badge overlay and merged semantics $direction', (tester) async {
      final handle = tester.ensureSemantics();
      await display(
        tester,
        Semantics(
          label: 'Inbox',
          value: 'existing',
          button: true,
          child: const SizedBox(key: ValueKey('base'), width: 100, height: 40),
        ).frostBadge(120),
        direction: direction,
      );
      final badge = find.byType(FrostCountBadge);
      final parent = tester.getRect(find.byKey(const ValueKey('base')));
      final rect = tester.getRect(badge);
      expect(rect.center.dx, direction == TextDirection.ltr ? parent.right - 4 : parent.left + 4);
      expect(rect.center.dy, parent.top + 4);
      expect(find.text('+'), findsOneWidget);
      final data = tester.getSemantics(find.bySemanticsLabel('Inbox')).getSemanticsData();
      expect(data.label, 'Inbox');
      expect(data.value, contains('120'));
      expect(data.value, contains('existing'));
      expect(data.flagsCollection.isButton, true);
      handle.dispose();
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('badge presence and digit changes reduced=$reduced', (tester) async {
      var count = 0;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostCountBadge(count: count);
          },
        ),
        reduced: reduced,
      );
      expect(find.byType(FrostRollingText), findsNothing);
      update(() => count = 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final fade = tester.widget<FrostMaterialRevealTransition>(
        find.descendant(of: find.byType(FrostPresence), matching: find.byType(FrostMaterialRevealTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(find.byType(ScaleTransition), reduced ? findsNothing : findsOneWidget);
      await tester.pumpAndSettle();
      update(() => count = 6);
      await tester.pump();
      expect(find.text('6'), findsOneWidget);
      await tester.pumpAndSettle();
      update(() => count = 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('6'), findsOneWidget);
      expect(
        tester
            .widget<FrostMaterialRevealTransition>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(FrostMaterialRevealTransition)).first)
            .opacity
            .value,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FrostRollingText), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    for (final direction in TextDirection.values) {
      testWidgets('filter geometry and complete wrapping $density $direction', (tester) async {
        await display(
          tester,
          FrostFilterChip(label: 'A long active filter 20', value: 'Full value', onPressed: () {}, onClear: () {}),
          width: 160,
          scale: 2,
          direction: direction,
          density: density,
        );
        final chip = find.byType(FrostFilterChip);
        final tokens = FrostThemeTokens.of(tester.element(chip));
        final shape = decorations(tester, chip).first.decoration as ShapeDecoration;
        expect(shape.color, tokens.selectionFill);
        expect((shape.shape as RoundedSuperellipseBorder).borderRadius.resolve(direction).topLeft.x, 8);
        expect(tester.getSize(find.byType(FrostCloseControl)), const Size(20, 20));
        final closeIcon = tester.widget<FrostIcon>(find.descendant(of: find.byType(FrostCloseControl), matching: find.byType(FrostIcon)));
        expect(closeIcon.color, tokens.selectionInk);
        final paragraph = tester.renderObject<RenderParagraph>(find.text('A long active filter 20 · Full value'));
        expect(paragraph.maxLines, isNull);
        expect(paragraph.didExceedMaxLines, false);
        expect(paragraph.text.style!.color, tokens.selectionInk);
        expect(paragraph.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('filter body and clear have independent focus, semantics and input', (tester) async {
    final semantics = tester.ensureSemantics();
    var body = 0, clear = 0;
    await display(tester, FrostFilterChip(label: 'Type', value: 'Image', onPressed: () => body++, onClear: () => clear++));
    final surfaces = find.descendant(of: find.byType(FrostFilterChip), matching: find.byType(FrostClickSurface));
    expect(surfaces, findsNWidgets(2));
    await tester.tap(find.text('Type · Image'));
    expect(body, 1);
    expect(clear, 0);
    await tester.tap(find.byType(FrostCloseControl));
    expect(body, 1);
    expect(clear, 1);
    final bodyNode = tester.getSemantics(surfaces.first), clearNode = tester.getSemantics(surfaces.last);
    expect(bodyNode.id, isNot(clearNode.id));
    expect(bodyNode.getSemanticsData().label, 'Type · Image');
    expect(clearNode.getSemanticsData().label, 'L.clearText');
    tester.widget<Focus>(find.descendant(of: surfaces.first, matching: find.byType(Focus)).first).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(body, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(clear, 2);
    semantics.dispose();
  });
  testWidgets('filter hover and pressed layers interpolate, reduced motion is supported', (tester) async {
    for (final reduced in [false, true]) {
      await display(
        tester,
        FrostFilterChip(label: 'Active', onPressed: () {}),
        reduced: reduced,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Active')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final paints = decorations(tester, find.byType(FrostFilterChip));
      final layer = (paints.last.decoration as ShapeDecoration).color!;
      expect(layer.a, greaterThan(0));
      await mouse.down(tester.getCenter(find.text('Active')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final transforms = tester.widgetList<Transform>(find.descendant(of: find.byType(FrostFilterChip), matching: find.byType(Transform)));
      expect(transforms.where((t) => t.transform.entry(0, 0) != 1), isEmpty);
      await mouse.up();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  for (final tone in FrostStatusTone.values) {
    testWidgets('status dot real paint and label $tone', (tester) async {
      final semantics = tester.ensureSemantics();
      await display(
        tester,
        FrostStatusDot(tone: tone, label: 'Status 24'),
        width: 95,
        scale: 2,
        direction: TextDirection.rtl,
      );
      final dot = find.byType(FrostStatusDot), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostStatusDot)));
      final expected = switch (tone) {
        FrostStatusTone.neutral => tokens.textTertiary,
        FrostStatusTone.accent => tokens.accentInk,
        FrostStatusTone.positive => tokens.positiveInk,
        FrostStatusTone.caution => tokens.cautionInk,
        FrostStatusTone.negative => tokens.negativeInk,
      };
      final box = decorations(tester, dot).first;
      expect(box.size, const Size(8, 8));
      expect((box.decoration as BoxDecoration).color, expected);
      expect((box.decoration as BoxDecoration).shape, BoxShape.circle);
      final text = tester.renderObject<RenderParagraph>(find.text('Status 24'));
      expect(text.text.style!.color, tokens.textSecondary);
      expect(text.maxLines, isNull);
      expect(tester.getSemantics(dot).getSemanticsData().label, 'Status 24');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
