import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'support.dart';

void main() {
  for (final dark in [false, true]) {
    for (final grouped in [false, true]) {
      for (final task in [false, true]) {
        testWidgets('row state shape and trailing ink stay complete dark=$dark grouped=$grouped task=$task', (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey(), button = GlobalKey();
          var rowTaps = 0, actionTaps = 0;
          late FrostThemeTokens tokens;
          Widget row(BuildContext context) {
            final trailing = FrostButton.icon(key: button, icon: testIcons.more, label: 'More', onPressed: () => actionTaps++);
            return FrostSwipeActions(
              showsPointerActions: false,
              trailing: [FrostSwipeAction(icon: testIcons.delete, label: 'Delete', onPressed: () {})],
              child: task
                  ? FrostTaskRow(title: 'Item', selected: true, status: FrostTaskStatus.running, progress: .4, trailing: trailing, onPressed: () => rowTaps++)
                  : FrostListRow(title: 'Item', selected: true, trailing: trailing, onPressed: () => rowTaps++),
            );
          }

          final body = FrostContentColumn(
            child: Builder(
              builder: (context) {
                tokens = FrostThemeTokens.of(context);
                return grouped
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: FrostGroupedSection(children: [row(context)]),
                      )
                    : FrostList<int>(items: const [1], itemBuilder: (context, _, _) => row(context));
              },
            ),
          );
          await tester.pumpWidget(
            frostTestApp(
              Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: ColoredBox(
                    color: Colors.purple,
                    child: SizedBox(width: 440, height: 180, child: body),
                  ),
                ),
              ),
              brightness: dark ? Brightness.dark : Brightness.light,
              density: FrostDensity.compact,
            ),
          );
          await tester.pumpAndSettle();
          final selection = find.byWidgetPredicate(
            (w) =>
                w is AnimatedContainer &&
                switch (w.decoration) {
                  ShapeDecoration(:final color) => color == tokens.selectionFill,
                  BoxDecoration(:final color) => color == tokens.selectionFill,
                  _ => false,
                },
          );
          expect(selection, findsOneWidget);
          final rect = tester.getRect(selection);
          final shape = tester.widget<FrostClickFeedbackVisual>(find.byType(FrostClickFeedbackVisual).first).shape!;
          final radius = switch (shape) {
            RoundedSuperellipseBorder(:final borderRadius) => borderRadius.resolve(TextDirection.ltr),
            RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(TextDirection.ltr),
            _ => BorderRadius.zero,
          };
          expect(radius.topLeft.x, greaterThan(0));
          final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          final point = rect.topLeft + Offset(100, rect.height / 2);
          await mouse.moveTo(point);
          await tester.pumpAndSettle();
          Finder feedback(WidgetState state) => find.byWidgetPredicate((w) => w is FrostClickFeedbackVisual && w.states.contains(state));
          expect(feedback(WidgetState.hovered), findsOneWidget);
          expect(tester.widget<FrostClickFeedbackVisual>(feedback(WidgetState.hovered)).shape, shape);
          expect(tester.getRect(feedback(WidgetState.hovered)), rect);
          await mouse.down(point);
          await tester.pump();
          expect(tester.widget<FrostClickFeedbackVisual>(feedback(WidgetState.pressed)).shape, shape);
          expect(tester.getRect(feedback(WidgetState.pressed)), rect);
          await mouse.up();
          await tester.pumpAndSettle();
          Future<int> pixel(Offset global) async => (await tester.runAsync(() async {
            final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary)).toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
              final local = global - tester.getTopLeft(find.byKey(boundary));
              return bytes.getUint32((local.dy.floor() * image.width + local.dx.floor()) * 4);
            } finally {
              image.dispose();
            }
          }))!;

          final canvas = await pixel(tester.getTopLeft(find.byKey(boundary)) + const Offset(1, 1));
          expect(await pixel(rect.topLeft + const Offset(1, 1)), canvas);
          final buttonRect = tester.getRect(find.byKey(button));
          final visualRect = tester.getRect(find.descendant(of: find.byKey(button), matching: find.byType(FrostClickSurface)).first);
          final edge = Offset(visualRect.right - 2, visualRect.center.dy);
          await mouse.moveTo(buttonRect.center);
          await tester.pumpAndSettle();
          expect(await pixel(edge), isNot(canvas));
          // Compare the edge with the adjacent row in the same presented
          // frame. The whole hover surface, including its right cap, is visible.
          expect(await pixel(edge), isNot(await pixel(Offset(visualRect.left - 4, visualRect.center.dy))));
          final previousRows = rowTaps;
          await tester.tapAt(Offset(buttonRect.right - 1, buttonRect.center.dy));
          await tester.pumpAndSettle();
          expect(actionTaps, 1);
          expect(rowTaps, previousRows);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
