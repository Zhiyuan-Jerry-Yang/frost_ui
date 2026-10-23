import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('mouse focus keeps activation without a ring and Tab reveals keyboard focus', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostButton(label: 'Original', onPressed: () => calls++),
              FrostButton(label: 'Copy', onPressed: () => calls++),
            ],
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    final original = find.text('Original');
    await mouse.moveTo(tester.getCenter(original));
    await mouse.down(tester.getCenter(original));
    await mouse.up();
    await tester.pumpAndSettle();
    Finder rings() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_ButtonFocusPainter');
    expect(calls, 1);
    expect(rings(), findsNothing, reason: 'Pointer-acquired focus is not a keyboard focus highlight');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(rings(), findsOneWidget);
    await mouse.down(tester.getCenter(original));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(rings(), findsNothing);
    expect(calls, 2);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
