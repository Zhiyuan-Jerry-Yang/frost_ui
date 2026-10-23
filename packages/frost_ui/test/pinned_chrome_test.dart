import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'shell_v2_test.dart' show shell;
import 'support.dart';

void main() {
  void viewport(WidgetTester tester, {Size size = const Size(390, 844), EdgeInsets safe = const EdgeInsets.only(top: 47, bottom: 34)}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(left: safe.left, top: safe.top, right: safe.right, bottom: safe.bottom);
    tester.view.viewPadding = FakeViewPadding(left: safe.left, top: safe.top, right: safe.right, bottom: safe.bottom);
    addTearDown(tester.view.reset);
  }

  Widget scrollingBody({ScrollController? controller, Key? first}) => CustomScrollView(
    controller: controller,
    slivers: [
      const FrostChromeSpacer(),
      SliverToBoxAdapter(child: SizedBox(key: first, height: 40)),
      const SliverToBoxAdapter(child: SizedBox(height: 2000)),
    ],
  );

  testWidgets('status safe area surrounds the 48 header and first-frame spacer; glass covers both', (tester) async {
    viewport(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    MediaQueryData? chromeMedia;
    const first = ValueKey('first');
    await tester.pumpWidget(
      frostTestApp(
        FrostPinnedChrome(
          chrome: Builder(
            builder: (context) {
              chromeMedia = MediaQuery.of(context);
              return const FrostPageHeader(title: Text('Title'));
            },
          ),
          body: scrollingBody(controller: scroll, first: first),
        ),
        platform: TargetPlatform.android,
      ),
    );
    final header = find.byType(FrostPageHeader);
    final glass = find.byType(FrostPinnedChromeGlass);
    expect(tester.getSize(header).height, 48);
    expect(tester.getTopLeft(header).dy, 47);
    expect(tester.getSize(glass).height, 95);
    expect(tester.getTopLeft(glass).dy, 0);
    expect(tester.getTopLeft(find.byKey(first)).dy, 95);
    expect(chromeMedia!.padding.top, 0);
    expect(chromeMedia!.viewPadding.top, 0);
    expect(chromeMedia!.padding.bottom, 34);
    final tokens = FrostThemeTokens.of(tester.element(glass));
    for (final (offset, opacity) in [(0.0, 0.0), (12.0, .5), (24.0, 1.0)]) {
      scroll.jumpTo(offset);
      await tester.pump();
      expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, opacity);
      final separator = find.descendant(
        of: glass,
        matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border is Border),
      );
      expect(separator, findsOneWidget);
      final border = (tester.widget<DecoratedBox>(separator).decoration as BoxDecoration).border! as Border;
      expect(border.top.style, BorderStyle.none);
      expect(border.bottom.color.a, closeTo(tokens.separator.a * opacity, 1e-6));
      expect(tester.getRect(separator).bottom, 95);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape insets protect both edges and chrome descendants consume them', (tester) async {
    viewport(tester, size: const Size(844, 390), safe: const EdgeInsets.fromLTRB(47, 0, 21, 21));
    EdgeInsets? remaining;
    const content = ValueKey('chrome content');
    await tester.pumpWidget(
      frostTestApp(
        FrostPinnedChrome(
          chrome: Builder(
            builder: (context) {
              remaining = MediaQuery.paddingOf(context);
              return const SizedBox(key: content, height: 48);
            },
          ),
          body: scrollingBody(),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(content)), const Rect.fromLTWH(47, 0, 776, 48));
    expect(remaining, const EdgeInsets.only(bottom: 21));
    expect(tester.getRect(find.byType(FrostPinnedChromeGlass)), const Rect.fromLTWH(0, 0, 844, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('outer SafeArea and nested pinned bars do not consume the reserved header height again', (tester) async {
    viewport(tester);
    const first = ValueKey('nested first');
    await tester.pumpWidget(
      frostTestApp(
        SafeArea(
          bottom: false,
          child: FrostPinnedChrome(
            chrome: const SizedBox(height: 48),
            body: FrostPinnedChrome(
              chrome: const SizedBox(height: 48),
              body: scrollingBody(first: first),
            ),
          ),
        ),
      ),
    );
    final bars = find.byType(FrostPinnedChromeGlass);
    expect(bars, findsNWidgets(2));
    for (final bar in bars.evaluate()) {
      expect(tester.getSize(find.byElementPredicate((e) => identical(e, bar))).height, 48);
    }
    expect(tester.getTopLeft(find.byKey(first)).dy, 95);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed extent includes the safe area; zero-inset desktop geometry stays 52', (tester) async {
    viewport(tester);
    const content = ValueKey('fixed content');
    Widget tree(double extent) => frostTestApp(
      FrostPinnedChrome(
        extent: extent,
        chrome: const SizedBox(key: content, height: 48),
        body: scrollingBody(),
      ),
    );
    await tester.pumpWidget(tree(95));
    expect(tester.getSize(find.byKey(content)).height, 48);
    expect(tester.getSize(find.byType(FrostPinnedChromeGlass)).height, 95);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.padding = const FakeViewPadding();
    tester.view.viewPadding = const FakeViewPadding();
    await tester.pumpWidget(
      frostTestApp(
        FrostPinnedChrome(
          chrome: const FrostPageHeader(title: Text('Title')),
          body: scrollingBody(),
        ),
      ),
    );
    expect(tester.getRect(find.byType(FrostPageHeader)), const Rect.fromLTWH(0, 0, 1440, 52));
    expect(tester.getRect(find.byType(FrostPinnedChromeGlass)), const Rect.fromLTWH(0, 0, 1440, 52));
    expect(tester.takeException(), isNull);
  });

  for (final sheet in [false, true]) {
    testWidgets('nested chrome in ${sheet ? 'Sheet' : 'Dialog'} does not add an already consumed status inset', (tester) async {
      viewport(tester);
      const inner = ValueKey('modal chrome');
      final content = SizedBox(
        height: 180,
        child: FrostPinnedChrome(
          chrome: const SizedBox(key: inner, height: 48),
          body: scrollingBody(),
        ),
      );
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => Center(
              child: FrostButton(
                label: 'Open',
                onPressed: () {
                  if (sheet) {
                    showFrostSheet<void>(context: context, detents: const [FrostSheetDetent.fitted], scrollable: false, builder: (_) => content);
                  } else {
                    showFrostDialog<void>(
                      context: context,
                      builder: (_) => FrostDialog(title: 'Dialog', scrollable: false, content: content),
                    );
                  }
                },
              ),
            ),
          ),
          platform: TargetPlatform.android,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostPinnedChromeGlass)).height, 48);
      expect(tester.getTopLeft(find.byKey(inner)), tester.getTopLeft(find.byType(FrostPinnedChromeGlass)));
      expect(MediaQuery.paddingOf(tester.element(find.byKey(inner))).top, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('band separator follows actual material progress at rest and half coverage', (tester) async {
    for (final progress in [0.0, .5, 1.0]) {
      await tester.pumpWidget(
        frostTestApp(
          shell(
            child: FrostPinnedChromeGlass(opacity: progress, animate: false, child: const SizedBox(height: 52)),
          ),
        ),
      );
      final glass = find.byType(FrostPinnedChromeGlass);
      final borders = find.descendant(
        of: glass,
        matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border is Border),
      );
      expect(borders, findsOneWidget);
      final border = (tester.widget<DecoratedBox>(borders).decoration as BoxDecoration).border! as Border;
      final tokens = FrostThemeTokens.of(tester.element(glass));
      expect(border.bottom.color.a, closeTo(tokens.separator.a * progress, 1e-6));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('pinned glass stays inside the sheet, transparent at rest with separator after scrolling', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        shell(
          style: const FrostSidebarStyle.inset(),
          child: FrostPinnedChrome(
            chrome: const SizedBox(height: 72),
            body: CustomScrollView(
              slivers: [
                const FrostChromeSpacer(),
                SliverList.builder(itemCount: 60, itemBuilder: (_, i) => SizedBox(height: 40, child: Text('item $i'))),
              ],
            ),
          ),
        ),
      ),
    );
    final glass = find.byType(FrostPinnedChromeGlass);
    expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, 0);
    expect(tester.getTopLeft(glass).dy, FrostGap.related);
    expect(find.ancestor(of: glass, matching: find.byWidgetPredicate((w) => w is ClipRRect || w is ClipRSuperellipse || w is ClipPath)), findsWidgets);
    await tester.drag(find.text('item 3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, 1);
    final tokens = FrostThemeTokens.of(tester.element(glass));
    expect(
      find.descendant(
        of: glass,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border == Border(bottom: BorderSide(color: tokens.separator)),
        ),
      ),
      findsOneWidget,
    );
  });
  testWidgets('measured chrome insets visible body in its first layout and on height changes', (tester) async {
    var top = 0.0;
    Widget tree(double height) => frostTestApp(
      FrostPinnedChrome(
        chrome: SizedBox(height: height),
        body: Builder(
          builder: (context) {
            top = MediaQuery.paddingOf(context).top;
            return CustomScrollView(
              slivers: [
                const FrostChromeSpacer(),
                const SliverToBoxAdapter(child: Text('first row')),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpWidget(tree(83));
    expect(top, 83);
    expect(tester.getTopLeft(find.text('first row')).dy, 83);
    expect(find.ancestor(of: find.text('first row'), matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0)), findsNothing);
    await tester.pumpWidget(tree(111));
    expect(top, 111);
    expect(tester.getTopLeft(find.text('first row')).dy, 111);
    expect(tester.takeException(), isNull);
  });
  testWidgets('wheel and drag over the pinned bar scroll the list beneath, and its controls still work', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var tapped = 0;
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: FrostPinnedChrome(
            extent: 56,
            // Like a scrollable tab bar, the row takes every pointer over the bar.
            chrome: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                TextButton(onPressed: () => tapped++, child: const Text('tab')),
                for (var i = 0; i < 20; i++) TextButton(onPressed: () {}, child: Text('tab $i')),
              ],
            ),
            body: CustomScrollView(
              controller: controller,
              slivers: [
                const FrostChromeSpacer(),
                SliverList.builder(itemCount: 100, itemBuilder: (context, index) => SizedBox(height: 40, child: Text('row $index'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final bar = tester.getTopLeft(find.byType(FrostPinnedChrome)) + const Offset(300, 28);

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(bar));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
    await tester.pump();
    expect(controller.offset, 120);

    await tester.dragFrom(bar, const Offset(0, -100), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThanOrEqualTo(200));

    await tester.tap(find.text('tab'));
    expect(tapped, 1);
  });
}
