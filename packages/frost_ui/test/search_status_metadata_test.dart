import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';
import 'support.dart';

Future<void> mount(WidgetTester tester, Widget child, {TextDirection direction = TextDirection.ltr, double width = 390}) async {
  await tester.pumpWidget(
    frostTestApp(
      Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Finder row(String label) => find.byWidgetPredicate((w) => w is FrostListRow && w.title == label);
Color dotColor(WidgetTester tester, Finder parent) {
  final dot = find.descendant(of: parent, matching: find.byType(FrostDataDot));
  final container = tester.widget<Container>(find.descendant(of: dot, matching: find.byType(Container)));
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('category marker shares Tag color and mixed rows align ($direction)', (tester) async {
      final controller = TextEditingController(text: 'query'), focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await mount(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FrostTag(label: 'Reference', dataColor: 2),
            FrostSearchInput(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: (_) {},
              suggestions: [
                FrostSearchSuggestionGroup(
                  items: [
                    FrostSearchSuggestion(label: 'Artist', detail: 'Translation', dataColor: 2, value: '1234', onSelected: () {}),
                    FrostSearchSuggestion(label: 'Plain', onSelected: () {}),
                    FrostSearchSuggestion(label: 'History', icon: testIcons.clock, onSelected: () {}),
                  ],
                ),
              ],
            ),
          ],
        ),
        direction: direction,
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(dotColor(tester, row('Artist')), dotColor(tester, find.byType(FrostTag)));
      expect(tester.getSize(find.descendant(of: row('Artist'), matching: find.byType(FrostDataDot))), const Size(6, 6));
      expect(tester.widget<FrostListRow>(row('Artist')).value, '1234');
      final value = find.descendant(of: row('Artist'), matching: find.text('1234'));
      expect(tester.renderObject<RenderParagraph>(value).text.toPlainText(), '1234');
      final title = tester.getRect(find.text('Artist'));
      final plain = tester.getRect(find.text('Plain'));
      expect(direction == TextDirection.ltr ? title.left : title.right, closeTo(direction == TextDirection.ltr ? plain.left : plain.right, .01));
      expect(find.text('Translation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('status-only panel retains editing focus and never becomes a selection', (tester) async {
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final calls = <String>[];
    bool loading = true;
    String? message = 'Loading matches';
    late StateSetter update;
    await mount(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: calls.add, loading: loading, message: message);
        },
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FrostPopoverSurface), findsOneWidget);
    expect(find.descendant(of: find.byType(FrostPopoverSurface), matching: find.byType(FrostActivityIndicator)), findsOneWidget);
    expect(find.byType(FrostListRow), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['raw']);
    expect(focus.hasFocus, isTrue);
    update(() {
      loading = false;
      message = 'No matches';
    });
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    expect(find.descendant(of: find.byType(FrostPopoverSurface), matching: find.byType(FrostActivityIndicator)), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, ['raw', 'raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(focus.hasFocus, isTrue);
    controller.text = 'new';
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    update(() => message = null);
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('status replaces removed items without ghost selections and scrolls within keyboard viewport', (tester) async {
    final controller = FrostTokenEditingController(text: 'query'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var loading = false, selected = 0, submitted = 0;
    String? message;
    var items = [FrostSearchSuggestion(label: 'Old match', onSelected: () => selected++)];
    late StateSetter update;
    await mount(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600), viewInsets: EdgeInsets.only(bottom: 260)),
        child: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostSearchInput(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: (_) => submitted++,
              loading: loading,
              message: message,
              suggestions: [FrostSearchSuggestionGroup(items: items)],
            );
          },
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    update(() {
      loading = true;
      message = List.filled(120, 'Failure detail').join(' ');
      items = [];
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(row('Old match'), findsNothing);
    expect(tester.getSize(find.byType(FrostPopoverSurface)).height, lessThanOrEqualTo(170));
    final scrollable = find.descendant(of: find.byType(FrostPopoverSurface), matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(FrostPopoverSurface), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 500));
    expect(position.pixels, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, 0);
    expect(submitted, 1);
    controller.value = const TextEditingValue(text: 'query', selection: TextSelection.collapsed(offset: 5), composing: TextRange(start: 0, end: 5));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(submitted, 1);
    expect(controller.value.composing, const TextRange(start: 0, end: 5));
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
