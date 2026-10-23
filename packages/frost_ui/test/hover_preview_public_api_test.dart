import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('hover preview and extension compile from widgets and frost_ui only', () {
    final widgets = <Widget>[
      FrostHoverPreview(previewBuilder: (_) => const Text('Preview'), enabled: true, child: const Text('Target')),
      const Text('Target').frostHoverPreview((_) => const Text('Preview'), enabled: false),
    ];
    expect(widgets, hasLength(2));
  });
}
