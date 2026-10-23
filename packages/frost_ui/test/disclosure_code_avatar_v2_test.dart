import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_control_geometry.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'display_badges_v2_test.dart' show display, decorations;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => FrostButton(label: 'Count $count', onPressed: () => setState(() => count++));
}

void main() {
  testWidgets('disclosure retains unkeyed child state across motion preference changes', (tester) async {
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: const FrostDisclosure(title: 'Preferences', initiallyExpanded: true, child: Counter()),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Count 0'));
    await tester.pumpAndSettle();
    final before = tester.state<CounterState>(find.byType(Counter));
    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();
    update(() => reduced = true);
    await tester.pump();
    expect(tester.state<CounterState>(find.byType(Counter, skipOffstage: false)), same(before));
    update(() => reduced = false);
    await tester.pump();
    expect(tester.state<CounterState>(find.byType(Counter, skipOffstage: false)), same(before));
    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final direction in TextDirection.values) {
    for (final reduced in [false, true]) {
      testWidgets('disclosure retains child, rotates actual arrow and excludes hidden focus $direction $reduced', (tester) async {
        final semantics = tester.ensureSemantics(), childKey = GlobalKey<CounterState>();
        await display(
          tester,
          FrostDisclosure(
            title: 'Details',
            child: Counter(key: childKey),
          ),
          direction: direction,
          reduced: reduced,
        );
        final initialState = childKey.currentState!;
        final title = find.byType(FrostClickSurface).first;
        final closed = tester.getSize(find.byType(FrostDisclosure)).height;
        expect(tester.getSemantics(title).getSemanticsData().flagsCollection.isExpanded, Tristate.isFalse);
        expect(find.bySemanticsLabel('Count 0'), findsNothing);
        expect(Focus.of(tester.element(find.text('Count 0', skipOffstage: false))).canRequestFocus, false);
        await tester.tap(find.text('Details'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final rotation = tester.widget<RotationTransition>(find.byType(RotationTransition)).turns.value;
        final target = direction == TextDirection.ltr ? .25 : -.25;
        expect(rotation.abs(), reduced ? .25 : inExclusiveRange(0, .25));
        final middle = tester.getSize(find.byType(FrostDisclosure)).height;
        await tester.pumpAndSettle();
        final open = tester.getSize(find.byType(FrostDisclosure)).height;
        expect(middle, reduced ? open : inExclusiveRange(closed, open));
        expect(tester.widget<RotationTransition>(find.byType(RotationTransition)).turns.value, target);
        expect(tester.widget<FrostIcon>(find.byType(FrostIcon)).icon, testIcons.chevronRight);
        await tester.tap(find.text('Count 0'));
        await tester.pumpAndSettle();
        expect(childKey.currentState!.count, 1);
        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();
        expect(childKey.currentState, same(initialState));
        expect(find.bySemanticsLabel('Count 1'), findsNothing);
        expect(TickerMode.valuesOf(tester.element(find.text('Count 1', skipOffstage: false))).enabled, false);
        expect(find.text('Count 1'), findsNothing);
        tester.widget<Focus>(find.descendant(of: title, matching: find.byType(Focus)).first).focusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Count 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
  testWidgets('controlled disclosure reports requests without changing its input', (tester) async {
    final requests = <bool>[];
    var expanded = false;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostDisclosure(title: 'Controlled', expanded: expanded, onExpansionChanged: requests.add, child: const Text('Body'));
        },
      ),
    );
    await tester.tap(find.text('Controlled'));
    await tester.pumpAndSettle();
    expect(requests, [true]);
    expect(find.text('Body'), findsNothing);
    update(() => expanded = true);
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    testWidgets('disclosure typography, density, large text and feedback $density', (tester) async {
      await display(
        tester,
        const FrostDisclosure(title: 'A long complete title at large scale', child: Text('Body')),
        width: 160,
        scale: 2,
        direction: TextDirection.rtl,
        density: density,
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text('A long complete title at large scale'));
      expect(paragraph.maxLines, isNull);
      expect(paragraph.didExceedMaxLines, false);
      final context = tester.element(find.byType(FrostDisclosure)), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostDisclosure)));
      expect(paragraph.text.style!.fontSize, FrostTypography.of(context).style(FrostTextRole.headline).fontSize);
      expect(paragraph.text.style!.color, tokens.textPrimary);
      expect(
        tester.getSize(find.byType(FrostClickSurface)).height,
        greaterThanOrEqualTo(frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.headline).height),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('A long complete title at large scale')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect((decorations(tester, find.byType(FrostClickFeedbackVisual)).first.decoration as ShapeDecoration).color!.a, greaterThan(0));
      await mouse.down(tester.getCenter(find.text('A long complete title at large scale')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        tester
            .widgetList<Transform>(find.descendant(of: find.byType(FrostClickFeedbackVisual), matching: find.byType(Transform)))
            .where((w) => w.transform.getMaxScaleOnAxis() < 1),
        isEmpty,
      );
      await mouse.cancel();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('code copy exact content, crossfade, 1500ms reset, announcement and stable focus', (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = <MethodCall>[], announcements = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (message) async {
      announcements.add(message);
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null);
    });
    await display(tester, const FrostCodeBlock(text: 'line 1\nline 2'));
    final surface = find.byType(FrostClickSurface), node = tester.widget<Focus>(find.descendant(of: surface, matching: find.byType(Focus)).first).focusNode!;
    expect(tester.getSemantics(surface).getSemanticsData().label, 'L.copy');
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls.where((call) => call.method == 'Clipboard.setData').single.arguments, {'text': 'line 1\nline 2'});
    expect(announcements.any((event) => event is Map && (event['data'] as Map?)?['message'] == 'L.copied'), true);
    final check = find.byKey(const ValueKey(true));
    expect(check, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 70));
    final fade = tester.widget<FadeTransition>(find.ancestor(of: check, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(FocusManager.instance.primaryFocus, same(node));
    await tester.pump(const Duration(milliseconds: 1429));
    expect(check, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey(false)), findsOneWidget);
    await tester.pumpAndSettle();
    expect(check, findsNothing);
    expect(FocusManager.instance.primaryFocus, same(node));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  for (final brightness in Brightness.values) {
    testWidgets('code actual surface, mono role, no wrap and horizontal scroll $brightness', (tester) async {
      await display(
        tester,
        const FrostCodeBlock(text: 'one very long unbroken source code line 1234567890\nsecond line', copyable: false),
        width: 160,
        scale: 2,
        direction: TextDirection.rtl,
        brightness: brightness,
      );
      final block = find.byType(FrostCodeBlock), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostCodeBlock)));
      final decoration = decorations(tester, block).first.decoration as ShapeDecoration;
      expect(decoration.color, tokens.fillSubtle);
      expect((decoration.shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.rtl).topLeft.x, 10);
      final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectable.style!.fontFamily, 'Consolas');
      expect(selectable.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
      expect(editable.text!.style!.color, tokens.textPrimary);
      expect(editable.text!.style!.fontSize, FrostTypography.of(tester.element(block)).style(FrostTextRole.callout).fontSize);
      expect(editable.size.height, closeTo(editable.preferredLineHeight * 2, .1));
      expect(tester.stateList<ScrollableState>(find.descendant(of: block, matching: find.byType(Scrollable))).any((s) => s.position.maxScrollExtent > 0), true);
      expect(find.byType(FrostClickSurface), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('code ignores stale clipboard completion after disposal', (tester) async {
    final completion = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await completion.future;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await display(tester, const FrostCodeBlock(text: 'source'));
    await tester.tap(find.byType(FrostClickSurface));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    completion.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  for (final (size, dimension, iconSize, role) in [
    (FrostAvatarSize.small, 24.0, 16.0, FrostTextRole.caption),
    (FrostAvatarSize.regular, 32.0, 18.0, FrostTextRole.footnote),
    (FrostAvatarSize.large, 40.0, 22.0, FrostTextRole.callout),
    (FrostAvatarSize.xlarge, 56.0, 28.0, FrostTextRole.headline),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('avatar real circle, dimensions, placeholder, graphemes $size $scale', (tester) async {
        final semantics = tester.ensureSemantics();
        await display(
          tester,
          FrostAvatar(size: size, semanticLabel: 'User'),
          scale: scale,
          direction: TextDirection.rtl,
        );
        final avatar = find.byType(FrostAvatar), tokens = FrostThemeTokens.of(tester.element(find.byType(FrostAvatar)));
        expect(tester.getSize(avatar), Size.square(dimension));
        expect(find.byType(ClipOval), findsOneWidget);
        final stroke = decorations(tester, find.byType(FrostMediaFrame)).first.decoration as ShapeDecoration;
        expect(stroke.shape, isA<CircleBorder>());
        expect((stroke.shape as CircleBorder).side.color, tokens.mediaInnerStroke);
        expect((stroke.shape as CircleBorder).side.width, 1);
        final icon = tester.widget<FrostIcon>(find.byType(FrostIcon));
        expect(icon.size, iconSize);
        expect(icon.color, tokens.textTertiary);
        expect((decorations(tester, avatar).first.decoration as BoxDecoration).color, tokens.fill);
        final data = tester.getSemantics(avatar).getSemanticsData();
        expect(data.label, 'User');
        expect(data.flagsCollection.isImage, true);
        await display(
          tester,
          FrostAvatar(size: size, initials: '👩‍💻AB', semanticLabel: 'Initials'),
          scale: scale,
          direction: TextDirection.rtl,
        );
        expect(find.text('👩‍💻A'), findsOneWidget);
        final text = tester.renderObject<RenderParagraph>(find.text('👩‍💻A'));
        expect(text.text.style!.fontSize, FrostTypography.of(tester.element(find.byType(FrostAvatar))).style(role).fontSize);
        expect(text.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
  testWidgets('avatar provider failure, fade, explicit child and exclusivity', (tester) async {
    final error = ControlledImage();
    await display(tester, FrostAvatar(image: error, initials: 'XY', semanticLabel: 'User'));
    error.completer.fail(StateError('image failure'));
    await tester.pump();
    expect(find.text('XY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final image = ControlledImage();
    await display(tester, FrostAvatar(image: image, semanticLabel: 'Loaded'));
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    final opacity = find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity));
    expect(tester.renderObject<RenderOpacity>(opacity).opacity, 0);
    await tester.pump(FrostMotion.imageFade ~/ 2);
    expect(tester.renderObject<RenderOpacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    const child = Text('App-owned');
    await display(tester, const FrostAvatar(semanticLabel: 'Child', child: child));
    expect(tester.widget<FrostMediaFrame>(find.byType(FrostMediaFrame)).child, same(child));
    expect(find.text('App-owned'), findsOneWidget);
    expect(() => FrostAvatar(image: ControlledImage(), semanticLabel: 'Invalid', child: const SizedBox()), throwsAssertionError);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced code feedback and avatar loading apply without moving transitions', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await display(tester, const FrostCodeBlock(text: 'source'), width: 160, scale: 2, reduced: true);
    await tester.tap(find.byType(FrostClickSurface));
    await tester.pump();
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    expect(find.byKey(const ValueKey(false)), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.takeException(), isNull);
    final image = ControlledImage();
    await display(tester, FrostAvatar(image: image, semanticLabel: 'Reduced'), reduced: true);
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
