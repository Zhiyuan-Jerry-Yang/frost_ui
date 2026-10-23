import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';

const triggerKey = ValueKey('preview-trigger');
Widget preview({bool enabled = true, WidgetBuilder? builder, FocusNode? focus}) => FrostHoverPreview(
  enabled: enabled,
  previewBuilder: builder ?? (_) => const Text('Preview card'),
  child: FrostClickSurface(
    focusNode: focus,
    onTap: () {},
    child: const SizedBox(key: triggerKey, width: 100, height: 40, child: Text('Target')),
  ),
);
Widget app(Widget child) => frostTestApp(
  Align(
    alignment: Alignment.topLeft,
    child: Padding(padding: const EdgeInsets.all(50), child: child),
  ),
);
Future<TestGesture> hover(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
  return mouse;
}

Future<void> mount(WidgetTester tester, Widget child) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
  await tester.pumpWidget(child);
}

void main() {
  for (final event in ['press-inside', 'scroll', 'trackpad']) {
    testWidgets('global $event dismisses preview without consuming input', (tester) async {
      await mount(tester, app(preview()));
      final mouse = await hover(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final point = tester.getCenter(find.text('Preview card'));
      if (event == 'press-inside') {
        await tester.tapAt(point);
      } else if (event == 'scroll') {
        tester.binding.handlePointerEvent(PointerScrollEvent(position: point, scrollDelta: const Offset(0, 50)));
      } else {
        tester.binding.handlePointerEvent(PointerPanZoomStartEvent(position: point));
      }
      await tester.pumpAndSettle();
      expect(find.text('Preview card'), findsNothing);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('a newly opened preview closes the previous keyboard-focused preview', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(
      tester,
      app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            preview(focus: focus),
            const SizedBox(height: 120),
            FrostHoverPreview(
              previewBuilder: (_) => const Text('Second preview'),
              child: const SizedBox(key: ValueKey('second'), width: 100, height: 40),
            ),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('second'))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsNothing);
    expect(find.text('Second preview'), findsOneWidget);
    expect(focus.hasPrimaryFocus, isTrue);
    await mouse.removePointer();
  });

  testWidgets('hover delay is 600ms and short content measures naturally below target', (tester) async {
    var builds = 0;
    await mount(
      tester,
      app(
        preview(
          builder: (_) {
            builds++;
            return const Text('Preview card');
          },
        ),
      ),
    );
    expect(builds, 0);
    final mouse = await hover(tester);
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.text('Preview card'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(builds, 1);
    final panel = tester.getRect(find.byType(FrostPopoverSurface)), target = tester.getRect(find.byKey(triggerKey));
    expect(panel.top, target.bottom);
    expect(panel.width, lessThan(320));
    expect(panel.width, greaterThan(32));
    await mouse.removePointer();
  });
  testWidgets('150ms exit grace lets pointer enter card and closes after leaving both', (tester) async {
    await mount(tester, app(preview()));
    final mouse = await hover(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.text('Preview card'), findsOneWidget);
    await mouse.moveTo(tester.getCenter(find.text('Preview card')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Preview card'), findsOneWidget);
    await mouse.moveTo(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsNothing);
    await mouse.removePointer();
  });
  testWidgets('keyboard delay preserves original focus and preview controls cannot take it', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(
      tester,
      app(
        preview(
          focus: focus,
          builder: (_) => FrostButton(label: 'Preview action', onPressed: () {}),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.text('Preview action'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Preview action'), findsOneWidget);
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.tap(find.text('Preview action'));
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    focus.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.text('Preview action'), findsNothing);
  });
  testWidgets('touch long press centers with mask and release closes', (tester) async {
    await mount(tester, app(preview()));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(triggerKey)), kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout);
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsOneWidget);
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    expect(panel.center.dx, 400);
    expect(panel.center.dy, 300);
    expect(find.byType(AbsorbPointer), findsWidgets);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsNothing);
  });
  testWidgets('outside desktop taps and scrolling pass through and menus replace preview', (tester) async {
    var tapped = 0;
    await mount(
      tester,
      app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            preview(),
            const SizedBox(height: 180),
            FrostToolbarMenuButton(
              label: 'Menu',
              entries: [FrostMenuAction('Menu item', onSelected: () {})],
            ),
            GestureDetector(
              onTap: () => tapped++,
              child: const SizedBox(width: 200, height: 40, child: Text('Outside')),
            ),
            SizedBox(width: 200, height: 80, child: ListView(children: [for (var i = 0; i < 20; i++) Text('Row $i')])),
          ],
        ),
      ),
    );
    final mouse = await hover(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outside'));
    expect(tapped, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable))).position.pixels, greaterThan(0));
    await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsNothing);
    expect(find.text('Menu item'), findsOneWidget);
    await mouse.removePointer();
  });
  testWidgets('bottom/right placement flips and long preview scrolls inside safe keyboard viewport', (tester) async {
    await mount(
      tester,
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.all(20), viewInsets: EdgeInsets.only(bottom: 150)),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 170),
              child: preview(
                builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 100; i++) Text('Preview $i')]),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await hover(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(FrostPopoverSurface)), target = tester.getRect(find.byKey(triggerKey));
    expect(panel.width, lessThanOrEqualTo(320));
    expect(panel.right, lessThanOrEqualTo(772));
    expect(panel.bottom, lessThanOrEqualTo(target.top));
    expect(panel.top, greaterThanOrEqualTo(28));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced preview only fades and Escape dismisses with trigger focus intact', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(
      tester,
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(child: preview(focus: focus)),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final opacity = tester
        .widgetList<FrostMaterialReveal>(find.ancestor(of: find.byType(FrostPopoverSurface), matching: find.byType(FrostMaterialReveal)))
        .first
        .opacity;
    expect(opacity, inExclusiveRange(0, 1));
    final transform = tester.widgetList<Transform>(find.ancestor(of: find.byType(FrostPopoverSurface), matching: find.byType(Transform))).first;
    expect(transform.transform.storage[0], 1);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsNothing);
    expect(focus.hasPrimaryFocus, isTrue);
  });
  testWidgets('preview can coexist with an already open Popover without focus or menu coupling', (tester) async {
    await mount(
      tester,
      app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostPopover(
              builder: (_, focus, toggle) => FrostClickSurface(
                focusNode: focus,
                onTap: toggle,
                child: const SizedBox(width: 100, height: 40, child: Text('Popover')),
              ),
              contentBuilder: (_, _) => const Text('Popover content'),
            ),
            const SizedBox(width: 250),
            preview(),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Popover'));
    await tester.pumpAndSettle();
    expect(find.text('Popover content'), findsOneWidget);
    final mouse = await hover(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsOneWidget);
    expect(find.text('Popover content'), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('disable or unmount cancels pending hover and closes visible preview safely', (tester) async {
    var enabled = true;
    StateSetter? update;
    await mount(
      tester,
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return preview(enabled: enabled);
          },
        ),
      ),
    );
    final mouse = await hover(tester);
    await tester.pump(const Duration(milliseconds: 300));
    update!(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Preview card'), findsNothing);
    update!(() => enabled = true);
    await tester.pump();
    await mouse.moveTo(Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(triggerKey)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsOneWidget);
    update!(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.text('Preview card'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });
}
