import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Rect visibleBounds(RenderBox box) {
  var visible = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
  RenderObject child = box;
  while (child.parent != null) {
    final parent = child.parent!;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) visible = visible.intersect(MatrixUtils.transformRect(parent.getTransformTo(null), clip));
    child = parent;
  }
  return visible;
}

void main() {
  for (final direction in TextDirection.values) {
    for (final density in FrostDensity.values) {
      for (final inHeader in [false, true]) {
        testWidgets('leading label complete and on keyline header=$inHeader $direction ${density.name}', (tester) async {
          const title = '最近收藏';
          await tester.pumpWidget(
            frostTestApp(
              Directionality(
                textDirection: direction,
                child: FrostCollectionLayout(
                  header: FrostPageHeader(title: inHeader ? const FrostLabel(title: title) : const Text('Heading')),
                  toolbar: inHeader ? null : const FrostToolbar(leading: [FrostLabel(title: title)]),
                  slivers: const [SliverToBoxAdapter(child: SizedBox(key: ValueKey('keyline'), height: 1))],
                ),
              ),
              density: density,
            ),
          );
          final text = tester.renderObject<RenderParagraph>(find.text(title));
          final rect = MatrixUtils.transformRect(text.getTransformTo(null), Offset.zero & text.size);
          final line = tester.getRect(find.byKey(const ValueKey('keyline')));
          expect(direction == TextDirection.ltr ? rect.left : rect.right, closeTo(direction == TextDirection.ltr ? line.left : line.right, .001));
          expect(text.didExceedMaxLines, isFalse);
          final boxes = text.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4));
          expect(boxes, isNotEmpty);
          final visible = visibleBounds(text);
          for (final box in boxes) {
            final glyph = MatrixUtils.transformRect(text.getTransformTo(null), box.toRect());
            expect(visible.left, lessThanOrEqualTo(glyph.left + .001));
            expect(visible.right, greaterThanOrEqualTo(glyph.right - .001));
            expect(visible.top, lessThanOrEqualTo(glyph.top + .001));
            expect(visible.bottom, greaterThanOrEqualTo(glyph.bottom - .001));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
    for (final count in [3, 4]) {
      for (final dpr in [1.0, 1.25, 1.5]) {
        testWidgets('stat strip paints all $count separators visibly $direction dpr=$dpr', (tester) async {
          final key = GlobalKey();
          await tester.pumpWidget(
            frostTestApp(
              MediaQuery(
                data: MediaQueryData(size: const Size(800, 600), devicePixelRatio: dpr, textScaler: const TextScaler.linear(1.01)),
                child: Directionality(
                  textDirection: direction,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: RepaintBoundary(
                        key: key,
                        child: ColoredBox(
                          color: Colors.white,
                          child: SizedBox(
                            width: 700,
                            child: FrostCollectionLayout(
                              header: const FrostPageHeader(title: Text('Collection')),
                              toolbar: const FrostToolbar(leading: [FrostLabel(title: '最近收藏')]),
                              slivers: const [],
                              stats: [
                                const FrostStat(value: '128', caption: '作品'),
                                const FrostStat(value: '12', caption: '集合'),
                                const FrostStat(value: '3', caption: '本周新增'),
                                if (count == 4) const FrostStat(value: '24', caption: '下载'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              density: FrostDensity.compact,
            ),
          );
          final strip = tester.getRect(find.byType(FrostStatStrip));
          final dividers = find.byType(FrostDivider);
          expect(dividers, findsNWidgets(count - 1));
          for (var i = 0; i < count - 1; i++) {
            final line = tester.getRect(dividers.at(i));
            final before = tester.getRect(find.byType(FrostStat).at(i));
            final after = tester.getRect(find.byType(FrostStat).at(i + 1));
            expect(line.height, strip.height);
            expect(line.top, strip.top);
            expect(line.width, closeTo(1 / dpr, .001));
            expect(direction == TextDirection.ltr ? line.left - before.right : before.left - line.right, closeTo(16, .001));
            expect(direction == TextDirection.ltr ? after.left - line.right : line.left - after.right, closeTo(16, .001));
          }
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await tester.runAsync(() => boundary.toImage(pixelRatio: dpr));
          final bytes = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!.buffer.asUint8List();
          final ink = Color.alphaBlend(FrostThemeTokens.of(tester.element(find.byType(FrostStatStrip))).separator, Colors.white);
          final expected = [(ink.r * 255).round(), (ink.g * 255).round(), (ink.b * 255).round()];
          // Count full-height painted runs after compositing/clipping. Drawing
          // commands alone cannot prove that a hairline survives rasterization.
          var runs = 0, previous = false;
          for (var x = 0; x < image!.width; x++) {
            var line = true;
            for (
              var y = ((strip.top - boundary.localToGlobal(Offset.zero).dy) * dpr).ceil() + 1;
              y < ((strip.bottom - boundary.localToGlobal(Offset.zero).dy) * dpr).floor() - 1;
              y++
            ) {
              final offset = (y * image.width + x) * 4;
              if (List.generate(3, (c) => (bytes[offset + c] - expected[c]).abs()).any((delta) => delta > 1)) {
                line = false;
                break;
              }
            }
            if (line && !previous) runs++;
            previous = line;
          }
          expect(runs, count - 1);
          image.dispose();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
