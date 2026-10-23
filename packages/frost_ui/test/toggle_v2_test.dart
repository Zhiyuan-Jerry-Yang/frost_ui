import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'display_badges_v2_test.dart' show display;
import 'support.dart';

void main() {
  test('button toggle requires an icon and rejects a subtitle', () {
    expect(() => FrostToggle(value: false, onChanged: (_) {}, label: 'Toggle', style: FrostToggleStyle.button), throwsAssertionError);
    expect(
      () => FrostToggle(value: false, onChanged: (_) {}, label: 'Toggle', icon: testIcons.eye, subtitle: 'Detail', style: FrostToggleStyle.button),
      throwsAssertionError,
    );
  });
  for (final style in FrostToggleStyle.values) {
    for (final density in FrostDensity.values) {
      testWidgets('Toggle $style delegates the original geometry and semantics at $density', (tester) async {
        var changed = false;
        await display(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostToggle(value: true, onChanged: (v) => changed = !v, label: 'Toggle', icon: testIcons.eye, style: style),
              switch (style) {
                FrostToggleStyle.switchRow => FrostListRow.toggle(title: 'Reference', icon: testIcons.eye, value: true, onChanged: (_) {}),
                FrostToggleStyle.checkbox => FrostCheckboxRow(title: 'Reference', value: true, onChanged: (_) {}),
                FrostToggleStyle.button => FrostButton.icon(icon: testIcons.eye, label: 'Reference', selected: true, onPressed: () {}),
              },
            ],
          ),
          density: density,
        );
        final toggle = find.byType(FrostToggle),
            reference = switch (style) {
              FrostToggleStyle.switchRow => find.byType(FrostListRow).last,
              FrostToggleStyle.checkbox => find.byType(FrostCheckboxRow).last,
              FrostToggleStyle.button => find.byType(FrostButton).last,
            };
        expect(tester.getSize(toggle), tester.getSize(reference));
        final first = tester.getSemantics(find.bySemanticsLabel('Toggle')).getSemanticsData().flagsCollection;
        final second = tester.getSemantics(find.bySemanticsLabel('Reference')).getSemanticsData().flagsCollection;
        expect(first.isChecked, second.isChecked);
        expect(first.isToggled, second.isToggled);
        expect(first.isSelected, second.isSelected);
        await tester.tap(toggle);
        expect(changed, true);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('button icon snapshots crossfade without a selection scale reset', (tester) async {
    const selectedIcon = FrostIconData.glyph(IconData(0xe002));
    var value = false;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, update) => FrostToggle(
          value: value,
          onChanged: (v) => update(() => value = v),
          label: 'Favorite',
          style: FrostToggleStyle.button,
          icon: testIcons.eye,
          selectedIcon: selectedIcon,
        ),
      ),
    );
    await tester.tap(find.byType(FrostToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.widget<FrostButtonControl>(find.byType(FrostButtonControl)).selected, true);
    expect(tester.widget<FrostIcon>(find.byType(FrostIcon)).icon, selectedIcon);
    expect(
      tester.widgetList<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).any((w) => w.opacity.value > 0 && w.opacity.value < 1),
      true,
    );
    expect(tester.widgetList<ScaleTransition>(find.byType(ScaleTransition)).every((w) => w.scale.value == 1), true);
    await tester.pumpAndSettle();
    expect(value, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scope disabled toggles preserve every underlying disabled path', (tester) async {
    var calls = 0;
    await display(
      tester,
      FrostControlScope(
        enabled: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final style in FrostToggleStyle.values)
              FrostToggle(value: false, onChanged: (_) => calls++, label: '$style', style: style, icon: testIcons.eye),
          ],
        ),
      ),
    );
    for (final element in find.byType(FrostToggle).evaluate()) {
      await tester.tap(find.byWidget(element.widget), warnIfMissed: false);
    }
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
