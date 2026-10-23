import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final header in [false, true]) {
    for (final direction in TextDirection.values) {
      testWidgets('middle grows continuously after leading without squeezing actions header=$header direction=$direction', (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final width = ValueNotifier(744.0);
        addTearDown(width.dispose);
        final controller = TextEditingController(text: 'retained query');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        final source = GlobalKey(), middle = GlobalKey();
        final actions = [GlobalKey(), GlobalKey()];
        Widget row() {
          final leading = [SizedBox(key: source, width: 140, height: 32)];
          final field = SizedBox(
            key: middle,
            child: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
          );
          final trailing = [
            for (final key in actions)
              FrostToolbarItem.custom(
                minWidth: 80,
                priority: FrostToolbarPriority.high,
                builder: (_) => SizedBox(key: key, width: 80, height: 32),
                overflowEntry: FrostMenuAction('Action', onSelected: () {}),
              ),
          ];
          return header
              ? FrostPageHeader(leading: leading, middle: field, middleMaxWidth: 640, actions: trailing)
              : FrostToolbar(leading: leading, middle: field, middleMaxWidth: 640, trailing: trailing);
        }

        tester.view.physicalSize = const Size(1024, 900);
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: width,
                  builder: (_, value, _) => SizedBox(width: value, child: row()),
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        final initialState = tester.state(find.byType(EditableText));
        focus.requestFocus();
        await tester.pump();
        controller.selection = const TextSelection.collapsed(offset: 5);
        await tester.pump();
        double? previous;
        for (final viewport in [1024.0, 1025.0, 1440.0, 1920.0, 1024.0]) {
          tester.view.physicalSize = Size(viewport, 900);
          width.value = viewport - 280;
          await tester.pump();
          final sourceRect = tester.getRect(find.byKey(source));
          final middleRect = tester.getRect(find.byKey(middle));
          expect(middleRect.width, inInclusiveRange(360, 640));
          if (viewport >= 1440) expect(middleRect.width, 640);
          if (viewport == 1025) expect(middleRect.width, closeTo(previous! + 1, .001));
          final gap = direction == TextDirection.ltr ? middleRect.left - sourceRect.right : sourceRect.left - middleRect.right;
          expect(gap, FrostGap.related);
          for (final action in actions) {
            final rect = tester.getRect(find.byKey(action));
            expect(rect.width, 80);
            expect(direction == TextDirection.ltr ? rect.left >= middleRect.right : rect.right <= middleRect.left, isTrue);
          }
          expect(tester.state(find.byType(EditableText)), same(initialState));
          expect(controller.text, 'retained query');
          expect(controller.selection.extentOffset, 5);
          expect(focus.hasFocus, isTrue);
          expect(tester.takeException(), isNull);
          previous = middleRect.width;
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('default remains 360 and explicit maximum may be below the usual minimum', (tester) async {
    final key = GlobalKey();
    for (final maximum in [null, 120.0]) {
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 700,
              child: maximum == null
                  ? FrostToolbar(middle: SizedBox(key: key, height: 32))
                  : FrostPageHeader(
                      middleMaxWidth: maximum,
                      middle: SizedBox(key: key, height: 32),
                    ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(key)).width, maximum ?? 360);
    }
  });
  test('maximum must be positive and finite', () {
    for (final width in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => FrostToolbar(middleMaxWidth: width), throwsAssertionError);
      expect(() => FrostPageHeader(middleMaxWidth: width), throwsAssertionError);
    }
  });
}
