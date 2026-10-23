import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final remaining in [3.0, 4.0, 4.5, 12.0]) {
    testWidgets('bleed boundary $remaining has correct first-frame geometry and snap', (tester) async {
      late FrostBleedSnap snap;
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: FrostKeyline(
                leadingRoom: 20,
                trailingRoom: 20,
                edgeDistanceStart: 20,
                edgeDistanceEnd: 20,
                insideContainer: false,
                contentStart: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FrostBleed(
                    amount: 20 - remaining,
                    child: Builder(
                      builder: (context) {
                        snap = FrostBleed.snappedOf(context);
                        return const SizedBox(key: ValueKey('row'), height: 24);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const ValueKey('row')));
      final snapped = remaining <= 4;
      final left = snapped ? 0.0 : remaining;
      expect(rect, Rect.fromLTWH(left, 0, 300 - left * 2, 24));
      expect(snap.start, snapped);
      expect(snap.end, snapped);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('bleed caps insufficient room and mirrors logical start/end', (tester) async {
    for (final rtl in [false, true]) {
      late FrostBleedSnap snap;
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: FrostKeyline(
                  leadingRoom: 8,
                  trailingRoom: 20,
                  edgeDistanceStart: 40,
                  edgeDistanceEnd: 50,
                  insideContainer: false,
                  contentStart: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FrostBleed(
                      amount: 12,
                      child: Builder(
                        builder: (context) {
                          snap = FrostBleed.snappedOf(context);
                          return const SizedBox(key: ValueKey('row'), height: 24);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const ValueKey('row'))), Rect.fromLTWH(rtl ? 8 : 12, 0, 280, 24));
      expect(snap.start, false);
      expect(snap.end, false);
    }
  });
  testWidgets('container prevents bleed and missing scope returns none', (tester) async {
    for (final role in [FrostSurfaceRole.sheet, FrostSurfaceRole.module, FrostSurfaceRole.panel, FrostSurfaceRole.glassPanel]) {
      late FrostBleedSnap snap;
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: FrostSurface(
                role: role,
                child: FrostBleed(
                  amount: 20,
                  child: Builder(
                    builder: (context) {
                      snap = FrostBleed.snappedOf(context);
                      return const SizedBox(key: ValueKey('row'), height: 24);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const ValueKey('row'))), const Rect.fromLTWH(0, 0, 200, 24));
      expect(snap.start, false);
      expect(snap.end, false);
    }
    late FrostBleedSnap missing;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            missing = FrostBleed.snappedOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(missing, same(FrostBleedSnap.none));
    expect(missing.start || missing.end, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('content column provides page keyline without double divider inset', (tester) async {
    late FrostKeyline line;
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: FrostContentColumn(
              maxWidth: 200,
              child: Builder(
                builder: (context) {
                  line = FrostKeyline.maybeOf(context)!;
                  return const FrostDivider(inset: FrostDividerInset.keyline);
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(line.contentStart, 12);
    expect(line.leadingRoom, 12);
    expect(line.trailingRoom, 112);
    expect(line.insideContainer, false);
    final leaf = find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget));
    expect(
      tester.renderObject(leaf),
      paints..line(p1: Offset(0, .5 / tester.view.devicePixelRatio), p2: Offset(176, .5 / tester.view.devicePixelRatio), strokeWidth: 0),
    );
    expect(tester.getTopLeft(find.byType(FrostDivider)).dx, 12);
    expect(tester.takeException(), isNull);
  });
  testWidgets('extended bleed region remains hit-testable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: FrostContentColumn(
              maxWidth: 300,
              child: FrostBleed(
                amount: 8,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox(height: 24)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(1, 12));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nested bleed shares the available margin instead of spending it twice', (tester) async {
    late FrostBleedSnap snap;
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: FrostKeyline(
              leadingRoom: 20,
              trailingRoom: 20,
              edgeDistanceStart: 20,
              edgeDistanceEnd: 20,
              insideContainer: false,
              contentStart: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FrostBleed(
                  amount: 8,
                  child: FrostBleed(
                    amount: 8,
                    child: Builder(
                      builder: (context) {
                        snap = FrostBleed.snappedOf(context);
                        return const SizedBox(key: ValueKey('nested'), height: 24);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(const ValueKey('nested'))), const Rect.fromLTWH(0, 0, 300, 24));
    expect(snap.start && snap.end, true);
    expect(tester.takeException(), isNull);
  });
}
