import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/overlays/_menu_item.dart';

import 'support.dart';

Finder get panel => find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.overlay);
Finder get sheet => find.byWidgetPredicate((widget) => widget is FrostSurface && widget.role == FrostSurfaceRole.sheet);

Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(900, 700), bool reduced = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

Widget popover({
  String title = 'Compact title',
  double? width,
  Widget? content,
  Alignment alignment = Alignment.topLeft,
  ValueChanged<FocusNode>? triggerFocus,
}) => Align(
  alignment: alignment,
  child: FrostPopover(
    title: title,
    maxWidth: width,
    builder: (context, focus, toggle) {
      triggerFocus?.call(focus);
      return FrostButtonControl(label: 'Open popover', focusNode: focus, onPressed: toggle);
    },
    contentBuilder: (_, close) => content ?? FrostButton(label: 'Close content', onPressed: close),
  ),
);

void main() {
  testWidgets('Popover shrinks intrinsically within 160–400 and an explicit ceiling', (tester) async {
    for (final (preferred, content, size, expected) in [
      (null, const Text('Short'), const Size(900, 700), 160.0),
      (null, Text(List.filled(50, 'Long').join(' ')), const Size(900, 700), 400.0),
      (320.0, const Text('Short'), const Size(900, 700), 160.0),
      (320.0, const SizedBox(width: 500, height: 40), const Size(900, 700), 320.0),
      (900.0, const SizedBox(width: 700, height: 40), const Size(620, 700), 604.0),
    ]) {
      await pump(
        tester,
        popover(title: 'Short', width: preferred, content: content),
        size: size,
      );
      await tester.tap(find.text('Open popover'));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).width, expected);
      expect(tester.widget<FrostSurface>(panel).borderRadius, FrostRadius.borderRadius(FrostRadius.xl));
      expect(tester.widget<Padding>(find.descendant(of: panel, matching: find.byType(Padding)).first).padding, const EdgeInsets.all(16));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Popover prefers below, flips at bottom, and clamps at right edge', (tester) async {
    for (final alignment in [Alignment.topLeft, Alignment.bottomRight]) {
      await pump(tester, popover(width: 320, content: const SizedBox(height: 180), alignment: alignment));
      final trigger = tester.getRect(find.text('Open popover'));
      await tester.tap(find.text('Open popover'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(panel);
      if (alignment == Alignment.topLeft) {
        expect(rect.top, greaterThan(trigger.bottom));
      } else {
        expect(rect.bottom, lessThan(trigger.top));
      }
      expect(rect.right, lessThanOrEqualTo(892));
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.bottom, lessThanOrEqualTo(692));
      await tester.tapAt(const Offset(450, 350));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
    }
  });

  testWidgets('Popover initial content focus, closed loop, Escape and restored trigger', (tester) async {
    FocusNode? trigger;
    final field = FocusNode();
    addTearDown(field.dispose);
    await pump(
      tester,
      popover(
        width: 320,
        triggerFocus: (value) => trigger = value,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(focusNode: field),
            FrostButton(label: 'Other', onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open popover'));
    await tester.pumpAndSettle();
    expect(field.hasPrimaryFocus, isTrue);
    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(trigger!.hasFocus, isFalse);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(trigger!.hasPrimaryFocus, isTrue);
  });

  testWidgets('Content close callback and outside tap both close popover', (tester) async {
    await pump(tester, popover());
    await tester.tap(find.text('Open popover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close content'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    await tester.tap(find.text('Open popover'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(800, 600));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('Menu and popover replace each other without outgoing focus theft', (tester) async {
    VoidCallback? menuToggle, popoverToggle;
    final field = FocusNode();
    addTearDown(field.dispose);
    await pump(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FrostMenuAnchor(
            entries: [FrostMenuAction('Menu action', onSelected: () {})],
            builder: (_, focus, toggle) {
              menuToggle = toggle;
              return FrostButtonControl(label: 'Menu', focusNode: focus, onPressed: toggle);
            },
          ),
          FrostPopover(
            builder: (_, focus, toggle) {
              popoverToggle = toggle;
              return FrostButtonControl(label: 'Popover', focusNode: focus, onPressed: toggle);
            },
            contentBuilder: (_, close) => TextField(focusNode: field),
          ),
        ],
      ),
    );
    menuToggle!();
    await tester.pumpAndSettle();
    expect(find.text('Menu action'), findsOneWidget);
    popoverToggle!();
    await tester.pumpAndSettle();
    expect(find.text('Menu action'), findsNothing);
    expect(field.hasPrimaryFocus, isTrue);
    menuToggle!();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Menu action'), findsOneWidget);
    expect(field.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FrostMenuItem>(), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact popover becomes medium Sheet and content callback closes it', (tester) async {
    await pump(tester, popover(width: 320), size: const Size(390, 800));
    await tester.tap(find.text('Open popover'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet), const Size(390, 400));
    expect(find.text('Compact title'), findsOneWidget);
    await tester.tap(find.text('Close content'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('Reduced popover fades over 120 ms and never scales', (tester) async {
    await pump(tester, popover(), reduced: true);
    await tester.tap(find.text('Open popover'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final opacity = tester.widget<FrostMaterialReveal>(find.ancestor(of: panel, matching: find.byType(FrostMaterialReveal)).first);
    expect(opacity.opacity, inExclusiveRange(0, 1));
    final transform = tester.widget<Transform>(find.ancestor(of: panel, matching: find.byType(Transform)).first).transform;
    expect(transform.entry(0, 0), 1);
    expect(transform.entry(1, 1), 1);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<FrostMaterialReveal>(find.ancestor(of: panel, matching: find.byType(FrostMaterialReveal)).first).opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });
}
