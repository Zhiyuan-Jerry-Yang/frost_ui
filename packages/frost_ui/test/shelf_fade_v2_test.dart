import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Finder get shelfMask => find.descendant(of: find.byType(FrostShelf), matching: find.byType(ShaderMask));
ScrollPosition position(WidgetTester tester) =>
    tester.stateList<ScrollableState>(find.byType(Scrollable)).singleWhere((s) => s.position.axis == Axis.horizontal).position;
FrostButton button(WidgetTester tester, String label) => tester.widget<FrostButton>(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.$label'));
Future<void> shelf(WidgetTester tester, {bool rtl = false, bool touch = false, int count = 10, VoidCallback? onTap, GlobalKey? boundary}) {
  final content = RepaintBoundary(
    key: boundary,
    child: FrostShelf(
      title: 'Shelf',
      itemCount: count,
      itemExtent: 100,
      spacing: 0,
      inset: 0,
      height: 100,
      itemBuilder: (_, _) => FrostClickSurface(
        onTap: onTap,
        child: const ColoredBox(color: Colors.red),
      ),
    ),
  );
  return tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(platform: touch ? TargetPlatform.android : TargetPlatform.windows),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 300, child: content),
              ),
            ),
          ),
        ),
      ),
      density: FrostDensity.compact,
    ),
  );
}

Future<List<int>> alphas(WidgetTester tester, GlobalKey boundary) async {
  final origin = tester.getTopLeft(find.byKey(boundary)), mask = tester.getTopLeft(shelfMask);
  final y = (mask.dy - origin.dy + 50).round();
  return (await tester.runAsync(() async {
    final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary)).toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = [
      for (final x in [6, 293]) bytes.getUint8((y * image.width + x) * 4 + 3),
    ];
    image.dispose();
    return result;
  }))!;
}

void main() {
  testWidgets('Shelf shaders grow continuously from 0 to 24 and clear the reached endpoint', (tester) async {
    final boundary = GlobalKey();
    await shelf(tester, boundary: boundary);
    await tester.pumpAndSettle();
    final initial = await alphas(tester, boundary);
    expect(initial.first, 255);
    expect(initial.last, inInclusiveRange(50, 90));
    position(tester).jumpTo(12);
    await tester.pumpAndSettle();
    final halfway = await alphas(tester, boundary);
    expect(halfway.first, inInclusiveRange(125, 150));
    position(tester).jumpTo(24);
    await tester.pumpAndSettle();
    final full = await alphas(tester, boundary);
    expect(full.first, inInclusiveRange(55, 85));
    expect(halfway.first, greaterThan(full.first));
    position(tester).jumpTo(position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    final end = await alphas(tester, boundary);
    expect(end.last, 255);
    expect(end.first, full.first);
    expect(tester.getSize(shelfMask).width, 300);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Shelf RTL mirrors shader edges and the mask never intercepts taps', (tester) async {
    final boundary = GlobalKey();
    var taps = 0;
    await shelf(tester, rtl: true, boundary: boundary, onTap: () => taps++);
    await tester.pumpAndSettle();
    final initial = await alphas(tester, boundary);
    expect(initial.first, inInclusiveRange(55, 85));
    expect(initial.last, 255);
    position(tester).jumpTo(12);
    await tester.pumpAndSettle();
    final moved = await alphas(tester, boundary);
    expect(moved.last, inInclusiveRange(125, 150));
    await tester.tapAt(tester.getTopLeft(shelfMask) + const Offset(6, 50));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
  testWidgets('Pointer paging controls exist on the cold frame, disable at ends, and touch hides them', (tester) async {
    await shelf(tester, count: 2);
    expect(button(tester, 'previous').onPressed, isNull);
    expect(button(tester, 'next').onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    await shelf(tester);
    expect(button(tester, 'previous').onPressed, isNull);
    expect(button(tester, 'next').onPressed, isNotNull);
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.next'));
    await tester.pumpAndSettle();
    expect(position(tester).pixels, greaterThan(0));
    expect(button(tester, 'previous').onPressed, isNotNull);
    position(tester).jumpTo(position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    expect(button(tester, 'next').onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    await shelf(tester, touch: true);
    expect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.previous'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.next'), findsNothing);
  });
}
