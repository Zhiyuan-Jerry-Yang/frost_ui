import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/_navigation_tile.dart';
import 'support.dart';

class SectionBody extends StatefulWidget {
  const SectionBody({super.key});
  @override
  State<SectionBody> createState() => _BodyState();
}

class _BodyState extends State<SectionBody> {
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      FrostSliverContentColumn(
        sliver: SliverList.builder(itemCount: 80, itemBuilder: (_, index) => SizedBox(height: 40, child: Text('Section content $index'))),
      ),
    ],
  );
}

void main() {
  testWidgets('builder is lazy when two panes cannot fit; click delegates without building content', (tester) async {
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final built = <int>[];
    final chosen = <int>[];
    await tester.pumpWidget(
      frostTestApp(
        FrostSettingsSections.builder(
          labels: const ['Appearance', 'Network'],
          selectedIndex: 0,
          onSelected: chosen.add,
          sectionBuilder: (_, index) {
            built.add(index);
            return const SectionBody();
          },
        ),
      ),
    );
    expect(built, isEmpty);
    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();
    expect(chosen, [1]);
    expect(built, isEmpty);
    expect(find.byType(SectionBody), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('controlled selection and shared keyboard navigation build only selected sections', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final built = <int>{};
    var selected = 0;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, update) => FrostSettingsSections.builder(
            labels: const ['Appearance', 'Network'],
            selectedIndex: selected,
            onSelected: (index) => update(() => selected = index),
            sectionBuilder: (_, index) {
              built.add(index);
              return FrostContentColumn(child: Text('Body $index'));
            },
          ),
        ),
      ),
    );
    expect(built, {0});
    final tiles = tester.widgetList<FrostNavigationTile>(find.byType(FrostNavigationTile)).toList();
    expect(tester.getSize(find.byType(ListView).first).width, 236);
    // Content limit is actual render geometry, independent of the viewport width.
    expect(tester.getSize(find.text('Body 0')).width, lessThanOrEqualTo(640));
    expect(tester.getTopLeft(find.text('Body 0')).dx, closeTo(236 + 1 + 32, .01));
    tiles.first.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(selected, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(built, {0, 1});
    expect(find.text('Body 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow and restore keeps the mounted section State and scroll offset', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      frostTestApp(
        FrostSettingsSections.builder(labels: const ['Appearance'], selectedIndex: 0, onSelected: (_) {}, sectionBuilder: (_, _) => const SectionBody()),
      ),
    );
    final before = tester.state(find.byType(SectionBody));
    final scroll = tester.state<ScrollableState>(find.descendant(of: find.byType(SectionBody), matching: find.byType(Scrollable)));
    scroll.position.jumpTo(240);
    await tester.pump();
    tester.view.physicalSize = const Size(390, 900);
    await tester.pump();
    expect(identical(tester.state(find.byType(SectionBody, skipOffstage: false)), before), true);
    expect(find.byType(SectionBody), findsNothing);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    expect(identical(tester.state(find.byType(SectionBody)), before), true);
    expect(scroll.position.pixels, 240);
    expect(tester.takeException(), isNull);
  });
  for (final direction in TextDirection.values) {
    testWidgets('builder icons, separator and content keyline are exact on first frame $direction', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900), devicePixelRatio: 2),
            child: Directionality(
              textDirection: direction,
              child: FrostSettingsSections.builder(
                labels: const ['Appearance', 'Network'],
                icons: [testIcons.eye, testIcons.info],
                selectedIndex: 0,
                onSelected: (_) {},
                sectionBuilder: (_, _) => const FrostContentColumn(child: SizedBox.expand(key: ValueKey('content'))),
              ),
            ),
          ),
        ),
      );
      final navigation = tester.getRect(find.byType(ListView));
      final divider = tester.getRect(find.byType(FrostDivider));
      final content = tester.getRect(find.byKey(const ValueKey('content')));
      expect(navigation.width, 236);
      expect(divider.width, .5);
      expect(content.width, lessThanOrEqualTo(640));
      expect(tester.widgetList<FrostNavigationTile>(find.byType(FrostNavigationTile)).map((tile) => tile.icon), [testIcons.eye, testIcons.info]);
      if (direction == TextDirection.ltr) {
        expect(divider.left, navigation.right);
        expect(content.left, divider.right + 32);
      } else {
        expect(divider.right, navigation.left);
        expect(content.right, divider.left - 32);
      }
      expect(content.top, tester.getRect(find.byType(FrostNavigationTile).first).top);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('custom compact navigation opens sections without rebuilding retained content', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chosen = <int>[];
    await tester.pumpWidget(
      frostTestApp(
        FrostSettingsSections.builder(
          labels: const ['Appearance'],
          selectedIndex: 0,
          onSelected: chosen.add,
          compactNavigationBuilder: (_) => FrostGroupedSection(
            children: [FrostListRow(title: 'Appearance', value: 'System', onPressed: () => chosen.add(0))],
          ),
          sectionBuilder: (_, _) => const SectionBody(),
        ),
      ),
    );
    final before = tester.state(find.byType(SectionBody));
    tester.view.physicalSize = const Size(390, 900);
    await tester.pump();
    expect(find.byType(FrostGroupedSection), findsOneWidget);
    expect(find.byType(FrostNavigationTile), findsNothing);
    expect(tester.state(find.byType(SectionBody, skipOffstage: false)), same(before));
    await tester.tap(find.text('Appearance'));
    expect(chosen, [0]);
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pump();
    expect(tester.state(find.byType(SectionBody)), same(before));
    expect(tester.takeException(), isNull);
  });
  test('builder validates controlled index and accepts empty navigation', () {
    expect(
      () => FrostSettingsSections.builder(
        labels: const ['One'],
        icons: const [],
        selectedIndex: 0,
        onSelected: (_) {},
        sectionBuilder: (_, _) => const SizedBox(),
      ),
      throwsAssertionError,
    );
    expect(
      () => FrostSettingsSections.builder(labels: const ['One'], selectedIndex: 1, onSelected: (_) {}, sectionBuilder: (_, _) => const SizedBox()),
      throwsAssertionError,
    );
    expect(
      () => FrostSettingsSections.builder(labels: const [], selectedIndex: 0, onSelected: (_) {}, sectionBuilder: (_, _) => const SizedBox()),
      returnsNormally,
    );
  });
}
