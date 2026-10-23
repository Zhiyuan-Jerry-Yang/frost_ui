import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

const icon = FrostIconData.glyph(IconData(0xe001));
void main() {
  test('social actions compile from widgets and frost_ui only', () {
    final widgets = <Widget>[
      FrostToggleButton(
        icon: icon,
        selectedIcon: icon,
        selected: false,
        onChanged: (_) {},
        label: 'Like',
        tint: const Color(0xff123456),
        size: FrostControlSize.compact,
      ),
      FrostActionCount(icon: icon, selectedIcon: icon, selected: true, count: 1, onChanged: (_) {}, label: 'Like', format: (n) => '$n'),
      const FrostAvatarStack(
        avatars: [FrostAvatar(initials: 'A', semanticLabel: 'Person')],
        max: 3,
        label: 'People',
        size: FrostAvatarSize.small,
        semanticLabel: 'People',
      ),
    ];
    expect(widgets, hasLength(3));
  });
}
