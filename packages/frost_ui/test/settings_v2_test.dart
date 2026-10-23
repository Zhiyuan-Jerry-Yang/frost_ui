import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/navigation/_navigation_tile.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'package:frost_ui/src/overlays/_menu_target.dart';

import 'support.dart';

const choices = [FrostPickerOption(value: 0, label: 'Automatic'), FrostPickerOption(value: 1, label: 'Manual')];
Color ink(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

void main() {
  for (final reduced in [false, true]) {
    testWidgets('settings row value height transitions obey layout motion, reduced=$reduced', (tester) async {
      int value = 0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduced),
            child: Center(
              child: SizedBox(
                width: 260,
                child: StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    return FrostSettingsSelectTile(
                      icon: testIcons.info,
                      title: 'Mode',
                      value: value,
                      items: const [
                        FrostPickerOption(value: 0, label: 'Auto'),
                        FrostPickerOption(value: 1, label: 'A much longer preference value that wraps across several lines'),
                      ],
                      onChanged: (_) {},
                    );
                  },
                ),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final before = tester.getSize(find.byType(FrostClickSurface)).height;
      update(() => value = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 90));
      final middle = tester.getSize(find.byType(FrostClickSurface)).height;
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byType(FrostClickSurface)).height;
      expect(after, greaterThan(before));
      if (reduced) {
        expect(middle, after);
      } else {
        expect(middle, greaterThan(before));
        expect(middle, lessThan(after));
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final tapValue in [false, true]) {
    testWidgets('settings ${tapValue ? 'value' : 'whole row'} opens the same menu at the value', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 460,
              child: FrostSettingsSelectTile(icon: testIcons.info, title: 'Mode', value: 0, items: choices, onChanged: (value) => selected = value),
            ),
          ),
        ),
      );
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(FrostPicker<int>), findsNothing);
      final tokens = FrostThemeTokens.of(tester.element(find.text('Mode')));
      expect(ink(tester, 'Mode'), tokens.textPrimary);
      expect(ink(tester, 'Automatic'), tokens.textSecondary);
      final icons = tester.widgetList<FrostIcon>(find.descendant(of: find.byType(FrostSettingsSelectTile<int>), matching: find.byType(FrostIcon))).toList();
      expect(icons.map((icon) => icon.color), [tokens.textSecondary, tokens.textTertiary]);
      final target = tester.widget<FrostMenuTarget>(find.byType(FrostMenuTarget)).targetKey!;
      expect(
        tester.getBottomRight(find.byKey(target)).dx,
        tester.getBottomRight(find.byType(FrostClickSurface)).dx - FrostGap.of(tester.element(find.text('Mode'))).rowInset,
      );
      final origin = tester.getBottomLeft(find.byKey(target));
      await tester.tap(find.text(tapValue ? 'Automatic' : 'Mode'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(FrostMenuPanel)), origin);
      expect(tester.getSize(find.byType(FrostMenuPanel)).width, greaterThanOrEqualTo(tester.getSize(find.byKey(target)).width));
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.byType(FrostMenuPanel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('settings semantics is one button with a value; disabled cannot focus or open', (tester) async {
    final semantics = tester.ensureSemantics();
    Future<void> show(bool enabled) => tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 460,
            child: FrostSettingsSelectTile(icon: testIcons.info, title: 'Mode', value: 0, items: choices, onChanged: (_) {}, enabled: enabled),
          ),
        ),
      ),
    );
    await show(true);
    final node = tester.getSemantics(find.bySemanticsLabel('Mode'));
    expect(node.getSemanticsData().label, 'Mode');
    expect(node.getSemanticsData().value, 'Automatic');
    expect(node.getSemanticsData().flagsCollection.isButton, true);
    expect(node.childrenCount, 0);
    await show(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .renderObject<RenderFrostContentFade>(find.descendant(of: find.byType(FrostAnimatedMaterialReveal), matching: find.byType(FrostContentFade)).first)
          .opacity,
      .38,
    );
    final surface = tester.widget<FrostClickSurface>(find.byType(FrostClickSurface));
    expect(surface.onTap, isNull);
    expect(surface.focusNode!.canRequestFocus, false);
    await tester.tap(find.text('Mode'));
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('large settings text grows and wraps without clipping', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600), textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 360,
              child: FrostSettingsSelectTile.values(
                icon: testIcons.info,
                title: 'Preferred application language',
                value: 0,
                values: const [0],
                label: (_) => 'Use system preferences',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FrostClickSurface)).height, greaterThan(80));
    for (final label in ['Preferred application language', 'Use system preferences']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, false);
      expect(tester.getRect(find.byType(FrostClickSurface)).contains(tester.getBottomLeft(find.text(label))), true);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings sections share the sidebar tile and arrows move focus before Enter selects', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      frostTestApp(
        FrostSettingsSections(
          labels: const ['General', 'About'],
          groups: const [
            [Text('General content')],
            [Text('About content')],
          ],
        ),
      ),
    );
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FrostNavigationTile), findsNWidgets(2));
    final tiles = tester.widgetList<FrostNavigationTile>(find.byType(FrostNavigationTile)).toList();
    final tokens = FrostThemeTokens.of(tester.element(find.text('General')));
    expect(ink(tester, 'General'), tokens.selectionInk);
    expect(ink(tester, 'About'), tokens.textSecondary);
    tiles.first.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tiles.last.focusNode!.hasPrimaryFocus, true);
    expect(find.text('General content'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final middle = ink(tester, 'About');
    expect(middle, isNot(tokens.textSecondary));
    expect(middle, isNot(tokens.selectionInk));
    await tester.pumpAndSettle();
    expect(find.text('About content'), findsOneWidget);
    expect(ink(tester, 'About'), tokens.selectionInk);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tiles.first.focusNode!.hasPrimaryFocus, true);
    expect(find.text('About content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
