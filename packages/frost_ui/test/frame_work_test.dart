import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_frame_work.dart';
import 'support.dart';

void main() {
  testWidgets('shared queue runs one work item per frame and skips cancelled owners', (tester) async {
    final introduced = <int>[];
    FrostFrameWorkQueue.enqueue(() => introduced.add(1));
    final cancelled = FrostFrameWorkQueue.enqueue(() => introduced.add(2));
    FrostFrameWorkQueue.enqueue(() => introduced.add(3));
    await tester.pump();
    expect(introduced, [1]);
    cancelled.cancel();
    await tester.pump();
    expect(introduced, [1, 3]);
    await tester.pump();
    expect(introduced, [1, 3]);
  });

  for (final reduced in [false, true]) {
    testWidgets('detail keeps critical content in the first frame and stages secondary blocks in order reduced=$reduced', (tester) async {
      late BuildContext home;
      final built = <String>[];
      Widget block(String name) => Builder(
        builder: (_) {
          if (!built.contains(name)) built.add(name);
          return SizedBox(height: 40, child: Text(name));
        },
      );
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              home = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      Navigator.of(home).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(seconds: 1),
          pageBuilder: (_, _, _) => MediaQuery(
            data: MediaQuery.of(home).copyWith(disableAnimations: reduced),
            child: FrostDetailLayout(
              header: const Text('Back and header'),
              stage: const Text('Main media'),
              primary: const Text('Primary'),
              actions: const Text('Primary actions'),
              sections: [block('related'), block('modules'), block('tags')],
              technical: block('technical'),
            ),
          ),
        ),
      );
      await tester.pump(); // HeroController's offstage geometry pass.
      await tester.pump(); // The route's first actually visible frame.
      for (final label in ['Back and header', 'Main media', 'Primary', 'Primary actions']) {
        expect(find.text(label), findsOneWidget);
      }
      // Mounted blocks have their final geometry before any paint is released.
      const labels = ['related', 'modules', 'tags', 'technical'];
      expect(built, labels);
      final rectangles = [for (final label in labels) tester.getRect(find.text(label))];
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
      final extent = scroll.position.maxScrollExtent;
      List<bool> visibility() => tester.allRenderObjects.whereType<FrostFrameWorkRender>().toSet().map((gate) => gate.visible).toList();
      expect(visibility(), List.filled(4, reduced));
      if (!reduced) {
        for (var count = 1; count <= 4; count++) {
          await tester.pump(const Duration(milliseconds: 8));
          expect(visibility(), List.generate(4, (i) => i < count));
          expect([for (final label in labels) tester.getRect(find.text(label))], rectangles);
          expect(scroll.position.maxScrollExtent, extent);
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final unmount in [false, true]) {
    testWidgets('detail pending work is cancelled on ${unmount ? 'unmount' : 'route exit'}', (tester) async {
      late BuildContext home;
      final built = <int>[];
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              home = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      Navigator.of(home).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(seconds: 1),
          reverseTransitionDuration: const Duration(milliseconds: 100),
          pageBuilder: (_, _, _) => FrostDetailLayout(
            stage: const SizedBox(),
            primary: const Text('Primary'),
            sections: List.generate(
              8,
              (i) => Builder(
                builder: (_) {
                  built.add(i);
                  return const SizedBox(height: 40);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(built, List.generate(8, (i) => i));
      final gates = tester.allRenderObjects.whereType<FrostFrameWorkRender>().toSet().toList();
      expect(gates.every((gate) => !gate.visible), isTrue);
      if (unmount) {
        await tester.pumpWidget(const SizedBox());
      } else {
        Navigator.of(home).pop();
      }
      await tester.pumpAndSettle();
      // The owner cancels unreleased paint, including callbacks already queued
      // for the next frame. Layout and State were created before route exit.
      expect(gates.every((gate) => !gate.visible), isTrue);
      expect(built, List.generate(8, (i) => i));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('detail information builds visible blocks lazily and retains visited State', (tester) async {
    final built = <int>{};
    final keys = List.generate(100, (_) => GlobalKey());
    await tester.pumpWidget(
      frostTestApp(
        FrostDetailLayout(
          stage: const SizedBox(),
          primary: const Text('Primary'),
          sections: List.generate(100, (i) => _VisitedBlock(key: keys[i], index: i, built: built)),
        ),
      ),
    );
    expect(built.length, lessThan(10));
    final first = keys.first.currentState;
    expect(first, isNotNull);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    scroll.position.jumpTo(1400);
    await tester.pump();
    expect(built.length, lessThan(25));
    expect(keys.first.currentState, same(first));
    scroll.position.jumpTo(0);
    await tester.pump();
    expect(keys.first.currentState, same(first));
    expect(tester.takeException(), isNull);
  });
}

class _VisitedBlock extends StatefulWidget {
  const _VisitedBlock({required this.index, required this.built, super.key});
  final int index;
  final Set<int> built;
  @override
  State<_VisitedBlock> createState() => _VisitedBlockState();
}

class _VisitedBlockState extends State<_VisitedBlock> {
  @override
  void initState() {
    super.initState();
    widget.built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: 100, child: Text('Block ${widget.index}'));
}
