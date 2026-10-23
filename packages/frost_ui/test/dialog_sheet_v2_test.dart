import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/overlays/_modal_frame.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';

Future<void> launch(
  WidgetTester tester,
  void Function(BuildContext) open, {
  Size size = const Size(900, 700),
  bool settle = true,
  FocusNode? origin,
  bool reduced = false,
  bool router = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final body = Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FrostButtonControl(label: 'Open', focusNode: origin, onPressed: () => open(context)),
          ),
        ),
      ),
    ),
  );
  if (router) {
    final delegate = TestRouter(body);
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig,
        title: 'Test',
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
      ),
    );
  } else {
    await tester.pumpWidget(frostTestApp(body));
  }
  if (origin != null) {
    origin.requestFocus();
    await tester.pump();
  }
  await tester.tap(find.text('Open'));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Finder get modalSurface => find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.sheet);

FrostButtonControl action(WidgetTester tester, String label) =>
    tester.widget<FrostButtonControl>(find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == label));

double dividerOpacity(WidgetTester tester, bool atTop) => tester
    .renderObject<RenderFrostModalScrollDivider>(find.byWidgetPredicate((widget) => widget is FrostModalScrollDivider && widget.atTop == atTop))
    .paintedOpacity;

void main() {
  testWidgets('Alert measures 400 and orders the same buttons in the cold frame', (tester) async {
    await launch(
      tester,
      (context) => showFrostAlert<int>(
        context: context,
        title: 'Title',
        message: 'Message',
        actions: const [
          FrostDialogAction(label: 'Go', value: 1, isDefault: true),
          FrostDialogAction(label: 'Other', value: 2),
          FrostDialogAction(label: 'Cancel', value: 0, role: FrostButtonRole.cancel),
        ],
      ),
      settle: false,
    );
    expect(tester.getSize(modalSurface).width, 400);
    expect(tester.getTopLeft(find.text('Cancel')).dx, lessThan(tester.getTopLeft(find.text('Other')).dx));
    expect(tester.getTopLeft(find.text('Other')).dx, lessThan(tester.getTopLeft(find.text('Go')).dx));
    expect(tester.getCenter(find.text('Cancel')).dy, tester.getCenter(find.text('Go')).dy);
    expect(action(tester, 'Go').variant, FrostButtonVariant.prominent);
    expect(action(tester, 'Other').variant, FrostButtonVariant.standard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Alert overflows into full width default-first cancel-last before paint', (tester) async {
    await launch(
      tester,
      (context) => showFrostAlert(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Cancel a very long operation', role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'Keep another long operation'),
          FrostDialogAction(label: 'Delete a very long operation', isDefault: true, role: FrostButtonRole.destructive),
        ],
      ),
      settle: false,
    );
    final buttons = ['Delete a very long operation', 'Keep another long operation', 'Cancel a very long operation'];
    for (var index = 1; index < buttons.length; index++) {
      expect(tester.getCenter(find.text(buttons[index])).dy, greaterThan(tester.getCenter(find.text(buttons[index - 1])).dy));
    }
    for (final label in buttons) {
      final button = find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == label);
      expect(tester.getSize(button).width, 360);
      final paintedFill = find.descendant(of: button, matching: find.byType(FrostInteractionDecoration)).first;
      expect(tester.getSize(paintedFill).width, 360);
    }
    expect(action(tester, buttons.first).variant, FrostButtonVariant.prominent);
    expect(action(tester, buttons.first).role, FrostButtonRole.destructive);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Alert asserts duplicate defaults or cancels', (tester) async {
    expect(
      () => FrostAlert(
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'A', isDefault: true),
          FrostDialogAction(label: 'B', isDefault: true),
        ],
      ),
      throwsAssertionError,
    );
    expect(
      () => FrostDialog(
        title: 'Title',
        content: const SizedBox(),
        actions: const [
          FrostDialogAction(label: 'A', role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'B', role: FrostButtonRole.cancel),
        ],
      ),
      throwsAssertionError,
    );
  });

  testWidgets('Enter returns default value and focus restores to origin', (tester) async {
    final origin = FocusNode();
    addTearDown(origin.dispose);
    int? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert<int>(
        context: context,
        title: 'Title',
        actions: const [FrostDialogAction(label: 'Accept', value: 7, isDefault: true)],
      ),
      origin: origin,
    );
    expect(action(tester, 'Accept').focusNode!.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, 7);
    expect(origin.hasFocus, isTrue);
  });

  testWidgets('Escape uses cancel value and disabled cancel blocks scrim fallback', (tester) async {
    int? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert<int>(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Cancel', value: 3, role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'Accept', isDefault: true),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, 3);
    await launch(
      tester,
      (context) => showFrostAlert(
        context: context,
        title: 'Disabled',
        actions: const [
          FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel, enabled: false),
          FrostDialogAction(label: 'Accept', isDefault: true, enabled: false),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('Dialog has 480/640 widths, viewport bound and compact 16 insets', (tester) async {
    for (final (size, viewport, width) in [
      (FrostDialogSize.regular, const Size(900, 700), 480.0),
      (FrostDialogSize.wide, const Size(900, 700), 640.0),
      (FrostDialogSize.wide, const Size(390, 700), 358.0),
    ]) {
      await launch(
        tester,
        (context) => showFrostDialog(
          context: context,
          builder: (_) => FrostDialog(title: 'Title', size: size, content: const SizedBox(height: 2000)),
        ),
        size: viewport,
      );
      expect(tester.getSize(modalSurface).width, width);
      expect(tester.getSize(modalSurface).height, lessThanOrEqualTo(viewport.height - 48));
      if (viewport.width == 390) expect(tester.getTopLeft(modalSurface).dx, 16);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Content gets first focus, multiline Enter leaves default untouched', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var calls = 0;
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Title',
          content: TextField(controller: controller, maxLines: 3),
          actions: [
            FrostDialogAction(
              label: 'Accept',
              isDefault: true,
              onPressed: () {
                calls++;
                return false;
              },
            ),
          ],
        ),
      ),
    );
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), 'a\nb');
    expect(controller.text, 'a\nb');
  });

  testWidgets('Lazy Dialog uses primary controller and dividers fade from measured edges', (tester) async {
    ScrollController? scroll;
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Title',
          scrollable: false,
          content: Builder(
            builder: (context) {
              scroll = PrimaryScrollController.of(context);
              return ListView.builder(itemCount: 1000, itemExtent: 40, itemBuilder: (_, index) => Text('Row $index'));
            },
          ),
          actions: const [FrostDialogAction(label: 'Accept', isDefault: true)],
        ),
      ),
      settle: false,
    );
    expect(dividerOpacity(tester, true), 0);
    expect(dividerOpacity(tester, false), 1);
    scroll!.jumpTo(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, true), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, true), 1);
    scroll!.jumpTo(scroll!.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, false), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 70));
    expect(dividerOpacity(tester, false), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Async Enter runs once and follows the 300/400 loading gate', (tester) async {
    var calls = 0;
    final pending = Completer<bool>();
    await launch(
      tester,
      (context) => showFrostDialog(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Title',
          content: const Text('Form'),
          actions: [
            FrostDialogAction(
              label: 'Accept',
              isDefault: true,
              onPressed: () {
                calls++;
                return pending.future;
              },
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    expect(action(tester, 'Accept').loading, isTrue);
    final gate = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == 'Accept'),
      matching: find.byType(FrostLoadingGate),
    );
    final spinner = find.descendant(of: gate, matching: find.byType(FrostActivityIndicator));
    double spinnerOpacity() => tester.widget<AnimatedOpacity>(find.ancestor(of: spinner, matching: find.byType(AnimatedOpacity)).first).opacity;
    expect(spinnerOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 299));
    expect(spinnerOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(spinnerOpacity(), 1);
    pending.complete(false);
    await tester.pump();
    expect(action(tester, 'Accept').loading, isFalse);
    expect(find.text('Title'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 399));
    expect(spinnerOpacity(), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(spinnerOpacity(), 0);
  });

  testWidgets('Cancel during async execution drops the late completion', (tester) async {
    final pending = Completer<bool>();
    Object? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert(
        context: context,
        title: 'Title',
        actions: [
          FrostDialogAction(label: 'Accept', value: 'accepted', isDefault: true, onPressed: () => pending.future),
          const FrostDialogAction(label: 'Cancel', value: 'cancelled', role: FrostButtonRole.cancel),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, 'cancelled');
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Action exceptions are reported and restore the open modal', (tester) async {
    await launch(
      tester,
      (context) => showFrostAlert(
        context: context,
        title: 'Title',
        actions: [FrostDialogAction(label: 'Accept', isDefault: true, onPressed: () => throw StateError('validation'))],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);
    expect(find.text('Title'), findsOneWidget);
    expect(action(tester, 'Accept').loading, isFalse);
    expect(action(tester, 'Accept').onPressed, isNotNull);
  });

  testWidgets('Confirm is Alert on wide and all cancel paths return false', (tester) async {
    for (final mode in ['button', 'escape', 'barrier']) {
      bool? result;
      await launch(tester, (context) async => result = await showFrostConfirm(context: context, title: 'Confirm', confirmLabel: 'Delete'));
      expect(find.byType(FrostAlert), findsOneWidget);
      expect(find.text('L.cancel'), findsOneWidget);
      if (mode == 'button') await tester.tap(find.text('L.cancel'));
      if (mode == 'escape') await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      if (mode == 'barrier') await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    }
  });

  testWidgets('Compact Confirm is a sheet with full width default above cancel', (tester) async {
    bool? result;
    await launch(
      tester,
      (context) async => result = await showFrostConfirm(context: context, title: 'Confirm', message: 'Message', confirmLabel: 'Delete'),
      size: const Size(390, 800),
    );
    expect(find.byType(FrostAlert), findsNothing);
    expect(tester.getSize(modalSurface).width, 390);
    expect(tester.getCenter(find.text('Delete')).dy, lessThan(tester.getCenter(find.text('L.cancel')).dy));
    for (final label in ['Delete', 'L.cancel']) {
      final button = find.byWidgetPredicate((widget) => widget is FrostButtonControl && widget.label == label);
      expect(tester.getSize(find.descendant(of: button, matching: find.byType(FrostInteractionDecoration)).first).width, 350);
    }
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Sheet sorts/deduplicates detents, has exact handle, and springs between heights', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Sheet',
        detents: const [FrostSheetDetent.large, FrostSheetDetent.medium, FrostSheetDetent.large],
        builder: (_) => const Text('Content'),
      ),
      size: const Size(390, 800),
    );
    expect(tester.getSize(modalSurface).height, 400);
    final handle = find.byWidgetPredicate((widget) => widget is Container && widget.constraints?.maxWidth == 36 && widget.constraints?.maxHeight == 5);
    expect(tester.getSize(handle), const Size(36, 5));
    expect(tester.getTopLeft(handle).dy - tester.getTopLeft(modalSurface).dy, 6);
    await tester.fling(handle, const Offset(0, -90), 800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(490, 792));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 792);
    await tester.fling(find.text('Sheet'), const Offset(0, 80), 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
    await tester.fling(find.text('Sheet'), const Offset(0, 80), 800);
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
  });

  testWidgets('Single detent closes only after the minimum pull boundary', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', detents: const [FrostSheetDetent.medium], builder: (_) => const Text('Content')),
      size: const Size(390, 800),
    );
    await tester.timedDrag(find.text('Sheet'), const Offset(0, 80), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
    await tester.timedDrag(find.text('Sheet'), const Offset(0, 120), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
  });

  testWidgets('Mouse dragging the sheet header selects large without barrier dismissal', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Sheet',
        detents: const [FrostSheetDetent.medium, FrostSheetDetent.large],
        builder: (_) => const Text('Content'),
      ),
      size: const Size(390, 800),
    );
    final handle = find.byWidgetPredicate((widget) => widget is Container && widget.constraints?.maxWidth == 36 && widget.constraints?.maxHeight == 5);
    await tester.drag(handle, const Offset(0, -250), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 792);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes a lazy Sheet with no focusable content under both app entries', (tester) async {
    for (final router in [false, true]) {
      await launch(
        tester,
        (context) => showFrostSheet(
          context: context,
          title: 'Sheet',
          scrollable: false,
          builder: (_) => ListView.builder(itemCount: 100, itemBuilder: (_, index) => Text('Item $index')),
        ),
        size: const Size(390, 800),
        router: router,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(modalSurface, findsNothing, reason: FocusManager.instance.rootScope.toStringDeep());
    }
  });

  testWidgets('Lazy Sheet constructs visible rows and consumes downward drag only after list top', (tester) async {
    ScrollController? scroll;
    final built = <int>{};
    await launch(
      tester,
      (context) => showFrostSheet(
        context: context,
        title: 'Sheet',
        detents: const [FrostSheetDetent.medium, FrostSheetDetent.large],
        scrollable: false,
        builder: (context) {
          scroll = PrimaryScrollController.of(context);
          return ListView.builder(
            itemCount: 1000,
            itemExtent: 40,
            itemBuilder: (_, index) {
              built.add(index);
              return Text('Row $index');
            },
          );
        },
      ),
      size: const Size(390, 800),
    );
    expect(built.length, lessThan(30));
    scroll!.jumpTo(100);
    await tester.pump();
    await tester.timedDrag(find.byType(ListView), const Offset(0, 60), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
    expect(scroll!.offset, closeTo(40, 2));
    scroll!.jumpTo(0);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();
    expect(tester.getSize(modalSurface).height, lessThan(400));
    expect(scroll!.offset, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keyboard opens and closes with standard spring rather than jumping height', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', detents: const [FrostSheetDetent.medium], builder: (_) => const Text('Content')),
      size: const Size(390, 800),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getSize(modalSurface).height, 400);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(300, 400));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 300);
    tester.view.resetViewInsets();
    await tester.pump();
    expect(tester.getSize(modalSurface).height, 300);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(modalSurface).height, inExclusiveRange(300, 400));
    await tester.pumpAndSettle();
    expect(tester.getSize(modalSurface).height, 400);
  });

  testWidgets('Wide Sheet ignores detents and supplies close, focus and Escape', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', detents: const [FrostSheetDetent.medium], builder: (_) => const TextField()),
    );
    expect(tester.getSize(modalSurface).width, 480);
    expect(findFrostTooltip('L.close'), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(modalSurface, findsNothing);
  });

  testWidgets('Reduced Sheet entry has opacity intermediate frames and no movement', (tester) async {
    await launch(
      tester,
      (context) => showFrostSheet(context: context, title: 'Sheet', builder: (_) => const Text('Content')),
      size: const Size(390, 800),
      reduced: true,
      settle: false,
    );
    final initial = tester.getTopLeft(modalSurface);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(modalSurface), initial);
    final fade = tester.widget<FrostMaterialRevealTransition>(find.ancestor(of: modalSurface, matching: find.byType(FrostMaterialRevealTransition)).first);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(tester.widget<SlideTransition>(find.ancestor(of: modalSurface, matching: find.byType(SlideTransition)).first).position.value, Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Action variants render role ink and the sheet material uses xl and dual shadows', (tester) async {
    late FrostThemeTokens tokens;
    await launch(tester, (context) {
      tokens = FrostThemeTokens.of(context);
      showFrostAlert(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Delete', isDefault: true, role: FrostButtonRole.destructive),
          FrostDialogAction(label: 'Remove', role: FrostButtonRole.destructive),
          FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
        ],
      );
    });
    Color? ink(String label) => tester.renderObject<RenderParagraph>(find.descendant(of: find.text(label), matching: find.byType(RichText))).text.style?.color;
    expect(ink('Delete'), tokens.onNegative);
    expect(ink('Remove'), tokens.negativeInk);
    expect(ink('Cancel'), tokens.textPrimary);
    final surface = tester.widget<FrostSurface>(modalSurface);
    expect(surface.borderRadius, FrostRadius.borderRadius(FrostRadius.xl));
    expect(surface.elevated, isTrue);
    final decorations = tester.widgetList<DecoratedBox>(find.descendant(of: modalSurface, matching: find.byType(DecoratedBox)));
    expect(
      decorations.any(
        (widget) => switch (widget.decoration) {
          ShapeDecoration(:final shadows) => shadows?.length == 2,
          BoxDecoration(:final boxShadow) => boxShadow?.length == 2,
          _ => false,
        },
      ),
      isTrue,
    );
  });

  testWidgets('Enter still selects default with cancel focused and Tab stays within modal', (tester) async {
    final origin = FocusNode();
    addTearDown(origin.dispose);
    int? result;
    await launch(
      tester,
      (context) async => result = await showFrostAlert<int>(
        context: context,
        title: 'Title',
        actions: const [
          FrostDialogAction(label: 'Cancel', value: 0, role: FrostButtonRole.cancel),
          FrostDialogAction(label: 'Go', value: 1, isDefault: true),
        ],
      ),
      origin: origin,
    );
    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(origin.hasFocus, isFalse);
    }
    action(tester, 'Cancel').focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, 1);
  });
}
