import 'dart:ui' show CheckedState;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'support.dart';

Finder row(String text) => find.ancestor(of: find.text(text).last, matching: find.byType(FrostMenuItem));
TextStyle textStyle(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text).last).text.style!;

void main() {
  test('menu compact density applies to every pointer platform and touch stays regular', () {
    for (final platform in TargetPlatform.values) {
      for (final density in FrostDensity.values) {
        final theme = FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: platform, locale: const Locale('en'), density: density);
        final pointer = [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux].contains(platform);
        expect(theme.menuButtonTheme.style!.minimumSize!.resolve({})!.height, pointer && density == FrostDensity.compact ? 32 : 44);
      }
    }
  });

  test('Material menu fallback shares Frost menu geometry', () {
    for (final density in FrostDensity.values) {
      final theme = FrostTheme.build(
        config: testConfig,
        brightness: Brightness.light,
        platform: TargetPlatform.windows,
        locale: const Locale('en'),
        density: density,
      );
      final style = theme.menuButtonTheme.style!;
      expect(style.minimumSize!.resolve({})!.height, density == FrostDensity.compact ? 32 : 44);
      expect(style.padding!.resolve({})!.resolve(TextDirection.ltr).left, 8);
      expect(style.visualDensity, VisualDensity.standard);
      expect(style.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect((style.shape!.resolve({})! as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, 8);
      expect(theme.menuTheme.style!.padding!.resolve({}), const EdgeInsets.all(4));
      expect(theme.menuTheme.style!.minimumSize!.resolve({})!.width, 160);
      expect(theme.menuTheme.style!.maximumSize!.resolve({})!.width, 360);
      expect((theme.menuTheme.style!.shape!.resolve({})! as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, 12);
    }
  });

  testWidgets('short root menus use 160 and long labels wrap at 360', (tester) async {
    for (final label in ['A', 'A long menu label that wraps across more than one line within the maximum width']) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostMenuAnchor(
              entries: [
                FrostMenuAction(label, onSelected: () {}),
                FrostMenuAction('B', onSelected: () {}),
              ],
              builder: (context, focus, toggle) => FrostButton(label: 'Open', onPressed: toggle),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostMenuPanel)).width, label == 'A' ? 160 : 360);
      if (label != 'A') {
        expect(
          tester.renderObject<RenderParagraph>(find.text(label)).getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: label.length)).length,
          greaterThan(1),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('value menus match their triggers and stay within the right viewport edge', (tester) async {
    for (final field in [false, true]) {
      const items = [FrostPickerOption(value: 1, label: 'A'), FrostPickerOption(value: 2, label: 'B')];
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 300,
              child: field
                  ? FrostPicker<int>.menu(value: 1, options: items, onChanged: (_) {}, label: "Choice")
                  : FrostPicker<int>.menu(value: 1, options: items, onChanged: (_) {}, label: "Choice"),
            ),
          ),
        ),
      );
      final trigger = tester.getRect(find.byType(FrostButtonControl));
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      final menu = tester.getRect(find.byType(FrostMenuPanel));
      expect(menu.width, greaterThanOrEqualTo(trigger.width));
      expect(menu.right, lessThanOrEqualTo(792));
      expect(menu.left, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('menu minimum yields to the available width in a narrow viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(140, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostMenuAnchor(
            entries: [
              FrostMenuAction('A', onSelected: () {}),
              FrostMenuAction('B', onSelected: () {}),
            ],
            builder: (context, focus, toggle) => FrostButton(label: 'Open', onPressed: toggle),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(FrostMenuPanel));
    expect(rect.width, 124);
    expect(rect.left, 8);
    expect(rect.right, 132);
    expect(tester.takeException(), isNull);
  });

  testWidgets('500-wide Select menu follows its trigger and yields to a smaller viewport', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final viewportWidth in [800.0, 400.0]) {
      await tester.binding.setSurfaceSize(Size(viewportWidth, 600));
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: OverflowBox(
              minWidth: 500,
              maxWidth: 500,
              child: FrostPicker<int>.menu(
                value: 1,
                options: const [
                  FrostPickerOption(value: 1, label: 'A'),
                  FrostPickerOption(value: 2, label: 'B'),
                ],
                onChanged: (_) {},
                label: 'Choice',
              ),
            ),
          ),
        ),
      );
      final trigger = tester.getRect(find.byType(FrostButtonControl));
      expect(trigger.width, 500);
      await tester.tap(find.byType(FrostButtonControl));
      await tester.pumpAndSettle();
      final menu = tester.getRect(find.byType(FrostMenuPanel));
      expect(menu.width, viewportWidth == 800 ? 500 : 384);
      expect(menu.left, greaterThanOrEqualTo(8));
      expect(menu.right, lessThanOrEqualTo(viewportWidth - 8));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  for (final density in FrostDensity.values) {
    testWidgets('menu row height, padding and nested corners: $density', (tester) async {
      double? padding, unscaled;
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: FrostMenuAnchor(
                  entries: [FrostMenuAction('Action', onSelected: () {})],
                  builder: (context, focus, toggle) => Focus(
                    focusNode: focus,
                    child: FrostButton(label: 'Open', onPressed: toggle),
                  ),
                ),
              ),
            ),
            density: density,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final frame = tester.getRect(row('Action')), text = tester.getRect(find.text('Action'));
        final top = text.top - frame.top, bottom = frame.bottom - text.bottom;
        padding ??= top;
        unscaled ??= text.height;
        expect(top, closeTo(bottom, .001));
        expect(top, closeTo(padding, .001));
        expect(frame.height, (density == FrostDensity.compact ? 32 : 44) + text.height - unscaled);
        final material = tester.widget<Material>(find.descendant(of: row('Action'), matching: find.byType(Material)));
        final shape = material.shape! as RoundedSuperellipseBorder;
        expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, 8);
        final clip = tester.widget<ClipRSuperellipse>(find.descendant(of: find.byType(FrostMenuPanel), matching: find.byType(ClipRSuperellipse)).first);
        expect(clip.borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.lg);
        expect(tester.getRect(row('Action')).left - tester.getRect(find.byType(FrostMenuPanel)).left, 4);
        expect(tester.getRect(find.text('Action')).left - frame.left, 8);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('group check/icon columns, false semantics, destructive ink and trailing alignment', (tester) async {
    final handle = tester.ensureSemantics();
    late FrostThemeTokens tokens;
    late StateSetter update;
    var checked = false;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return Center(
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return FrostMenuAnchor(
                    entries: [
                      FrostMenuSection(
                        header: 'Values',
                        entries: [
                          FrostMenuAction('Value A', icon: testIcons.add, checked: checked, onSelected: () {}),
                          FrostMenuAction('Value B', checked: false, onSelected: () {}),
                          FrostMenuAction('Mixed plain', onSelected: () {}),
                        ],
                      ),
                      const FrostMenuDivider(),
                      FrostMenuSection(
                        header: 'Operations',
                        entries: [
                          FrostMenuAction('Action', shortcut: const FrostShortcut(LogicalKeyboardKey.keyA, primary: true), onSelected: () {}),
                          FrostMenuAction('Delete', icon: testIcons.delete, destructive: true, onSelected: () {}),
                          FrostMenuSubmenu('More actions', entries: [FrostMenuAction('Nested', onSelected: () {})]),
                        ],
                      ),
                    ],
                    builder: (context, focus, toggle) => Focus(
                      focusNode: focus,
                      child: FrostButton(label: 'Open', onPressed: toggle),
                    ),
                  );
                },
              ),
            );
          },
        ),
        density: FrostDensity.compact,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final valueX = tester.getTopLeft(find.text('Value A')).dx;
    expect(tester.getTopLeft(find.text('Value B')).dx, valueX);
    expect(tester.getTopLeft(find.text('Mixed plain')).dx, valueX);
    expect(tester.getTopLeft(find.text('Values')).dx, valueX);
    expect(tester.getTopLeft(find.text('Operations')).dx, tester.getTopLeft(find.text('Action')).dx);
    expect(tester.getTopLeft(find.text('Action')).dx, valueX);
    final icon = find.descendant(of: row('Value A'), matching: find.byType(FrostIcon));
    expect(tester.getTopLeft(icon).dx - tester.getTopLeft(row('Value A')).dx, 8);
    expect(valueX - tester.getTopLeft(icon).dx, FrostControlSize.compact.iconSize + 8);
    expect(tester.getSemantics(find.text('Value B')).getSemanticsData().flagsCollection.isChecked, CheckedState.isFalse);
    expect(tester.getSemantics(find.text('Mixed plain')).getSemanticsData().flagsCollection.isChecked, CheckedState.none);
    expect(textStyle(tester, 'Delete').color, tokens.negativeInk);
    expect(tester.widget<FrostIcon>(find.descendant(of: row('Delete'), matching: find.byType(FrostIcon))).color, tokens.negativeInk);
    expect(textStyle(tester, 'Ctrl+A').color, tokens.textTertiary);
    expect(textStyle(tester, 'Ctrl+A').fontSize, 12);
    expect(textStyle(tester, 'Values').color, tokens.textTertiary);
    expect(textStyle(tester, 'Values').fontSize, 11);
    expect(tester.getRect(find.text('Ctrl+A')).right, tester.getRect(row('Action')).right - 8);
    final arrow = find.descendant(of: row('More actions'), matching: find.byType(FrostIcon));
    expect(tester.widget<FrostIcon>(arrow).color, tokens.textTertiary);
    expect(tester.getRect(arrow).right, tester.getRect(row('More actions')).right - 8);
    update(() => checked = true);
    await tester.pumpAndSettle();
    final check = find.descendant(of: row('Value A'), matching: find.byWidgetPredicate((w) => w is FrostIcon && w.color == tokens.selectionInk));
    expect(check, findsOneWidget);
    expect(tester.getTopLeft(check).dx - tester.getTopLeft(row('Value A')).dx, 8);
    expect(textStyle(tester, 'Value A').color, tokens.textPrimary);
    final material = tester.widget<Material>(find.descendant(of: row('Value A'), matching: find.byType(Material)));
    expect(material.color!.a, 0);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('select uses one host, initial current focus, external keyboard ring and Escape restoration', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            return Center(
              child: SizedBox(
                width: 320,
                child: FrostPicker.menu(
                  value: 2,
                  label: 'Select label',
                  options: const [
                    FrostPickerOption(value: 1, label: 'Other'),
                    FrostPickerOption(value: 2, label: 'Chosen'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(find.byType(FrostMenuAnchor), findsOneWidget);
    expect(find.byType(RawMenuAnchor), findsOneWidget);
    final trigger = find.byType(FrostButtonControl);
    Color stroke() =>
        ((tester
                            .renderObject<RenderDecoratedBox>(
                              find
                                  .descendant(
                                    of: trigger,
                                    matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.position == DecorationPosition.foreground),
                                  )
                                  .first,
                            )
                            .decoration
                        as ShapeDecoration)
                    .shape
                as OutlinedBorder)
            .side
            .color;
    expect(stroke().a, 0);
    expect(tester.widget<FrostButtonControl>(trigger).chevron, FrostButtonChevron.upDown);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<FrostMenuItem>(), same(tester.widget(row('Chosen'))));
    expect(tester.getSemantics(find.text('Chosen').last).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    expect(tester.widget<FrostButtonControl>(trigger).focusNode!.hasFocus, true);
    expect(stroke().a, 0);
    expect(frostFocusRings(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select trigger shares field height and padding through text scaling', (tester) async {
    for (final size in FrostControlSize.values) {
      double? padding, unscaled;
      for (final scale in [1.0, 1.5, 2.0]) {
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: FrostPicker.menu(
                    value: 1,
                    options: const [FrostPickerOption(value: 1, label: 'Current')],
                    onChanged: (_) {},
                    size: size,
                    label: 'Choice',
                  ),
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        await tester.pumpAndSettle();
        final frame = tester.getRect(find.byType(FrostClickSurface)), text = tester.getRect(find.text('Current'));
        padding ??= text.top - frame.top;
        unscaled ??= text.height;
        expect(text.top - frame.top, closeTo(frame.bottom - text.bottom, .001));
        expect(text.top - frame.top, closeTo(padding, .001));
        expect(frame.height, size.visualHeight(touch: false) + text.height - unscaled);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('content Picker menu uses a labeled field, up/down and a checked current item', (tester) async {
    const itemIcon = FrostIconData.glyph(IconData(0xe001));
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostPicker.menu(
            value: 1,
            options: const [
              FrostPickerOption(value: 1, label: 'Current', icon: itemIcon),
              FrostPickerOption(value: 2, label: 'Other'),
            ],
            onChanged: (_) {},
            label: 'Choice',
          ),
        ),
      ),
    );
    expect(find.text('Choice'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(tester.widget<FrostButtonControl>(find.byType(FrostButtonControl)).presentation, FrostButtonPresentation.field);
    expect(tester.widget<FrostButtonControl>(find.byType(FrostButtonControl)).chevron, FrostButtonChevron.upDown);
    expect(find.byWidgetPredicate((w) => w is FrostIcon && w.icon == itemIcon), findsOneWidget);
    await tester.tap(find.text('Current'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('Current').last).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
    expect(tester.takeException(), isNull);
  });
}
