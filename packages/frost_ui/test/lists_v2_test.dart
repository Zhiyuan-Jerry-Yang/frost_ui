import 'dart:ui' show CheckedState, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_list_viewport.dart';
import 'package:frost_ui/src/lists/_row_scope.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'support.dart';

Finder rowSurface(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(FrostListRow)),
  matching: find.byType(FrostClickSurface),
);
BorderRadius rowCorners(WidgetTester tester, String title) => switch (tester.widget<FrostClickSurface>(rowSurface(title)).customBorder) {
  RoundedSuperellipseBorder(:final borderRadius) => borderRadius.resolve(TextDirection.ltr),
  RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(TextDirection.ltr),
  _ => throw StateError('shape'),
};
Color rowFill(WidgetTester tester, String title) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.descendant(of: rowSurface(title), matching: find.byType(FrostInteractionDecoration)).first,
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as ShapeDecoration)
        .color!;
FocusNode listFocus(WidgetTester tester) =>
    tester.widget<Focus>(find.ancestor(of: find.byType(FrostListScrollView), matching: find.byType(Focus)).first).focusNode!;

void main() {
  for (final list in [false, true]) {
    testWidgets('plain row bleed remains visible and clickable through viewport list=$list', (tester) async {
      var calls = 0;
      final row = FrostListRow(title: 'Bleed', onPressed: () => calls++);
      final content = list
          ? FrostList<int>(
              items: List.generate(1000, (i) => i),
              itemBuilder: (_, item, _) => FrostListRow(title: 'Row $item', onPressed: () => calls++),
            )
          : row;
      final keyline = FrostKeyline(
        leadingRoom: 20,
        trailingRoom: 20,
        edgeDistanceStart: 20,
        edgeDistanceEnd: 20,
        insideContainer: false,
        contentStart: 0,
        child: content,
      );
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: keyline),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final surface = tester.getRect(rowSurface(list ? 'Row 0' : 'Bleed'));
      final text = tester.getRect(find.text(list ? 'Row 0' : 'Bleed'));
      final hitInset = FrostGap.of(tester.element(find.text(list ? 'Row 0' : 'Bleed'))).hitInset;
      expect(text.left - surface.left, hitInset);
      if (list) {
        final viewport = tester.getRect(find.byWidgetPredicate((w) => w is Viewport));
        expect(surface.left, viewport.left);
        expect(surface.right, viewport.right);
      }
      await tester.tapAt(Offset(surface.left + 2, surface.center.dy));
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('short selected list shows every row on the cold frame', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: FrostList<int>(
              items: const [0, 1, 2],
              selected: 1,
              onSelected: (_) {},
              itemBuilder: (_, item, _) => FrostListRow(title: 'Row $item'),
            ),
          ),
        ),
      ),
    );
    final viewport = tester.getRect(find.byType(FrostList<int>));
    for (var i = 0; i < 3; i++) {
      final row = tester.getRect(rowSurface('Row $i'));
      expect(row.top, greaterThanOrEqualTo(viewport.top));
      expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('End then Enter before the next frame selects the new mounted target once', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          height: 200,
          child: FrostList<int>(
            items: List.generate(1000, (i) => i),
            onSelected: selected.add,
            itemBuilder: (_, item, _) => FrostListRow(title: 'Row $item'),
          ),
        ),
      ),
    );
    listFocus(tester).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, [999]);
    expect(tester.takeException(), isNull);
  });
  for (final rtl in [false, true]) {
    testWidgets('group actual text keylines, corners, captions and module rtl=$rtl', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 400,
                child: FrostGroupedSection(
                  header: 'Header',
                  footer: 'Footer',
                  children: [
                    FrostListRow(title: 'Icon', icon: testIcons.info, onPressed: () {}),
                    FrostListRow(title: 'Plain', onPressed: () {}),
                    FrostListRow(title: 'Avatar', leading: const SizedBox(width: 40, height: 40), onPressed: () {}),
                    FrostListRow(title: 'Last', onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final surface = tester.widget<FrostSurface>(find.byType(FrostSurface));
      expect(surface.role, FrostSurfaceRole.module);
      expect(surface.edge, FrostSurfaceEdge.none);
      expect(surface.elevated, false);
      expect(surface.borderRadius, FrostRadius.borderRadius(FrostRadius.xl));
      final rect = tester.getRect(find.byType(FrostSurface));
      final inset = FrostGap.of(tester.element(find.text('Plain'))).rowInset;
      double start(Finder finder) {
        final r = tester.getRect(finder);
        return rtl ? rect.right - r.right : r.left - rect.left;
      }

      expect(start(find.text('Plain')), inset);
      expect(start(find.text('Icon')), inset + 36);
      expect(start(find.text('Avatar')), inset + 48);
      expect(start(find.text('Header')), inset);
      expect(start(find.text('Footer')), inset);
      expect(rect.top - tester.getBottomLeft(find.text('Header')).dy, 6);
      expect(tester.getTopLeft(find.text('Footer')).dy - rect.bottom, 6);
      for (final title in ['Icon', 'Plain', 'Avatar', 'Last']) {
        expect(tester.getRect(rowSurface(title)).width, rect.width);
      }
      expect(rowCorners(tester, 'Icon').topLeft.x, FrostRadius.inner(FrostRadius.xl, 0));
      expect(rowCorners(tester, 'Icon').bottomLeft.x, 0);
      expect(rowCorners(tester, 'Plain'), BorderRadius.zero);
      expect(rowCorners(tester, 'Last').bottomLeft.x, FrostRadius.inner(FrostRadius.xl, 0));
      final dividers = find.byType(FrostDivider);
      expect(dividers, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        final leaf = find.descendant(of: dividers.at(i), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget));
        final render = tester.renderObject<RenderBox>(leaf);
        final leading = [inset + 36, inset, inset + 48][i];
        final dpr = tester.view.devicePixelRatio;
        expect(render, paints..line(p1: Offset(rtl ? 0 : leading, .5 / dpr), p2: Offset((rtl ? 0 : leading) + rect.width - leading, .5 / dpr), strokeWidth: 0));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('settings groups share GroupedSection with section spacing', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const SizedBox(
          height: 400,
          child: FrostGroupedSettingsList(
            groups: [
              [FrostListRow(title: 'One')],
              [FrostListRow(title: 'Two')],
            ],
          ),
        ),
      ),
    );
    expect(find.byType(FrostGroupedSection), findsNWidgets(2));
    final a = tester.getRect(find.byType(FrostGroupedSection).first);
    final b = tester.getRect(find.byType(FrostGroupedSection).last);
    expect(b.top - a.bottom, FrostGap.of(tester.element(find.text('One'))).section);
  });
  testWidgets('no initial highlight; Down/Up/Home/End/Enter select exactly once', (tester) async {
    final selected = <int>[];
    var rowCalls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: FrostList<int>(
              items: const [0, 1, 2],
              itemBuilder: (_, item, highlighted) => FrostListRow(title: 'Row $item', onPressed: () => rowCalls++),
              onSelected: selected.add,
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    listFocus(tester).requestFocus();
    await tester.pump();
    expect(tester.widgetList<FrostListItemScope>(find.byType(FrostListItemScope)).where((s) => s.highlighted), isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final tokens = FrostThemeTokens.of(tester.element(find.text('Row 0')));
    expect(rowFill(tester, 'Row 0'), tokens.fillSubtle);
    for (final key in [LogicalKeyboardKey.end, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.home]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    }
    expect(selected, [2, 1, 0]);
    await tester.tap(find.text('Row 1'));
    expect(selected, [2, 1, 0, 1]);
    expect(rowCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('first Up highlights last, null list callback retains row action', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          height: 200,
          child: FrostList<int>(
            items: const [0, 1, 2],
            itemBuilder: (_, item, _) => FrostListRow(title: 'Row $item', onPressed: () => calls++),
          ),
        ),
      ),
    );
    listFocus(tester).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tester.widgetList<FrostListItemScope>(find.byType(FrostListItemScope)).last.highlighted, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.tap(find.text('Row 0'));
    expect(calls, 2);
  });
  testWidgets('selected scope drives actual check and initial keyboard highlight; hover restores keyboard', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          height: 200,
          child: FrostList<int>(
            items: const [0, 1, 2],
            selected: 1,
            onSelected: (_) {},
            itemBuilder: (_, item, _) => FrostListRow(title: 'Row $item'),
          ),
        ),
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.text('Row 1')));
    expect(rowFill(tester, 'Row 1'), tokens.fillSubtle);
    expect(tester.getSemantics(find.bySemanticsLabel('Row 1')).getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
    expect(find.descendant(of: rowSurface('Row 1'), matching: find.byWidgetPredicate((w) => w is FrostIcon && w.color == tokens.selectionInk)), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(799, 599));
    await mouse.moveTo(tester.getCenter(find.text('Row 2')));
    await tester.pumpAndSettle();
    expect(rowFill(tester, 'Row 2'), tokens.fillSubtle);
    expect(tester.widget<FrostListItemScope>(find.ancestor(of: find.text('Row 2'), matching: find.byType(FrostListItemScope))).highlighted, true);
    await mouse.moveTo(const Offset(799, 599));
    await tester.pumpAndSettle();
    expect(tester.widget<FrostListItemScope>(find.ancestor(of: find.text('Row 1'), matching: find.byType(FrostListItemScope))).highlighted, true);
    expect(tester.widget<FrostListItemScope>(find.ancestor(of: find.text('Row 2'), matching: find.byType(FrostListItemScope))).highlighted, false);
    await mouse.removePointer();
    semantics.dispose();
  });
  testWidgets('1000 rows stay lazy; End reveals the last variable-height item', (tester) async {
    final built = <int>{};
    int? selected;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: FrostList<int>(
              items: List.generate(1000, (i) => i),
              dividers: true,
              onSelected: (i) => selected = i,
              itemBuilder: (_, item, _) {
                built.add(item);
                return FrostListRow(title: 'Row $item', subtitle: item.isEven ? 'Longer detail that wraps across several lines in this narrow list' : null);
              },
            ),
          ),
        ),
        density: FrostDensity.compact,
      ),
    );
    expect(built.length, lessThan(30));
    listFocus(tester).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.text('Row 999'), findsOneWidget);
    expect(tester.getRect(find.byType(FrostList<int>)).contains(tester.getCenter(find.text('Row 999'))), true);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, 999);
    expect(built.length, lessThan(60));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disabled highlighted row cannot select on Enter or pointer', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          height: 200,
          child: FrostList<int>(
            items: const [0],
            selected: 0,
            onSelected: (_) => calls++,
            itemBuilder: (_, item, _) => const FrostListRow(title: 'Disabled', enabled: false),
          ),
        ),
      ),
    );
    listFocus(tester).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.tap(find.text('Disabled'), warnIfMissed: false);
    expect(calls, 0);
  });
}
