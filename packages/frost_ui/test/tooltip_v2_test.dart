import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

double tooltipOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.ancestor(of: find.byType(FrostSurfaceScope), matching: find.byType(FadeTransition)).first).opacity.value;

void main() {
  for (final reduced in [false, true]) {
    testWidgets('hover waits 500ms then fades, exit starts immediately, reduced=$reduced', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Center(
              child: FrostTooltip(message: 'help', child: SizedBox(width: 80, height: 40)),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(FrostTooltip)));
      await tester.pump(const Duration(milliseconds: 499));
      expect(find.text('help'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(Duration(milliseconds: reduced ? 60 : 110));
      expect(tooltipOpacity(tester), inExclusiveRange(0, 1));
      expect(find.descendant(of: find.byType(FrostSurfaceScope), matching: find.byType(Transform)), findsNothing);
      await tester.pump(Duration(milliseconds: reduced ? 60 : 110));
      expect(tooltipOpacity(tester), 1);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(Duration(milliseconds: reduced ? 60 : 80));
      expect(tooltipOpacity(tester), inExclusiveRange(0, 1));
      await tester.pump(Duration(milliseconds: reduced ? 60 : 80));
      expect(tooltipOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('help'), findsNothing);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    });
  }

  testWidgets('touch long press remains visible for 1500ms after release then fades out', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: FrostTooltip(message: 'help', child: SizedBox(width: 80, height: 40)),
        ),
      ),
    );
    final touch = await tester.startGesture(tester.getCenter(find.byType(FrostTooltip)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('help'), findsOneWidget);
    await touch.up();
    await tester.pump(const Duration(milliseconds: 1499));
    expect(tooltipOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tooltipOpacity(tester), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tooltipOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('help'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long tooltip wraps at 280, stays inside the viewport and flips with a 6 gap', (tester) async {
    const message = 'A long tooltip message that must wrap onto several lines without going outside the viewport';
    await tester.pumpWidget(
      frostTestApp(
        const Align(
          alignment: Alignment.bottomRight,
          child: FrostTooltip(message: message, child: SizedBox(width: 40, height: 40)),
        ),
      ),
    );
    final target = tester.getRect(find.byType(FrostTooltip));
    tester.state<RawTooltipState>(find.byType(RawTooltip)).ensureTooltipVisible();
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(FrostSurfaceScope));
    expect(panel.width, 280);
    expect(panel.bottom, target.top - 6);
    expect(panel.right, lessThanOrEqualTo(800));
    final text = tester.renderObject<RenderParagraph>(find.text(message));
    expect(text.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: message.length)).length, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('excludeFromSemantics removes only the tooltip description', (tester) async {
    final handle = tester.ensureSemantics();
    for (final excluded in [false, true]) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: FrostTooltip(
              message: 'help',
              excludeFromSemantics: excluded,
              child: Semantics(button: true, label: 'target', child: const SizedBox(width: 80, height: 40)),
            ),
          ),
        ),
      );
      final data = tester.getSemantics(find.bySemanticsLabel('target')).getSemanticsData();
      expect(data.label, 'target');
      expect(data.flagsCollection.isButton, true);
      expect(data.tooltip, excluded ? '' : 'help');
    }
    handle.dispose();
  });
}
