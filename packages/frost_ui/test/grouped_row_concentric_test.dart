import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'support.dart';

// Inspect the effective clipping path rather than estimating a dark fringe in
// a raster screenshot. A grouped row is intended to touch the outer card.
double _leftEdge(ui.Path path, Rect bounds, double y) {
  var outside = bounds.left - 1, inside = bounds.left + 40;
  for (var step = 0; step < 30; step++) {
    final x = (outside + inside) / 2;
    if (path.contains(Offset(x, y))) {
      inside = x;
    } else {
      outside = x;
    }
  }
  return (outside + inside) / 2;
}

double _rightEdge(ui.Path path, Rect bounds, double y) {
  var inside = bounds.right - 40, outside = bounds.right + 1;
  for (var step = 0; step < 30; step++) {
    final x = (inside + outside) / 2;
    if (path.contains(Offset(x, y))) {
      inside = x;
    } else {
      outside = x;
    }
  }
  return (outside + inside) / 2;
}

void main() {
  for (final continuous in [false, true]) {
    for (final rtl in [false, true]) {
      for (final density in FrostDensity.values) {
        for (final count in [1, 3]) {
          testWidgets('group feedback touches card edges and corners continuous=$continuous rtl=$rtl density=$density rows=$count', (tester) async {
            tester.view.devicePixelRatio = 1.5;
            tester.view.physicalSize = const Size(1800, 1200);
            addTearDown(tester.view.reset);
            final direction = rtl ? TextDirection.rtl : TextDirection.ltr;
            await tester.pumpWidget(
              frostTestApp(
                Directionality(
                  textDirection: direction,
                  child: FrostScope(
                    config: testConfig.copyWith(continuousCorners: continuous),
                    child: Center(
                      child: SizedBox(
                        width: 640,
                        child: FrostGroupedSection(
                          children: [for (var index = 0; index < count; index++) FrostListRow(title: 'Row $index', onPressed: () {})],
                        ),
                      ),
                    ),
                  ),
                ),
                density: density,
              ),
            );
            await tester.pumpAndSettle();
            final surfaceFinder = find.byType(FrostSurface);
            final surface = tester.widget<FrostSurface>(surfaceFinder);
            final bounds = tester.getRect(surfaceFinder);
            final outerRadius = surface.borderRadius!.resolve(direction);
            final clipFinder = find.descendant(of: surfaceFinder, matching: continuous ? find.byType(ClipRSuperellipse) : find.byType(ClipRRect)).first;
            expect(tester.getRect(clipFinder), bounds);
            final outerClip = tester.widget(clipFinder);
            final clipRadius = switch (outerClip) {
              ClipRSuperellipse(:final borderRadius) => borderRadius,
              ClipRRect(:final borderRadius) => borderRadius,
              _ => throw StateError('Unexpected card clip'),
            };
            expect(clipRadius.resolve(direction), outerRadius);
            final outerShape = continuous ? RoundedSuperellipseBorder(borderRadius: outerRadius) : RoundedRectangleBorder(borderRadius: outerRadius);
            final outerPath = outerShape.getOuterPath(Offset.zero & bounds.size, textDirection: direction).shift(bounds.topLeft);
            final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: Offset.zero);
            addTearDown(mouse.removePointer);
            for (final index in {0, count - 1}) {
              final row = find.byWidgetPredicate((w) => w is FrostListRow && w.title == 'Row $index');
              final feedbackFinder = find.descendant(of: row, matching: find.byType(FrostClickFeedbackVisual));
              final feedbackBounds = tester.getRect(feedbackFinder);
              expect(feedbackBounds.left, bounds.left);
              expect(feedbackBounds.right, bounds.right);
              if (index == 0) expect(feedbackBounds.top, bounds.top);
              if (index == count - 1) expect(feedbackBounds.bottom, bounds.bottom);
              await mouse.moveTo(feedbackBounds.center);
              await tester.pumpAndSettle();
              for (final pressed in [false, true]) {
                if (pressed) {
                  await mouse.down(feedbackBounds.center);
                  await tester.pumpAndSettle();
                }
                final feedback = tester.widget<FrostClickFeedbackVisual>(feedbackFinder);
                expect(feedback.states, contains(pressed ? WidgetState.pressed : WidgetState.hovered));
                final corners = switch (feedback.shape!) {
                  RoundedSuperellipseBorder(:final borderRadius) when continuous => borderRadius.resolve(direction),
                  RoundedRectangleBorder(:final borderRadius) when !continuous => borderRadius.resolve(direction),
                  _ => throw StateError('Card and feedback must use the same curve family'),
                };
                expect(
                  corners,
                  BorderRadius.only(
                    topLeft: index == 0 ? outerRadius.topLeft : Radius.zero,
                    topRight: index == 0 ? outerRadius.topRight : Radius.zero,
                    bottomLeft: index == count - 1 ? outerRadius.bottomLeft : Radius.zero,
                    bottomRight: index == count - 1 ? outerRadius.bottomRight : Radius.zero,
                  ),
                );
                expect(feedback.clipsContent, isFalse);
                expect(feedback.fillsBounds, isTrue);
                expect(find.descendant(of: feedbackFinder, matching: find.byType(ClipPath)), findsNothing);
                final rowPath = feedback.shape!.getOuterPath(Offset.zero & feedbackBounds.size, textDirection: direction).shift(feedbackBounds.topLeft);
                final paintFinder = find.descendant(of: feedbackFinder, matching: find.byType(FrostInteractionDecoration)).first;
                expect(tester.getRect(paintFinder), feedbackBounds);
                expect(tester.widget<FrostInteractionDecoration>(paintFinder).decoration, isA<BoxDecoration>());
                for (final top in [if (index == 0) true, if (index == count - 1) false]) {
                  // Path.contains uses the engine's float curve approximation.
                  // 0.025 logical px (<0.04 physical at DPR1.5) tolerates that
                  // precision, while rejecting any visible inset or radius error.
                  for (final depth in [.125, .5, 1.0, 2.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 32.0]) {
                    final y = top ? bounds.top + depth : bounds.bottom - depth;
                    expect(_leftEdge(rowPath, bounds, y) - _leftEdge(outerPath, bounds, y), closeTo(0, .025), reason: 'Left corner gap at depth $depth');
                    expect(_rightEdge(outerPath, bounds, y) - _rightEdge(rowPath, bounds, y), closeTo(0, .025), reason: 'Right corner gap at depth $depth');
                  }
                }
                if (pressed) {
                  await mouse.up();
                  await tester.pumpAndSettle();
                }
              }
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
