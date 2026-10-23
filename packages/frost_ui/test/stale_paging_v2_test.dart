import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'display_badges_v2_test.dart' show display;

void main() {
  testWidgets('stale gate skips short refresh, holds dim and blocks input through recovery', (tester) async {
    final handle = tester.ensureSemantics();
    var stale = false, taps = 0;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return FrostButton(label: 'Existing content', onPressed: () => taps++).frostStale(stale);
        },
      ),
    );
    final opacity = find.ancestor(of: find.byType(FrostButton), matching: find.byType(FrostMaterialReveal)).first;
    double alpha() => tester.widget<FrostMaterialReveal>(opacity).opacity;
    update(() => stale = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(alpha(), 1);
    update(() => stale = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(alpha(), 1);
    update(() => stale = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 70));
    expect(alpha(), inExclusiveRange(.5, 1));
    update(() => stale = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(alpha(), .5);
    expect(find.bySemanticsLabel('Existing content'), findsOneWidget);
    final ignores = tester.widgetList<IgnorePointer>(find.ancestor(of: find.byType(FrostButton), matching: find.byType(IgnorePointer)));
    expect(ignores.any((w) => w.ignoring), true);
    await tester.tap(find.byType(FrostButton), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 259));
    expect(alpha(), .5);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 70));
    expect(alpha(), inExclusiveRange(.5, 1));
    await tester.pumpAndSettle();
    expect(alpha(), 1);
    await tester.tap(find.byType(FrostButton));
    expect(taps, 1);
    handle.dispose();
  });
  testWidgets('stale reduced motion changes opacity immediately after shared gate', (tester) async {
    var stale = true;
    late StateSetter update;
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return const Text('Readable').frostStale(stale);
        },
      ),
      reduced: true,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<FrostMaterialReveal>(find.ancestor(of: find.text('Readable'), matching: find.byType(FrostMaterialReveal)).first).opacity, .5);
    update(() => stale = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<FrostMaterialReveal>(find.ancestor(of: find.text('Readable'), matching: find.byType(FrostMaterialReveal)).first).opacity, 1);
  });
}
