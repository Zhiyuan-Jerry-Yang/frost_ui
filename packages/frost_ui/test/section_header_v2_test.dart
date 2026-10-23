import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_control_geometry.dart';
import 'support.dart';

Future<void> headerFrame(
  WidgetTester tester,
  Widget child, {
  FrostDensity density = FrostDensity.compact,
  double scale = 1,
  double width = 500,
  double margin = 20,
  bool rtl = false,
}) {
  final keyline = FrostKeyline(
    leadingRoom: margin,
    trailingRoom: margin,
    edgeDistanceStart: margin,
    edgeDistanceEnd: margin,
    insideContainer: false,
    contentStart: 0,
    child: child,
  );
  final column = SizedBox(
    width: width,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: keyline,
    ),
  );
  return tester.pumpWidget(
    frostTestApp(
      MediaQuery(
        data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Center(child: column),
        ),
      ),
      density: density,
    ),
  );
}

void main() {
  for (final density in FrostDensity.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('section header natural height and same-row actions $density $scale', (tester) async {
        var calls = 0;
        await headerFrame(
          tester,
          FrostSectionHeader(
            title: 'Title',
            onAction: () => calls++,
            trailing: [FrostButton.icon(label: 'Next', icon: testIcons.chevronRight, onPressed: () => calls++)],
          ),
          density: density,
          scale: scale,
          width: 700,
        );
        final header = tester.getRect(find.byType(FrostSectionHeader));
        final context = tester.element(find.text('Title'));
        expect(header.height, frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.headline).height);
        final paragraph = tester.renderObject<RenderParagraph>(find.text('Title'));
        expect(paragraph.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.headline).fontSize);
        expect(paragraph.text.style!.color, FrostThemeTokens.of(context).textPrimary);
        final action = tester.widget<FrostButton>(find.ancestor(of: find.text('L.showAll'), matching: find.byType(FrostButton)));
        expect(action.variant, FrostButtonVariant.plain);
        expect(action.size, FrostControlSize.compact);
        expect(tester.getRect(find.byType(FrostButton).first).center.dy, header.center.dy);
        expect(tester.getRect(find.byType(FrostButton).last).center.dy, header.center.dy);
        expect(tester.getTopLeft(find.text('L.showAll')).dx, lessThan(tester.getTopLeft(find.byType(FrostIcon)).dx));
        expect(tester.hasRunningAnimations, false);
        await tester.tap(find.text('L.showAll'));
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final rtl in [false, true]) {
    for (final margin in [12.0, 20.0]) {
      testWidgets('section last glyph on exact keyline rtl=$rtl margin=$margin', (tester) async {
        var calls = 0;
        await headerFrame(
          tester,
          FrostSectionHeader(
            title: 'Title',
            actionLabel: 'Action',
            onAction: () {},
            trailing: [FrostButton.icon(label: 'Next', icon: testIcons.chevronRight, onPressed: () => calls++)],
          ),
          rtl: rtl,
          margin: margin,
        );
        final header = tester.getRect(find.byType(FrostSectionHeader));
        final title = tester.getRect(find.text('Title'));
        final glyph = tester.getRect(find.byType(FrostIcon));
        expect(rtl ? title.right : title.left, rtl ? header.right : header.left);
        expect(rtl ? glyph.left : glyph.right, rtl ? header.left : header.right);
        final button = tester.getRect(find.byType(FrostButton).last);
        expect(rtl ? button.left : button.right, rtl ? lessThan(header.left) : greaterThan(header.right));
        await tester.tapAt(Offset(rtl ? button.left + 3 : button.right - 3, button.center.dy));
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('section text action alone places its text edge on keyline', (tester) async {
    await headerFrame(tester, FrostSectionHeader(title: 'Title', actionLabel: 'Action', onAction: () {}), width: 400);
    expect(tester.getRect(find.text('Action')).right, tester.getRect(find.byType(FrostSectionHeader)).right);
    expect(tester.takeException(), isNull);
  });
  testWidgets('200% two-line headline grows while actions stay centered on same row', (tester) async {
    await headerFrame(
      tester,
      FrostSectionHeader(
        title: 'A longer section title that wraps onto two lines',
        actionLabel: 'All',
        onAction: () {},
        trailing: [FrostButton.icon(label: 'Next', icon: testIcons.chevronRight, onPressed: () {})],
      ),
      scale: 2,
      width: 400,
    );
    final header = tester.getRect(find.byType(FrostSectionHeader));
    final title = tester.renderObject<RenderParagraph>(find.text('A longer section title that wraps onto two lines'));
    expect(title.maxLines, 2);
    expect(header.height, greaterThan(44));
    expect(tester.getRect(find.byType(FrostButton).first).center.dy, header.center.dy);
    expect(tester.getRect(find.byType(FrostButton).last).center.dy, header.center.dy);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shelf uses SectionHeader, aligned items, paging and action', (tester) async {
    var calls = 0;
    await headerFrame(
      tester,
      FrostShelf(
        title: 'Shelf',
        itemCount: 20,
        itemExtent: 100,
        height: 100,
        inset: 20,
        action: FrostButton(label: 'Action', variant: FrostButtonVariant.plain, onPressed: () => calls++),
        itemBuilder: (_, index) => SizedBox(key: ValueKey(index), child: Text('Item $index')),
      ),
      margin: 0,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostSectionHeader), findsOneWidget);
    expect(tester.getTopLeft(find.text('Shelf')).dx, tester.getTopLeft(find.byKey(const ValueKey(0))).dx);
    final position = tester.stateList<ScrollableState>(find.byType(Scrollable)).singleWhere((state) => state.position.axis == Axis.horizontal).position;
    expect(position.pixels, 0);
    await tester.tap(find.text('Action'));
    expect(calls, 1);
    await tester.tap(findFrostTooltip('L.next'));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    await tester.tap(findFrostTooltip('L.previous'));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
  });
}
