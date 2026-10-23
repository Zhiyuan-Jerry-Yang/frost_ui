import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

const glyph = FrostIconData.glyph(IconData(0xe020));
void main() {
  for (final rtl in [false, true]) {
    for (final count in [1, 2, 3, 4]) {
      testWidgets('mosaic every cell clip has only exterior corners count=$count rtl=$rtl', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: FrostMediaMosaic(images: List.generate(count, (_) => ControlledImage()), onPressed: (_) {}),
                ),
              ),
            ),
          ),
        );
        final frames = find.byType(FrostMediaFrame);
        for (var i = 0; i < count; i++) {
          final cell = find.ancestor(of: frames.at(i), matching: find.byType(FrostClickFeedbackVisual)).first;
          final shape = tester.widget<FrostClickFeedbackVisual>(cell).shape as RoundedSuperellipseBorder;
          final expected = BorderRadiusDirectional.only(
            topStart: i == 0 ? const Radius.circular(10) : Radius.zero,
            topEnd: (count == 1 ? i == 0 : i == 1) ? const Radius.circular(10) : Radius.zero,
            bottomStart: (count < 4 ? i == 0 : i == 2) ? const Radius.circular(10) : Radius.zero,
            bottomEnd: i == count - 1 ? const Radius.circular(10) : Radius.zero,
          ).resolve(rtl ? TextDirection.rtl : TextDirection.ltr);
          expect(shape.borderRadius, expected);
          final clip = tester.widget<ClipPath>(find.descendant(of: cell, matching: find.byType(ClipPath)).first);
          expect((clip.clipper as ShapeBorderClipper).shape, shape);
        }
      });
    }
    testWidgets('avatar layers are opaque and count fits exposed part rtl=$rtl', (tester) async {
      late Color background;
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: FrostSurface(
              role: FrostSurfaceRole.module,
              child: Builder(
                builder: (context) {
                  background = FrostSurfaceScope.maybeOf(context)!.background;
                  return MediaQuery(
                    data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: Center(
                      child: FrostAvatarStack(
                        avatars: List.generate(1003, (i) => FrostAvatar(key: ValueKey(i), initials: '$i', semanticLabel: '$i')),
                        semanticLabel: 'People',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final stack = tester.widget<Stack>(find.descendant(of: find.byType(FrostAvatarStack), matching: find.byType(Stack)).first);
      final positions = stack.children.cast<PositionedDirectional>().toList();
      expect(positions.map((p) => p.start), [56, 38, 20, 2]); // last painted = first avatar
      final layers = positions.map((p) => ((p.child as DecoratedBox).decoration as BoxDecoration)).toList();
      for (final layer in layers) {
        expect(layer.color, background);
        expect((layer.border as Border).top.color, background);
        expect(layer.color!.a, 1);
      }
      final previous = tester.getRect(find.byKey(const ValueKey(2)));
      final text = tester.getRect(find.text('+1000'));
      if (rtl) {
        expect(text.right, lessThanOrEqualTo(previous.left - 2));
      } else {
        expect(text.left, greaterThanOrEqualTo(previous.right + 2));
      }
      final last = tester.getRect(find.ancestor(of: find.text('+1000'), matching: find.byType(ClipOval)).first);
      expect(last.contains(text.topLeft), isTrue);
      expect(last.contains(text.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    });
    testWidgets('social glyphs bleed to local content start rtl=$rtl', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: FrostContentColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Body'),
                  FrostActionCount(icon: glyph, selectedIcon: glyph, selected: false, count: 3, onChanged: (_) {}, label: 'Count'),
                  FrostToggleButton(icon: glyph, selectedIcon: glyph, selected: false, onChanged: (_) {}, label: 'Toggle'),
                ],
              ),
            ),
          ),
        ),
      );
      final body = tester.getRect(find.text('Body'));
      for (final type in [FrostActionCount, FrostToggleButton]) {
        final icon = tester.getRect(find.descendant(of: find.byType(type), matching: find.byType(FrostIcon)).first);
        expect(rtl ? icon.right : icon.left, closeTo(rtl ? body.right : body.left, .01));
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final density in FrostDensity.values) {
    for (final rtl in [false, true]) {
      testWidgets('attachment 20 circle, 12 glyph, full hit corners $density rtl=$rtl', (tester) async {
        final text = TextEditingController(), focus = FocusNode();
        addTearDown(text.dispose);
        addTearDown(focus.dispose);
        var removed = 0;
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: FrostComposer(
                    controller: text,
                    focusNode: focus,
                    placeholder: 'Write',
                    onSend: (_) {},
                    attachments: [FrostComposerAttachment(thumbnail: const SizedBox.expand(), label: 'Photo', onRemove: () => removed++)],
                  ),
                ),
              ),
            ),
            density: density,
          ),
        );
        final control = find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.remove');
        final glyphRect = tester.getRect(find.descendant(of: control, matching: find.byType(FrostIcon)).first);
        expect(glyphRect.size, const Size(12, 12));
        final frame = tester.getRect(find.byType(FrostMediaFrame));
        expect(glyphRect.center.dy - frame.top, 14);
        expect(rtl ? glyphRect.center.dx - frame.left : frame.right - glyphRect.center.dx, 14);
        final hit = tester.getRect(control);
        final target = FrostDensity.of(tester.element(control)).targetHeight;
        expect(hit.size, Size.square(target));
        expect(tester.widget<FrostButtonControl>(control).geometry!.visualHeight, 20);
        for (final point in [
          hit.topLeft + const Offset(.5, .5),
          hit.topRight + const Offset(-.5, .5),
          hit.bottomLeft + const Offset(.5, -.5),
          hit.bottomRight - const Offset(.5, .5),
        ]) {
          await tester.tapAt(point);
          await tester.pump();
        }
        expect(removed, 4);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('Popover maxWidth rejects values below 160 and nonfinite', () {
    Widget trigger(BuildContext c, FocusNode f, VoidCallback t) => const SizedBox();
    for (final width in [159.0, double.infinity, double.nan]) {
      expect(() => FrostPopover(maxWidth: width, builder: trigger, contentBuilder: (_, _) => const Text('Body')), throwsAssertionError);
    }
  });
}
