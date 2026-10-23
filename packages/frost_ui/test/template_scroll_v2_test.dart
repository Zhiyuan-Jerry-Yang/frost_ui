import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('new collection controller replaces only the viewport and keeps the header State', (tester) async {
    final first = ScrollController(keepScrollOffset: false);
    final second = ScrollController(keepScrollOffset: false);
    final restored = ScrollController(initialScrollOffset: 500, keepScrollOffset: false);
    addTearDown(() {
      first.dispose();
      second.dispose();
      restored.dispose();
    });
    var controller = first;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return PrimaryScrollController(
              controller: controller,
              automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
              child: const FrostBrowseLayout(
                header: Material(child: TextField()),
                slivers: [SliverToBoxAdapter(child: SizedBox(height: 2000))],
              ),
            );
          },
        ),
      ),
    );
    final header = tester.state(find.byType(EditableText));
    first.jumpTo(500);
    await tester.pump();
    update(() => controller = second);
    await tester.pump();
    expect(second.offset, 0);
    expect(tester.state(find.byType(EditableText)), same(header));
    update(() => controller = restored);
    await tester.pump();
    expect(restored.offset, 500);
    expect(tester.state(find.byType(EditableText)), same(header));
    expect(tester.takeException(), isNull);
  });

  Widget app(Widget child) => frostTestApp(SizedBox.expand(child: child));
  const header = SizedBox(key: ValueKey('header'), height: 52, child: Text('header'));
  Widget rows() => SliverList.builder(itemCount: 80, itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')));

  testWidgets('browse fixes header, shares keyline and reveals glass after scroll', (tester) async {
    FrostKeyline? keyline;
    await tester.pumpWidget(
      app(
        FrostBrowseLayout(
          header: header,
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  keyline = FrostKeyline.maybeOf(context);
                  return const SizedBox(height: 40, child: Text('keyline'));
                },
              ),
            ),
            rows(),
          ],
        ),
      ),
    );
    final start = tester.getTopLeft(find.byKey(const ValueKey('header')));
    expect(keyline, isNotNull);
    expect(keyline!.insideContainer, isFalse);
    expect(tester.getTopLeft(find.text('keyline')).dx, start.dx);
    expect(tester.getTopLeft(find.text('keyline')).dy, 52);
    expect(tester.widget<FrostPinnedChromeGlass>(find.byType(FrostPinnedChromeGlass)).opacity, 0);
    await tester.drag(find.text('row 3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('header'))), start);
    expect(tester.widget<FrostPinnedChromeGlass>(find.byType(FrostPinnedChromeGlass)).opacity, 1);
  });

  testWidgets('filter expands and collapses while exact header height stays fixed', (tester) async {
    var visible = false;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostBrowseLayout(
              header: header,
              filterBar: visible ? const SizedBox(height: 80, child: Text('filter')) : null,
              slivers: [rows()],
            );
          },
        ),
      ),
    );
    double y() => tester.getTopLeft(find.text('row 0')).dy;
    expect(y(), 52);
    update(() => visible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(y(), inExclusiveRange(52, 132));
    expect(tester.getSize(find.byKey(const ValueKey('header'))).height, 52);
    await tester.pumpAndSettle();
    expect(y(), 132);
    update(() => visible = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(y(), inExclusiveRange(52, 132));
    expect(tester.getSize(find.byKey(const ValueKey('header'))).height, 52);
    await tester.pumpAndSettle();
    expect(y(), 52);
  });

  testWidgets('empty suppresses slivers and centers in remaining viewport on first frame', (tester) async {
    await tester.pumpWidget(
      app(FrostBrowseLayout(header: header, filterBar: const SizedBox(height: 80), isEmpty: true, empty: const Text('empty'), slivers: [rows()])),
    );
    expect(find.text('row 0'), findsNothing);
    expect(tester.getCenter(find.text('empty')).dy, (132 + 600) / 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection tools and uncontained stats scroll in token order without absent gaps', (tester) async {
    Widget collection({bool tools = true, bool stats = true}) => FrostCollectionLayout(
      header: header,
      toolbar: tools ? const SizedBox(height: 40, child: Text('tools')) : null,
      stats: stats ? const [FrostStat(value: '12', caption: 'items'), FrostStat(value: '3', caption: 'days')] : [],
      slivers: [rows()],
    );
    await tester.pumpWidget(app(collection()));
    final stat = find.byType(FrostStatStrip);
    expect(tester.getTopLeft(stat).dy - tester.getBottomLeft(find.text('tools')).dy, 12 + (40 - tester.getSize(find.text('tools')).height));
    expect(tester.getTopLeft(find.text('row 0')).dy - tester.getBottomLeft(stat).dy, 24);
    expect(find.ancestor(of: stat, matching: find.byType(FrostSurface)), findsNothing);
    final headerTop = tester.getTopLeft(find.byKey(const ValueKey('header')));
    await tester.drag(find.text('row 2'), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('header'))), headerTop);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(collection(tools: false, stats: false)));
    expect(tester.getTopLeft(find.text('row 0')).dy, 52);
  });
}
