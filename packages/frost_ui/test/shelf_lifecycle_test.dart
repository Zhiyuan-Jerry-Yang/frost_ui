import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class _Page extends StatefulWidget {
  const _Page({required this.count});
  final int count;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  bool _layout = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            FrostTag(label: 'Layout', selected: _layout, onPressed: () => setState(() => _layout = true)),
            FrostTag(label: 'Other', selected: !_layout, onPressed: () => setState(() => _layout = false)),
          ],
        ),
        Expanded(
          child: _layout
              ? SingleChildScrollView(
                  key: const PageStorageKey('layout'),
                  child: Column(
                    children: [
                      FrostShelf(title: 'Shelf', itemCount: widget.count, itemExtent: 100, height: 100, itemBuilder: (_, index) => Text('$index')),
                      const SizedBox(height: 1600),
                    ],
                  ),
                )
              : const SingleChildScrollView(key: PageStorageKey('other'), child: SizedBox(height: 1600)),
        ),
      ],
    ),
  );
}

ScrollPosition position(WidgetTester tester, Axis axis) =>
    tester.stateList<ScrollableState>(find.byType(Scrollable)).singleWhere((s) => s.position.axis == axis).position;
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('lifecycle probe: restoring page and resizing never dirties layout or scroll dimensions', (tester) async {
    // This is the catalog diagnostic's call chain without an ignored app import.
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(frostTestApp(const _Page(count: 3)));
    await frames(tester);
    await tester.drag(find.byKey(const PageStorageKey('layout')), const Offset(0, -700));
    await frames(tester);
    final outer = position(tester, Axis.vertical).pixels;
    expect(outer, greaterThan(500));
    await tester.tap(find.text('Other'));
    await frames(tester);
    await tester.tap(find.text('Layout'));
    await frames(tester);
    expect(position(tester, Axis.vertical).pixels, outer);
    expect(position(tester, Axis.horizontal).pixels, 0);
    expect(position(tester, Axis.horizontal).maxScrollExtent, 0);
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await frames(tester);
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    await frames(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('storage probe: horizontal offset is independent of outer vertical storage', (tester) async {
    await tester.pumpWidget(frostTestApp(const _Page(count: 30)));
    await frames(tester);
    final horizontal = position(tester, Axis.horizontal);
    expect(horizontal.keepScrollOffset, false);
    horizontal.jumpTo(300);
    await frames(tester);
    position(tester, Axis.vertical).jumpTo(700);
    await frames(tester);
    expect(horizontal.pixels, 300);
    expect(position(tester, Axis.vertical).pixels, 700);
    await tester.tap(find.text('Other'));
    await frames(tester);
    await tester.tap(find.text('Layout'));
    await frames(tester);
    expect(position(tester, Axis.vertical).pixels, 700);
    expect(position(tester, Axis.horizontal).pixels, 0);
    expect(position(tester, Axis.horizontal).hasContentDimensions, true);
    expect(tester.takeException(), isNull);
  });
}
