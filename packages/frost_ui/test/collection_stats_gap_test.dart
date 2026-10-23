import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('collection reserves section gap from header to stats and group after tools', (tester) async {
    for (final tools in [false, true]) {
      await tester.pumpWidget(
        frostTestApp(
          FrostCollectionLayout(
            key: ValueKey(tools),
            header: const SizedBox(key: ValueKey('header'), height: 52),
            toolbar: tools ? const SizedBox(key: ValueKey('tools'), height: 40) : null,
            stats: const [FrostStat(value: '2', caption: 'Active')],
            slivers: const [SliverToBoxAdapter(child: Text('Task'))],
          ),
        ),
      );
      final anchor = find.byKey(ValueKey(tools ? 'tools' : 'header'));
      expect(tester.getTopLeft(find.byType(FrostStatStrip)).dy - tester.getBottomLeft(anchor).dy, tools ? FrostGap.group : FrostGap.section);
      expect(tester.takeException(), isNull);
    }
  });
}
