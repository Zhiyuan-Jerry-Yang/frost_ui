import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'dialog_sheet_v2_test.dart' show modalSurface;
import 'support.dart';

void main() {
  testWidgets('inline width spring gives up content space, header and closed focus/semantics', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    var open = false;
    late StateSetter update;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostInspector(
              sheetBelow: FrostSizeClass.medium,
              open: open,
              title: 'Info',
              onOpenChanged: (value) => setState(() => open = value),
              inspector: TextButton(focusNode: focus, onPressed: () {}, child: const Text('panel')),
              child: const SizedBox(key: ValueKey('main')),
            );
          },
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 800);
    update(() => open = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getSize(find.byKey(const ValueKey('main'))).width;
    expect(middle, greaterThan(479));
    expect(middle, lessThan(800));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 479);
    expect(find.byType(FrostSectionHeader), findsOneWidget);
    expect(findFrostTooltip('L.close'), findsOneWidget);
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.tap(find.byType(FrostButton).last);
    await tester.pump();
    expect(focus.canRequestFocus, isFalse);
    final excluded = find.ancestor(of: find.text('panel'), matching: find.byWidgetPredicate((w) => w is ExcludeSemantics && w.excluding));
    expect(excluded, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, greaterThan(479));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 800);
  });

  testWidgets('RTL inspector is at logical end and local cap preserves main content', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    var width = 500.0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: FrostInspector(
                    sheetBelow: FrostSizeClass.compact,
                    open: true,
                    width: 320,
                    onOpenChanged: (_) {},
                    inspector: const SizedBox(key: ValueKey('panel')),
                    child: const SizedBox(key: ValueKey('main')),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 240);
    expect(tester.getTopLeft(find.byType(FrostDivider)).dx, closeTo(259, .001));
    update(() => width = 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 479);
    update(() => width = 100);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion changes width immediately and only fades content', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    var open = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600), disableAnimations: true),
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return FrostInspector(
                sheetBelow: FrostSizeClass.medium,
                open: open,
                onOpenChanged: (_) {},
                inspector: const Text('panel'),
                child: const SizedBox(key: ValueKey('main')),
              );
            },
          ),
        ),
      ),
    );
    update(() => open = true);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 479);
    await tester.pump(const Duration(milliseconds: 60));
    final opacity = tester
        .renderObject<RenderFrostContentFade>(find.descendant(of: find.byType(FrostInspector), matching: find.byType(FrostContentFade)).last)
        .opacity;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    await tester.pumpAndSettle();
    update(() => open = false);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 800);
    expect(find.text('panel'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final external in [false, true]) {
    testWidgets('compact sheet external=$external closes correctly', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var open = true, calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return FrostInspector(
                sheetBelow: FrostSizeClass.medium,
                open: open,
                title: 'Info',
                onOpenChanged: (value) {
                  calls++;
                  setState(() => open = value);
                },
                inspector: ListView.builder(itemCount: 500, itemBuilder: (_, i) => Text('item $i')),
                child: const Text('main'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsNothing);
      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 499'), findsNothing);
      if (external) {
        update(() => open = false);
      } else {
        await tester.tap(find.byType(FrostButton).last);
      }
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsNothing);
      expect(calls, external ? 0 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('size-class transfer, live content, close ownership under a newer dialog and disposal', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1024, 700);
    var calls = 0, label = 'panel';
    late StateSetter update;
    late BuildContext source;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            source = context;
            update = setState;
            return FrostInspector(open: true, title: 'Info', onOpenChanged: (_) => calls++, inspector: Text(label), child: const Text('main'));
          },
        ),
      ),
    );
    expect(find.byType(FrostSectionHeader), findsOneWidget);
    tester.view.physicalSize = const Size(390, 700);
    await tester.pumpAndSettle();
    expect(find.byType(FrostSectionHeader), findsNothing);
    expect(find.text('Info'), findsNothing);
    update(() => label = 'updated');
    await tester.pumpAndSettle();
    expect(find.text('updated'), findsOneWidget);
    showDialog<void>(
      context: source,
      builder: (_) => const AlertDialog(content: Text('newer')),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1024, 700);
    await tester.pumpAndSettle();
    expect(find.text('newer'), findsOneWidget);
    expect(calls, 0);
    Navigator.of(tester.element(find.text('newer'))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FrostSectionHeader), findsOneWidget);
    expect(find.text('updated'), findsOneWidget);
    tester.view.physicalSize = const Size(390, 700);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls, 0);
  });

  testWidgets('rapid compact open/close before route builds does not leave an orphan', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var open = false, calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostInspector(open: open, onOpenChanged: (_) => calls++, inspector: const Text('panel'), child: const Text('main'));
          },
        ),
      ),
    );
    update(() => open = true);
    await tester.pump();
    update(() => open = false);
    await tester.pumpAndSettle();
    expect(find.text('panel'), findsNothing);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
  for (final dismissal in ['semantics', 'back', 'escape']) {
    testWidgets('headerless fitted inspector retains handle and $dismissal dismissal', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      var open = true, calls = 0;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, setState) => FrostInspector(
              open: open,
              title: null,
              sheetDetents: const [FrostSheetDetent.fitted],
              showsSheetCloseButton: false,
              onOpenChanged: (value) {
                calls++;
                setState(() => open = value);
              },
              inspector: const SingleChildScrollView(primary: false, child: SizedBox(height: 180, child: Text('fitted panel'))),
              child: const Text('main'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FrostButton), findsNothing);
      expect(tester.getSize(modalSurface).height, closeTo(6 + 5 + 8 + 180 + 20 + 34, .01));
      expect(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 36 && w.constraints?.maxHeight == 5).hitTestable(), findsOneWidget);
      if (dismissal == 'semantics') {
        final node = tester.getSemantics(find.bySemanticsLabel('L.dismiss'));
        expect(node.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
        node.owner!.performAction(node.id, SemanticsAction.dismiss);
      } else if (dismissal == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      await tester.pumpAndSettle();
      expect(find.text('fitted panel'), findsNothing);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  testWidgets('long headerless fitted inspector caps its own scrolling content below top safe area', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        FrostInspector(
          open: true,
          sheetDetents: const [FrostSheetDetent.fitted],
          showsSheetCloseButton: false,
          onOpenChanged: (_) {},
          inspector: const SingleChildScrollView(primary: false, child: SizedBox(height: 2000, child: Text('long panel'))),
          child: const Text('main'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(modalSurface);
    expect(rect.top, closeTo(47 + 8, .01));
    expect(rect.bottom, 800);
    final scroll = find.byType(Scrollable);
    expect(tester.getRect(scroll).bottom, lessThanOrEqualTo(800 - 34));
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scroll).position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
