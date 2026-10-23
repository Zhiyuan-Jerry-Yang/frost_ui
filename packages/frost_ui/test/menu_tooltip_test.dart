import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  testWidgets('disabled action keeps its label, shows help and announces one reason', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostMenuAnchor(
            entries: [
              FrostMenuAction('Copy image', enabled: false, tooltip: 'Loading image', onSelected: () => calls++),
              FrostMenuAction('Available', onSelected: () => calls++),
            ],
            builder: (context, focus, toggle) => TextButton(focusNode: focus, onPressed: toggle, child: const Text('Open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Copy image'), findsOneWidget);
    expect(find.textContaining(' · Loading'), findsNothing);
    final node = tester.getSemantics(find.text('Copy image'));
    expect(node.getSemanticsData().hint, 'Loading image');
    expect(node.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Copy image')));
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pumpAndSettle();
    expect(find.text('Loading image'), findsOneWidget);
    await tester.tap(find.text('Copy image'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Available'), findsOneWidget);
    await mouse.removePointer();
    await tester.tap(find.text('Available'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('icon forwarding keeps label separate from tooltip and semantics hint', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(FrostButton.icon(icon: testIcons.copy, label: 'Copy image', tooltip: 'Loading image')));
    final hint = tester.getSemantics(find.byType(FrostButton)).getSemanticsData();
    expect(hint.label, 'Copy image');
    expect(hint.hint, 'Loading image');
    expect(tester.widget<FrostTooltip>(find.byType(FrostTooltip)).message, 'Loading image');
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
