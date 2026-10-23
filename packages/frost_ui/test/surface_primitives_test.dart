import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

List<ShapeDecoration> decorations(WidgetTester tester, Finder root) => tester
    .renderObjectList<RenderDecoratedBox>(find.descendant(of: root, matching: find.byType(DecoratedBox)))
    .map((box) => box.decoration)
    .whereType<ShapeDecoration>()
    .toList();

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('sheet and nested module render specified layers $brightness', (tester) async {
      late FrostThemeTokens tokens;
      late FrostSurfaceScope sheetScope, moduleScope;
      late FrostKeyline keyline;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return Center(
                child: FrostSurface(
                  key: const ValueKey('sheet'),
                  role: FrostSurfaceRole.sheet,
                  child: Builder(
                    builder: (context) {
                      sheetScope = FrostSurfaceScope.maybeOf(context)!;
                      keyline = FrostKeyline.maybeOf(context)!;
                      return FrostSurface(
                        key: const ValueKey('module'),
                        role: FrostSurfaceRole.module,
                        child: Builder(
                          builder: (context) {
                            moduleScope = FrostSurfaceScope.maybeOf(context)!;
                            return const SizedBox(width: 200, height: 100);
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          brightness: brightness,
        ),
      );
      final module = decorations(tester, find.byKey(const ValueKey('module')));
      final moduleFill = module.singleWhere((d) => d.color != null);
      final expected = Color.alphaBlend(tokens.fillSubtle, tokens.surface);
      expect(moduleFill.color, expected);
      expect(expected, isNot(tokens.surface));
      expect(moduleFill.shape, isA<RoundedSuperellipseBorder>());
      expect((moduleFill.shape as OutlinedBorder).side, BorderSide.none);
      expect(module.expand((d) => d.shadows ?? <BoxShadow>[]), isEmpty);
      expect(moduleScope.background, expected);
      expect(moduleScope.isGlass, false);
      final sheet = decorations(tester, find.byKey(const ValueKey('sheet')));
      final sheetFill = sheet.singleWhere((d) => d.color == tokens.surface);
      expect((sheetFill.shape as OutlinedBorder).side.color, tokens.edgeHairline);
      expect((sheetFill.shape as OutlinedBorder).side.width, 1 / tester.view.devicePixelRatio);
      expect(sheet.any((d) => d.shadows.toString() == [...tokens.shadowAmbient, ...tokens.shadowContact].toString()), true);
      expect(sheetScope.background, tokens.surface);
      expect(sheetScope.isGlass, false);
      expect(keyline.insideContainer, true);
      expect(keyline.leadingRoom, 0);
      expect(keyline.trailingRoom, 0);
      expect(keyline.contentStart, 0);
      if (brightness == Brightness.dark) {
        expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color == tokens.edgeHighlight), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all roles report actual composited surface and solid fallback', (tester) async {
    for (final brightness in Brightness.values) {
      for (final role in FrostSurfaceRole.values) {
        for (final solid in [false, true]) {
          late FrostSurfaceScope scope;
          late FrostThemeTokens tokens;
          await tester.pumpWidget(
            frostTestApp(
              Builder(
                builder: (context) {
                  tokens = FrostThemeTokens.of(context);
                  return Center(
                    child: FrostSurface(
                      role: role,
                      child: Builder(
                        builder: (context) {
                          scope = FrostSurfaceScope.maybeOf(context)!;
                          return const SizedBox(width: 80, height: 60);
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
          await tester.pumpAndSettle();
          expect(scope.background.a, 1);
          if (solid ||
              [FrostSurfaceRole.base, FrostSurfaceRole.sheet, FrostSurfaceRole.module, FrostSurfaceRole.reading, FrostSurfaceRole.panel].contains(role)) {
            expect(scope.isGlass, false);
          } else {
            expect(scope.isGlass, true);
          }
          if (role == FrostSurfaceRole.base) {
            expect(scope.background, tokens.isDark ? tokens.canvas : Color.alphaBlend(tokens.fillSubtle, tokens.canvas));
          }
          if (role == FrostSurfaceRole.glassPanel) {
            final fill = decorations(tester, find.byType(FrostSurface)).singleWhere((d) => d.color != null).color!;
            expect(scope.background, Color.alphaBlend(fill, tokens.canvas));
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('high contrast disables glass and base uses an existing ambient host', (tester) async {
    late FrostSurfaceScope scope;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: FrostSurface(
              role: FrostSurfaceRole.glassPanel,
              child: Builder(
                builder: (context) {
                  scope = FrostSurfaceScope.maybeOf(context)!;
                  return const SizedBox(width: 80, height: 60);
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(scope.isGlass, false);
    expect(scope.background.a, 1);
    await tester.pumpWidget(
      frostTestApp(
        const FrostAmbientBackdropHost(
          image: null,
          child: FrostSurface(role: FrostSurfaceRole.base, child: SizedBox(width: 80, height: 60)),
        ),
      ),
    );
    expect(find.descendant(of: find.byType(FrostSurface), matching: find.byType(FrostAmbientBackdrop)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
