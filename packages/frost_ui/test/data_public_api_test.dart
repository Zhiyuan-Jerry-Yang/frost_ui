import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('8A selection APIs compile from widgets and frost_ui', () {
    final selection = FrostSelection<int>();
    final widgets = <Widget>[
      FrostSelectionScope(
        selection: selection,
        items: const [1],
        child: const FrostSelectableItem(item: 1, child: SizedBox()),
      ),
      FrostSelectableList(selection: selection, items: const [1], itemBuilder: (_, item, selected) => const SizedBox()),
      FrostSelectionBar(
        selection: selection,
        allItems: const [1],
        actions: [FrostSelectionAction(label: 'Action', icon: const FrostIconData.glyph(IconData(0)), onPressed: null, destructive: true)],
      ),
    ];
    widgets.add(
      FrostSwipeActions(
        leading: [FrostSwipeAction(label: 'Action', icon: const FrostIconData.glyph(IconData(0)), onPressed: () {}, tone: FrostSwipeTone.accent)],
        trailing: [FrostSwipeAction(label: 'Delete', icon: const FrostIconData.glyph(IconData(0)), onPressed: () {}, tone: FrostSwipeTone.destructive)],
        child: const SizedBox(),
      ),
    );
    widgets.add(
      FrostReorderableList(
        items: const [1],
        itemBuilder: (_, item) => const FrostListRow(title: 'Row'),
        onReorder: (_, _) {},
      ),
    );
    widgets.add(
      FrostTable<int>(
        columns: [FrostTableColumn<int>(label: 'Column', cell: (_, item) => Text(''), text: (item) => '', sortKey: (item) => item)],
        rows: const [1],
        selection: selection,
        onSort: (_) {},
        onActivate: (_) {},
      ),
    );
    widgets.add(
      FrostTaskRow(
        title: 'Task',
        status: FrostTaskStatus.running,
        showsStatusDot: false,
        progressPlacement: FrostTaskProgressPlacement.belowDetail,
        progress: .5,
        detail: 'Detail',
        thumbnail: const SizedBox(),
        actions: [FrostTaskAction(label: 'Action', icon: const FrostIconData.glyph(IconData(0)), onPressed: () {})],
        onPressed: () {},
        contextMenu: const [],
      ),
    );
    expect(widgets, hasLength(7));
    selection.dispose();
  });
}
