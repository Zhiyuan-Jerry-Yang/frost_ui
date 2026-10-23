import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'r2_material_reveal_test.dart' show expectSafeLayers;
import 'support.dart';

const nested = ValueKey('integration glass');

enum OverlayCase { menu, toolbar, popover, hover, dialog, sheet, toast, tooltip }

Widget nestedContent() => const SizedBox(
  width: 180,
  height: 80,
  child: FrostSurface(key: nested, role: FrostSurfaceRole.chrome, child: FrostText('Nested glass')),
);

FrostMaterialReveal reveal(WidgetTester tester) =>
    tester.widget<FrostMaterialReveal>(find.ancestor(of: find.byKey(nested), matching: find.byType(FrostMaterialReveal)).first);

FrostRevealHandle handle(WidgetTester tester) =>
    tester.widget<FrostContentRevealScope>(find.ancestor(of: find.byKey(nested), matching: find.byType(FrostContentRevealScope)).first).handle;

Future<void> systemBack(WidgetTester tester, String method, [double? progress]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall(
        method,
        progress == null
            ? null
            : <String, Object>{
                'touchOffset': <double>[20 + progress * 200, 300],
                'progress': progress,
                'swipeEdge': 0,
              },
      ),
    ),
    (_) {},
  );
}

void main() {
  for (final kind in OverlayCase.values) {
    for (final preference in ['normal', 'solid', 'reduced']) {
      testWidgets('$kind actual opening and closing layers $preference', (tester) async {
        tester.view.physicalSize = kind == OverlayCase.sheet ? const Size(500, 700) : const Size(900, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        late BuildContext origin;
        Widget trigger(VoidCallback open) => FrostButton(label: 'Open', onPressed: open);
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) {
                origin = context;
                final child = switch (kind) {
                  OverlayCase.menu || OverlayCase.toolbar => FrostControlScope(
                    toolbar: kind == OverlayCase.toolbar,
                    child: FrostMenuAnchor(
                      entries: [FrostMenuAction('Option', onSelected: () {})],
                      builder: (_, _, toggle) => trigger(toggle),
                    ),
                  ),
                  OverlayCase.popover => FrostPopover(builder: (_, _, toggle) => trigger(toggle), contentBuilder: (_, _) => nestedContent()),
                  OverlayCase.hover => FrostHoverPreview(
                    previewBuilder: (_) => nestedContent(),
                    child: Focus(focusNode: focus, child: const Text('Hover')),
                  ),
                  OverlayCase.dialog => trigger(
                    () => showFrostDialog<void>(
                      context: origin,
                      builder: (_) => FrostDialog(title: 'Dialog', content: nestedContent()),
                    ),
                  ),
                  OverlayCase.sheet => trigger(
                    () => showFrostSheet<void>(context: origin, title: 'Sheet', detents: const [FrostSheetDetent.fitted], builder: (_) => nestedContent()),
                  ),
                  OverlayCase.toast => trigger(() => FrostToast.error('Notice')),
                  OverlayCase.tooltip => const FrostTooltip(message: 'Tip', child: Text('Target')),
                };
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(disableAnimations: preference == 'reduced'),
                  child: Builder(
                    builder: (localContext) {
                      origin = localContext;
                      return Scaffold(body: Center(child: child));
                    },
                  ),
                );
              },
            ),
            reduceTransparency: preference == 'solid',
          ),
        );
        if (kind == OverlayCase.hover) {
          focus.requestFocus();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        } else if (kind == OverlayCase.tooltip) {
          tester.state<RawTooltipState>(find.byType(RawTooltip)).ensureTooltipVisible();
        } else {
          await tester.tap(find.text('Open'));
        }
        await tester.pump();
        var intermediate = false;
        for (var frame = 0; frame < 65; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectSafeLayers(tester);
          intermediate |= tester.widgetList<FrostMaterialReveal>(find.byType(FrostMaterialReveal)).any((w) => w.opacity > 0 && w.opacity < 1);
          intermediate |= tester.widgetList<FadeTransition>(find.byType(FadeTransition)).any((w) => w.opacity.value > 0 && w.opacity.value < 1);
        }
        if (preference != 'reduced' ||
            kind == OverlayCase.tooltip ||
            kind == OverlayCase.popover ||
            kind == OverlayCase.hover ||
            kind == OverlayCase.dialog ||
            kind == OverlayCase.sheet) {
          expect(intermediate, isTrue);
        }
        final samplers = expectSafeLayers(tester);
        expect(samplers, preference == 'solid' || kind == OverlayCase.tooltip ? 0 : greaterThan(0));
        switch (kind) {
          case OverlayCase.dialog || OverlayCase.sheet:
            Navigator.of(origin).pop();
          case OverlayCase.toast:
            await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == FrostScope.labelsOf(origin).dismiss));
          case OverlayCase.tooltip:
            RawTooltip.dismissAllToolTips();
          default:
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await tester.pump();
        for (var frame = 0; frame < 65; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectSafeLayers(tester);
        }
        expect(find.byKey(nested), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final sheet in [false, true]) {
    testWidgets('owned modal holds content while nested blur exits sheet=$sheet', (tester) async {
      tester.view.physicalSize = sheet ? const Size(500, 700) : const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext origin;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              origin = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );
      if (sheet) {
        showFrostSheet<void>(context: origin, builder: (_) => nestedContent(), detents: const [FrostSheetDetent.fitted]);
      } else {
        showFrostDialog<void>(
          context: origin,
          builder: (_) => FrostDialog(title: 'Dialog', content: nestedContent()),
        );
      }
      await tester.pumpAndSettle();
      expect(handle(tester).nestedProgress, 1);
      Navigator.of(origin).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(reveal(tester).opacity, 1);
      expect(handle(tester).nestedProgress, inExclusiveRange(0, 1));
      expectSafeLayers(tester);
      await tester.pump(const Duration(milliseconds: 70));
      expect(reveal(tester).opacity, 1);
      expect(handle(tester).nestedProgress, 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(reveal(tester).opacity, inExclusiveRange(0, 1));
      expect(handle(tester).nestedProgress, 0);
      expectSafeLayers(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(nested), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (predictive, opaque) in [(false, true), (true, true), (false, false), (true, false)]) {
    testWidgets('FrostDetailPage preserves pre-close sequence predictive=$predictive opaque=$opaque', (tester) async {
      var shown = false;
      late StateSetter update;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Navigator(
                key: navigator,
                pages: [
                  const MaterialPage<void>(child: Scaffold(body: Text('Home'))),
                  if (shown)
                    FrostDetailPage<void>.media(
                      key: const ValueKey('detail'),
                      opaque: opaque,
                      child: Scaffold(body: Center(child: nestedContent())),
                    ),
                ],
                onDidRemovePage: (_) => update(() => shown = false),
              );
            },
          ),
          platform: TargetPlatform.android,
        ),
      );
      update(() => shown = true);
      await tester.pumpAndSettle();
      if (predictive) {
        await systemBack(tester, 'startBackGesture', 0);
        await systemBack(tester, 'updateBackGestureProgress', .3);
        await tester.pump();
        expect(navigator.currentState!.userGestureInProgress, isTrue);
        expect(reveal(tester).opacity, inExclusiveRange(0, 1));
        expect(handle(tester).nestedProgress, 0);
        expectSafeLayers(tester);
        await systemBack(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(navigator.currentState!.userGestureInProgress, isFalse);
        expect(find.byKey(nested), findsOneWidget);
        await systemBack(tester, 'startBackGesture', 0);
        await systemBack(tester, 'updateBackGestureProgress', .3);
        await tester.pump();
        await systemBack(tester, 'commitBackGesture');
      } else {
        navigator.currentState!.pop();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      if (predictive) {
        expect(reveal(tester).opacity, inInclusiveRange(0, 1));
        expect(handle(tester).nestedProgress, 0);
      } else {
        expect(reveal(tester).opacity, 1);
        expect(handle(tester).nestedProgress, inExclusiveRange(0, 1));
      }
      expectSafeLayers(tester);
      await tester.pump(const Duration(milliseconds: 70));
      expect(reveal(tester).opacity, predictive ? inInclusiveRange(0, 1) : 1);
      expect(handle(tester).nestedProgress, 0);
      await tester.pumpAndSettle();
      expect(find.byKey(nested), findsNothing);
      expect(navigator.currentState!.userGestureInProgress, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
