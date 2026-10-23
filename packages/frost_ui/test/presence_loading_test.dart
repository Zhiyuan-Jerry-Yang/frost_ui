import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

void main() {
  testWidgets('presence starts settled, dismisses input immediately and removes after fading', (tester) async {
    var visible = true;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Center(
              child: FrostPresence(
                visible: visible,
                child: TextButton(key: const ValueKey('content'), onPressed: () {}, child: const Text('Content')),
              ),
            );
          },
        ),
      ),
    );
    expect(tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).opacity.value, 1);
    expect(tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value, 1);
    update(() => visible = false);
    await tester.pump();
    expect(tester.widget<IgnorePointer>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(IgnorePointer)).first).ignoring, true);
    expect(tester.widget<ExcludeFocus>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(ExcludeFocus)).first).excluding, true);
    expect(tester.widget<ExcludeSemantics>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(ExcludeSemantics)).first).excluding, true);
    await tester.pump(FrostMotion.dismiss ~/ 2);
    expect(tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).opacity.value, inExclusiveRange(0, 1));
    expect(tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value, inExclusiveRange(.96, 1));
    await tester.pump(FrostMotion.dismiss ~/ 2);
    expect(find.byKey(const ValueKey('content')), findsNothing);
  });

  for (final axis in Axis.values) {
    testWidgets('expand moves $axis layout after mounting and reverses continuously', (tester) async {
      var visible = false;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, set) {
              update = set;
              return Center(
                child: FrostPresence(visible: visible, effect: FrostPresenceEffect.expand, axis: axis, child: const SizedBox(width: 100, height: 80)),
              );
            },
          ),
        ),
      );
      expect(tester.getSize(find.byType(FrostPresence)), Size.zero);
      update(() => visible = true);
      await tester.pump();
      await tester.pump(FrostMotion.reveal ~/ 2);
      final before = tester.getSize(find.byType(FrostPresence));
      expect(axis == Axis.vertical ? before.height : before.width, inExclusiveRange(0, axis == Axis.vertical ? 80 : 100));
      final opacity = tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).opacity.value;
      update(() => visible = false);
      await tester.pump();
      expect(tester.getSize(find.byType(FrostPresence)), before);
      expect(tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).opacity.value, opacity);
      await tester.pump(FrostMotion.dismiss ~/ 2);
      final reversed = tester.getSize(find.byType(FrostPresence));
      expect(axis == Axis.vertical ? reversed.height : reversed.width, lessThan(axis == Axis.vertical ? before.height : before.width));
      update(() => visible = true);
      await tester.pump();
      expect(tester.getSize(find.byType(FrostPresence)), reversed);
      await tester.pump(FrostMotion.reveal);
      expect(tester.getSize(find.byType(FrostPresence)), const Size(100, 80));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced presence fades with full geometry and no scale or size animation', (tester) async {
    for (final effect in FrostPresenceEffect.values) {
      var visible = false;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return Center(
                    child: FrostPresence(visible: visible, effect: effect, child: const SizedBox(width: 100, height: 80)),
                  );
                },
              ),
            ),
          ),
        ),
      );
      update(() => visible = true);
      await tester.pump();
      expect(tester.getSize(find.byType(FrostPresence)), const Size(100, 80));
      expect(find.byType(ScaleTransition), findsNothing);
      await tester.pump(FrostMotion.reducedFade ~/ 2);
      expect(tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition)).opacity.value, inExclusiveRange(0, 1));
      await tester.pump(FrostMotion.reducedFade ~/ 2);
      update(() => visible = false);
      await tester.pump();
      await tester.pump(FrostMotion.reducedFade ~/ 2);
      expect(tester.getSize(find.byType(FrostPresence)), const Size(100, 80));
      await tester.pump(FrostMotion.reducedFade ~/ 2);
      expect(tester.getSize(find.byType(FrostPresence)), Size.zero);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('loading gate skips short work, delays mounting, holds 400ms and cancels timers', (tester) async {
    var loading = false;
    late StateSetter update;
    Widget app() => frostTestApp(
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostLoadingGate(loading: loading, builder: (_, shown) => Text('$shown'));
        },
      ),
    );
    await tester.pumpWidget(app());
    update(() => loading = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    update(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('false'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    loading = true;
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text('false'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('true'), findsOneWidget);
    update(() => loading = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('true'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('false'), findsOneWidget);
    update(() => loading = true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading restarts cancel stale delays and do not interrupt a minimum hold', (tester) async {
    var loading = true;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostLoadingGate(loading: loading, builder: (_, shown) => Text('$shown'));
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    update(() => loading = false);
    await tester.pump();
    update(() => loading = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('false'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('true'), findsOneWidget);
    update(() => loading = false);
    await tester.pump();
    update(() => loading = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('true'), findsOneWidget);
    update(() => loading = false);
    await tester.pump();
    expect(find.text('false'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('activity geometry, spoke movement and semantics are actually rendered', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final (size, diameter) in [(FrostControlSize.compact, 16.0), (FrostControlSize.regular, 20.0), (FrostControlSize.large, 28.0)]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: RepaintBoundary(
              key: key,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: FrostActivityIndicator(size: size, semanticLabel: 'Waiting'),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FrostActivityIndicator)), Size.square(diameter));
      expect(find.bySemanticsLabel('Waiting'), findsOneWidget);
      final paintFinder = find.descendant(of: find.byType(FrostActivityIndicator), matching: find.byType(CustomPaint));
      final paint = tester.widget<CustomPaint>(paintFinder);
      final before = await _alphas(tester, key, diameter);
      await tester.pump(const Duration(milliseconds: 125));
      final after = await _alphas(tester, key, diameter);
      expect(before.indexOf(before.reduce((a, b) => a > b ? a : b)), 0);
      expect(after.indexOf(after.reduce((a, b) => a > b ? a : b)), 1);
      expect(identical(tester.widget<CustomPaint>(paintFinder), paint), true);
      await tester.pumpWidget(const SizedBox());
    }
    await tester.pumpWidget(frostTestApp(const Center(child: FrostActivityIndicator(semanticLabel: null))));
    expect(find.bySemanticsLabel('Waiting'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('reduced activity keeps all eight spokes stationary while opacity breathes', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Center(
              child: RepaintBoundary(key: key, child: const FrostActivityIndicator(semanticLabel: null)),
            ),
          ),
        ),
      ),
    );
    final before = await _alphas(tester, key, 20);
    await tester.pump(const Duration(milliseconds: 1000));
    final middle = await _alphas(tester, key, 20);
    expect(before.every((value) => value > 0), true);
    expect(middle.every((value) => value > 0), true);
    expect(before.indexOf(before.reduce((a, b) => a > b ? a : b)), 0);
    expect(middle.indexOf(middle.reduce((a, b) => a > b ? a : b)), 0);
    expect(before[0] / middle[0], closeTo(.6, .03));
    await tester.pumpWidget(const SizedBox());
  });
}

Future<List<int>> _alphas(WidgetTester tester, GlobalKey key, double diameter) async => (await tester.runAsync(() async {
  final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage(pixelRatio: 4);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final centre = diameter / 2, r = diameter * .35;
  const directions = [
    Offset(0, -1),
    Offset(.707, -.707),
    Offset(1, 0),
    Offset(.707, .707),
    Offset(0, 1),
    Offset(-.707, .707),
    Offset(-1, 0),
    Offset(-.707, -.707),
  ];
  final result = [for (final d in directions) data.getUint8((((centre + d.dy * r) * 4).floor() * image.width + ((centre + d.dx * r) * 4).floor()) * 4 + 3)];
  image.dispose();
  return result;
}))!;
