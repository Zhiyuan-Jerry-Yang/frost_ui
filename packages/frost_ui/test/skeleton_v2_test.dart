import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:skeletonizer/src/rendering/render_skeletonizer.dart';

import 'display_badges_v2_test.dart' show display;
import 'support.dart';

void main() {
  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('six skeletons use real RenderBox geometry $density $scale', (tester) async {
        final pairs = <(Widget, Widget)>[
          (
            FrostListRow.skeleton(title: '000000000000', icon: true, subtitle: '00000000000000000000', value: '000000'),
            FrostListRow(title: '0' * 12, subtitle: '0' * 20, value: '0' * 6, icon: testIcons.empty),
          ),
          (
            FrostModule.skeleton(title: '0000000000', icon: true, value: '0000', note: '00000000000000000000'),
            FrostModule(title: '0' * 10, value: '0' * 4, note: '0' * 20, icon: testIcons.empty),
          ),
          (FrostTag.skeleton(label: '00000000'), FrostTag(label: '0' * 8)),
          (FrostAvatar.skeleton(size: FrostAvatarSize.regular), const FrostAvatar(semanticLabel: 'Person')),
          (FrostStat.skeleton(value: '0000', unit: null, caption: '0000000000'), FrostStat(value: '0' * 4, caption: '0' * 10)),
          (FrostMediaFrame.skeleton(aspectRatio: 1.5), const FrostMediaFrame(aspectRatio: 1.5, child: SizedBox.expand())),
        ];
        for (final (skeleton, real) in pairs) {
          const marker = ValueKey('component');
          await display(
            tester,
            KeyedSubtree(key: marker, child: skeleton),
            scale: scale,
            density: density,
          );
          final size = tester.getSize(find.byKey(marker));
          expect(size.isEmpty, false);
          await display(
            tester,
            KeyedSubtree(key: marker, child: real),
            scale: scale,
            density: density,
          );
          expect(tester.getSize(find.byKey(marker)), size, reason: skeleton.runtimeType.toString());
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('media skeleton without ratio follows finite parent constraints', (tester) async {
    await display(tester, SizedBox(height: 137, child: FrostMediaFrame.skeleton(aspectRatio: null)));
    expect(tester.getSize(find.byWidgetPredicate((w) => w is FrostMediaFrame).first), const Size(300, 137));
    for (final size in FrostAvatarSize.values) {
      await display(tester, FrostAvatar.skeleton(size: size));
      expect(tester.getSize(find.byWidgetPredicate((w) => w is FrostAvatar).first), Size.square([24, 32, 40, 56][size.index].toDouble()));
      expect(find.byType(ClipOval), findsOneWidget);
    }
  });
  testWidgets('skeleton pulse tokens, actual clock and reduced static fill', (tester) async {
    await display(tester, const FrostListRow(title: 'Actual row').frostSkeleton(true));
    final render = tester.allRenderObjects.whereType<RenderSkeletonizer>().toSet().single;
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostListRow)));
    final effect = render.config.effect as PulseEffect;
    expect(effect.from, tokens.fill);
    expect(effect.to, tokens.fillStrong);
    expect(effect.duration, const Duration(milliseconds: 1000));
    expect(render.config.textBorderRadius.borderRadius, const BorderRadius.all(Radius.circular(FrostRadius.xs)));
    await tester.pump(const Duration(milliseconds: 250));
    final phase = render.animationValue;
    await tester.pump(const Duration(milliseconds: 250));
    expect(render.animationValue, greaterThan(phase));
    await display(tester, const FrostListRow(title: 'Actual row').frostSkeleton(true), reduced: true);
    final reduced = tester.allRenderObjects.whereType<RenderSkeletonizer>().toSet().single;
    expect((reduced.config.effect as SolidColorEffect).color, tokens.fill);
    await tester.pump(const Duration(milliseconds: 250));
    expect(reduced.animationValue, 0);
  });
  for (final avatar in [false, true]) {
    testWidgets('shading layer stays inside the actual ${avatar ? 'circle' : 'continuous corner'} clip', (tester) async {
      final handle = tester.ensureSemantics();
      await display(tester, avatar ? FrostAvatar.skeleton(size: FrostAvatarSize.regular) : FrostMediaFrame.skeleton(aspectRatio: 1), reduced: true);
      final render = tester.allRenderObjects.whereType<RenderSkeletonizer>().toSet().single;
      Layer? layer = render.layer;
      var insideClip = false;
      while (layer != null) {
        insideClip |= avatar ? layer is ClipPathLayer : layer is ClipRSuperellipseLayer;
        layer = layer.parent;
      }
      expect(insideClip, true, reason: 'The pulse must never paint outside the real media boundary.');
      expect(find.bySemanticsLabel(FrostScope.labelsOf(tester.element(find.byWidgetPredicate((w) => w is FrostMediaFrame).first)).loading), findsOneWidget);
      handle.dispose();
    });
  }
  for (final footer in [null, 'Landscape']) {
    testWidgets('media card shading stays inside its clip, footer=$footer', (tester) async {
      final handle = tester.ensureSemantics();
      await display(tester, FrostMediaCard.skeleton(aspectRatio: 1, footer: footer), reduced: true);
      final render = tester.allRenderObjects.whereType<RenderSkeletonizer>().toSet();
      expect(render.length, footer == null ? 1 : 2);
      var mediaClips = 0;
      for (final skeleton in render) {
        Layer? layer = skeleton.layer;
        var insideClip = false;
        while (layer != null) {
          insideClip |= layer is ClipRSuperellipseLayer;
          layer = layer.parent;
        }
        if (insideClip) mediaClips++;
      }
      expect(mediaClips, 1, reason: 'Only the media shading is inside the rounded clip; the footer keeps its own text geometry.');
      final labels = FrostScope.labelsOf(tester.element(find.byWidgetPredicate((w) => w is FrostMediaCard).first));
      expect(find.bySemanticsLabel(labels.loading), findsOneWidget);
      expect(find.bySemanticsLabel('Landscape'), findsNothing);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('single loading semantics, reveal and child state preserved reduced=$reduced', (tester) async {
      final semantics = tester.ensureSemantics();
      var loading = true, calls = 0;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return _StatefulContent(onTap: () => calls++).frostSkeleton(loading);
          },
        ),
        reduced: reduced,
      );
      final state = tester.state<_ContentState>(find.byType(_StatefulContent));
      final original = tester.getSize(find.byType(_StatefulContent));
      final loadingLabel = FrostScope.labelsOf(tester.element(find.byType(_StatefulContent))).loading;
      expect(find.bySemanticsLabel(loadingLabel), findsOneWidget);
      expect(find.bySemanticsLabel('Content action'), findsNothing);
      update(() => loading = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 110));
      expect(identical(tester.state(find.byType(_StatefulContent)), state), true);
      expect(tester.getSize(find.byType(_StatefulContent)), original);
      final fade = tester.widget<FrostMaterialRevealTransition>(
        find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostMaterialRevealTransition)).first,
      );
      expect(fade.opacity.value, reduced ? 1 : inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.bySemanticsLabel(loadingLabel), findsNothing);
      expect(find.bySemanticsLabel('Content action'), findsOneWidget);
      await tester.tap(find.byType(_StatefulContent));
      expect(calls, 1);
      update(() => loading = true);
      await tester.pump();
      expect(identical(tester.state(find.byType(_StatefulContent)), state), true);
      semantics.dispose();
    });
  }
  test('old block and image skeleton APIs are absent', () {
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(file.readAsStringSync(), isNot(matches(r'\b(?:FrostSkeletonBlock|FrostImageSkeleton)\b')), reason: file.path);
    }
  });
}

class _StatefulContent extends StatefulWidget {
  const _StatefulContent({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_StatefulContent> createState() => _ContentState();
}

class _ContentState extends State<_StatefulContent> {
  @override
  Widget build(BuildContext context) => FrostButton(label: 'Content action', onPressed: widget.onTap);
}
