import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/status_glyph.dart';

import 'support.dart';

void show(FrostToastKind kind) => switch (kind) {
  FrostToastKind.success => FrostToast.success('Message'),
  FrostToastKind.info => FrostToast.info('Message'),
  FrostToastKind.warning => FrostToast.warning('Message'),
  FrostToastKind.error => FrostToast.error('Message'),
};
Widget app({required Brightness brightness, required bool continuous, TargetPlatform platform = TargetPlatform.windows}) {
  final config = testConfig.copyWith(continuousCorners: continuous);
  return FrostScope(
    config: config,
    child: MaterialApp(
      theme: FrostTheme.build(config: config, brightness: brightness, platform: platform, locale: const Locale('en')),
      builder: (_, child) => FrostToastHost(child: child!),
      home: const Scaffold(body: SizedBox()),
    ),
  );
}

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final error in [false, true]) {
      testWidgets('result detail and action are shared and run once $platform $error', (tester) async {
        await tester.pumpWidget(app(brightness: Brightness.light, continuous: true, platform: platform));
        var called = 0;
        void action() => called++;
        if (error) {
          FrostToast.error('Failed', description: '#42 · timed out', actionLabel: 'Retry', onAction: action);
        } else {
          FrostToast.success('Added', description: '#42', actionLabel: 'View', onAction: action);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        final title = find.text(error ? 'Failed' : 'Added');
        final detail = find.text(error ? '#42 · timed out' : '#42');
        final button = find.widgetWithText(FrostButton, error ? 'Retry' : 'View');
        expect(title, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(detail);
        final context = tester.element(detail);
        expect(paragraph.text.style!.color, FrostThemeTokens.of(context).textSecondaryGlass);
        expect(paragraph.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.footnote).fontSize);
        if (platform == TargetPlatform.windows) {
          expect(tester.getCenter(button).dx, greaterThan(tester.getRect(title).right));
          expect(tester.getCenter(button).dy, lessThan(tester.getRect(detail).bottom));
        }
        final callback = tester.widget<FrostButton>(button).onPressed!;
        callback();
        callback();
        expect(called, 1);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text(error ? 'Failed' : 'Added'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('result actions require label and callback together', () {
    expect(() => FrostToast.success('Added', actionLabel: 'View'), throwsAssertionError);
    expect(() => FrostToast.error('Failed', onAction: () {}), throwsAssertionError);
  });
  for (final brightness in Brightness.values) {
    for (final continuous in [true, false]) {
      for (final kind in FrostToastKind.values) {
        testWidgets('desktop toast actual typography/ink/shape $brightness $continuous $kind', (tester) async {
          await tester.pumpWidget(app(brightness: brightness, continuous: continuous));
          show(kind);
          await tester.pump();
          await tester.pumpAndSettle();
          final context = tester.element(find.text('Message'));
          final role = FrostTypography.of(context).style(FrostTextRole.callout);
          final paragraph = tester.renderObject<RenderParagraph>(find.text('Message'));
          expect(paragraph.text.style!.fontSize, role.fontSize);
          expect(paragraph.text.style!.height, role.height);
          expect(paragraph.text.style!.fontWeight, role.fontWeight);
          final tokens = FrostThemeTokens.of(context);
          final expected = switch (kind) {
            FrostToastKind.success => tokens.positiveInk,
            FrostToastKind.info => tokens.infoInk,
            FrostToastKind.warning => tokens.cautionInk,
            FrostToastKind.error => tokens.negativeInk,
          };
          final glyph = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ToastGlyph');
          if (kind == FrostToastKind.info) {
            expect(tester.widget<FrostIcon>(find.descendant(of: glyph, matching: find.byType(FrostIcon))).color, expected);
          } else {
            final paint = tester.widget<CustomPaint>(find.descendant(of: glyph, matching: find.byType(CustomPaint)));
            final painter = paint.painter! as FrostStatusGlyphPainter;
            expect(painter.color, expected);
            expect(painter.progress, 1);
            expect(painter.kind, switch (kind) {
              FrostToastKind.success => FrostStatusGlyphKind.success,
              FrostToastKind.warning => FrostStatusGlyphKind.warning,
              _ => FrostStatusGlyphKind.failure,
            });
          }
          final surface = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.overlay);
          final decoration =
              tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: surface, matching: find.byType(DecoratedBox))).first.decoration
                  as ShapeDecoration;
          final shape = decoration.shape;
          expect(shape, continuous ? isA<RoundedSuperellipseBorder>() : isA<RoundedRectangleBorder>());
          final radius = switch (shape) {
            RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
            RoundedRectangleBorder(:final borderRadius) => borderRadius,
            _ => throw StateError('$shape'),
          };
          expect(radius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.xl);
          expect(find.descendant(of: surface, matching: find.byType(ClipRSuperellipse)), continuous ? findsOneWidget : findsNothing);
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final continuous in [true, false]) {
    testWidgets('touch capsule retains capsule geometry and curvature $continuous', (tester) async {
      await tester.pumpWidget(app(brightness: Brightness.light, continuous: continuous, platform: TargetPlatform.android));
      FrostToast.info('Message');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Message'));
      final role = FrostTypography.of(tester.element(find.text('Message'))).style(FrostTextRole.callout);
      expect(paragraph.text.style!.fontSize, role.fontSize);
      expect(paragraph.text.style!.fontWeight, role.fontWeight);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CapsuleLayer'), findsOneWidget);
      final surface = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.overlay);
      final decoration =
          tester.renderObjectList<RenderDecoratedBox>(find.descendant(of: surface, matching: find.byType(DecoratedBox))).first.decoration as ShapeDecoration;
      expect(decoration.shape, continuous ? isA<RoundedSuperellipseBorder>() : isA<RoundedRectangleBorder>());
      final radius = switch (decoration.shape) {
        RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
        RoundedRectangleBorder(:final borderRadius) => borderRadius,
        _ => throw StateError('shape'),
      };
      expect(radius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.full(44));
      expect(find.descendant(of: surface, matching: find.byType(ClipRSuperellipse)), continuous ? findsOneWidget : findsNothing);
      expect(find.descendant(of: surface, matching: find.byType(ClipRRect)), continuous ? findsNothing : findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
