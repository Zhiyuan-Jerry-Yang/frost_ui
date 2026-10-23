import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'support.dart';

void main() {
  testWidgets('standalone rows retain their own rounded fill and clip', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 320,
            child: FrostListRow(title: 'Standalone', selected: true, onPressed: () {}),
          ),
        ),
      ),
    );
    final feedback = tester.widget<FrostClickFeedbackVisual>(find.byType(FrostClickFeedbackVisual));
    expect(feedback.clipsContent, isTrue);
    expect(feedback.fillsBounds, isFalse);
    final decoration = tester.widget<FrostInteractionDecoration>(find.byType(FrostInteractionDecoration));
    expect(decoration.decoration, isA<ShapeDecoration>());
  });

  testWidgets('group selection is rectangular while nested buttons own their shape', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 480,
            child: FrostGroupedSection(
              children: [
                FrostListRow(
                  title: 'Selected',
                  selected: true,
                  onPressed: () {},
                  trailing: FrostButton(label: 'Nested', onPressed: () {}),
                ),
                FrostListRow(title: 'Last', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    final feedbacks = tester.widgetList<FrostClickFeedbackVisual>(find.byType(FrostClickFeedbackVisual)).toList();
    expect(feedbacks.where((f) => f.fillsBounds), hasLength(2));
    final nested = find.descendant(of: find.byType(FrostButton), matching: find.byType(FrostInteractionDecoration));
    expect(tester.widgetList<FrostInteractionDecoration>(nested).map((w) => w.decoration), everyElement(isA<ShapeDecoration>()));
    final selection = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).where((w) => w.decoration is BoxDecoration).toList();
    expect(selection.any((w) => (w.decoration! as BoxDecoration).color!.a > 0), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stepper asymmetric end fills use their existing clip', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostScope(
            config: testConfig.copyWith(continuousCorners: true),
            child: FrostStepper(value: 5, min: 0, max: 10, semanticLabel: 'Count', onChanged: (_) {}),
          ),
        ),
      ),
    );
    final feedbacks = find.byType(FrostClickFeedbackVisual);
    expect(feedbacks, findsNWidgets(2));
    for (final element in feedbacks.evaluate()) {
      final finder = find.byElementPredicate((e) => e == element);
      final feedback = element.widget as FrostClickFeedbackVisual;
      expect(feedback.clipsContent, isTrue);
      expect(feedback.shape, isA<RoundedSuperellipseBorder>());
      expect(
        tester.widget<FrostInteractionDecoration>(find.descendant(of: finder, matching: find.byType(FrostInteractionDecoration))).decoration,
        isA<BoxDecoration>(),
      );
      expect(find.descendant(of: finder, matching: find.byType(ClipPath)), findsOneWidget);
    }
  });

  testWidgets('asymmetric surface and drop overlay separate fill from strokes', (tester) async {
    const radius = BorderRadius.vertical(top: Radius.circular(16));
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostScope(
            config: testConfig.copyWith(continuousCorners: true),
            child: const FrostSurface(
              role: FrostSurfaceRole.sheet,
              borderRadius: radius,
              child: SizedBox(width: 320, height: 100),
            ).frostDropTarget(active: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final shapes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((w) => w.decoration).whereType<ShapeDecoration>();
    expect(shapes.where((d) => d.shape is RoundedSuperellipseBorder && d.color != null), isEmpty);
    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    expect(find.byType(ClipPath), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
