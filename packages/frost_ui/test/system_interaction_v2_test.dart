import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart';

import 'support.dart';

Future<void> systemApp(WidgetTester tester, Widget child, {double width = 300, bool reduced = false}) => tester.pumpWidget(
  frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  ),
);
Finder copyButton() => find.byType(FrostClickSurface);
ShapeDecoration dropDecoration(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((w) => w.decoration)
    .whereType<ShapeDecoration>()
    .singleWhere((d) => d.shape is OutlinedBorder && (d.shape as OutlinedBorder).side.width == 2);

void main() {
  testWidgets('Copyable wraps selectable display, copies source, announces and checks for exactly 1500ms', (tester) async {
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
    await systemApp(
      tester,
      const FrostCopyable(text: 'full source', display: 'A displayed value that wraps across several lines in a narrow area', monospace: true),
      width: 180,
    );
    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.maxLines, isNull);
    expect(selectable.enableInteractiveSelection, true);
    expect(selectable.style!.fontFamily, 'Consolas');
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.renderEditable.size.height, greaterThan(state.renderEditable.preferredLineHeight * 2));
    final selection = await tester.startGesture(tester.getTopLeft(find.byType(SelectableText)) + const Offset(5, 5), kind: PointerDeviceKind.mouse);
    await selection.moveBy(const Offset(60, 0));
    await selection.up();
    await tester.pumpAndSettle();
    expect(state.textEditingValue.selection.isValid, true);
    expect(state.textEditingValue.selection.isCollapsed, false);
    await tester.tap(copyButton());
    await tester.pump();
    expect(calls.where((c) => c.method == 'Clipboard.setData').single.arguments, {'text': 'full source'});
    expect(announcements.any((e) => e is Map && (e['data'] as Map?)?['message'] == 'L.copied'), true);
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey(false)), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(true)), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('Copyable secondary click on selectable text opens one shared Copy action', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await systemApp(tester, const FrostCopyable(text: 'source', display: 'Display'));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SelectableText)), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuItem), findsOneWidget);
    expect(find.text('L.copy'), findsOneWidget);
    await tester.tap(find.byType(FrostMenuItem));
    await tester.pumpAndSettle();
    expect(clipboard, 'source');
    expect(find.byKey(const ValueKey(true)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Copyable ignores stale clipboard completion when text changes or unmounts', (tester) async {
    final completion = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await completion.future;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await systemApp(tester, const FrostCopyable(text: 'old'));
    await tester.tap(copyButton());
    await systemApp(tester, const FrostCopyable(text: 'new'));
    completion.complete();
    await tester.pump();
    expect(find.byKey(const ValueKey(true)), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Share passes source, gates loading and prevents repeated invocations', (tester) async {
    final done = Completer<void>();
    final values = <String>[];
    await systemApp(
      tester,
      FrostShare(
        text: 'share source',
        label: 'Share',
        onShare: (value) {
          values.add(value);
          return done.future;
        },
      ),
    );
    final button = tester.widget<FrostButton>(find.byType(FrostButton));
    expect(button.icon, testIcons.share);
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(values, ['share source']);
    expect(tester.widget<FrostButton>(find.byType(FrostButton)).loading, true);
    await tester.pump(const Duration(milliseconds: 299));
    expect(TickerMode.valuesOf(tester.element(find.byType(FrostActivityIndicator))).enabled, false);
    await tester.pump(const Duration(milliseconds: 1));
    expect(TickerMode.valuesOf(tester.element(find.byType(FrostActivityIndicator))).enabled, true);
    done.complete();
    await tester.pump();
    expect(tester.widget<FrostButton>(find.byType(FrostButton)).loading, false);
    await tester.pump(const Duration(milliseconds: 399));
    expect(TickerMode.valuesOf(tester.element(find.byType(FrostActivityIndicator))).enabled, true);
    await tester.pumpAndSettle();
    expect(TickerMode.valuesOf(tester.element(find.byType(FrostActivityIndicator))).enabled, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Share recovers and reports errors, ignores completion after disposal', (tester) async {
    await systemApp(tester, FrostShare(text: 'source', label: 'Share', onShare: (_) => Future.error(StateError('failed'))));
    await tester.tap(find.byType(FrostButton));
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(tester.widget<FrostButton>(find.byType(FrostButton)).loading, false);
    final done = Completer<void>();
    await systemApp(tester, FrostShare(text: 'source', label: 'Share', onShare: (_) => done.future));
    await tester.tap(find.byType(FrostButton));
    await tester.pumpWidget(const SizedBox());
    done.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Share without integration copies source and shows shared copied toast', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await systemApp(tester, const FrostShare(text: 'fallback source', label: 'Share'));
    await tester.tap(find.byType(FrostButton));
    await tester.pumpAndSettle();
    expect(clipboard, 'fallback source');
    expect(find.text('L.copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  testWidgets('Drop highlight uses tokens, inside border, nearest surface radius, hint and pointer pass-through', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await systemApp(
      tester,
      FrostSurface(
        role: FrostSurfaceRole.panel,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 100,
          child: FrostButton(label: 'Underlay', onPressed: () => calls++),
        ).frostDropTarget(active: true, hint: 'Drop here'),
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.text('Drop here')));
    final decoration = dropDecoration(tester), shape = decoration.shape as RoundedSuperellipseBorder;
    expect(decoration.color, tokens.selectionFill);
    expect(shape.side.color, tokens.actionFill);
    expect(shape.side.width, 2);
    expect(shape.side.strokeAlign, BorderSide.strokeAlignInside);
    expect(shape.borderRadius.resolve(TextDirection.ltr).topLeft.x, 30);
    final hint = tester.widget<Text>(find.text('Drop here'));
    expect(hint.style!.color, tokens.selectionInk);
    expect(hint.style!.fontSize, FrostTypography.of(tester.element(find.text('Drop here'))).style(FrostTextRole.callout).fontSize);
    final region = find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true && w.properties.hint == 'Drop here');
    expect(tester.getSemantics(region).getSemanticsData().hint, 'Drop here');
    await tester.tap(find.byType(FrostClickSurface));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await systemApp(tester, const SizedBox(height: 100).frostDropTarget(active: true));
    expect((dropDecoration(tester).shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, 12);
    await systemApp(
      tester,
      const FrostSurface(
        role: FrostSurfaceRole.overlay,
        borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(8), bottomEnd: Radius.circular(24)),
        child: SizedBox(height: 100),
      ).frostDropTarget(active: true),
    );
    final direct = (dropDecoration(tester).shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr);
    expect(direct.topLeft.x, 8);
    expect(direct.bottomRight.x, 24);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('Drop presence shows and dismisses in 140ms with intermediate fade/scale frames', (tester) async {
    var active = false;
    late StateSetter update;
    await systemApp(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return const SizedBox(height: 100).frostDropTarget(active: active, hint: 'Drop');
        },
      ),
    );
    update(() => active = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(
      tester
          .widget<FrostMaterialRevealTransition>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(FrostMaterialRevealTransition)))
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    expect(
      tester.widget<ScaleTransition>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(ScaleTransition))).scale.value,
      inExclusiveRange(.96, 1),
    );
    await tester.pump(const Duration(milliseconds: 70));
    expect(
      tester
          .widget<FrostMaterialRevealTransition>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(FrostMaterialRevealTransition)))
          .opacity
          .value,
      1,
    );
    update(() => active = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(
      tester
          .widget<FrostMaterialRevealTransition>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(FrostMaterialRevealTransition)))
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('Drop'), findsNothing);
  });
  testWidgets('Drop reduced motion keeps presence opacity but removes scale', (tester) async {
    var active = false;
    late StateSetter update;
    await systemApp(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return const SizedBox(height: 100).frostDropTarget(active: active, hint: 'Drop');
        },
      ),
      reduced: true,
    );
    update(() => active = true);
    await tester.pump();
    await tester.pump(FrostMotion.reducedFade ~/ 2);
    expect(find.descendant(of: find.byType(FrostPresence), matching: find.byType(ScaleTransition)), findsNothing);
    expect(
      tester
          .widget<FrostMaterialRevealTransition>(find.descendant(of: find.byType(FrostPresence), matching: find.byType(FrostMaterialRevealTransition)))
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
