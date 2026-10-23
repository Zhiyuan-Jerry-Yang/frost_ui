import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('child media frame preserves playback and recovery controls', (tester) async {
    final handle = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 500,
            height: 300,
            child: FrostMediaFrame(
              child: FrostButton.icon(icon: testIcons.play, label: 'Play', selected: true, onPressed: () => presses++),
            ),
          ),
        ),
      ),
    );
    final button = find.bySemanticsLabel('Play');
    expect(button, findsOneWidget);
    expect(tester.getSemantics(button).flagsCollection.isToggled, Tristate.isTrue);
    await tester.tap(button);
    await tester.pump();
    expect(presses, 1);
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
    expect(tester.takeException(), isNull);
  });
}
