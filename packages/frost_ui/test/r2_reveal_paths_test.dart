import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'r2_material_reveal_test.dart' show expectSafeLayers, filter, parameters, outerKey;
import 'support.dart';

const glassKey = ValueKey('path glass');
Widget glass() => const FrostSurface(
  key: glassKey,
  role: FrostSurfaceRole.chrome,
  child: SizedBox(width: 180, height: 60, child: FrostText('Glass content')),
);

void main() {
  testWidgets('external route defers opening blur and disables it on first reverse frame', (tester) async {
    late BuildContext origin;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            origin = context;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );
    final route = PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => Scaffold(body: Center(child: glass())),
      transitionsBuilder: (context, animation, secondary, child) => frostPageTransition(context, animation, secondary, child),
    );
    Navigator.of(origin).push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(filter(tester, glassKey).enabled, isFalse);
    expectSafeLayers(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(filter(tester, glassKey).enabled, isFalse);
    await tester.pump(const Duration(milliseconds: 70));
    expect(filter(tester, glassKey).enabled, isTrue);
    expectSafeLayers(tester);
    await tester.pumpAndSettle();
    Navigator.of(origin).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(filter(tester, glassKey).enabled, isFalse);
    expectSafeLayers(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(glassKey), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final role in [FrostSurfaceRole.overlay, FrostSurfaceRole.chrome, FrostSurfaceRole.glassPanel]) {
      testWidgets('all material alpha and sigma components match static $brightness $role', (tester) async {
        var progress = 0.0;
        late StateSetter update;
        Widget surface() => FrostSurface(key: outerKey, role: role, child: const SizedBox(width: 180, height: 60));
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Center(
                  child: FrostMaterialReveal(opacity: progress, child: surface()),
                );
              },
            ),
            brightness: brightness,
          ),
        );
        final strokes = <double, List<BorderSide>>{};
        final snapshots = <double, ({Color fill, BorderSide edge, List<BoxShadow> shadows})>{};
        for (final p in [0.0, .25, .5, .95, 1.0]) {
          update(() => progress = p);
          await tester.pump();
          snapshots[p] = parameters(tester, outerKey);
          strokes[p] = tester
              .widgetList<DecoratedBox>(find.descendant(of: find.byKey(outerKey), matching: find.byType(DecoratedBox)))
              .map((w) => w.decoration)
              .whereType<ShapeDecoration>()
              .map((d) => (d.shape as OutlinedBorder).side)
              .where((s) => s.style != BorderStyle.none)
              .toList();
          final sigma = (switch (role) {
            FrostSurfaceRole.overlay => 24.0,
            FrostSurfaceRole.chrome => 18.0,
            _ => 14.0,
          });
          expect(
            filter(tester, outerKey).filter,
            frostGlassFilter(
              sigma: sigma,
              opacity: frostGlassFilterOpacity(
                p,
                role == FrostSurfaceRole.chrome
                    ? frostNavigationGlassFillOpacity(
                        FrostThemeTokens.of(tester.element(find.byKey(outerKey))).surface,
                        frostGlassFillOpacity(
                          FrostThemeTokens.of(tester.element(find.byKey(outerKey))).surface,
                          FrostThemeTokens.of(tester.element(find.byKey(outerKey))).textPrimary,
                          brightness == Brightness.dark,
                        ),
                      )
                    : frostGlassFillOpacity(
                        FrostThemeTokens.of(tester.element(find.byKey(outerKey))).surfaceRaised,
                        FrostThemeTokens.of(tester.element(find.byKey(outerKey))).textPrimary,
                        brightness == Brightness.dark,
                      ),
              ),
            ),
          );
          expectSafeLayers(tester);
        }
        final full = snapshots[1]!;
        for (final entry in snapshots.entries) {
          expect(entry.value.fill.a, closeTo(full.fill.a * entry.key, 1e-8));
          if (full.edge.style != BorderStyle.none) expect(entry.value.edge.color.a, closeTo(full.edge.color.a * entry.key, 1e-8));
          expect(strokes[entry.key]!.length, strokes[1]!.length);
          for (var i = 0; i < strokes[1]!.length; i++) {
            expect(strokes[entry.key]![i].color.a, closeTo(strokes[1]![i].color.a * entry.key, 1e-8));
          }
          expect(entry.value.shadows.length, full.shadows.length);
          for (var i = 0; i < full.shadows.length; i++) {
            expect(entry.value.shadows[i].color.a, closeTo(full.shadows[i].color.a * entry.key, 1e-8));
          }
        }
        await tester.pumpWidget(frostTestApp(Center(child: surface()), brightness: brightness));
        final actual = parameters(tester, outerKey);
        expect(actual.fill, full.fill);
        expect(actual.edge, full.edge);
        expect(actual.shadows, full.shadows);
        expectSafeLayers(tester);
      });
    }
  }

  testWidgets('pinned chrome interpolates material without fading its content', (tester) async {
    var coverage = 0.0;
    late StateSetter update;
    const content = ValueKey('pinned content');
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Center(
              child: SizedBox(
                width: 400,
                child: FrostPinnedChromeGlass(
                  opacity: coverage,
                  animate: false,
                  child: const SizedBox(key: content, height: 52, child: FrostText('Header')),
                ),
              ),
            );
          },
        ),
      ),
    );
    for (final p in [0.0, .25, .5, .95, 1.0, .95, .5, .25, 0.0]) {
      update(() => coverage = p);
      await tester.pump();
      expectSafeLayers(tester);
      final fades = tester.renderObjectList<RenderFrostContentFade>(find.ancestor(of: find.byKey(content), matching: find.byType(FrostContentFade)));
      expect(fades.every((r) => r.opacity == 1), isTrue);
      final reveal = tester.widget<FrostMaterialReveal>(
        find.descendant(of: find.byType(FrostPinnedChromeGlass), matching: find.byType(FrostMaterialReveal)).first,
      );
      expect(reveal.opacity, p);
    }
  });

  testWidgets('Presence holds opacity for glass removal; reopening remains live', (tester) async {
    var shown = true;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Center(
              child: FrostPresence(visible: shown, child: glass()),
            );
          },
        ),
      ),
    );
    update(() => shown = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final fade = tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition));
    expect(fade.opacity.value, 1);
    expectSafeLayers(tester);
    update(() => shown = true);
    await tester.pumpAndSettle();
    expect(find.byKey(glassKey), findsOneWidget);
    expect(filter(tester, glassKey).enabled, isTrue);
    update(() => shown = false);
    await tester.pumpAndSettle();
    expect(find.byKey(glassKey), findsNothing);
    expectSafeLayers(tester);
  });

  testWidgets('layout crossfade with nested chrome remains safe during first layout and every tick', (tester) async {
    var identity = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Center(
              child: FrostLayoutCrossfade(layoutIdentity: identity, child: glass()),
            );
          },
        ),
      ),
    );
    update(() => identity++);
    await tester.pump();
    expectSafeLayers(tester);
    for (var i = 0; i < 32; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expectSafeLayers(tester);
    }
    expect(filter(tester, glassKey).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final solid in [false, true]) {
    testWidgets('owned dialog without active nested blur keeps original close duration solid=$solid', (tester) async {
      late BuildContext origin;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              origin = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
          reduceTransparency: solid,
        ),
      );
      showFrostDialog<void>(
        context: origin,
        builder: (_) => FrostDialog(title: 'Timing', content: solid ? glass() : const Text('Plain content')),
      );
      await tester.pumpAndSettle();
      Navigator.of(origin).pop();
      await tester.pump();
      await tester.pump(FrostMotion.dismiss + const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('Timing'), findsNothing);
      expectSafeLayers(tester);
    });
  }
}
