import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_window/frost_window.dart';

void main() {
  test('native caption state preserves single buttons and reuses unchanged theme icons', () {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    Map<Object?, Object?> native(Uint8List icon) => {
      'captionStyle': 'breeze',
      'leftButtons': ['close'],
      'rightButtons': <String>[],
      'captionIcons': {'close': icon},
    };
    final first = FrostWindowState.fromMap(native(bytes));
    expect(first.captionStyle, FrostCaptionStyle.breeze);
    expect(first.leftButtons, [FrostCaptionAction.close]);
    expect(first.rightButtons, isEmpty);
    final next = FrostWindowState.fromMap(native(Uint8List.fromList(bytes)), previous: first);
    expect(identical(first.captionIcons[FrostCaptionIcon.close], next.captionIcons[FrostCaptionIcon.close]), isTrue);
    final missing = FrostWindowState.fromMap({'captionStyle': 'adwaita', 'captionIcons': <String, Object>{}}, previous: first);
    expect(missing.captionIcons, isEmpty);
    expect(() => first.captionIcons.clear(), throwsUnsupportedError);
  });
}
