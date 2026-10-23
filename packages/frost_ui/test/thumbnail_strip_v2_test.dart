import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

Finder get _strip => find.byType(FrostThumbnailStrip);
ScrollPosition _position(WidgetTester tester) => tester.state<ScrollableState>(find.descendant(of: _strip, matching: find.byType(Scrollable))).position;
Future<void> _host(WidgetTester tester, Widget child, {bool rtl = false, bool reduced = false}) => tester.pumpWidget(
  frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 300, child: child),
            ),
          ),
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets('strip minimally reveals the initial selection in the first layout and builds lazily', (tester) async {
    final built = <int>{};
    await _host(
      tester,
      FrostThumbnailStrip(
        itemCount: 900,
        selectedIndex: 450,
        onSelected: (_) {},
        itemBuilder: (_, index) {
          built.add(index);
          return ColoredBox(key: ValueKey(index), color: Colors.red);
        },
      ),
    );
    final rect = tester.getRect(find.byKey(const ValueKey(450)));
    expect(rect.right, 296);
    expect(_position(tester).pixels, greaterThan(30000));
    expect(built.length, lessThan(30));
    expect(_position(tester).isScrollingNotifier.value, isFalse);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('strip keyboard is one stop, mirrors arrows and supports Home End', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final rtl in [false, true]) {
      var selected = 2;
      var calls = 0;
      await _host(
        tester,
        StatefulBuilder(
          builder: (_, set) => Column(
            children: [
              FrostThumbnailStrip(
                itemCount: 8,
                selectedIndex: selected,
                onSelected: (index) {
                  calls++;
                  set(() => selected = index);
                },
                itemBuilder: (_, index) => const ColoredBox(color: Colors.red),
              ),
              TextButton(onPressed: () {}, child: const Text('After')),
            ],
          ),
        ),
        rtl: rtl,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.widget, isA<Focus>());
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot(contains('Button')));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(selected, rtl ? 1 : 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(selected, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(selected, 7);
      expect(_position(tester).pixels, _position(tester).maxScrollExtent);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(calls, 4);
      final selectedNode = find.bySemanticsLabel('1 of 8');
      expect(selectedNode, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>(), isNotNull);
      await tester.pumpWidget(const SizedBox());
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('external paging minimally reveals on a standard spring and reduced motion jumps', (tester) async {
    for (final reduced in [false, true]) {
      late StateSetter update;
      var selected = 0;
      await _host(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostThumbnailStrip(
              itemCount: 30,
              selectedIndex: selected,
              onSelected: (_) {},
              itemBuilder: (_, _) => const ColoredBox(color: Colors.red),
            );
          },
        ),
        reduced: reduced,
      );
      update(() => selected = 15);
      await tester.pump();
      final start = _position(tester).pixels;
      await tester.pump();
      await tester.pump(FrostMotion.standardDuration ~/ 2);
      final middle = _position(tester).pixels;
      if (!reduced) {
        expect(middle, greaterThan(start));
      }
      await tester.pumpAndSettle();
      final end = _position(tester).pixels;
      if (!reduced) {
        expect(middle, lessThan(end));
      } else {
        expect(start, end);
      }
      final selectedThumb = find.byWidgetPredicate((w) => w is FrostThumbnail && w.selected);
      expect(tester.getRect(selectedThumb).right, closeTo(296, .001));
      final mask = tester.renderObject<RenderShaderMask>(find.byType(ShaderMask));
      expect(mask.blendMode, BlendMode.dstIn);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('pointer selection preserves the strip scroll offset', (tester) async {
    var selected = 0;
    await _host(
      tester,
      StatefulBuilder(
        builder: (_, set) => FrostThumbnailStrip(
          itemCount: 30,
          selectedIndex: selected,
          onSelected: (index) => set(() => selected = index),
          itemBuilder: (_, index) => ColoredBox(key: ValueKey(index), color: Colors.red),
        ),
      ),
    );
    final before = _position(tester).pixels;
    await tester.tap(find.byKey(const ValueKey(2)));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(_position(tester).pixels, before);
    expect(tester.takeException(), isNull);
  });
  testWidgets('strip supports empty and readonly states without focus or callbacks', (tester) async {
    await _host(tester, FrostThumbnailStrip(itemCount: 0, selectedIndex: null, onSelected: null, itemBuilder: (_, _) => throw StateError('not built')));
    expect(find.byType(FrostThumbnail), findsNothing);
    expect(tester.getSize(_strip).height, 72);
    await _host(tester, FrostThumbnailStrip(itemCount: 3, selectedIndex: 1, onSelected: null, itemBuilder: (_, _) => const SizedBox()));
    expect(tester.widgetList<FrostThumbnail>(find.byType(FrostThumbnail)).every((w) => w.onPressed == null), isTrue);
    expect(tester.takeException(), isNull);
  });
}
