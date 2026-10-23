import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Finder handle(int index) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'L.reorderHandle').at(index);
Finder surfaceHandle(int index) => find.descendant(of: handle(index), matching: find.byType(FrostClickSurface)).first;
void focusHandle(WidgetTester tester, int index) => tester.widget<FrostClickSurface>(surfaceHandle(index)).focusNode!.requestFocus();

class _Host extends StatefulWidget {
  const _Host({this.count = 5, this.height = 300, this.reduced = false, super.key});
  final int count;
  final double height;
  final bool reduced;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final items = List.generate(widget.count, (i) => i);
  final moves = <(int, int)>[];
  int builds = 0;
  bool enabled = true;
  void disable() => setState(() => enabled = false);
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: widget.reduced),
    child: FrostControlScope(
      enabled: enabled,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: widget.height,
          child: FrostReorderableList<int>(
            items: items.toList(),
            itemBuilder: (_, item) {
              builds++;
              return _Probe(item: item);
            },
            onReorder: (oldIndex, newIndex) {
              moves.add((oldIndex, newIndex));
              setState(() {
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
              });
            },
          ),
        ),
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.item});
  final int item;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => taps++,
    child: SizedBox(
      height: 44,
      child: Align(alignment: Alignment.centerLeft, child: Text('Item ${widget.item}')),
    ),
  );
}

