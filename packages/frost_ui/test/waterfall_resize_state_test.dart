import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class _Item extends StatefulWidget {
  const _Item({required this.index, required this.created, super.key});
  final int index;
  final ValueChanged<int> created;
  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  int count = 0;
  @override
  void initState() {
    super.initState();
    widget.created(widget.index);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: FrostButton(label: '${widget.index}:$count', onPressed: () => setState(() => count++)),
  );
}

void main() {
  testWidgets('waterfall resize reattaches visible State and remains lazy across column counts', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var width = 1000.0;
    final created = <int, int>{};
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Center(
              child: SizedBox(
                width: width,
                height: 600,
                child: FrostWaterfallGrid<int>(
                  items: List.generate(500, (i) => i),
                  padding: EdgeInsets.zero,
                  preferredTileWidth: 230,
                  itemBuilder: (_, index, _) => _Item(key: ValueKey(index), index: index, created: (i) => created[i] = (created[i] ?? 0) + 1),
                ),
              ),
            );
          },
        ),
      ),
    );
    final item = find.byKey(const ValueKey(0));
    final state = tester.state(item);
    await tester.tap(find.text('0:0'));
    await tester.pump();
    final before = tester.getSize(item).width;
    expect(created.length, lessThan(100));
    for (final next in [980.0, 930.0, 900.0, 850.0, 800.0, 600.0, 1000.0]) {
      update(() => width = next);
      await tester.pump();
      expect(tester.state(item), same(state));
      expect(created[0], 1);
      expect(find.text('0:1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(tester.getSize(item).width, before);
    expect(created.length, lessThan(100));
  });
}
