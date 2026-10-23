import 'dart:ui' show FontFeature, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/progress.dart' show FrostProgressPainter;
import 'package:frost_ui/src/motion/_material_reveal.dart' show RenderFrostContentFade;
import 'package:frost_ui/src/navigation/_destination_status.dart' show FrostDestinationTrailing;

import 'support.dart';

FrostNavDestination destination({int badge = 0, double? progress}) =>
    FrostNavDestination(icon: testIcons.download, label: 'Downloads', badge: badge, progress: progress);

Widget shell(
  FrostNavDestination status, {
  bool expanded = false,
  bool selected = true,
  bool indicator = false,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: direction,
      child: FrostShell(
        destinations: [status],
        selectedIndex: selected ? 0 : null,
        atDestinationRoot: true,
        onDestinationSelected: (_) {},
        canGoBack: false,
        onBack: () {},
        showsMobileNavigation: true,
        initiallyExpanded: expanded,
        sidebarStyle: indicator ? const FrostSidebarStyle.flush(itemForm: FrostNavItemForm.indicator) : const FrostSidebarStyle.inset(),
        child: const FrostShellDestination(child: SizedBox.expand()),
      ),
    ),
  ),
);

void size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double opacityOf(WidgetTester tester, Finder finder) {
  double opacity = 1;
  RenderObject? object = tester.element(finder).findRenderObject();
  while (object != null) {
    if (object is RenderOpacity) opacity *= object.opacity;
    if (object is RenderAnimatedOpacity) opacity *= object.opacity.value;
    if (object is RenderFrostContentFade) opacity *= object.opacity;
    object = object.parent;
  }
  return opacity;
}

Finder get ringDrawing => find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is FrostProgressPainter);
FrostProgressPainter painter(WidgetTester tester) => tester.widget<CustomPaint>(ringDrawing).painter! as FrostProgressPainter;

void main() {
  test('progress rejects values outside the determinate range', () {
    for (final value in [-.1, 1.1, double.nan, double.infinity]) {
      expect(() => destination(progress: value), throwsAssertionError);
    }
    expect(destination(progress: 0).progress, 0);
    expect(destination(progress: 1).progress, 1);
  });

  for (final indicator in [false, true]) {
    for (final selected in [false, true]) {
      testWidgets('expanded count, ring, ink and merged semantics indicator=$indicator selected=$selected', (tester) async {
        size(tester, 1400);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          frostTestApp(
            shell(destination(badge: 7, progress: .42), expanded: true, selected: selected, indicator: indicator),
            density: FrostDensity.compact,
          ),
        );
        expect(find.byType(FrostProgressRing), findsOneWidget);
        expect(tester.getSize(ringDrawing), const Size.square(16));
        final trailing = find.byType(FrostDestinationTrailing);
        final digits = find.descendant(of: trailing, matching: find.byType(FrostRollingText));
        final count = tester.widget<FrostRollingText>(digits);
        final ink = tester.widget<FrostIcon>(find.descendant(of: find.byType(FrostNavItem), matching: find.byType(FrostIcon)).first).color;
        expect(count.text, '7');
        expect(count.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(count.style!.fontSize, FrostTypography.of(tester.element(trailing)).style(FrostTextRole.footnote).fontSize);
        expect(count.style!.color, ink);
        expect(painter(tester).ink, ink);
        expect(tester.getTopLeft(ringDrawing).dx - tester.getBottomRight(digits).dx, closeTo(6, .001));
        expect(opacityOf(tester, find.byType(FrostCountBadge)), 0);
        final data = tester.getSemantics(find.bySemanticsLabel('Downloads, L.navigationStatus(7,42)')).getSemanticsData();
        expect(data.flagsCollection.isSelected, selected ? Tristate.isTrue : Tristate.isFalse);
        expect(data.flagsCollection.isButton, true);
        expect(data.value, isEmpty);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  for (final width in [800.0, 390.0]) {
    testWidgets('icon navigation only paints count width=$width', (tester) async {
      size(tester, width);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(frostTestApp(shell(destination(badge: 7, progress: .42)), density: FrostDensity.compact));
      expect(find.byType(FrostProgressRing), findsNothing);
      final badge = find.byType(FrostCountBadge);
      expect(opacityOf(tester, badge), 1);
      expect(tester.widget<FrostCountBadge>(badge).count, 7);
      expect(find.bySemanticsLabel('Downloads, L.navigationStatus(7,42)'), findsOneWidget);
      await tester.pumpWidget(frostTestApp(shell(destination(progress: .42)), density: FrostDensity.compact));
      await tester.pumpAndSettle();
      expect(find.byType(FrostRollingText), findsNothing);
      expect(find.byType(FrostProgressRing), findsNothing);
      expect(find.bySemanticsLabel('Downloads, L.navigationStatus(0,42)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final width in [1400.0, 800.0, 390.0]) {
    testWidgets('status enters and exits through intermediate frames width=$width', (tester) async {
      size(tester, width);
      final state = ValueNotifier(destination());
      addTearDown(state.dispose);
      await tester.pumpWidget(
        frostTestApp(
          ValueListenableBuilder(
            valueListenable: state,
            builder: (_, value, _) => shell(value, expanded: width == 1400),
          ),
          density: FrostDensity.compact,
        ),
      );
      expect(find.byType(FrostRollingText), findsNothing);
      state.value = destination(badge: 7, progress: .2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final digits = width == 1400
          ? find.descendant(of: find.byType(FrostDestinationTrailing), matching: find.byType(FrostRollingText))
          : find.byType(FrostRollingText);
      expect(opacityOf(tester, digits), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, digits), 1);
      if (width == 1400) {
        state.value = destination(badge: 8, progress: .8);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(painter(tester).value, inExclusiveRange(.2, .8));
        expect(tester.widget<FrostRollingText>(digits).text, '8');
        await tester.pumpAndSettle();
        expect(painter(tester).value, closeTo(.8, .001));
      }
      state.value = destination();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(opacityOf(tester, digits), inExclusiveRange(0, 1));
      expect(tester.widget<FrostRollingText>(digits).text, width == 1400 ? '8' : '7');
      await tester.pumpAndSettle();
      expect(find.byType(FrostRollingText), findsNothing);
      expect(find.byType(FrostProgressRing), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expanded ring remains independent when count is zero', (tester) async {
    size(tester, 1400);
    await tester.pumpWidget(frostTestApp(shell(destination(progress: .5), expanded: true), density: FrostDensity.compact));
    expect(find.byType(FrostProgressRing), findsOneWidget);
    expect(find.byType(FrostRollingText), findsNothing);
    expect(painter(tester).value, .5);
  });

  testWidgets('large text, RTL and sidebar expansion preserve layout', (tester) async {
    size(tester, 1400);
    await tester.pumpWidget(
      frostTestApp(shell(destination(badge: 12, progress: .5), expanded: true, scale: 2, direction: TextDirection.rtl), density: FrostDensity.compact),
    );
    final digits = find.descendant(of: find.byType(FrostDestinationTrailing), matching: find.byType(FrostRollingText));
    expect(tester.getCenter(ringDrawing).dx, lessThan(tester.getCenter(digits).dx));
    await tester.tap(findFrostTooltip('L.collapseNavigation'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(opacityOf(tester, find.byType(FrostCountBadge)), 1);
  });
}
