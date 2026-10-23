import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('6D types need only widgets and frost_ui', () {
    const shortcut = FrostShortcut(LogicalKeyboardKey.keyC, primary: true);
    final widgets = <Widget>[
      const FrostCopyable(text: 'text'),
      const FrostShare(text: 'text', label: 'Share'),
      const SizedBox().frostDropTarget(active: true, hint: 'Drop'),
      FrostShortcuts(bindings: {shortcut: () {}}, child: const SizedBox()),
      const SizedBox().frostShortcut(shortcut, () {}),
      const FrostGrid(minItemWidth: 100, children: []),
      FrostSliverGrid(minItemWidth: 100, aspectRatio: 1, itemCount: 1, itemBuilder: (_, _) => const SizedBox()),
      const FrostWrap(children: []),
      FrostFit(candidates: [(_) => const SizedBox(width: 100)]),
    ];
    expect(widgets, hasLength(9));
  });
}
