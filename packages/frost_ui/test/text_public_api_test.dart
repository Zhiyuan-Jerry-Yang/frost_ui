import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('8B text compiles from widgets and frost_ui only', () {
    final widgets = <Widget>[
      FrostExpandableText(text: 'Text', maxLines: 3, role: FrostTextRole.body, expanded: false, onExpandedChanged: (_) {}),
      FrostRichText(text: 'Text', onLink: (_) {}, onMention: (_) {}, onHashtag: (_) {}, role: FrostTextRole.callout, selectable: false),
    ];
    expect(widgets, hasLength(2));
  });
}
