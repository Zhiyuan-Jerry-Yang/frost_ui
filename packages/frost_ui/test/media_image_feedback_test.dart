import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

List<double> scales(WidgetTester tester, Finder root) => tester
    .renderObjectList<RenderTransform>(
      find.descendant(of: root, matching: find.byElementPredicate((e) => e is RenderObjectElement && e.renderObject is RenderTransform)),
    )
    .map((r) => r.child!.getTransformTo(r).storage[0])
    .toList();
Widget host(Widget media, {VoidCallback? onTap, List<FrostMenuEntry> entries = const [], bool reduced = false}) => frostTestApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Center(
        child: SizedBox(
          width: 240,
          child: FrostMediaCard(aspectRatio: 1.5, media: media, onPressed: onTap ?? () {}, contextMenu: entries, footer: const Text('Footer')),
        ),
      ),
    ),
  ),
);
void main() {
  for (final state in ['loading', 'failed', 'unsupported', 'skeleton']) {
    testWidgets('$state has no card scale while hover, press and menu still work', (tester) async {
      var opens = 0, retries = 0;
      final provider = ControlledImage();
      final media = switch (state) {
        'unsupported' => const Text('Unsupported'),
        'skeleton' => FrostMediaFrame.skeleton(aspectRatio: 1.5),
        _ => FrostMediaFrame(
          image: provider,
          errorBuilder: (_, _) => Center(
            child: FrostButton(label: 'Retry', onPressed: () => retries++),
          ),
        ),
      };
      await tester.pumpWidget(
        host(
          media,
          reduced: state == 'skeleton',
          onTap: () => opens++,
          entries: [FrostMenuAction('Menu action', onSelected: () {})],
        ),
      );
      if (state == 'failed') {
        provider.completer.fail(StateError('fixture'));
        await tester.pump();
      }
      final card = find.byType(FrostMediaCard);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final point = tester.getTopLeft(card) + const Offset(15, 15);
      await mouse.moveTo(point);
      await tester.pumpAndSettle();
      expect(scales(tester, card), everyElement(1.0));
      await mouse.down(point);
      await tester.pumpAndSettle();
      expect(scales(tester, card), everyElement(1.0));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(opens, 1);
      if (state == 'failed') {
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(retries, 1);
        expect(opens, 1);
      }
      await mouse.removePointer();
      await tester.longPressAt(point);
      await tester.pumpAndSettle();
      expect(find.text('Menu action'), findsOneWidget);
      await tester.tap(find.text('Menu action'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('provider registers only displayed pixels; hover enters from 1, press scales the complete frame', (tester) async {
    final provider = ControlledImage();
    await tester.pumpWidget(host(FrostMediaFrame(image: provider)));
    final card = find.byType(FrostMediaCard), frame = find.byType(FrostMediaFrame).first;
    final footer = tester.getRect(find.text('Footer'));
    final bounds = tester.getRect(frame);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(bounds.center);
    await tester.pumpAndSettle();
    expect(scales(tester, card), everyElement(1.0));
    provider.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 80, height: 40)))!));
    await tester.pump();
    expect(scales(tester, card), everyElement(1.0), reason: 'No first-frame jump to the hovered endpoint');
    await tester.pump(const Duration(milliseconds: 80));
    expect(scales(tester, card).any((s) => s > 1 && s < FrostMetrics.mediaHoverZoom), isTrue);
    await tester.pumpAndSettle();
    expect(scales(tester, card), contains(closeTo(FrostMetrics.mediaHoverZoom, .0001)));
    expect(tester.getRect(frame), bounds);
    await mouse.down(bounds.center);
    await tester.pumpAndSettle();
    expect(scales(tester, card), contains(closeTo(.98, .0001)));
    expect(tester.getRect(frame).width, closeTo(bounds.width * .98, .001), reason: 'The clip and its stroke shrink together');
    expect(tester.getRect(find.text('Footer')), footer);
    provider.completer.fail(StateError('late failure'));
    await tester.pump();
    expect(scales(tester, card), everyElement(1.0), reason: 'Error content is unscaled in its first frame, even during a held press');
    expect(tester.getRect(frame), bounds);
    await mouse.cancel();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom image registration remains local across movement, retry and disposal', (tester) async {
    var displayed = true;
    var owner = 0;
    late StateSetter update;
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return Row(
              children: [
                for (var i = 0; i < 2; i++)
                  SizedBox(
                    width: 200,
                    child: FrostMediaCard(
                      key: ValueKey(i),
                      aspectRatio: 1,
                      media: displayed && i == owner
                          ? FrostMediaImage(
                              key: key,
                              child: const ColoredBox(color: Colors.red),
                            )
                          : const Text('Pending'),
                      onPressed: () {},
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
    final card = find.byKey(const ValueKey(0));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    expect(scales(tester, card), contains(closeTo(1.03, .0001)));
    expect(scales(tester, find.byKey(const ValueKey(1))), everyElement(1.0));
    update(() => displayed = false);
    await tester.pump();
    expect(scales(tester, card), everyElement(1.0));
    update(() => displayed = true);
    await tester.pump();
    expect(scales(tester, card), everyElement(1.0));
    await tester.pumpAndSettle();
    expect(scales(tester, card), contains(closeTo(1.03, .0001)));
    update(() => owner = 1);
    await tester.pump();
    expect(scales(tester, card), everyElement(1.0));
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey(1))));
    await tester.pumpAndSettle();
    expect(scales(tester, find.byKey(const ValueKey(1))), contains(closeTo(1.03, .0001)));
    await tester.pumpWidget(const SizedBox());
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('corner and footer images cannot enable feedback for failed media', (tester) async {
    const decoration = FrostMediaImage(
      child: SizedBox(width: 24, height: 24, child: ColoredBox(color: Colors.red)),
    );
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 240,
            child: FrostMediaCard(aspectRatio: 1.5, media: const Text('Failed'), topEnd: decoration, footer: decoration, onPressed: () {}),
          ),
        ),
      ),
    );
    final card = find.byType(FrostMediaCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final point = tester.getTopLeft(card) + const Offset(15, 15);
    await mouse.moveTo(point);
    await tester.pumpAndSettle();
    expect(scales(tester, card), everyElement(1.0));
    await mouse.down(point);
    await tester.pumpAndSettle();
    expect(scales(tester, card), everyElement(1.0));
    await mouse.cancel();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
