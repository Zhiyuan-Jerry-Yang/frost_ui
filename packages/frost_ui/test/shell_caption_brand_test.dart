import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _iconKey = ValueKey('brand-icon');
const _nameKey = ValueKey('brand-name');
const _pageKey = ValueKey('page');
const _brand = Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    SizedBox(key: _iconKey, width: 20, height: 20),
    SizedBox(width: 8),
    Flexible(
      child: FrostText('A long application brand name', key: _nameKey, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  ],
);

Widget _shell(
  FakeWindow? window, {
  bool expanded = false,
  TargetPlatform platform = TargetPlatform.windows,
  bool canGoBack = false,
  VoidCallback? onBack,
  FrostNavigationMetrics metrics = FrostNavigationMetrics.standard,
  TextDirection direction = TextDirection.ltr,
}) => frostTestApp(
  FrostWindowCaptionScope(
    window: window,
    child: Directionality(
      textDirection: direction,
      child: FrostShell(
        destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
        selectedIndex: 0,
        atDestinationRoot: true,
        canGoBack: canGoBack,
        onBack: onBack ?? () {},
        metrics: metrics,
        onDestinationSelected: (_) {},
        showsMobileNavigation: true,
        sidebarStyle: const FrostSidebarStyle.inset(),
        initiallyExpanded: expanded,
        brand: _brand,
        child: const FrostShellDestination(child: SizedBox.expand(key: _pageKey)),
      ),
    ),
  ),
  platform: platform,
);

void _expectVisibleBrand(WidgetTester tester) {
  final icon = tester.getRect(find.byKey(_iconKey));
  final name = tester.getRect(find.byKey(_nameKey));
  final buttons = tester.getRect(find.byType(FrostCaptionButtons));
  expect(icon.size, const Size(20, 20));
  expect(icon.top, greaterThanOrEqualTo(0));
  expect(icon.bottom, lessThanOrEqualTo(40));
  expect(name.width, greaterThan(0));
  expect(name.right, lessThanOrEqualTo(buttons.left));
  expect(icon.right, lessThan(name.left));
  expect(buttons.height, 40);
  RenderObject? node = tester.renderObject(find.byKey(_iconKey));
  while (node != null) {
    if (node is RenderOpacity) expect(node.opacity, 1);
    if (node is RenderAnimatedOpacity) expect(node.opacity.value, 1);
    node = node.parent;
  }
  expect(tester.takeException(), isNull);
}

