import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'shell_v2_test.dart' show shell;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  testWidgets('header stays 52 or 48 through collapse, menus and picker selection', (tester) async {
    addTearDown(tester.view.reset);
    for (final windowWidth in [1600.0, 400.0]) {
      tester.view.physicalSize = Size(windowWidth, 900);
      tester.view.devicePixelRatio = 1;
      final width = ValueNotifier(windowWidth), selection = ValueNotifier(0);
      final search = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: ListenableBuilder(
              listenable: Listenable.merge([width, selection]),
              builder: (context, _) => SizedBox(
                width: width.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrostPageHeader(
                      title: FrostTitleMenu(
                        title: 'Source',
                        entries: [FrostMenuAction('Other source', onSelected: () {})],
                      ),
                      onBack: () {},
                      middle: FrostSearchInput(controller: search, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
                      collapsedMiddle: const Icon(Icons.search),
                      actions: [
                        FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh collection', showsLabel: true, onPressed: () {}),
                        FrostToolbarItem.picker(
                          choices: const [
                            FrostPickerOption(value: 0, label: 'Latest'),
                            FrostPickerOption(value: 1, label: 'Popular'),
                          ],
                          value: selection.value,
                          onChanged: (v) => selection.value = v,
                          label: 'Mode',
                        ),
                        FrostToolbarItem.menu(
                          label: 'Period',
                          entries: [FrostMenuAction('Week', onSelected: () {})],
                        ),
                        FrostToolbarItem.action(icon: testIcons.add, label: 'High', priority: FrostToolbarPriority.high, onPressed: () {}),
                      ],
                    ),
                    const Text('Body'),
                  ],
                ),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final expected = windowWidth >= 600 ? 52.0 : 48.0;
      for (final w in [windowWidth, 900.0, 650.0, 400.0, 250.0, 120.0, windowWidth]) {
        width.value = w.clamp(0, windowWidth).toDouble();
        await tester.pump();
        expect(tester.getSize(find.byType(FrostPageHeader)).height, expected);
        expect(tester.getTopLeft(find.text('Body')).dy, tester.getBottomLeft(find.byType(FrostPageHeader)).dy);
        expect(find.byType(AppBar), findsNothing);
        expect(tester.takeException(), isNull);
      }
      if (windowWidth >= 600) {
        await tester.tap(find.text('Source').hitTestable());
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(FrostPageHeader)).height, expected);
        await tester.tap(find.text('Other source').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Popular').hitTestable());
        await tester.pumpAndSettle();
        expect(selection.value, 1);
        expect(tester.getSize(find.byType(FrostPageHeader)).height, expected);
      }
      await tester.pumpWidget(const SizedBox());
      width.dispose();
      selection.dispose();
      search.dispose();
      focus.dispose();
    }
  });

  testWidgets('large text grows the header and live labels stay inside it', (tester) async {
    addTearDown(tester.view.reset);
    final search = TextEditingController();
    final focus = FocusNode();
    addTearDown(search.dispose);
    addTearDown(focus.dispose);
    for (final width in [1400.0, 400.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      for (final scale in [1.0, 1.3, 2.0]) {
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: FrostPageHeader(
                    title: const Text('Heading'),
                    onBack: () {},
                    middle: FrostSearchInput(controller: search, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
                    collapsedMiddle: const Icon(Icons.search),
                    actions: [
                      FrostToolbarItem.action(icon: testIcons.add, label: 'Add', showsLabel: true, priority: FrostToolbarPriority.high, onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        final rect = tester.getRect(find.byType(FrostPageHeader));
        expect(rect.height, scale <= 1.3 ? (width >= 600 ? 52 : 48) : greaterThan(width >= 600 ? 52 : 48));
        for (final element in find.descendant(of: find.byType(FrostPageHeader), matching: find.byType(RichText)).hitTestable().evaluate()) {
          final box = element.findRenderObject()! as RenderBox;
          final textRect = box.localToGlobal(Offset.zero) & box.size;
          expect(textRect.top, greaterThanOrEqualTo(rect.top));
          expect(textRect.bottom, lessThanOrEqualTo(rect.bottom));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('back and trailing graphics align to keylines including compact edge snap', (tester) async {
    addTearDown(tester.view.reset);
    for (final width in [1400.0, 400.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostPageHeader(
              title: const Text('Title'),
              onBack: () {},
              actions: [FrostToolbarItem.action(icon: testIcons.add, label: 'Last', onPressed: () {})],
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final header = tester.getRect(find.byType(FrostPageHeader));
      final inset = FrostGap.of(tester.element(find.byType(FrostPageHeader))).page;
      final back = find.descendant(of: find.byType(FrostCompactBackButton), matching: find.byType(FrostIcon));
      final last = find.descendant(of: findFrostTooltip('Last').hitTestable(), matching: find.byType(FrostIcon));
      expect(tester.getTopLeft(back).dx, header.left + inset);
      expect(tester.getTopRight(last).dx, header.right - inset);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('capsule material is 0.6, 0.8, 1 while its content stays opaque; solid is always 1', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey(), contentKey = GlobalKey();
    const color = Color(0xffcc2244);
    for (final solid in [false, true]) {
      for (final coverage in [0.0, 0.5, 1.0]) {
        final panel = FrostPinnedChromeGlass(
          opacity: coverage,
          animate: false,
          child: SizedBox(
            key: contentKey,
            height: 52,
            child: const ColoredBox(color: color),
          ),
        );
        final tree = shell(
          style: const FrostSidebarStyle.capsule(),
          child: Align(
            alignment: Alignment.topCenter,
            child: RepaintBoundary(
              key: key,
              child: SizedBox(width: 500, child: panel),
            ),
          ),
        );
        await tester.pumpWidget(frostTestApp(tree, reduceTransparency: solid));
        final glass = find.byType(FrostPinnedChromeGlass);
        expect(
          tester.widget<FrostMaterialReveal>(find.descendant(of: glass, matching: find.byType(FrostMaterialReveal)).first).opacity,
          solid ? 1 : 0.6 + 0.4 * coverage,
        );
        final opacities = <double>[];
        contentKey.currentContext!.visitAncestorElements((element) {
          if (element.findRenderObject() case RenderOpacity(:final opacity) || RenderFrostContentFade(:final opacity)) opacities.add(opacity);
          return true;
        });
        expect(opacities.every((value) => value == 1), true);
        final sampled = await tester.runAsync(() async {
          final box = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          final image = await box.toImage();
          final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final point = (contentKey.currentContext!.findRenderObject()! as RenderBox).localToGlobal(const Offset(50, 20));
          final local = box.globalToLocal(point);
          final offset = (local.dy.round() * image.width + local.dx.round()) * 4;
          final result = Color.fromARGB(data.getUint8(offset + 3), data.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2));
          image.dispose();
          return result;
        });
        expect(sampled, color);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('capsule header shares sidebar top and window right inset with exact first-frame body extent', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final caption in [false, true]) {
      final window = FakeWindow();
      await tester.pumpWidget(
        frostTestApp(
          FrostWindowCaptionScope(
            window: caption ? window : null,
            child: shell(
              style: const FrostSidebarStyle.capsule(),
              child: FrostPinnedChrome(
                chrome: const FrostPageHeader(title: Text('Heading')),
                body: CustomScrollView(
                  slivers: const [
                    FrostChromeSpacer(),
                    SliverToBoxAdapter(child: Text('First body')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final panels = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.chrome);
      final panel = panels.evaluate().map((e) => tester.getRect(find.byElementPredicate((v) => v == e))).where((r) => r.width > 300).single;
      expect(panel.top, caption ? 48 : 8);
      expect(panel.right, 1392);
      expect(panel.height, 52);
      expect(tester.getTopLeft(find.text('First body')).dy, panel.bottom + 8);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      window.dispose();
    }
  });
}
