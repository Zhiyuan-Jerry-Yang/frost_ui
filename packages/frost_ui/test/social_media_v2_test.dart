import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_media_shape.dart';

import 'media_frame_test.dart' show ControlledImage;
import 'media_test_image.dart';
import 'support.dart';

Widget host(Widget child, {bool rtl = false}) => frostTestApp(
  Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 320, child: child),
    ),
  ),
);
void main() {
  testWidgets('link successful image stays in shared fade path with live pixels', (tester) async {
    final image = ControlledImage();
    await tester.pumpWidget(host(FrostLinkCard(title: 'Loaded', url: Uri.parse('https://example.org'), image: image)));
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    await tester.pump(FrostMotion.imageFade);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(find.byType(FrostMediaFrame), findsOneWidget);
    expect(FrostMediaInnerStroke.of(tester.element(find.byType(FrostMediaFrame))), isFalse);
    expect(
      tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(DecoratedBox)))
          .where((w) => w.decoration is ShapeDecoration),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
  for (final style in FrostLinkCardStyle.values) {
    testWidgets('link $style uses Module surface, real text slots and no missing-image space', (tester) async {
      final uri = Uri.parse('https://example.org/path?query=hidden');
      await tester.pumpWidget(host(FrostLinkCard(title: 'Title', description: 'Description', url: uri, style: style)));
      expect(find.text('example.org'), findsOneWidget);
      expect(find.textContaining('/path'), findsNothing);
      expect(find.byType(FrostMediaFrame), findsNothing);
      final title = tester.getRect(find.text('Title'));
      expect(title.left, 16);
      expect(title.top, 16);
      final surface = tester.widget<FrostSurface>(find.byType(FrostSurface));
      expect(surface.role, FrostSurfaceRole.module);
      expect(surface.borderRadius, FrostRadius.borderRadius(FrostRadius.lg));
      final description = tester.getRect(find.text('Description'));
      expect(description.top - title.bottom, 4);
    });
    testWidgets('link $style fails to genuinely missing, then handles provider replacement', (tester) async {
      final image = ControlledImage(), replacement = ControlledImage();
      Widget card(ControlledImage provider) => host(FrostLinkCard(title: 'Title', url: Uri.parse('https://example.org/path'), image: provider, style: style));
      await tester.pumpWidget(card(image));
      final withImage = tester.getSize(find.byType(FrostLinkCard)).height;
      final frame = tester.getSize(find.byType(FrostMediaFrame));
      if (style == FrostLinkCardStyle.row) {
        expect(frame, const Size(64, 64));
        expect(tester.getTopLeft(find.text('Title')).dx, 16 + 64 + 8);
      } else {
        expect(frame.width / frame.height, closeTo(1.91, .001));
      }
      image.completer.fail(StateError('failed'));
      await tester.pump();
      expect(find.byType(FrostMediaFrame), findsNothing);
      expect(tester.getSize(find.byType(FrostLinkCard)).height, lessThan(withImage));
      await tester.pumpWidget(card(replacement));
      expect(find.byType(FrostMediaFrame), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      replacement.completer.fail(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
    testWidgets('explicit link skeleton $style takes all content, no semantic leakage', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(FrostLinkCard.skeleton(style: style, image: true, title: 'Caller title', description: null, host: 'caller.host')));
      expect(find.byType(FrostMediaFrame), findsOneWidget);
      expect(find.bySemanticsLabel('L.loading'), findsOneWidget);
      expect(find.bySemanticsLabel('Caller title'), findsNothing);
      await tester.pumpWidget(
        host(FrostLinkCard.skeleton(style: style, image: false, title: 'Caller title', description: 'Caller detail', host: 'caller.host')),
      );
      expect(find.byType(FrostMediaFrame), findsNothing);
      expect(find.text('Caller detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  for (final count in [1, 2, 3, 4, 6]) {
    testWidgets('mosaic $count geometry, callbacks, outer corners and +N', (tester) async {
      final images = List.generate(count, (_) => ControlledImage());
      final selected = <int>[];
      await tester.pumpWidget(host(FrostMediaMosaic(images: images, onPressed: selected.add, semanticLabel: (index) => 'Image $index')));
      final cells = find.byType(FrostMediaFrame);
      expect(cells, findsNWidgets(count.clamp(1, 4)));
      final total = tester.getSize(find.byType(FrostMediaMosaic));
      expect(total.width, 320);
      expect(total.width / total.height, closeTo(count == 1 ? 1 : 16 / 9, .001));
      final rects = [for (var i = 0; i < count.clamp(1, 4); i++) tester.getRect(cells.at(i))];
      if (count > 1) expect(rects[1].left - rects[0].right, 2);
      if (count == 3) {
        expect(rects[0].height, total.height);
        expect(rects[2].top - rects[1].bottom, 2);
      }
      if (count >= 4) expect(rects[2].top - rects[0].bottom, 2);
      for (final frame in tester.widgetList<FrostMediaFrame>(cells)) {
        expect(frame.radius, 0);
        expect(frame.fit, BoxFit.cover);
      }
      final clip = tester.widget<ClipPath>(find.descendant(of: find.byType(FrostMediaMosaic), matching: find.byType(ClipPath)).first);
      final shape = (clip.clipper! as ShapeBorderClipper).shape as RoundedSuperellipseBorder;
      expect(shape.borderRadius, FrostRadius.borderRadius(FrostRadius.md));
      expect(find.text('+2'), count == 6 ? findsOneWidget : findsNothing);
      expect(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.value == '+2'), count == 6 ? findsOneWidget : findsNothing);
      for (var i = 0; i < rects.length; i++) {
        await tester.tapAt(rects[i].center);
      }
      expect(selected, [for (var i = 0; i < rects.length; i++) i]);
    });
  }
  for (final size in [null, const Size(1, 4), const Size(8, 1), const Size(3, 2)]) {
    testWidgets('single mosaic ratio size=$size', (tester) async {
      await tester.pumpWidget(host(FrostMediaMosaic(images: [ControlledImage()], sizes: [size])));
      final rect = tester.getSize(find.byType(FrostMediaMosaic));
      final ratio = size == null ? 1.0 : (size.width / size.height).clamp(.8, 1.91);
      expect(rect.width / rect.height, closeTo(ratio, .001));
    });
  }
  for (final rtl in [false, true]) {
    testWidgets('shared Hero partial source radii mirror rtl=$rtl', (tester) async {
      final tags = List.generate(3, (_) => FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1, sourceRadius: FrostRadius.borderRadius(FrostRadius.md)));
      await tester.pumpWidget(
        host(
          FrostMediaMosaic(images: List.generate(3, (_) => ControlledImage()), heroTag: (i) => tags[i]),
          rtl: rtl,
        ),
      );
      final heroes = tester.widgetList<FrostMediaHero>(find.byType(FrostMediaHero)).toList();
      expect(heroes.map((h) => h.tag), tags);
      final first = heroes.first.radius;
      expect(rtl ? first.topRight : first.topLeft, const Radius.circular(10));
      expect(rtl ? first.topLeft : first.topRight, Radius.zero);
      final second = heroes[1].radius;
      expect(rtl ? second.topLeft : second.topRight, const Radius.circular(10));
      expect(second.bottomLeft, Radius.zero);
      expect(second.bottomRight, Radius.zero);
    });
  }
  testWidgets('Mosaic pending image is not a skeleton; explicit count skeleton draws no +N', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(FrostMediaMosaic(images: [ControlledImage()])));
    expect(find.bySemanticsLabel('L.loading'), findsNothing);
    await tester.pumpWidget(host(FrostMediaMosaic.skeleton(count: 6, sizes: const [null, null, null, null])));
    expect(find.byType(FrostMediaFrame), findsNWidgets(4));
    expect(find.text('+2'), findsNothing);
    expect(find.bySemanticsLabel('L.loading'), findsOneWidget);
    await tester.pumpWidget(host(FrostMediaMosaic.skeleton(count: 1, sizes: const [Size(3, 2)])));
    final ratio = tester.getSize(find.byType(FrostMediaMosaic)).aspectRatio;
    expect(ratio, 1.5);
    semantics.dispose();
  });
  test('mosaic content and skeleton contracts fail explicitly', () {
    expect(() => FrostMediaMosaic(images: []), throwsAssertionError);
    expect(() => FrostMediaMosaic(images: [ControlledImage()], sizes: []), throwsAssertionError);
    expect(() => FrostMediaMosaic(images: [ControlledImage()], sizes: const [Size(0, 1)]), throwsAssertionError);
    expect(() => FrostMediaMosaic.skeleton(count: 0, sizes: []), throwsAssertionError);
    expect(() => FrostMediaMosaic.skeleton(count: 3, sizes: [null]), throwsAssertionError);
    expect(() => FrostMediaMosaic.skeleton(count: 1, sizes: [null]), throwsFlutterError);
    expect(() => FrostMediaMosaic.skeleton(count: 1, sizes: const [Size(0, 1)]), throwsFlutterError);
  });
}
