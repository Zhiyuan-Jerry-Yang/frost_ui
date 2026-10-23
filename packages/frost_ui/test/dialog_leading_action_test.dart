import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';

import 'dialog_sheet_v2_test.dart' show launch, action, modalSurface;
import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final width in [390.0, 900.0]) {
      testWidgets('leading dangerous action is plain with semantic ink and cold-frame geometry $direction $width', (tester) async {
        await launch(
          tester,
          (context) => showFrostDialog<void>(
            context: context,
            builder: (_) => Directionality(
              textDirection: direction,
              child: FrostDialog(
                title: 'Edit',
                content: const Text('Fields'),
                leadingAction: const FrostDialogAction(label: 'Delete', role: FrostButtonRole.destructive),
                actions: const [
                  FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
                  FrostDialogAction(label: 'Save', isDefault: true),
                ],
              ),
            ),
          ),
          size: Size(width, 700),
        );
        final delete = find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'Delete');
        final cancel = find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'Cancel');
        final save = find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'Save');
        final geometry = tester.getRect(delete);
        expect(action(tester, 'Delete').variant, FrostButtonVariant.plain);
        expect(action(tester, 'Delete').role, FrostButtonRole.destructive);
        final text = tester.renderObject<RenderParagraph>(find.text('Delete'));
        expect(text.text.style!.color, FrostThemeTokens.of(tester.element(delete)).negativeInk);
        if (width < 600) {
          expect(geometry.bottom, lessThan(tester.getRect(save).top));
          expect(tester.getRect(save).bottom, lessThan(tester.getRect(cancel).top));
          expect(geometry.width, tester.getRect(save).width);
        } else {
          expect(geometry.top, tester.getRect(save).top);
          final surface = tester.getRect(modalSurface);
          expect(direction == TextDirection.ltr ? geometry.left : geometry.right, direction == TextDirection.ltr ? surface.left + 20 : surface.right - 20);
          expect(
            direction == TextDirection.ltr ? tester.getRect(save).right : tester.getRect(save).left,
            direction == TextDirection.ltr ? surface.right - 20 : surface.left + 20,
          );
          final gap = direction == TextDirection.ltr ? tester.getRect(cancel).left - geometry.right : geometry.left - tester.getRect(cancel).right;
          expect(gap, greaterThan(8));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('leading and trailing positions are correct on the first layout, disabled leading does not call', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 480,
            child: FrostDialog(
              title: 'Edit',
              content: const Text('Fields'),
              leadingAction: FrostDialogAction(
                label: 'Delete',
                role: FrostButtonRole.destructive,
                enabled: false,
                onPressed: () {
                  calls++;
                  return true;
                },
              ),
              actions: const [
                FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
                FrostDialogAction(label: 'Save', isDefault: true),
              ],
            ),
          ),
        ),
      ),
    );
    final left = tester.getRect(find.text('Delete'));
    final right = tester.getRect(find.text('Cancel'));
    expect(left.right, lessThan(right.left));
    expect(left.center.dy, right.center.dy);
    expect(action(tester, 'Delete').onPressed, isNull);
    await tester.tap(find.text('Delete'));
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leading async action shares the loading gate, disables submit, restores on false and reports errors', (tester) async {
    var pending = Completer<bool>();
    var calls = 0;
    await launch(
      tester,
      (context) => showFrostDialog<void>(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Edit',
          content: const Text('Fields'),
          leadingAction: FrostDialogAction(
            label: 'Delete',
            role: FrostButtonRole.destructive,
            onPressed: () {
              calls++;
              return pending.future;
            },
          ),
          actions: const [
            FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
            FrostDialogAction(label: 'Save', isDefault: true),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, 1);
    expect(action(tester, 'Delete').loading, isTrue);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(action(tester, 'Cancel').onPressed, isNotNull);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(action(tester, 'Delete').loading, isFalse);
    expect(action(tester, 'Save').onPressed, isNotNull);
    pending = Completer<bool>();
    await tester.tap(find.text('Delete'));
    pending.completeError(StateError('delete failed'));
    await tester.pump();
    expect(tester.takeException(), isStateError);
    await tester.pumpAndSettle();
    expect(action(tester, 'Delete').loading, isFalse);
    expect(find.byType(FrostDialog), findsOneWidget);
  });

  testWidgets('cancel during leading async operation discards its result and never double pops', (tester) async {
    final pending = Completer<bool>();
    await launch(
      tester,
      (context) => showFrostDialog<void>(
        context: context,
        builder: (_) => FrostDialog(
          title: 'Edit',
          content: const Text('Fields'),
          leadingAction: FrostDialogAction(label: 'Delete', role: FrostButtonRole.destructive, onPressed: () => pending.future),
          actions: const [FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel)],
        ),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(FrostDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form dialog forwards leading action without submitting or owning confirmation', (tester) async {
    var submitted = 0, deleted = 0;
    bool? result;
    await launch(
      tester,
      (context) async => result = await showFrostFormDialog(
        context: context,
        title: 'Edit',
        sections: const [Text('Fields')],
        submitLabel: 'Save',
        onSubmit: () {
          submitted++;
          return true;
        },
        leadingAction: FrostDialogAction<bool>(
          label: 'Delete',
          role: FrostButtonRole.destructive,
          value: false,
          onPressed: () {
            deleted++;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(submitted, 0);
    expect(result, isFalse);
    expect(find.byType(FrostDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
