import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/_skeleton_geometry.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:skeletonizer/src/rendering/render_skeletonizer.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';

Widget host(
  Widget child, {
  FrostSkeletonStyle? style,
  Brightness brightness = Brightness.light,
  bool reduced = false,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  double width = 300,
}) => frostTestApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced, textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: direction,
        child: FrostScope(
          config: testConfig.copyWith(skeleton: style),
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  ),
  brightness: brightness,
  density: FrostDensity.compact,
);

List<RenderFrostSkeletonText> textBones(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderFrostSkeletonText>().toSet().where((bone) => bone.enabled && bone.bones.isNotEmpty).toList();
RenderSkeletonizer skeleton(WidgetTester tester) => tester.allRenderObjects.whereType<RenderSkeletonizer>().toSet().single;

void main() {
  test('appearance defaults and resolver ownership', () {
    const style = FrostSkeletonStyle();
    expect(style.color, isNull);
    expect(style.highlightColor, isNull);
    expect(style.effect, FrostSkeletonEffect.pulse);
    expect(style.period, const Duration(milliseconds: 1000));
    expect(style.textRadius, isNull);
    expect(style.textHeightFactor, .7);
    expect(testConfig.skeleton, isNull);
    expect(testConfig.copyWith(skeleton: style).skeleton, same(style));
    expect(() => FrostSkeletonStyle(textHeightFactor: 0), throwsAssertionError);
    expect(() => FrostSkeletonStyle(textRadius: -1), throwsAssertionError);
  });
  testWidgets('FrostApp supplies the configured effect and radius to raw Skeletonizer', (tester) async {
    final style = FrostSkeletonStyle(effect: FrostSkeletonEffect.solid, color: (tokens) => tokens.infoInk, textRadius: 2);
    final router = TestRouter(const Skeletonizer(child: FrostText('App config')));
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig.copyWith(skeleton: style),
        title: 'App',
        routerConfig: RouterConfig<Object>(routerDelegate: router),
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostText)));
    expect((skeleton(tester).config.effect as SolidColorEffect).color, tokens.infoInk);
    expect(skeleton(tester).config.textBorderRadius.borderRadius, BorderRadius.circular(2));
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  testWidgets('null colour resolvers keep current default fill in both modes', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(host(const FrostText('Default').frostSkeleton(true), brightness: brightness));
      await tester.pump(const Duration(milliseconds: 300));
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostText)));
      final effect = skeleton(tester).config.effect as PulseEffect;
      expect(effect.from, tokens.fill);
      expect(effect.to, tokens.fillStrong);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('self-painted expandable text uses configured line bones immediately', (tester) async {
    await tester.pumpWidget(host(FrostExpandableText(text: 'An intentionally long paragraph. ' * 20).frostSkeleton(true), reduced: true));
    final body = textBones(tester).where((r) => r.painter != null).single;
    expect(body.bones, hasLength(3));
    for (var i = 1; i < body.bones.length; i++) {
      expect(body.bones[i].top - body.bones[i - 1].bottom, greaterThanOrEqualTo(4 - .001));
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('filled icon plate paints only its outer bone', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: key,
          child: FrostButton.icon(icon: testIcons.add, label: 'Action', onPressed: () {}).frostSkeleton(true),
        ),
        style: FrostSkeletonStyle(effect: FrostSkeletonEffect.solid, color: (tokens) => tokens.infoInk),
        reduced: true,
      ),
    );
    final root = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => root.toImage()))!;
    final data = (await tester.runAsync(() => image.toByteData()))!.buffer.asUint8List();
    List<int> at(Offset point) {
      final p = root.globalToLocal(point);
      final n = (p.dy.floor() * image.width + p.dx.floor()) * 4;
      return data.sublist(n, n + 4);
    }

    final center = tester.getCenter(find.byType(FrostButton));
    expect(at(center), at(center + const Offset(5, 5)));
    image.dispose();
  });
  testWidgets('same resolver configuration follows light and dark current tokens', (tester) async {
    final style = FrostSkeletonStyle(
      color: (tokens) => tokens.positiveTint,
      highlightColor: (tokens) => tokens.positiveInk,
      period: const Duration(milliseconds: 1350),
      textRadius: 3,
      textHeightFactor: .5,
    );
    final colours = <Color>[];
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(host(const FrostText('Theme sample').frostSkeleton(true), style: style, brightness: brightness));
      await tester.pump(const Duration(milliseconds: 300));
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostText)));
      final effect = skeleton(tester).config.effect as PulseEffect;
      expect(effect.from, tokens.positiveTint);
      expect(effect.to, tokens.positiveInk);
      expect(effect.duration, style.period);
      expect(textBones(tester).single.radius, 3);
      expect(textBones(tester).single.bones, hasLength(1), reason: textBones(tester).single.bones.toString());
      expect(
        textBones(tester).single.bones.first.height,
        closeTo(FrostTypography.of(tester.element(find.byType(FrostText))).style(FrostTextRole.body).fontSize! * .5, .001),
      );
      colours.add(effect.from);
    }
    expect(colours.first, isNot(colours.last));
    await tester.pumpWidget(const SizedBox());
  });
  for (final effect in FrostSkeletonEffect.values) {
    testWidgets('reduced motion forces solid for $effect and keeps the configured base', (tester) async {
      final style = FrostSkeletonStyle(effect: effect, color: (tokens) => tokens.cautionInk);
      await tester.pumpWidget(host(const FrostText('Static').frostSkeleton(true), style: style, reduced: true));
      final render = skeleton(tester);
      expect(render.config.effect, isA<SolidColorEffect>());
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostText)));
      expect((render.config.effect as SolidColorEffect).color, tokens.cautionInk);
      await tester.pump(const Duration(seconds: 3));
      expect(render.animationValue, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('shimmer shader actually mirrors its travel in RTL', (tester) async {
    await tester.pumpWidget(
      host(
        const FrostText('Shimmer').frostSkeleton(true),
        style: const FrostSkeletonStyle(effect: FrostSkeletonEffect.shimmer, period: Duration(milliseconds: 1500)),
      ),
    );
    final effect = skeleton(tester).config.effect as ShimmerEffect;
    expect(effect.duration, const Duration(milliseconds: 1500));
    Future<List<int>> pixels(TextDirection direction) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 4), effect.createPaint(.25, const Rect.fromLTWH(0, 0, 100, 4), direction));
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 4);
      final data = (await image.toByteData())!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return data;
    }

    final ltr = (await tester.runAsync(() => pixels(TextDirection.ltr)))!, rtl = (await tester.runAsync(() => pixels(TextDirection.rtl)))!;
    for (var x = 0; x < 100; x++) {
      for (var channel = 0; channel < 4; channel++) {
        // Rasterization may round the mirrored gradient by one byte.
        expect((ltr[x * 4 + channel] - rtl[(99 - x) * 4 + channel]).abs(), lessThanOrEqualTo(1));
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('one paragraph bone has actual width and centred configured height at $scale', (tester) async {
      await tester.pumpWidget(host(const FrostText('Real width').frostSkeleton(true), scale: scale, reduced: true));
      final render = textBones(tester).single, bone = render.bones.single;
      final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText).first);
      final boxes = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 10));
      expect(bone.width, closeTo(boxes.fold<double>(0, (v, b) => v + b.right - b.left), .001));
      expect(bone.height, closeTo(paragraph.text.style!.fontSize! * scale * .7, .001));
      expect(bone.center.dy, closeTo(render.size.height / 2, .001));
    });
    testWidgets('tight multiline and adjacent title/subtitle keep at least four at $scale', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FrostText.rich(TextSpan(text: 'First line\nSecond line', style: TextStyle(height: .8))),
              FrostText('Adjacent subtitle', role: FrostTextRole.footnote),
            ],
          ).frostSkeleton(true),
          style: const FrostSkeletonStyle(textHeightFactor: 3),
          scale: scale,
          reduced: true,
        ),
      );
      final bones = textBones(tester);
      expect(bones, hasLength(2));
      expect(bones.first.bones.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < bones.first.bones.length; i++) {
        expect(bones.first.bones[i].top - bones.first.bones[i - 1].bottom, greaterThanOrEqualTo(4 - .001));
      }
      final firstBottom = bones.first.localToGlobal(bones.first.bones.last.bottomLeft).dy;
      final secondTop = bones.last.localToGlobal(bones.last.bones.first.topLeft).dy;
      expect(secondTop - firstBottom, greaterThanOrEqualTo(4 - .001));
    });
  }
  testWidgets('inline stat value and unit keep actual minimum gap; rolling value is one bone', (tester) async {
    await tester.pumpWidget(host(const FrostStat(value: '1,280', unit: 'MB', caption: 'Stored').frostSkeleton(true), reduced: true));
    final bones = textBones(tester);
    expect(bones, hasLength(3));
    expect(bones.first.bones, hasLength(1));
    expect(
      bones[1].localToGlobal(bones[1].bones.single.topLeft).dx - bones.first.localToGlobal(bones.first.bones.single.topRight).dx,
      greaterThanOrEqualTo(4 - .001),
    );
    expect(find.text('1,280'), findsOneWidget);
    await tester.pumpWidget(host(FrostModule.skeleton(title: 'Stored', icon: true, value: '1,280', note: 'Since yesterday'), reduced: true));
    expect(textBones(tester), hasLength(3));
    expect(find.text('1,280'), findsOneWidget);
  });
  testWidgets('FrostText.rich uses one line bone across differently styled spans', (tester) async {
    await tester.pumpWidget(
      host(
        const FrostText.rich(
          TextSpan(
            children: [
              TextSpan(text: 'One '),
              TextSpan(
                text: 'paragraph',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ).frostSkeleton(true),
        reduced: true,
      ),
    );
    expect(textBones(tester).single.bones, hasLength(1));
  });
  testWidgets('rich lines use their own actual font size and merge mixed runs', (tester) async {
    await tester.pumpWidget(
      host(
        const FrostText.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Large', style: TextStyle(fontSize: 30, height: 1.4)),
              TextSpan(text: ' mix\n', style: TextStyle(fontSize: 12)),
              TextSpan(text: 'Small', style: TextStyle(fontSize: 10, height: 1.4)),
            ],
          ),
        ).frostSkeleton(true),
        reduced: true,
      ),
    );
    final bones = textBones(tester).single.bones;
    expect(bones, hasLength(2));
    expect(bones.first.height, closeTo(30 * .7, .001));
    expect(bones.last.height, closeTo(10 * .7, .001));
    expect(bones.last.top - bones.first.bottom, greaterThanOrEqualTo(4 - .001));
  });
  testWidgets('avatar and badge paint one uniform outer bone, no inner glyphs', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: boundaryKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FrostAvatar(initials: 'AB', size: FrostAvatarSize.xlarge, semanticLabel: 'User'),
              const FrostBadge(label: 'Label', icon: FrostIconData.glyph(Icons.add)),
            ],
          ).frostSkeleton(true),
        ),
        style: FrostSkeletonStyle(effect: FrostSkeletonEffect.solid, color: (tokens) => tokens.positiveInk),
        reduced: true,
      ),
    );
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(() => image.toByteData()))!.buffer.asUint8List();
    List<int> at(Offset global) {
      final p = boundary.globalToLocal(global);
      final offset = (p.dy.floor() * image.width + p.dx.floor()) * 4;
      return data.sublist(offset, offset + 4);
    }

    final avatar = tester.getRect(find.byType(FrostAvatar));
    expect(at(avatar.center), at(avatar.center + const Offset(8, 8)));
    expect(at(avatar.center), at(avatar.center + const Offset(-8, -8)));
    final badge = tester.getRect(find.byType(FrostBadge));
    expect(at(badge.center), at(Offset(badge.left + 8, badge.center.dy)));
    image.dispose();
  });
  for (final card in [false, true]) {
    testWidgets('unbounded null ratio reports missing shape card=$card', (tester) async {
      await tester.pumpWidget(
        host(SingleChildScrollView(child: card ? FrostMediaCard.skeleton(aspectRatio: null, footer: null) : FrostMediaFrame.skeleton(aspectRatio: null))),
      );
      expect(tester.takeException(), isA<FlutterError>().having((e) => e.toString(), 'message', contains('requires aspectRatio')));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
