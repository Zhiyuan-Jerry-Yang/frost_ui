import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_choice_mark.dart';
import 'package:frost_ui/src/media/media_card.dart';
import 'package:frost_ui/src/primitives/status_glyph.dart';
import 'support.dart';

class CircleCanvas implements Canvas {
  final paints = <Paint>[];
  final radii = <double>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #drawCircle) {
      radii.add(invocation.positionalArguments[1] as double);
      paints.add(invocation.positionalArguments[2] as Paint);
    }
    return null;
  }
}

Future<ui.Image> rasterCircle(double dpr, {required bool outline, bool glyph = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr);
  // Fractional origins exercise the same subpixel positions as spring scaling.
  canvas.translate(1.25, 1.25);
  FrostMediaSelectionCirclePainter(fill: Colors.pink, outline: outline ? Colors.white : null).paint(canvas, const Size.square(20));
  if (glyph) {
    canvas.translate(2, 2);
    const FrostStatusGlyphPainter(kind: FrostStatusGlyphKind.success, color: Colors.white, progress: 1).paint(canvas, const Size.square(16));
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage((23 * dpr).ceil(), (23 * dpr).ceil());
  picture.dispose();
  return image;
}

void main() {
  test('circle fill and outline explicitly antialias; retired outline paints nothing', () {
    final canvas = CircleCanvas();
    const FrostMediaSelectionCirclePainter(fill: Colors.pink, outline: Colors.white).paint(canvas, const Size.square(20));
    expect(canvas.radii, [10, 9.25]);
    expect(canvas.paints.every((p) => p.isAntiAlias), true);
    expect(canvas.paints.last.strokeWidth, 1.5);
    final hidden = CircleCanvas();
    const FrostMediaSelectionCirclePainter(fill: Colors.pink, outline: Colors.white, opacity: 0).paint(hidden, const Size.square(20));
    expect(hidden.paints, isEmpty);
    final radio = CircleCanvas();
    const FrostChoicePainter(kind: FrostChoiceKind.radio, ink: Colors.white, check: 0, mixed: 0, dot: 1).paint(radio, const Size.square(20));
    expect(radio.paints.single.isAntiAlias, true);
  });
  for (final dpr in [1.0, 1.5, 2.0]) {
    test('DPR $dpr circle outline, fill and check have partial edge coverage', () async {
      for (final outlined in [false, true]) {
        final image = await rasterCircle(dpr, outline: outlined);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        expect([for (var i = 3; i < bytes.length; i += 4) bytes[i]].any((alpha) => alpha > 0 && alpha < 255), true);
        image.dispose();
      }
      final plain = await rasterCircle(dpr, outline: false);
      final checked = await rasterCircle(dpr, outline: false, glyph: true);
      final base = (await plain.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final drawn = (await checked.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      var softenedCheckEdge = false;
      for (var i = 0; i < base.length; i += 4) {
        if (base[i + 3] == 255 && drawn[i + 1] > base[i + 1] && drawn[i + 1] < 255) softenedCheckEdge = true;
      }
      expect(softenedCheckEdge, true);
      plain.dispose();
      checked.dispose();
    });
  }
  testWidgets('selected circle retires its outline and retains shared glyph and card AA clip', (tester) async {
    var selected = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Center(
              child: SizedBox(
                width: 120,
                child: FrostMediaCard(selected: selected, media: const SizedBox(height: 80), onPressed: () {}),
              ),
            );
          },
        ),
      ),
    );
    Iterable<FrostMediaSelectionCirclePainter> circles() =>
        tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<FrostMediaSelectionCirclePainter>();
    expect(circles().singleWhere((p) => p.outline != null).opacity, 1);
    update(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(circles().singleWhere((p) => p.outline != null).opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(circles().singleWhere((p) => p.outline != null).opacity, 0);
    expect(tester.widgetList<FrostStatusGlyphDrawing>(find.byType(FrostStatusGlyphDrawing)).single.progress, 1);
    expect(
      tester
          .widgetList<ClipRSuperellipse>(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(ClipRSuperellipse)))
          .every((clip) => clip.clipBehavior == Clip.antiAlias),
      true,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('avatar and avatar-stack circular clips explicitly antialias', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: FrostAvatarStack(
            semanticLabel: 'people',
            max: 1,
            avatars: [
              FrostAvatar(semanticLabel: 'A', initials: 'A'),
              FrostAvatar(semanticLabel: 'B', initials: 'B'),
            ],
          ),
        ),
      ),
    );
    expect(tester.widgetList<ClipOval>(find.byType(ClipOval)), isNotEmpty);
    expect(tester.widgetList<ClipOval>(find.byType(ClipOval)).every((clip) => clip.clipBehavior == Clip.antiAlias), true);
  });
}
