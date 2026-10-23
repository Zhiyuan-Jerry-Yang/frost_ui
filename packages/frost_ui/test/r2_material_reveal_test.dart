import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

const revealKey = ValueKey('test reveal');
const outerKey = ValueKey('outer surface');
const innerKey = ValueKey('nested surface');

int expectSafeLayers(WidgetTester tester) {
  var samplers = 0;
  void visit(Layer layer, List<Layer> ancestors) {
    if (layer is BackdropFilterLayer) {
      samplers++;
      expect(ancestors.where((l) => l is OpacityLayer || l is ShaderMaskLayer || l is ColorFilterLayer), isEmpty);
    }
    if (layer is ContainerLayer) {
      for (Layer? child = layer.firstChild; child != null; child = child.nextSibling) {
        visit(child, [...ancestors, layer]);
      }
    }
  }

  final root = tester.binding.renderViews.first.debugLayer;
  expect(root, isNotNull);
  visit(root!, []);
  return samplers;
}

BackdropFilter filter(WidgetTester tester, Key key) =>
    tester.widget<BackdropFilter>(find.descendant(of: find.byKey(key), matching: find.byType(BackdropFilter)).first);

({Color fill, BorderSide edge, List<BoxShadow> shadows}) parameters(WidgetTester tester, Key key) {
  final decorations = tester
      .widgetList<DecoratedBox>(find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox)))
      .map((w) => w.decoration)
      .whereType<ShapeDecoration>();
  final material = decorations.firstWhere((d) => d.color != null);
  return (fill: material.color!, edge: (material.shape as OutlinedBorder).side, shadows: decorations.firstWhere((d) => d.shadows != null).shadows!);
}

