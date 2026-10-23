import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  Widget app(Widget child, {TextDirection direction = TextDirection.ltr}) => frostTestApp(
    Directionality(
      textDirection: direction,
      child: Center(child: child),
    ),
    density: FrostDensity.compact,
  );
  Finder active(WidgetTester tester, {bool onMedia = false}) {
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostPageIndicator)));
    return find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == (onMedia ? tokens.onMediaInk : tokens.textPrimary),
    );
  }

  testWidgets('dot geometry and snappy position/width intermediate frames', (tester) async {
    var current = 0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostPageIndicator(count: 3, current: current);
          },
        ),
      ),
    );
    expect(tester.getSize(find.byType(FrostPageIndicator)), const Size(40, 6));
    expect(tester.getSize(active(tester)), const Size(16, 6));
    final start = tester.getTopLeft(active(tester)).dx;
    current = 1;
    update(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final middle = tester.getTopLeft(active(tester)).dx;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(start + 12));
    expect(tester.getSize(active(tester)).width, inExclusiveRange(6, 16));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(active(tester)).dx, start + 12);
    expect(tester.getSize(active(tester)).width, 16);
    final dots = find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && w != tester.widget(active(tester)));
    expect(tester.getCenter(dots.at(0)).dx, start + 3);
    expect(tester.getCenter(dots.at(2)).dx, start + 37);
  });

  for (final direction in TextDirection.values) {
    testWidgets('nonoverlapping hit band reaches both half-gap ends in $direction', (tester) async {
      var selected = -1;
      await tester.pumpWidget(app(FrostPageIndicator(count: 3, current: 0, onSelected: (value) => selected = value), direction: direction));
      final box = tester.getRect(find.byType(FrostPageIndicator));
      final context = tester.element(find.byType(FrostPageIndicator));
      expect(box.width, 46);
      expect(box.height, FrostDensity.of(context).targetHeight);
      for (final (x, expected) in [(0.1, 0), (19.6, 1), (45.9, 2)]) {
        await tester.tapAt(Offset(direction == TextDirection.ltr ? box.left + x : box.right - x, box.center.dy));
        expect(selected, expected);
      }
      final semantics = tester.ensureSemantics();
      final data = tester.getSemantics(find.byType(FrostPageIndicator)).getSemanticsData();
      expect(data.value, '1 of 3');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      semantics.dispose();
    });
  }

  testWidgets('onMedia colors, localized tabular text and hidden singleton/empty', (tester) async {
    await tester.pumpWidget(app(const FrostPageIndicator(count: 3, current: 1, onMedia: true)));
    expect(tester.getSize(active(tester, onMedia: true)).width, 16);
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostPageIndicator)));
    final inactive = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == tokens.onMediaInk.withValues(alpha: .4),
    );
    expect(inactive, findsNWidgets(3));
    await tester.pumpWidget(app(const FrostPageIndicator(count: 15, current: 11, onMedia: true)));
    final paragraph = tester.renderObject<RenderParagraph>(find.text('12 of 15'));
    expect(paragraph.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(paragraph.text.style!.color, tokens.onMediaInk);
    for (final count in [0, 1]) {
      await tester.pumpWidget(app(FrostPageIndicator(count: count, current: 0)));
      expect(find.byType(DecoratedBox), findsNothing);
      expect(find.text('1 of $count'), findsNothing);
    }
  });
}