double y(WidgetTester tester, int item) => tester.getTopLeft(find.text('Item $item')).dy;
void main() {
  testWidgets('keyboard pickup, spring displacement, final-index callback and position announcement', (tester) async {
    final messages = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (message) async {
      messages.add(message);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key)));
    focusHandle(tester, 0);
    await tester.pump();
    final before = y(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(y(tester, 1), inExclusiveRange(before - 44, before));
    expect(key.currentState!.moves, isEmpty);
    await tester.pumpAndSettle();
    expect(y(tester, 1), closeTo(before - 44, .01));
    expect(messages.toString(), contains('2 / 5'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, [(0, 2)]);
    expect(key.currentState!.items, [1, 2, 0, 3, 4]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Escape cancels keyboard preview without calling application', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key)));
    focusHandle(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(y(tester, 1), lessThan(y(tester, 0)));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, isEmpty);
    expect(y(tester, 0), lessThan(y(tester, 1)));
  });
  testWidgets('pointer lift preserves child State, token shadow and drop parameters', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key)));
    final probe = find.byWidgetPredicate((w) => w is _Probe && w.item == 0);
    final state = tester.state<_ProbeState>(probe);
    final gesture = await tester.startGesture(tester.getCenter(surfaceHandle(0)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.state<_ProbeState>(probe), same(state));
    final token = FrostThemeTokens.of(tester.element(find.byType(FrostReorderableList<int>)));
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .any((w) => w.decoration is ShapeDecoration && listEquals((w.decoration! as ShapeDecoration).shadows, token.shadowAmbient)),
      isTrue,
    );
    final scales = tester.widgetList<Transform>(find.ancestor(of: probe, matching: find.byType(Transform))).map((w) => w.transform.storage[0]);
    expect(scales.any((scale) => scale > 1 && scale <= 1.02), isTrue);
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(y(tester, 1), inExclusiveRange(0, 44));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, [(0, 2)]);
    expect(tester.state<_ProbeState>(probe), same(state));
    expect(tester.takeException(), isNull);
  });
  testWidgets('900 rows remain lazy and edge dragging scrolls beyond the initial viewport', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key, count: 900, height: 180)));
    expect(key.currentState!.builds, lessThan(30));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final gesture = await tester.startGesture(tester.getCenter(surfaceHandle(0)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 170));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(scrollable.position.pixels, greaterThan(0));
    expect(key.currentState!.builds, lessThan(150));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion displacements apply immediately and lift does not scale', (tester) async {
    await tester.pumpWidget(frostTestApp(const _Host(reduced: true)));
    final before = y(tester, 1);
    focusHandle(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(y(tester, 1), before - 44);
    final transforms = tester.widgetList<Transform>(find.ancestor(of: find.text('Item 0'), matching: find.byType(Transform)));
    expect(transforms.every((w) => w.transform.storage[0] == 1), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
  testWidgets('disabling or disposing during a drag never commits', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key)));
    final gesture = await tester.startGesture(tester.getCenter(surfaceHandle(0)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    key.currentState!.disable();
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('duplicate values assert', (tester) async {
    await tester.pumpWidget(
      frostTestApp(FrostReorderableList(items: const [1, 1], itemBuilder: (_, item) => const SizedBox(height: 40), onReorder: (_, _) {})),
    );
    expect(tester.takeException(), isAssertionError);
  });
  testWidgets('redirecting a moving row keeps position and bounds inherited velocity', (tester) async {
    await tester.pumpWidget(frostTestApp(const _Host()));
    focusHandle(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 69));
    final a = y(tester, 1);
    await tester.pump(const Duration(milliseconds: 1));
    final b = y(tester, 1);
    // Reverse the target while this neighbor is moving towards the start.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    final redirected = y(tester, 1);
    expect(redirected, closeTo(b, .01));
    await tester.pump(const Duration(milliseconds: 1));
    final c = y(tester, 1);
    expect(b, lessThan(a), reason: 'The row was moving towards the old target.');
    expect(c, greaterThanOrEqualTo(redirected), reason: 'Opposing inherited velocity must not continue away from the new target.');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('reverse drag and no-op drop report final indexes exactly once', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key)));
    var gesture = await tester.startGesture(tester.getCenter(surfaceHandle(3)));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -95));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, [(3, 1)]);
    gesture = await tester.startGesture(tester.getCenter(surfaceHandle(1)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, [(3, 1)]);
  });

  testWidgets('unmount while pointer is held drops no callbacks or overlay resources', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key)));
    final state = key.currentState!;
    final gesture = await tester.startGesture(tester.getCenter(surfaceHandle(0)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.moves, isEmpty);
    expect(find.text('Item 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL and large ListRow keep handle at logical end and full title', (tester) async {
    const title = 'A long title that wraps completely at larger text sizes';
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 240,
                height: 500,
                child: FrostReorderableList(
                  items: const [1, 2],
                  itemBuilder: (_, item) => const FrostListRow(title: title, subtitle: 'Details'),
                  onReorder: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getRect(handle(0)).right, lessThanOrEqualTo(tester.getRect(find.text(title).first).left));
    final text = tester.widget<Text>(find.text(title).first);
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unequal heights and nullable item keys preserve final index meaning', (tester) async {
    var items = <int?>[null, 1, 2];
    final moves = <(int, int)>[];
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, update) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 300,
              child: FrostReorderableList<int?>(
                items: items,
                itemBuilder: (_, item) => SizedBox(height: item == 1 ? 80 : 44, child: Text('Value $item')),
                onReorder: (oldIndex, newIndex) {
                  moves.add((oldIndex, newIndex));
                  update(() {
                    items = items.toList();
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
    focusHandle(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(moves, [(0, 1)]);
    expect(items, [1, null, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the lifted item cancels on the same frame', (tester) async {
    var items = [1, 2, 3];
    late StateSetter update;
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostReorderableList(
              items: items,
              itemBuilder: (_, item) => SizedBox(height: 44, child: Text('Value $item')),
              onReorder: (_, _) => calls++,
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(surfaceHandle(0)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    update(() => items = [2, 3]);
    await tester.pump();
    expect(find.text('Value 1'), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fully wrapped row taller than the viewport can still be dragged', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 120,
            child: FrostReorderableList(
              items: const [1, 2],
              itemBuilder: (_, item) => SizedBox(height: 200, child: Text('Value $item')),
              onReorder: (_, _) {},
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(surfaceHandle(0)));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('moving content receives taps at its painted position outside the new slot', (tester) async {
    await tester.pumpWidget(frostTestApp(const _Host()));
    final probe = find.byWidgetPredicate((w) => w is _Probe && w.item == 0);
    final state = tester.state<_ProbeState>(probe);
    focusHandle(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tapAt(tester.getCenter(find.text('Item 0')));
    expect(state.taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
  testWidgets('keyboard ordering crosses the viewport while retaining handle focus', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(frostTestApp(_Host(key: key, count: 900, height: 180)));
    focusHandle(tester, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    for (var i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(key.currentState!.moves, [(0, 15)]);
    expect(key.currentState!.builds, lessThan(900));
    expect(tester.takeException(), isNull);
  });
}
