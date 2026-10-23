import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

const _home = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe001)), label: 'Home');
const _search = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe002)), label: 'Search');
const _settings = FrostNavDestination(icon: FrostIconData.glyph(IconData(0xe003)), label: 'Settings');

class _Items extends FrostListSource<int> {
  _Items(this.pages);

  final List<List<int>> pages;
  int _page = 0;

  @override
  Future<List<int>> initList() async {
    _page = 0;
    return pages.first;
  }

  @override
  Future<List<int>> nextList() async => ++_page < pages.length ? pages[_page] : const [];
}

void main() {
  testWidgets('components read the configuration from the Frost theme without a scope', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
        home: Scaffold(
          body: FrostCompactMessage.error(error: 'x', onAction: () {}),
        ),
      ),
    );
    expect(find.text('E.message(x)'), findsOneWidget);
    expect(find.text('L.retry'), findsOneWidget);
  });

  Finder navItem(String label) => find.byWidgetPredicate((widget) => widget is FrostNavItem && widget.label == label);

  Future<void> desktop(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final style in const [
    FrostSidebarStyle.inset(),
    FrostSidebarStyle.capsule(),
    FrostSidebarStyle.flush(),
    FrostSidebarStyle.flush(itemForm: FrostNavItemForm.indicator),
  ]) {
    testWidgets('FrostShell ${style.runtimeType}: navigation, reselection and More', (tester) async {
      await desktop(tester, const Size(1400, 900));
      final selected = <int>[];
      final secondary = <int>[];
      var reselections = 0;
      await tester.pumpWidget(
        frostTestApp(
          FrostShell(
            destinations: const [_home, _search],
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: selected.add,
            secondaryDestinations: const [_settings],
            onSecondarySelected: secondary.add,
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            sidebarStyle: style,
            child: Builder(
              builder: (context) {
                FrostShellNavigationScope.maybeOf(context)!.primaryReselection.addListener(() => reselections++);
                return const Center(child: Text('page'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('page'), findsOneWidget);
      expect(navItem('L.more'), findsOneWidget);

      await tester.tap(navItem('Search'));
      expect(selected, [1]);

      // The current root destination again signals reselection instead.
      await tester.tap(navItem('Home'));
      expect(selected, [1]);
      expect(reselections, 1);

      await tester.tap(navItem('L.more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(secondary, [0]);

      // The sidebar expands on wide windows.
      await tester.tap(findFrostTooltip('L.expandNavigation'));
      await tester.pumpAndSettle();
      expect(findFrostTooltip('L.collapseNavigation'), findsOneWidget);
    });
  }

  Widget flushShell({required ValueChanged<bool> onExpandedChanged, bool initiallyExpanded = false, Widget? child}) => frostTestApp(
    FrostShell(
      destinations: const [_home, _search],
      selectedIndex: 0,
      atDestinationRoot: true,
      onDestinationSelected: (_) {},
      canGoBack: false,
      onBack: () {},
      showsMobileNavigation: true,
      sidebarStyle: const FrostSidebarStyle.flush(),
      metrics: const FrostNavigationMetrics(railWidth: 56, expandedWidth: 192, expandableMinWidth: 1200, mobileMaxWidth: 600),
      initiallyExpanded: initiallyExpanded,
      onExpandedChanged: onExpandedChanged,
      child: child ?? const SizedBox.expand(key: ValueKey('page')),
    ),
  );

  testWidgets('a flush sidebar opens over the page in a narrow window and keeps the saved choice', (tester) async {
    await desktop(tester, const Size(1000, 800));
    final changes = <bool>[];
    await tester.pumpWidget(flushShell(onExpandedChanged: changes.add, initiallyExpanded: true));
    await tester.pumpAndSettle();
    // Too narrow to sit beside the page: collapsed, the page beside the rail.
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 56);
    expect(findFrostTooltip('L.expandNavigation'), findsOneWidget);

    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pumpAndSettle();
    // Open over the page: the page stays put, and opening is not a choice.
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 56);
    expect(tester.getSize(find.byType(FrostNavItem).first).width, 192 - 16);
    expect(changes, isEmpty);

    // A click on the page closes it.
    await tester.tapAt(const Offset(600, 400));
    await tester.pumpAndSettle();
    expect(findFrostTooltip('L.expandNavigation'), findsOneWidget);

    // Wide again, the saved choice returns and pushes the page.
    await desktop(tester, const Size(1400, 800));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 192);
    await tester.tap(findFrostTooltip('L.collapseNavigation'));
    await tester.pumpAndSettle();
    expect(changes, [false]);
    expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 56);
  });

  testWidgets('Escape closes a flush sidebar open over the page', (tester) async {
    await desktop(tester, const Size(1000, 800));
    // Escape goes to the focused page, as it would from a field or list.
    await tester.pumpWidget(
      flushShell(
        onExpandedChanged: (_) {},
        child: const Focus(autofocus: true, child: SizedBox.expand(key: ValueKey('page'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pumpAndSettle();
    expect(findFrostTooltip('L.collapseNavigation'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(findFrostTooltip('L.expandNavigation'), findsOneWidget);
  });

  testWidgets('Escape on a page goes back through the page and shell Scaffolds', (tester) async {
    await desktop(tester, const Size(1400, 800));
    var backs = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [_home, _search],
          selectedIndex: 0,
          atDestinationRoot: false,
          onDestinationSelected: (_) {},
          canGoBack: true,
          onBack: () => backs++,
          showsMobileNavigation: false,
          sidebarStyle: const FrostSidebarStyle.capsule(),
          child: const Scaffold(body: Focus(autofocus: true, child: SizedBox.expand())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(backs, 1);
  });

  testWidgets('pinned glass beside a flush sidebar covers the content sheet', (tester) async {
    await desktop(tester, const Size(1400, 800));
    await tester.pumpWidget(
      flushShell(
        onExpandedChanged: (_) {},
        child: FrostPinnedChrome(
          extent: 48,
          chrome: const SizedBox.expand(),
          body: ListView(
            children: [
              const SizedBox(height: 48),
              for (var index = 0; index < 50; index++) SizedBox(height: 40, child: Text('$index')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    final band = find.descendant(of: find.byType(FrostPinnedChromeGlass), matching: find.byType(FrostSurface));
    expect(tester.getSize(band).width, 1400 - 56 - 8);
    // Centred in the page beside the 56 rail.
    expect(tester.getCenter(band).dx, 56 + (1400 - 56 - 8) / 2);
  });

  testWidgets('FrostShell uses the bottom bar on phones', (tester) async {
    await desktop(tester, const Size(400, 800));
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [_home, _search],
          selectedIndex: 1,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: true,
          onBack: () {},
          showsMobileNavigation: true,
          sidebarStyle: const FrostSidebarStyle.flush(),
          child: const FrostShellDestination(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('L.more'), findsNothing);
  });

  testWidgets('errors use the app presenter and labels', (tester) async {
    await desktop(tester, const Size(1000, 800));
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: Column(
            children: [
              FrostCompactMessage.error(error: 'boom', onAction: () {}),
              Expanded(
                child: FrostErrorContent.fromError(error: 'down', onRetry: () {}),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('E.message(boom)'), findsOneWidget);
    expect(find.text('E.message(down)'), findsOneWidget);
    expect(find.text('L.retry'), findsNWidgets(2));
    expect(find.text('L.errorDetails'), findsNWidgets(2));
  });

  testWidgets('a paged list shows the supplied skeleton, then items and its end', (tester) async {
    await desktop(tester, const Size(1000, 800));
    final source = _Items([
      [1, 2],
      [3],
    ]);
    addTearDown(source.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: FrostLoadingScrollView(
            slivers: [
              FrostSliverDataList<int>(
                source: source,
                firstLoadSkeleton: const Text('skeleton'),
                itemBuilder: (context, item, index) => SizedBox(height: 40, child: Text('item $item')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(source.initialized, isTrue); // The shared sliver now starts its own first load.
    await source.refresh(true);
    await tester.pumpAndSettle();
    expect(find.text('item 1'), findsOneWidget);
    await source.loadMore();
    await source.loadMore();
    await tester.pumpAndSettle();
    expect(find.text('item 3'), findsOneWidget);
    expect(source.hasMore, isFalse);
  });

  testWidgets('toasts: action runs once, identical notices merge on desktop', (tester) async {
    await desktop(tester, const Size(1200, 800));
    await tester.pumpWidget(frostTestApp(const Scaffold(body: SizedBox.expand())));
    var undone = 0;
    FrostToast.actionableInfo('Removed', actionLabel: 'Undo', onAction: () => undone++);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Removed'), findsNothing);

    FrostToast.info('Saved');
    FrostToast.info('Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved  ×2'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('load state switcher, settings sections and controls render', (tester) async {
    await desktop(tester, const Size(1400, 900));
    var phase = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: FrostLoadStateSwitcher(phase: phase, child: Text('phase $phase')),
                  ),
                  FrostButton(label: 'Act', onPressed: () {}),
                  FrostSwitch(value: true, onChanged: (_) {}, semanticLabel: null),
                  FrostPicker<int>.menu(
                    value: 1,
                    options: const [
                      FrostPickerOption(value: 1, label: 'One'),
                      FrostPickerOption(value: 2, label: 'Two'),
                    ],
                    onChanged: (_) {},
                    label: 'Choice',
                  ),
                  Expanded(
                    child: FrostSettingsSections(
                      labels: const ['General', 'About'],
                      status: const Text('status row'),
                      groups: const [
                        [Text('general group')],
                        [Text('about group')],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('phase 0'), findsOneWidget);
    update(() => phase = 1);
    await tester.pumpAndSettle();
    expect(find.text('phase 1'), findsOneWidget);
    expect(find.text('phase 0'), findsNothing);
    expect(find.text('status row'), findsOneWidget);
    expect(find.text('general group'), findsOneWidget);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('about group'), findsOneWidget);
  });
}
