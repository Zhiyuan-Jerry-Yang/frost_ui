import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

const _options = [FrostPickerOption(value: 0, label: 'Automatic'), FrostPickerOption(value: 1, label: 'Manual')];

void main() {
  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    for (final direction in TextDirection.values) {
      testWidgets('all text-only settings rows share the inset and dividers: $density/$direction', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: SizedBox(
                  width: 500,
                  child: FrostGroupedSection(
                    children: [
                      FrostSettingsSelectTile(title: 'Mode', value: 0, items: _options, onChanged: (_) {}),
                      FrostListRow.toggle(title: 'Reduce', value: false, onChanged: (_) {}),
                      FrostListRow(
                        title: 'Count',
                        trailing: FrostStepper(value: 2, min: 1, max: 8, semanticLabel: 'Count', onChanged: (_) {}),
                      ),
                      FrostListRow(title: 'Open', accessory: FrostRowAccessory.chevron, onPressed: () {}),
                    ],
                  ),
                ),
              ),
            ),
            density: density,
          ),
        );
        final context = tester.element(find.text('Mode'));
        final inset = FrostGap.of(context).rowInset;
        final group = tester.getRect(find.byType(FrostGroupedSection));
        for (final title in ['Mode', 'Reduce', 'Count', 'Open']) {
          final rect = tester.getRect(find.text(title));
          expect(direction == TextDirection.ltr ? rect.left - group.left : group.right - rect.right, closeTo(inset, .001));
        }
        final separators = find.byType(FrostDivider).evaluate().where((e) => (e.widget as FrostDivider).axis == Axis.horizontal).toList();
        expect(separators, hasLength(3));
        for (final divider in separators) {
          final leaf = find.descendant(
            of: find.byElementPredicate((element) => identical(element, divider)),
            matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget),
          );
          final render = tester.renderObject<RenderBox>(leaf);
          expect(
            render,
            paints..line(
              p1: Offset(direction == TextDirection.ltr ? inset : 0, .5 / tester.view.devicePixelRatio),
              p2: Offset((direction == TextDirection.ltr ? inset : 0) + render.size.width - inset, .5 / tester.view.devicePixelRatio),
              strokeWidth: 0,
            ),
          );
        }
        expect(tester.widget<FrostSettingsSelectTile<int>>(find.byType(FrostSettingsSelectTile<int>)).icon, isNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('values constructor without icon keeps whole-row focus and selection', (tester) async {
    var selected = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 460,
            child: FrostSettingsSelectTile<int>.values(
              title: 'Mode',
              value: selected,
              values: const [0, 1],
              label: (value) => value == 0 ? 'Automatic' : 'Manual',
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    final data = tester.getSemantics(find.bySemanticsLabel('Mode')).getSemanticsData();
    expect(data.value, 'Automatic');
    expect(data.flagsCollection.isButton, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widget<FrostClickSurface>(find.byType(FrostClickSurface)).focusNode!.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.widget<FrostClickSurface>(find.byType(FrostClickSurface)).focusNode!.hasFocus, true);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
