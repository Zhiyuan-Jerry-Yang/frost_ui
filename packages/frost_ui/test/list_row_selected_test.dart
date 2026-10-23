import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final task in [false, true]) {
    testWidgets('full row background includes independent trailing controls task=$task', (tester) async {
      var opens = 0, actions = 0;
      final control = SizedBox(
        width: 72,
        child: FrostButton(label: 'Retry', onPressed: () => actions++),
      );
      final Widget row = task
          ? FrostTaskRow(title: 'Task', status: FrostTaskStatus.running, progress: .4, selected: true, trailing: control, onPressed: () => opens++)
          : FrostListRow(title: 'Task', selected: true, trailing: control, onPressed: () => opens++);
      await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 360, child: row))));
      final root = find.byType(FrostListRow);
      final tokens = FrostThemeTokens.of(tester.element(root));
      final fills = find.descendant(
        of: root,
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is ShapeDecoration && (w.decoration as ShapeDecoration).color == tokens.selectionFill,
        ),
      );
      expect(fills, findsOneWidget);
      expect(tester.getRect(fills), tester.getRect(root));
      expect(tester.getRect(find.text('Retry')).right, lessThanOrEqualTo(tester.getRect(fills).right));
      expect(tester.getSemantics(find.bySemanticsLabel('Retry')).getSemanticsData().flagsCollection.isButton, true);
      await tester.tap(find.text('Retry'));
      expect(actions, 1);
      expect(opens, 0);
      await tester.tap(find.text('Task'));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    testWidgets('plain and task rows share selection paint and preserve activation $direction', (tester) async {
      var selected = false;
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 360,
              child: Directionality(
                textDirection: direction,
                child: StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FrostListRow(
                          key: const ValueKey('saved'),
                          title: 'Saved task',
                          subtitle: 'Source · Size · Time',
                          selected: selected,
                          onPressed: () => calls++,
                        ),
                        FrostTaskRow(
                          key: const ValueKey('running'),
                          title: 'Active task',
                          detail: 'Source · Size · Speed',
                          status: FrostTaskStatus.running,
                          progress: .4,
                          selected: selected,
                          onPressed: () => calls++,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final plain = find.byKey(const ValueKey('saved'));
      final task = find.byKey(const ValueKey('running'));
      final tokens = FrostThemeTokens.of(tester.element(plain));
      final state = tester.state(plain);
      Color fill(Finder root) => tester
          .renderObjectList<RenderDecoratedBox>(find.descendant(of: root, matching: find.byType(DecoratedBox)))
          .map((r) => r.decoration)
          .whereType<ShapeDecoration>()
          .first
          .color!;
      Color ink(String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;
      expect(fill(plain).a, 0);
      expect(tester.getSemantics(plain).getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
      update(() => selected = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(fill(plain), fill(task));
      expect(fill(plain).a, inExclusiveRange(0, tokens.selectionFill.a));
      expect(ink('Saved task'), ink('Active task'));
      expect(ink('Source · Size · Time'), ink('Source · Size · Speed'));
      await tester.pump(const Duration(milliseconds: 70));
      expect(fill(plain), tokens.selectionFill);
      expect(ink('Saved task'), tokens.selectionInk);
      expect(ink('Source · Size · Time'), tokens.selectionInk);
      expect(tester.getSemantics(plain).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(find.byType(FrostCheckbox), findsNothing);
      expect(tester.state(plain), same(state));
      await tester.tap(find.text('Saved task'));
      expect(calls, 1);
      update(() => selected = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(fill(plain), fill(task));
      expect(fill(plain).a, inExclusiveRange(0, tokens.selectionFill.a));
      await tester.pumpAndSettle();
      expect(fill(plain).a, 0);
      expect(tester.state(plain), same(state));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('contiguous selected fill occupies the row while separators remain outside it', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: SizedBox(
            width: 360,
            child: FrostGroupedSection(
              children: [
                FrostListRow(title: 'Before'),
                FrostListRow(key: ValueKey('selected'), title: 'Selected', selected: true),
                FrostTaskRow(title: 'After', status: FrostTaskStatus.completed),
              ],
            ),
          ),
        ),
      ),
    );
    final row = find.byKey(const ValueKey('selected'));
    final bounds = tester.getRect(row);
    final tokens = FrostThemeTokens.of(tester.element(row));
    final fills = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == tokens.selectionFill,
      ),
    );
    expect(fills, findsOneWidget);
    expect(tester.getRect(fills), bounds);
    for (final separator in find.byType(FrostDivider).evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((element) => identical(element, separator)));
      expect(rect.overlaps(bounds), isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}
