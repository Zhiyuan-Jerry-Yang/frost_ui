import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'support.dart';

void main() {
  testWidgets('collapsed toolbar picker uses down chevron while content value menus use up-down', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 200,
            child: FrostToolbar(
              trailing: [
                FrostToolbarItem.picker<int>(
                  choices: const [
                    FrostPickerOption(value: 0, label: 'Latest'),
                    FrostPickerOption(value: 1, label: 'Popular'),
                    FrostPickerOption(value: 2, label: 'History'),
                  ],
                  value: 0,
                  onChanged: (_) {},
                  label: 'Mode',
                ),
              ],
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    final collapsed = find.byType(FrostPicker<int>).hitTestable();
    expect(collapsed, findsOneWidget);
    expect(tester.widget<FrostButtonControl>(find.descendant(of: collapsed, matching: find.byType(FrostButtonControl))).chevron, FrostButtonChevron.down);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostPicker<int>.menu(
            value: 0,
            options: const [
              FrostPickerOption(value: 0, label: 'Latest'),
              FrostPickerOption(value: 1, label: 'Popular'),
            ],
            onChanged: (_) {},
            label: 'Choice',
          ),
        ),
      ),
    );
    expect(tester.widget<FrostButtonControl>(find.byType(FrostButtonControl)).chevron, FrostButtonChevron.upDown);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page header middle inherits toolbar arrow rules for value buttons and fields', (tester) async {
    for (final field in [false, true]) {
      const items = [FrostPickerOption(value: 0, label: 'Latest'), FrostPickerOption(value: 1, label: 'Popular')];
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 700,
              child: FrostPageHeader(
                title: const Text('Heading'),
                middle: field
                    ? FrostPicker<int>.menu(value: 0, options: items, onChanged: (_) {}, label: "Choice")
                    : FrostPicker<int>.menu(value: 0, options: items, onChanged: (_) {}, label: "Choice"),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      expect(tester.widget<FrostButtonControl>(find.byType(FrostButtonControl).hitTestable()).chevron, FrostButtonChevron.down);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('toolbar middle gives search the compact field height without growing the page header', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 700,
            child: FrostPageHeader(
              title: const Text('Heading'),
              middle: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    expect(tester.getSize(find.byType(FrostTextField)).height, FrostControlSize.compact.visualHeight(touch: false));
    expect(tester.getSize(find.byType(FrostPageHeader)).height, 52);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
  testWidgets('cold first layout retains flexible middle or replaces it explicitly, with a scrolling safety net', (tester) async {
    for (final collapsed in [false, true]) {
      final width = ValueNotifier(150.0);
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: ValueListenableBuilder(
              valueListenable: width,
              builder: (context, w, _) => SizedBox(
                width: w,
                child: FrostToolbar(
                  middle: const SizedBox(key: ValueKey('full-middle'), height: 40),
                  collapsedMiddle: collapsed ? const Icon(Icons.search, key: ValueKey('collapsed-middle')) : null,
                  trailing: [
                    FrostToolbarItem.action(icon: testIcons.add, label: 'Always', priority: FrostToolbarPriority.high, onPressed: () {}),
                    FrostToolbarItem.action(icon: testIcons.delete, label: 'Extra', onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      expect(find.byKey(const ValueKey('full-middle')), collapsed ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('collapsed-middle')), collapsed ? findsOneWidget : findsNothing);
      width.value = 50;
      await tester.pump();
      final scroll = tester.state<ScrollableState>(find.descendant(of: find.byType(FrostToolbar), matching: find.byType(Scrollable)));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(findFrostTooltip('L.more').hitTestable(), findsOneWidget);
      width.value = 700;
      await tester.pump();
      expect(find.byKey(const ValueKey('full-middle')), findsOneWidget);
      expect(find.byKey(const ValueKey('collapsed-middle')), findsNothing);
      expect(scroll.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      width.dispose();
    }
  });

  testWidgets('overflow preserves item order and action, picker, menu and custom selection paths', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 150,
            child: FrostToolbar(
              middle: const SizedBox(height: 40),
              trailing: [
                FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh', onPressed: () => calls.add('refresh')),
                FrostToolbarItem.picker(
                  choices: const [
                    FrostPickerOption(value: 0, label: 'Latest'),
                    FrostPickerOption(value: 1, label: 'Popular'),
                  ],
                  value: 0,
                  onChanged: (v) => calls.add('pick$v'),
                  label: 'Mode',
                ),
                FrostToolbarItem.menu(
                  label: 'Period',
                  entries: [FrostMenuAction('Week', onSelected: () => calls.add('week'))],
                ),
                FrostToolbarItem.custom(
                  builder: (_) => const Text('Custom'),
                  minWidth: 100,
                  overflowEntry: FrostMenuAction('Custom entry', onSelected: () => calls.add('custom')),
                ),
                FrostToolbarItem.action(icon: testIcons.add, label: 'High', priority: FrostToolbarPriority.high, onPressed: () => calls.add('high')),
              ],
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    Future<void> open() async {
      await tester.ensureVisible(findFrostTooltip('L.more').last);
      await tester.pump();
      await tester.tap(findFrostTooltip('L.more').hitTestable());
      await tester.pumpAndSettle();
    }

    await open();
    final y = [
      for (final label in ['Refresh', 'Mode · Latest', 'Period', 'Custom entry']) tester.getTopLeft(find.text(label).hitTestable()).dy,
    ];
    expect(y, orderedEquals([...y]..sort()));
    await tester.tap(find.text('Mode · Latest').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Latest').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Popular').hitTestable());
    await tester.pumpAndSettle();
    await open();
    await tester.tap(find.text('Period').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week').hitTestable());
    await tester.pumpAndSettle();
    await open();
    await tester.tap(find.text('Custom entry').hitTestable());
    await tester.pumpAndSettle();
    await open();
    await tester.tap(find.text('Refresh').hitTestable());
    await tester.pumpAndSettle();
    expect(calls, ['pick1', 'week', 'custom', 'refresh']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leading and trailing mirror in RTL and only live controls enter keyboard traversal', (tester) async {
    for (final width in [600.0, 150.0]) {
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: FrostToolbar(
                    leading: const [Text('Heading')],
                    middle: const SizedBox(height: 40),
                    trailing: [
                      FrostToolbarItem.action(icon: testIcons.add, label: 'First', priority: FrostToolbarPriority.high, onPressed: () {}),
                      FrostToolbarItem.action(icon: testIcons.refresh, label: 'Second', onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        final firstControl = findFrostTooltip('First').last;
        final secondControl = findFrostTooltip(width == 600 ? 'Second' : 'L.more').last;
        await tester.ensureVisible(firstControl);
        await tester.pump();
        await tester.ensureVisible(secondControl);
        await tester.pump();
        // At an extreme width the non-collapsible middle keeps its State in
        // the horizontal safety viewport. Compare both live boxes in the same
        // scroll pose; keyboard traversal must still reveal both controls.
        final title = tester.getCenter(find.text('Heading')).dx;
        final first = tester.getCenter(firstControl).dx;
        final second = tester.getCenter(secondControl.hitTestable()).dx;
        expect(direction == TextDirection.ltr ? first < second : first > second, true);
        if (width == 600) expect(direction == TextDirection.ltr ? title < first : title > first, true);
        final seen = <String>{};
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
            if (e.widget case Semantics(:final properties)) {
              if (properties.label case final label?) seen.add(label);
            }
            return true;
          });
        }
        expect(seen, containsAll(['First', width == 600 ? 'Second' : 'L.more']));
        if (width == 150) expect(seen, isNot(contains('Second')));
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('toolbar collapses in order, keeps high actions and restores on the first layout', (tester) async {
    tester.view.physicalSize = const Size(1800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final width = ValueNotifier(1600.0);
    addTearDown(width.dispose);
    final items = [
      FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh collection', showsLabel: true, onPressed: () {}),
      FrostToolbarItem.picker(
        choices: const [
          FrostPickerOption(value: 0, label: 'Latest'),
          FrostPickerOption(value: 1, label: 'Popular'),
          FrostPickerOption(value: 2, label: 'History'),
        ],
        value: 0,
        onChanged: (_) {},
        label: 'Mode',
      ),
      FrostToolbarItem.menu(
        label: 'Period',
        entries: [FrostMenuAction('Week', onSelected: () {})],
      ),
      FrostToolbarItem.custom(
        builder: (_) => const SizedBox(height: 36, child: Text('Custom')),
        minWidth: 120,
        overflowEntry: FrostMenuAction('Custom entry', onSelected: () {}),
      ),
      FrostToolbarItem.action(icon: testIcons.add, label: 'High', priority: FrostToolbarPriority.high, onPressed: () {}),
      FrostToolbarItem.action(icon: testIcons.delete, label: 'Low', priority: FrostToolbarPriority.low, onPressed: () {}),
    ];
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: ValueListenableBuilder(
            valueListenable: width,
            builder: (context, w, _) => SizedBox(
              width: w,
              child: FrostToolbar(
                leading: const [Text('Collection heading')],
                middle: const SizedBox(key: ValueKey('middle'), height: 40),
                collapsedMiddle: const Icon(Icons.search, key: ValueKey('collapsed')),
                trailing: items,
              ),
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    for (final w in [1600.0, 1300.0, 1100.0, 950.0, 800.0, 650.0, 500.0, 350.0, 200.0, 100.0, 1600.0]) {
      width.value = w;
      await tester.pump();
      expect(find.text('Refresh collection').hitTestable().evaluate().length, w >= 1600 ? 1 : 0);
      expect(find.byWidgetPredicate((w) => w is FrostPicker<int> && w.style == FrostPickerStyle.segmented).hitTestable().evaluate().length, w >= 1300 ? 1 : 0);
      expect(find.byKey(const ValueKey('middle')).evaluate().length, w >= 350 ? 1 : 0);
      expect(find.byKey(const ValueKey('collapsed')).evaluate().length, w < 350 ? 1 : 0);
      if (w >= 200) expect(findFrostTooltip('L.more').hitTestable().evaluate().length, w <= 950 ? 1 : 0);
      final scrollable = tester.stateList<ScrollableState>(find.descendant(of: find.byType(FrostToolbar), matching: find.byType(Scrollable))).first;
      expect(scrollable.position.maxScrollExtent > 0, w == 100);
      expect(findFrostTooltip('High').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('toolbar scope changes the actual segmented track and compact height only locally', (tester) async {
    late FrostThemeTokens tokens;
    Widget segment() => FrostPicker<int>.segmented(
      options: const [
        FrostPickerOption(value: 0, label: 'One'),
        FrostPickerOption(value: 1, label: 'Two'),
      ],
      value: 0,
      onChanged: (_) {},
      label: 'Choice',
    );
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Material(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FrostToolbar(
                      trailing: [
                        FrostToolbarItem.picker(
                          choices: const [
                            FrostPickerOption(value: 0, label: 'One'),
                            FrostPickerOption(value: 1, label: 'Two'),
                          ],
                          value: 0,
                          onChanged: (_) {},
                          label: 'Pick',
                        ),
                      ],
                    ),
                    segment(),
                  ],
                ),
              ),
            );
          },
        ),
        density: FrostDensity.compact,
      ),
    );
    final controls = find.byType(FrostPicker<int>).hitTestable();
    expect(controls, findsNWidgets(2));
    final top = controls.first, bottom = controls.last;
    ShapeDecoration track(Finder root) => tester
        .renderObjectList<RenderDecoratedBox>(find.descendant(of: root, matching: find.byType(DecoratedBox)))
        .map((r) => r.decoration)
        .whereType<ShapeDecoration>()
        .first;
    expect(track(top).color, tokens.fillSubtle);
    expect(track(bottom).color, tokens.fill);
    expect(tester.getSize(top).height, 32);
    expect(tester.getSize(bottom).height, 40);
    expect(tester.takeException(), isNull);
  });
}