void main() {
  for (final contentOnly in [false, true]) {
    for (final solid in [false, true]) {
      testWidgets('actual layers remain safe in both directions, contentOnly=$contentOnly solid=$solid', (tester) async {
        var progress = 0.0;
        late StateSetter update;
        final handle = FrostRevealHandle();
        Widget content() => const FrostSurface(
          key: outerKey,
          role: FrostSurfaceRole.overlay,
          child: SizedBox(
            width: 200,
            height: 100,
            child: FrostSurface(key: innerKey, role: FrostSurfaceRole.chrome, child: FrostText('Nested content')),
          ),
        );
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: FrostMaterialReveal(key: revealKey, opacity: progress, contentOnly: contentOnly, handle: handle, child: content()),
                );
              },
            ),
            reduceTransparency: solid,
          ),
        );
        for (final p in [0.0, .25, .5, .95, 1.0]) {
          update(() => progress = p);
          await tester.pump();
          expectSafeLayers(tester);
          expect(filter(tester, innerKey).enabled, isFalse);
          expect(filter(tester, innerKey).filter, ui.ImageFilter.blur());
          final fade = tester.renderObject<RenderFrostContentFade>(find.descendant(of: find.byKey(revealKey), matching: find.byType(FrostContentFade)).first);
          expect(fade.opacity, p);
          expect(filter(tester, outerKey).enabled, !solid && !contentOnly && p > 0);
        }
        await tester.pump(frostNestedGlassDuration ~/ 2);
        if (!solid) {
          expect(handle.nestedProgress, greaterThan(0));
          expect(handle.nestedProgress, lessThan(1));
        }
        expectSafeLayers(tester);
        await tester.pump(frostNestedGlassDuration);
        expect(filter(tester, innerKey).enabled, !solid);
        expectSafeLayers(tester);

        var prepared = false;
        handle.prepareClose().then((ready) => prepared = ready);
        await tester.pump();
        if (!solid) {
          expect(prepared, isFalse);
          await tester.pump(frostNestedGlassDuration ~/ 2);
          expect(handle.nestedProgress, inExclusiveRange(0, 1));
          expect(
            tester.renderObject<RenderFrostContentFade>(find.descendant(of: find.byKey(revealKey), matching: find.byType(FrostContentFade)).first).opacity,
            1,
          );
          expectSafeLayers(tester);
        }
        await tester.pump(frostNestedGlassDuration);
        expect(prepared, isTrue);
        for (final p in [.95, .5, .25, 0.0]) {
          update(() => progress = p);
          await tester.pump();
          expect(filter(tester, innerKey).enabled, isFalse);
          expectSafeLayers(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('outer material is monotone and its full parameters equal static material', (tester) async {
    var progress = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: FrostMaterialReveal(
                key: revealKey,
                opacity: progress,
                child: const FrostSurface(key: outerKey, role: FrostSurfaceRole.overlay, child: SizedBox(width: 120, height: 80)),
              ),
            );
          },
        ),
      ),
    );
    var fill = 0.0, edge = 0.0;
    for (final p in [0.0, .25, .5, .95, 1.0]) {
      update(() => progress = p);
      await tester.pump();
      final actual = parameters(tester, outerKey);
      expect(actual.fill.a, greaterThanOrEqualTo(fill));
      expect(actual.edge.color.a, greaterThanOrEqualTo(edge));
      expect(
        filter(tester, outerKey).filter,
        frostGlassFilter(
          sigma: 24,
          opacity: frostGlassFilterOpacity(
            p,
            frostGlassFillOpacity(
              FrostThemeTokens.of(tester.element(find.byKey(outerKey))).surfaceRaised,
              FrostThemeTokens.of(tester.element(find.byKey(outerKey))).textPrimary,
              false,
            ),
          ),
        ),
      );
      fill = actual.fill.a;
      edge = actual.edge.color.a;
      expectSafeLayers(tester);
    }
    final revealed = parameters(tester, outerKey);
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: FrostSurface(key: outerKey, role: FrostSurfaceRole.overlay, child: SizedBox(width: 120, height: 80)),
        ),
      ),
    );
    final staticMaterial = parameters(tester, outerKey);
    expect(staticMaterial.fill, revealed.fill);
    expect(staticMaterial.edge, revealed.edge);
    expect(staticMaterial.shadows, revealed.shadows);
  });

  testWidgets('deferred glass keeps semantic ink and arbitrary child state at the boundary', (tester) async {
    var progress = .5;
    late StateSetter update;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final editing = TextEditingController(text: 'State stays');
    addTearDown(editing.dispose);
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: FrostMaterialReveal(
                key: revealKey,
                opacity: progress,
                child: FrostSurface(
                  key: outerKey,
                  role: FrostSurfaceRole.overlay,
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FrostSurface(
                          key: innerKey,
                          role: FrostSurfaceRole.chrome,
                          child: Builder(
                            builder: (context) {
                              expect(FrostSurfaceScope.maybeOf(context)!.isGlass, isTrue);
                              return const FrostText('Stable ink', tone: FrostTextTone.secondary);
                            },
                          ),
                        ),
                        TextField(controller: editing, focusNode: focus),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final state = tester.state(find.byType(EditableText));
    final ink = tester.renderObject<RenderParagraph>(find.text('Stable ink')).text.style!.color;
    focus.requestFocus();
    await tester.pump();
    update(() => progress = 1);
    await tester.pump();
    await tester.pump(frostNestedGlassDuration);
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(tester.renderObject<RenderParagraph>(find.text('Stable ink')).text.style!.color, ink);
    expect(focus.hasFocus, isTrue);
    expect(editing.text, 'State stays');
    expectSafeLayers(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening cancels pending pre-close and disposal cancels safely', (tester) async {
    final handle = FrostRevealHandle();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostMaterialReveal(
            opacity: 1,
            handle: handle,
            contentOnly: true,
            child: const FrostSurface(key: innerKey, role: FrostSurfaceRole.chrome, child: SizedBox(width: 80, height: 40)),
          ),
        ),
      ),
    );
    final closing = handle.prepareClose();
    await tester.pump();
    await tester.pump(frostNestedGlassDuration ~/ 2);
    handle.cancelClose();
    expect(await closing, isFalse);
    await tester.pump(frostNestedGlassDuration);
    expectSafeLayers(tester);
    final disposing = handle.prepareClose();
    await tester.pumpWidget(const SizedBox());
    expect(await disposing, isFalse);
    expect(tester.takeException(), isNull);
  });
}