void main() {
  const appMetrics = FrostNavigationMetrics(railWidth: 56, expandedWidth: 220, expandableMinWidth: 900, mobileMaxWidth: 600);
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android, TargetPlatform.iOS]) {
    for (final expanded in [false, true]) {
      testWidgets('sidebar header uses fixed Back and reveals brand platform=$platform expanded=$expanded', (tester) async {
        tester.view.physicalSize = const Size(1200, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final mac = platform == TargetPlatform.macOS;
        final window = mac ? FakeWindow() : null;
        if (window != null) {
          window.current = const FrostCaptionState(
            maximized: false,
            active: true,
            maximizeHovered: false,
            maximizePressed: false,
            failed: false,
            mode: FrostCaptionMode.nativeControls,
            leftButtons: [],
            rightButtons: [],
            nativeControls: Rect.fromLTRB(9, 9, 69, 23),
          );
        }
        var backCalls = 0;
        await tester.pumpWidget(_shell(window, platform: platform, expanded: expanded, metrics: appMetrics, canGoBack: true, onBack: () => backCalls++));
        final backFinder = find.byKey(const ValueKey('frost-shell-back'));
        final back = tester.getRect(backFinder);
        final sidebarLeft = tester.getRect(find.byKey(_pageKey)).left - (expanded ? appMetrics.expandedWidth : appMetrics.railWidth);
        expect(back.center.dx, closeTo(sidebarLeft + appMetrics.railWidth / 2, .01));
        final navigationIcon = find.descendant(of: find.byType(FrostNavItem).first, matching: find.byType(FrostIcon)).first;
        expect(tester.getCenter(navigationIcon).dx, closeTo(back.center.dx, .01));
        expect(back.top, greaterThanOrEqualTo(mac ? 28 : 0));
        expect(tester.getRect(find.byKey(_pageKey)).top, mac ? 28 : FrostGap.related);
        final brandFinder = find.byKey(_iconKey);
        if (expanded) {
          final brand = tester.getRect(brandFinder);
          expect(brand.left, greaterThan(back.right));
          expect(brand.center.dy, closeTo(back.center.dy, .01));
          expect(tester.element(brandFinder).findAncestorWidgetOfExactType<Opacity>()!.opacity, 1);
        } else {
          expect(tester.element(brandFinder).findAncestorWidgetOfExactType<Opacity>()!.opacity, 0);
        }
        await tester.tap(backFinder);
        expect(backCalls, 1);
        expect(find.byType(FrostCaptionButtons), findsNothing);
        if (mac) {
          expect(window!.calls.last, [const FrostHitRegion(rect: Rect.fromLTWH(0, 0, 1200, 28), kind: FrostHitKind.caption)]);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('sidebar header keeps Back stationary and brand text layout stable through expansion', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_shell(null, platform: TargetPlatform.android, metrics: appMetrics, canGoBack: true));
    final back = find.byKey(const ValueKey('frost-shell-back'));
    final before = tester.getRect(back);
    final textWidth = tester.getSize(find.byKey(_nameKey)).width;
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(back), before);
    expect(tester.getSize(find.byKey(_nameKey)).width, textWidth);
    await tester.pumpAndSettle();
    expect(tester.getRect(back), before);
    expect(tester.getSize(find.byKey(_nameKey)).width, textWidth);
    expect(tester.element(find.byKey(_iconKey)).findAncestorWidgetOfExactType<Opacity>()!.opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar header preserves physical icon axis in RTL and accommodates large text', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_shell(null, platform: TargetPlatform.android, metrics: appMetrics, expanded: true, direction: TextDirection.rtl));
    final back = tester.getRect(find.byKey(const ValueKey('frost-shell-back')));
    final brand = tester.getRect(find.byKey(_iconKey));
    expect(back.left, greaterThanOrEqualTo(0));
    expect(back.right, lessThanOrEqualTo(appMetrics.railWidth));
    expect(brand.left, greaterThan(back.right));
    expect(brand.center.dy, closeTo(back.center.dy, .01));
    final first = tester.getRect(find.byType(FrostNavItem).first);
    expect(first.top, greaterThanOrEqualTo(back.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('native strip grows for actual control geometry without moving Back beside it', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final window = FakeWindow();
    window.current = const FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.nativeControls,
      leftButtons: [],
      rightButtons: [],
      nativeControls: Rect.fromLTRB(12, 12, 72, 40),
    );
    await tester.pumpWidget(_shell(window, platform: TargetPlatform.macOS, expanded: true));
    expect(tester.getRect(find.byKey(_pageKey)).top, 44);
    expect(tester.getRect(find.byKey(const ValueKey('frost-shell-back'))).top, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  for (final expanded in [false, true]) {
    testWidgets('caption brand remains visible across sidebar animation from expanded=$expanded', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_shell(FakeWindow(), expanded: expanded));
      _expectVisibleBrand(tester);
      await tester.tap(findFrostTooltip(expanded ? 'L.collapseNavigation' : 'L.expandNavigation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final width = tester.getRect(find.byKey(_pageKey)).left;
      expect(width, greaterThan(80));
      expect(width, lessThan(176));
      _expectVisibleBrand(tester);
      await tester.pumpAndSettle();
      _expectVisibleBrand(tester);
    });
  }

  for (final width in [320.0, 390.0, 599.0]) {
    testWidgets('native compact width=$width retains caption and bottom navigation on first frame', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final window = FakeWindow();
      await tester.pumpWidget(_shell(window));
      _expectVisibleBrand(tester);
      expect(tester.getRect(find.byKey(_pageKey)).top, 40);
      expect(find.byType(FrostNavItem), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(_nameKey), matching: find.byType(RichText)));
      expect(paragraph.overflow, TextOverflow.ellipsis);
      if (width == 320) expect(paragraph.didExceedMaxLines, isTrue);
      expect(window.calls.last.any((region) => region.kind == FrostHitKind.maximize), isTrue);
    });
  }

  for (final expanded in [false, true]) {
    testWidgets('inset sidebar and page share top inset without a custom caption expanded=$expanded', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_shell(null, expanded: expanded));
      final toggle = findFrostTooltip(expanded ? 'L.collapseNavigation' : 'L.expandNavigation');
      expect(tester.getRect(toggle).bottom, lessThanOrEqualTo(900));
      expect(tester.getRect(toggle).top, greaterThan(800));
      expect(tester.getRect(find.byKey(_pageKey)).top, FrostGap.related);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone without native scope has no caption and starts content at top', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_shell(null, platform: TargetPlatform.android));
    expect(find.byType(FrostCaptionButtons), findsNothing);
    expect(find.byKey(_iconKey), findsNothing);
    expect(tester.getRect(find.byKey(_pageKey)).top, 0);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
