import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_glass_material.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/surface/_window_background.dart';

import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

List<Object> corners(WidgetTester tester, Finder owner) {
  final result = <Object>[];
  for (final element
      in find.descendant(of: owner, matching: find.byWidgetPredicate((w) => w is ClipPath || w is ClipRRect || w is ClipRSuperellipse)).evaluate()) {
    final w = element.widget;
    if (w is ClipPath && w.clipBehavior != Clip.none && w.clipper is ShapeBorderClipper) {
      final clipper = w.clipper! as ShapeBorderClipper;
      expect(w.clipBehavior, Clip.antiAlias);
      result.add(clipper.shape);
    } else if (w is ClipRRect) {
      expect(w.clipBehavior, Clip.antiAlias);
      result.add((ClipRRect, w.borderRadius));
    } else if (w is ClipRSuperellipse) {
      expect(w.clipBehavior, Clip.antiAlias);
      result.add((ClipRSuperellipse, w.borderRadius));
    }
  }
  return result;
}

void main() {
  for (final continuous in [true, false]) {
    final cases = <String, (Widget, bool)>{
      'row': (FrostListRow(title: 'Row', onPressed: () {}), false),
      'button': (FrostButton(label: 'Button', onPressed: () {}), false),
      'tag': (FrostTag(label: 'Tag', onPressed: () {}), false),
      'filter': (FrostFilterChip(label: 'Filter', onPressed: () {}), false),
      'segments': (
        FrostPicker<int>.segmented(
          label: 'Pick',
          options: const [
            FrostPickerOption(value: 1, label: 'One'),
            FrostPickerOption(value: 2, label: 'Two'),
          ],
          value: 1,
          onChanged: (_) {},
        ),
        false,
      ),
      'group ends': (
        FrostGroupedSection(
          children: [
            FrostListRow(title: 'First', onPressed: () {}),
            FrostListRow(title: 'Last', onPressed: () {}),
          ],
        ),
        false,
      ),
      'thumbnail': (
        FrostThumbnail(
          image: const ColoredBox(color: Colors.red),
          semanticLabel: 'Thumbnail',
          onPressed: () {},
        ),
        false,
      ),
      'module': (FrostModule(title: 'Module', value: '12', onPressed: () {}), true),
      'link': (FrostLinkCard(title: 'Link', url: Uri.parse('https://example.org'), onPressed: () {}), true),
      'media': (
        FrostMediaCard(
          media: const FrostMediaImage(child: ColoredBox(color: Colors.red)),
          aspectRatio: 2,
          onPressed: () {},
        ),
        true,
      ),
      'mosaic': (FrostMediaMosaic(images: const [AssetImage('missing')], onPressed: (_) {}), false),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key} preserves rounded clips while pressed; continuous=$continuous', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            FrostScope(
              config: testConfig.copyWith(continuousCorners: continuous),
              child: Center(child: SizedBox(width: 280, child: entry.value.$1)),
            ),
          ),
        );
        final owner = find.byWidget(entry.value.$1);
        final shape = corners(tester, owner);
        expect(shape, isNotEmpty);
        final hit = find.descendant(of: owner, matching: find.byType(FrostClickSurface)).first;
        final press = await tester.startGesture(tester.getCenter(hit));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(corners(tester, owner), shape);
        final scales = tester
            .renderObjectList<RenderTransform>(
              find.descendant(of: owner, matching: find.byElementPredicate((e) => e is RenderObjectElement && e.renderObject is RenderTransform)),
            )
            .where((r) => r.child!.getTransformTo(r).entry(0, 0) < 1);
        expect(scales.isNotEmpty, entry.value.$2);
        await tester.pump(const Duration(milliseconds: 700));
        expect(corners(tester, owner), shape);
        await press.cancel();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('pressed and long held rows never transform or cover physical dividers', (tester) async {
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 320,
            child: FrostGroupedSection(
              children: [
                FrostListRow(title: 'First', onPressed: () {}),
                FrostListRow(title: 'Last', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    final divider = find.byType(FrostDivider).first;
    final before = tester.getRect(divider);
    expect(before.height, closeTo(1 / 1.5, .001));
    final press = await tester.startGesture(tester.getCenter(find.text('First')));
    for (final ms in [70, 800]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(tester.getRect(divider), before);
      expect(find.ancestor(of: divider, matching: find.byType(FrostClickSurface)), findsNothing);
      expect(tester.widgetList<Transform>(find.ancestor(of: divider, matching: find.byType(Transform))).where((w) => !w.transform.isIdentity()), isEmpty);
    }
    await press.cancel();
  });
  test('static glass and semantic ink meet worst-backdrop contrast for all palettes', () {
    // An app palette may require a fully opaque fill. Its filter contribution
    // is zero even at progress one, where the general expression is 0/0.
    for (final progress in [0.0, .5, 1.0]) {
      expect(frostGlassFilterOpacity(progress, 1), 0);
    }
    for (final accent in FrostPalettes.pink.accentPresets) {
      final palettes = FrostPalettes.pink;
      for (final brightness in Brightness.values) {
        for (final tone in FrostTone.values) {
          final t = palettes.palette(brightness, tone, accent);
          for (final surface in [t.surface, t.surfaceRaised]) {
            final alpha = frostGlassFillOpacity(surface, t.textPrimary, t.isDark);
            expect(alpha, lessThan(t.isDark ? .92 : .88));
            final worst = t.isDark ? Colors.white : Colors.black;
            final background = Color.alphaBlend(surface.withValues(alpha: alpha), worst);
            expect(colorContrast(t.textPrimary, background), greaterThanOrEqualTo(4.5));
            if (surface == t.surfaceRaised) {
              expect(colorContrast(Color.alphaBlend(t.textSecondaryGlass, background), background), greaterThanOrEqualTo(4.5));
              expect(colorContrast(Color.alphaBlend(t.textTertiaryGlass, background), background), greaterThanOrEqualTo(3));
            }
            for (final p in [.0, .25, .5, .95, 1.0]) {
              final q = frostGlassFilterOpacity(p, alpha);
              expect((1 - alpha * p) * q, closeTo(p * (1 - alpha), 1e-10));
              expect((1 - alpha * p) * (1 - q), closeTo(1 - p, 1e-10));
            }
          }
        }
      }
    }
  });
  testWidgets('actual backdrop pixels reveal the static glass as one material', (tester) async {
    final boundary = GlobalKey();
    var p = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 120,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    children: [
                      for (final color in [Colors.red, Colors.blue, Colors.green, Colors.orange]) Expanded(child: ColoredBox(color: color)),
                    ],
                  ),
                  StatefulBuilder(
                    builder: (_, set) {
                      update = set;
                      return FrostMaterialReveal(
                        opacity: p,
                        child: const FrostSurface(
                          role: FrostSurfaceRole.overlay,
                          borderRadius: BorderRadius.zero,
                          edge: FrostSurfaceEdge.none,
                          elevated: false,
                          child: SizedBox.expand(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Future<List<int>> sample() async {
      final image = await tester.runAsync(() => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage());
      final data = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final bytes = data.buffer.asUint8List();
      final result = <int>[];
      for (final x in [24, 36, 54, 66, 84]) {
        final at = (50 * 120 + x) * 4;
        result.addAll(bytes.sublist(at, at + 3));
      }
      image!.dispose();
      return result;
    }

    final behind = await sample();
    update(() => p = 1);
    await tester.pump();
    final full = await sample();
    expect(full, isNot(behind));
    for (final progress in [.25, .5, .95]) {
      update(() => p = progress);
      await tester.pump();
      final actual = await sample();
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], closeTo(behind[i] * (1 - progress) + full[i] * progress, 3), reason: 'fixed blur and saturation should fade with the fill');
      }
    }
  });
  testWidgets('window base, content and cards switch on actual backdrop and solid preference', (tester) async {
    for (final dark in [false, true]) {
      for (final active in [false, true]) {
        for (final solid in [false, true]) {
          await tester.pumpWidget(
            frostTestApp(
              FrostWindowCaptionScope(
                systemBackdropActive: active,
                child: const FrostSurface(
                  role: FrostSurfaceRole.base,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FrostSurface(role: FrostSurfaceRole.panel, child: Text('Page')),
                      FrostSurface(role: FrostSurfaceRole.module, child: Text('Card')),
                      FrostSurface(role: FrostSurfaceRole.sheet, child: Text('Sheet')),
                    ],
                  ),
                ),
              ),
              brightness: dark ? Brightness.dark : Brightness.light,
              reduceTransparency: solid,
            ),
          );
          await tester.pumpAndSettle();
          Color fillFor(String text) {
            final owner = find.ancestor(of: find.text(text), matching: find.byType(FrostSurface)).first;
            return tester
                .widgetList<DecoratedBox>(find.descendant(of: owner, matching: find.byType(DecoratedBox)))
                .map((w) => w.decoration)
                .whereType<ShapeDecoration>()
                .firstWhere((d) => d.color != null)
                .color!;
          }

          expect(fillFor('Page').a, active && !solid ? (dark ? 76 / 255 : 128 / 255) : 1);
          expect(fillFor('Card').a, active && !solid ? (dark ? 13 / 255 : 179 / 255) : 1);
          expect(fillFor('Sheet').a, 1);
          expect(find.byType(BackdropFilter), findsNothing);
        }
      }
    }
  });
  testWidgets('editors and field pickers paint opaque fills over a translucent window base', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        frostTestApp(
          FrostWindowCaptionScope(
            systemBackdropActive: true,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  const FrostTextField(label: 'Input'),
                  FrostTimePicker(value: const TimeOfDay(hour: 14, minute: 20), onChanged: (_) {}, label: 'Time'),
                  FrostPicker<int>.menu(
                    label: 'Value',
                    value: 1,
                    options: const [FrostPickerOption(value: 1, label: 'One')],
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      for (final owner in [find.byType(FrostTextField), find.byType(FrostTimePicker), find.byType(FrostPicker<int>)]) {
        final colors = tester
            .widgetList<DecoratedBox>(find.descendant(of: owner, matching: find.byType(DecoratedBox)))
            .map((w) => w.decoration)
            .whereType<ShapeDecoration>()
            .map((d) => d.color)
            .nonNulls;
        expect(colors.first.a, 1);
      }
      expect(find.byType(BackdropFilter), findsNothing);
    }
  });
  testWidgets('fields and inline counts ignore page storage on their first frame', (tester) async {
    final token = FrostTokenEditingController(text: '#done');
    final plain = TextEditingController(text: '12');
    addTearDown(token.dispose);
    addTearDown(plain.dispose);
    final children = [
      FrostTextField(controller: plain),
      FrostNumberField(value: 12, onChanged: (_) {}),
      FrostTokenField(controller: token),
      const FrostStatStrip(
        stats: [
          FrostStat(value: '120', caption: 'Count'),
          FrostStat(value: '240', caption: 'Total'),
        ],
      ),
      FrostSlider(value: .5, valueLabel: (_) => '50', onChanged: (_) {}, semanticLabel: 'Value'),
      FrostActionCount(icon: testIcons.add, selectedIcon: testIcons.add, selected: false, count: 120, onChanged: (_) {}, label: 'Likes'),
    ];
    for (final child in children) {
      await tester.pumpWidget(const SizedBox());
      final bucket = PageStorageBucket();
      late BuildContext carrier;
      Widget page(Widget content) => PageStorage(
        bucket: bucket,
        child: Padding(
          key: const PageStorageKey('page'),
          padding: EdgeInsets.zero,
          child: Builder(
            builder: (context) {
              carrier = context;
              return content;
            },
          ),
        ),
      );
      await tester.pumpWidget(frostTestApp(page(const SizedBox())));
      bucket.writeState(carrier, 600.0);
      await tester.pumpWidget(
        frostTestApp(
          page(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 320, child: child),
            ),
          ),
        ),
      );
      for (final element in find.byType(Scrollable).evaluate()) {
        expect((element as StatefulElement).state, isA<ScrollableState>());
        expect((element.state as ScrollableState).position.pixels, 0);
      }
      for (final slide in tester.widgetList<SlideTransition>(find.byType(SlideTransition))) {
        expect(slide.position.value, Offset.zero);
      }
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('surface edges and highlights are physical hairlines at fractional DPR', (tester) async {
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final role in [FrostSurfaceRole.overlay, FrostSurfaceRole.chrome, FrostSurfaceRole.glassPanel]) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostSurface(role: role, child: const SizedBox(width: 160, height: 80)),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      for (final decoration in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((w) => w.decoration).whereType<ShapeDecoration>()) {
        final shape = decoration.shape;
        if (shape is OutlinedBorder && shape.side.style != BorderStyle.none) {
          expect(shape.side.width, closeTo(1 / 1.5, .0001));
          expect(shape.side.strokeAlign, BorderSide.strokeAlignInside);
        }
      }
    }
  });
  testWidgets('ambient host selects artwork then Mica or solid without changing its API', (tester) async {
    final image = ControlledImage();
    var translucent = false;
    Widget tree(ImageProvider? provider, bool mica) => frostTestApp(
      Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: FrostWindowCaptionScope(
            systemBackdropActive: mica,
            child: FrostAmbientBackdropHost(
              image: provider,
              child: Builder(
                builder: (context) {
                  translucent = frostHasTranslucentWindowBase(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(null, false));
    expect(translucent, false);
    await tester.pumpWidget(tree(null, true));
    expect(translucent, true);
    await tester.pumpWidget(tree(image, false));
    expect(translucent, false);
    final pixels = (await tester.runAsync(() => createTestImage(width: 8, height: 8)))!;
    image.completer.complete(ImageInfo(image: pixels));
    for (var i = 0; i < 10 && !translucent; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(translucent, true);
    await tester.pumpWidget(tree(null, false));
    await tester.pumpAndSettle();
    expect(translucent, false);
    final failed = ControlledImage();
    await tester.pumpWidget(tree(failed, true));
    failed.completer.fail(StateError('unavailable artwork'));
    await tester.pumpAndSettle();
    expect(translucent, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rolling values mount in final positions and only animate later changes', (tester) async {
    var value = '120';
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostRollingText(value);
          },
        ),
      ),
    );
    for (final slide in tester.widgetList<SlideTransition>(find.byType(SlideTransition))) {
      expect(slide.position.value, Offset.zero);
    }
    for (final text in ['1', '2', '0']) {
      expect(find.text(text), findsOneWidget);
    }
    update(() => value = '121');
    await tester.pump();
    expect(tester.widgetList<SlideTransition>(find.byType(SlideTransition)).any((w) => w.position.value != Offset.zero), true);
    await tester.pumpAndSettle();
  });
}
