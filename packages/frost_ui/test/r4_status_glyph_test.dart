import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_choice_mark.dart';
import 'package:frost_ui/src/primitives/status_glyph.dart';
import 'support.dart';

class RecordingCanvas implements Canvas {
  final paths = <Path>[];
  final paints = <Paint>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #drawPath) {
      paths.add(invocation.positionalArguments[0] as Path);
      paints.add(invocation.positionalArguments[1] as Paint);
    }
    return null;
  }
}

Iterable<FrostStatusGlyphPainter> glyphs(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<FrostStatusGlyphPainter>();
FrostChoicePainter choice(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<FrostChoicePainter>().first;
Future<void> host(WidgetTester tester, Widget child, {bool reduced = false}) => tester.pumpWidget(
  frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Center(child: child),
      ),
    ),
  ),
);

void main() {
  for (final kind in FrostStatusGlyphKind.values) {
    test('status $kind strokes use rounded geometry and path length clipping', () {
      for (final size in [12.0, 20.0, 28.0]) {
        final canvas = RecordingCanvas();
        const progress = .5;
        FrostStatusGlyphPainter(kind: kind, color: Colors.red, progress: progress).paint(canvas, Size.square(size));
        final paths = frostStatusPaths(kind, Size.square(size));
        final phases = frostStatusStrokeProgress(kind, progress);
        var emitted = 0;
        for (var i = 0; i < paths.length; i++) {
          if (phases[i] == 0) continue;
          expect(canvas.paths[emitted].computeMetrics().single.length, closeTo(paths[i].computeMetrics().single.length * phases[i], .001));
          final paint = canvas.paints[emitted++];
          expect(paint.strokeWidth, closeTo(frostStatusStrokeWidth(size), .000001));
          expect(paint.strokeCap, StrokeCap.round);
          expect(paint.strokeJoin, StrokeJoin.round);
          expect(paint.isAntiAlias, true);
        }
        expect(canvas.paths, hasLength(emitted));
      }
    });
    testWidgets('status $kind mounts complete and only real kind changes draw', (tester) async {
      var current = kind;
      late StateSetter update;
      await host(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostStatusGlyph(kind: current, size: 20);
          },
        ),
      );
      expect(glyphs(tester).single.progress, 1);
      update(() {});
      await tester.pump();
      expect(glyphs(tester).single.progress, 1);
      update(() => current = FrostStatusGlyphKind.values[(kind.index + 1) % 3]);
      await tester.pump();
      expect(glyphs(tester).single.progress, 0);
      await tester.pump(frostStatusDuration(current) ~/ 2);
      expect(glyphs(tester).single.progress, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(glyphs(tester).single.progress, 1);
    });
  }
  test('cross second stroke starts at 60 percent of the first, warning dot follows stem', () {
    expect(frostStatusDuration(FrostStatusGlyphKind.failure), const Duration(milliseconds: 224));
    final before = frostStatusStrokeProgress(FrostStatusGlyphKind.failure, 83 / 224);
    expect(before[0], greaterThan(0));
    expect(before[1], 0);
    final after = frostStatusStrokeProgress(FrostStatusGlyphKind.failure, 100 / 224);
    expect(after[1], greaterThan(0));
    expect(after[0], lessThan(1));
    expect(frostStatusStrokeProgress(FrostStatusGlyphKind.warning, 180 / 250), [1, 0]);
    expect(frostStatusStrokeProgress(FrostStatusGlyphKind.warning, 215 / 250)[1], inExclusiveRange(0, 1));
  });
  testWidgets('reduced status fades final shape for 100 ms without tracing', (tester) async {
    var kind = FrostStatusGlyphKind.success;
    late StateSetter update;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostStatusGlyph(kind: kind, size: 20);
        },
      ),
      reduced: true,
    );
    update(() => kind = FrostStatusGlyphKind.failure);
    await tester.pump();
    expect(glyphs(tester).single.progress, 1);
    final opacity = find.ancestor(of: find.byType(FrostStatusGlyphDrawing), matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
  });
  for (final determinate in [false, true]) {
    testWidgets('progress to result finishes ring before drawing, determinate=$determinate', (tester) async {
      FrostStatusGlyphKind? result;
      late StateSetter update;
      var finished = 0;
      await host(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostProgressResult(result: result, size: 20, progress: determinate ? .4 : null, onResultDrawn: () => finished++);
          },
        ),
      );
      update(() => result = FrostStatusGlyphKind.success);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final ring = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<FrostStatusRingPainter>().single;
      expect(ring.progress, inExclusiveRange(determinate ? .4 : 0, 1));
      expect(glyphs(tester).single.progress, 0);
      expect(finished, 0);
      if (!determinate) {
        final opacity = find.ancestor(of: find.byType(FrostActivityIndicator), matching: find.byType(Opacity)).first;
        expect(tester.widget<Opacity>(opacity).opacity, closeTo(1 - ring.progress, .000001));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(glyphs(tester).single.progress, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(glyphs(tester).single.progress, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(finished, 1);
    });
  }
  for (final success in [true, false]) {
    testWidgets('async button gates loading, fixes width, announces result and holds $success', (tester) async {
      final semantics = tester.ensureSemantics();
      final pending = Completer<bool>();
      var calls = 0;
      await host(
        tester,
        FrostButton(
          label: 'Save record',
          onPressedAsync: () {
            calls++;
            return pending.future;
          },
        ),
      );
      final button = find.byType(FrostButton);
      final width = tester.getSize(button).width;
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byType(FrostProgressResult), findsNothing);
      expect(tester.getSize(button).width, width);
      await tester.pump(const Duration(milliseconds: 1));
      pending.complete(success);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 399));
      expect(find.byType(FrostProgressResult), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(FrostProgressResult), findsOneWidget);
      expect(tester.getSize(button).width, width);
      final data = tester.getSemantics(button).getSemanticsData();
      expect(data.value, success ? 'L.actionSucceeded' : 'L.actionFailed');
      expect(data.flagsCollection.isLiveRegion, true);
      await tester.pump(Duration(milliseconds: success ? 450 : 424));
      expect(glyphs(tester).single.progress, 1);
      await tester.pump(const Duration(milliseconds: 1)); // Complete the ticker at its exact end boundary.
      await tester.pump(const Duration(milliseconds: 1199));
      await tester.tap(button);
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(FrostProgressResult), findsNothing);
      expect(tester.getSize(button).width, width);
      semantics.dispose();
    });
  }
  testWidgets('short async operation skips spinner and exception reports failure', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = old);
    await host(tester, FrostButton.icon(icon: testIcons.copy, label: 'Copy', onPressedAsync: () async => throw StateError('copy failed')));
    await tester.tap(find.byType(FrostButton));
    await tester.pump();
    expect(find.byType(FrostProgressResult), findsOneWidget);
    expect(errors, hasLength(1));
    expect(find.descendant(of: find.byType(FrostProgressResult), matching: find.byType(FrostActivityIndicator)), findsNothing);
    await tester.pump(const Duration(milliseconds: 424));
    expect(glyphs(tester).single.kind, FrostStatusGlyphKind.failure);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('pending async button disposal and disable discard completion', (tester) async {
    final pending = Completer<bool>();
    var enabled = true;
    late StateSetter update;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostButton(label: 'Run', onPressedAsync: enabled ? () => pending.future : null);
        },
      ),
    );
    await tester.tap(find.byType(FrostButton));
    await tester.pump();
    update(() => enabled = false);
    await tester.pump();
    pending.complete(true);
    await tester.pump();
    expect(find.byType(FrostProgressResult), findsNothing);
    expect(tester.takeException(), isNull);
    final lateResult = Completer<bool>();
    await host(tester, FrostButton(label: 'Run', onPressedAsync: () => lateResult.future));
    await tester.tap(find.byType(FrostButton));
    await tester.pumpWidget(const SizedBox());
    lateResult.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  test('async button callback and external loading contracts assert', () {
    expect(() => FrostButton(label: 'Run', onPressed: () {}, onPressedAsync: () async => true), throwsAssertionError);
    expect(() => FrostButton.icon(icon: testIcons.copy, label: 'Run', loading: true, onPressedAsync: () async => true), throwsAssertionError);
    expect(const FrostButton(label: 'Disabled').onPressed, isNull);
  });
  testWidgets('checkbox only draws after its own user toggle; programmatic updates are final', (tester) async {
    var value = false;
    late StateSetter update;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostCheckbox(value: value, semanticLabel: 'Pick', onChanged: (next) => set(() => value = next!));
        },
      ),
    );
    update(() => value = true);
    await tester.pump();
    expect(choice(tester).check, 1);
    update(() => value = false);
    await tester.pump();
    await tester.tap(find.byType(FrostCheckbox));
    await tester.pump();
    expect(choice(tester).check, 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(choice(tester).check, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 75));
    expect(choice(tester).check, 1);
  });
  testWidgets('scope media draws one user selection; selectAll and mount are final', (tester) async {
    final selection = FrostSelection<int>()..enter();
    addTearDown(selection.dispose);
    Widget item(int i) => SizedBox(
      width: 100,
      child: FrostSelectableItem(
        item: i,
        child: FrostMediaCard(media: const SizedBox(height: 100), onPressed: () {}, semanticLabel: 'Media $i'),
      ),
    );
    await host(
      tester,
      FrostSelectionScope(
        selection: selection,
        items: const [1, 2],
        child: Row(mainAxisSize: MainAxisSize.min, children: [item(1), item(2)]),
      ),
    );
    selection.selectAll([1, 2]);
    await tester.pump();
    expect(glyphs(tester).every((p) => p.progress == 1), true);
    selection.clear();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Media 1').first);
    await tester.pump();
    FrostStatusGlyphPainter selectedGlyph() => tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostMediaCard).first, matching: find.byType(CustomPaint)))
        .map((w) => w.painter)
        .whereType<FrostStatusGlyphPainter>()
        .single;
    expect(selectedGlyph().progress, 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(selectedGlyph().progress, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(selectedGlyph().progress, 1);
  });
  testWidgets('toast status starts after material reveal, info remains app icon', (tester) async {
    await host(tester, const SizedBox());
    FrostToast.success('Saved');
    await tester.pump();
    expect(glyphs(tester).single.progress, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(glyphs(tester).single.progress, 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(glyphs(tester).single.progress, 0);
    await tester.pump(const Duration(milliseconds: 125));
    expect(glyphs(tester).single.progress, inExclusiveRange(0, 1));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reduced progress result fades a complete ring and glyph for 100 ms', (tester) async {
    FrostStatusGlyphKind? result;
    late StateSetter update;
    var finished = 0;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostProgressResult(result: result, size: 20, onResultDrawn: () => finished++);
        },
      ),
      reduced: true,
    );
    update(() => result = FrostStatusGlyphKind.success);
    await tester.pump();
    expect(glyphs(tester).single.progress, 1);
    final opacity = find.ancestor(of: find.byType(FrostStatusGlyphDrawing), matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 51));
    expect(finished, 1);
  });
  testWidgets('bulk selection from an activation does not trace the clicked media', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await host(
      tester,
      FrostSelectionScope(
        selection: selection,
        items: const [1, 2],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [1, 2])
              SizedBox(
                width: 100,
                child: FrostSelectableItem(
                  item: item,
                  child: FrostMediaCard(media: const SizedBox(height: 100), onPressed: () => selection.selectAll([1, 2])),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(FrostMediaCard).first);
    await tester.pump();
    expect(selection.selected, {1, 2});
    expect(glyphs(tester).every((glyph) => glyph.progress == 1), true);
    await tester.pumpAndSettle();
  });
  testWidgets('long press entering media selection draws only the entered item', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    await host(
      tester,
      FrostSelectionScope(
        selection: selection,
        items: const [1],
        child: SizedBox(
          width: 100,
          child: FrostSelectableItem(
            item: 1,
            child: FrostMediaCard(media: const SizedBox(height: 100), onPressed: () {}),
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(FrostMediaCard));
    await tester.pump();
    expect(selection.selected, {1});
    expect(glyphs(tester).single.progress, 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(glyphs(tester).single.progress, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(glyphs(tester).single.progress, 1);
  });
  testWidgets('ignored checkbox input cannot animate a later program assignment', (tester) async {
    var value = false;
    late StateSetter update;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostCheckbox(value: value, semanticLabel: 'Pick', onChanged: (_) {});
        },
      ),
    );
    await tester.tap(find.byType(FrostCheckbox));
    await tester.pump();
    update(() => value = true);
    await tester.pump();
    expect(choice(tester).check, 1);
  });
  test('warning dot fades during its allotted phase instead of popping a round cap', () {
    final canvas = RecordingCanvas();
    FrostStatusGlyphPainter(kind: FrostStatusGlyphKind.warning, color: Colors.red, progress: 215 / 250).paint(canvas, const Size.square(20));
    expect(canvas.paints, hasLength(2));
    expect(canvas.paints.first.color.a, 1);
    expect(canvas.paints.last.color.a, inExclusiveRange(0, 1));
  });
  testWidgets('lazy remount of an already selected media does not replay the old user pulse', (tester) async {
    final selection = FrostSelection<int>()..enter();
    addTearDown(selection.dispose);
    var visible = true;
    late StateSetter update;
    await host(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostSelectionScope(
            selection: selection,
            items: const [1],
            child: visible
                ? SizedBox(
                    width: 100,
                    child: FrostSelectableItem(
                      item: 1,
                      child: FrostMediaCard(media: const SizedBox(height: 100), onPressed: () {}),
                    ),
                  )
                : const SizedBox(),
          );
        },
      ),
    );
    await tester.tap(find.byType(FrostMediaCard));
    await tester.pumpAndSettle();
    update(() => visible = false);
    await tester.pump();
    update(() => visible = true);
    await tester.pump();
    expect(selection.selected, {1});
    expect(glyphs(tester).single.progress, 1);
  });
}
