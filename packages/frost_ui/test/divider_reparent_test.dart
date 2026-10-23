import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('a row replaced by custom grouped content never paints its detached text anchor', (tester) async {
    late StateSetter update;
    var custom = false;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Center(
              child: SizedBox(
                width: 300,
                child: FrostGroupedSection(
                  children: [
                    if (custom) const Padding(padding: EdgeInsets.all(12), child: Text('Custom options')) else const FrostListRow(title: 'Options'),
                    const FrostListRow(title: 'Other'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    update(() => custom = true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final line = tester.renderObject<RenderBox>(
      find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget)),
    );
    final inset = FrostGap.of(tester.element(find.text('Other'))).rowInset;
    expect(line, paints..line(p1: Offset(inset, .5 / tester.view.devicePixelRatio), p2: Offset(300, .5 / tester.view.devicePixelRatio), strokeWidth: 0));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('retained divider resolves its current keyline after equal-data reparenting', (tester) async {
    final retained = GlobalKey();
    late StateSetter update;
    var moved = false;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: FrostKeyline(
                  key: ValueKey(moved),
                  leadingRoom: 0,
                  trailingRoom: 0,
                  edgeDistanceStart: 0,
                  edgeDistanceEnd: 0,
                  insideContainer: true,
                  contentStart: 20,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: moved ? 8 : 0),
                    child: KeyedSubtree(
                      key: retained,
                      child: const FrostDivider(inset: FrostDividerInset.keyline),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final original = retained.currentContext!.findRenderObject();
    update(() => moved = true);
    await tester.pump();
    expect(identical(retained.currentContext!.findRenderObject(), original), true);
    expect(tester.takeException(), isNull);
    final line = tester.renderObject<RenderBox>(
      find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget)),
    );
    expect(line, paints..line(p1: Offset(12, .5 / tester.view.devicePixelRatio), p2: Offset(292, .5 / tester.view.devicePixelRatio), strokeWidth: 0));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
