import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('R4 public types compile with only widgets and frost_ui', () {
    final widgets = <Widget>[
      const FrostStatusGlyph(kind: FrostStatusGlyphKind.success, size: 20),
      const FrostStatusGlyph(kind: FrostStatusGlyphKind.failure, size: 16, color: Color(0xff000000), animate: false),
      const FrostStatusGlyph(kind: FrostStatusGlyphKind.warning, size: 28),
      FrostButton(label: 'Save', onPressedAsync: () async => true),
      FrostButton.icon(icon: const FrostIconData.glyph(IconData(1)), label: 'Save', onPressedAsync: () async => false),
    ];
    expect(widgets, hasLength(5));
  });
}
