import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';

Finder row(String text) => find.byWidgetPredicate((w) => w is FrostListRow && w.title == text);
Future<void> setup(WidgetTester tester, Widget child, {double width = 500, double keyboard = 0}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
  await tester.pumpWidget(
    frostTestApp(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  for (final tokens in [false, true]) {
    testWidgets('search forwards native autofocus to the ${tokens ? 'token' : 'text'} field', (tester) async {
      final controller = tokens ? FrostTokenEditingController() : TextEditingController();
      final focus = FocusNode();
      await setup(tester, FrostSearchInput(controller: controller, focusNode: focus, autofocus: true, placeholder: 'Search', onSubmitted: (_) {}));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(tester.widget<EditableText>(find.byType(EditableText)).autofocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      controller.dispose();
    });
  }
  testWidgets('scope appears for focus or query and anchors suggestions below it on first layout', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var scope = 1;
    await setup(
      tester,
      StatefulBuilder(
        builder: (_, setState) => FrostSearchInput<int>(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: (_) {},
          scopes: const [
            FrostPickerOption(value: 1, label: 'All'),
            FrostPickerOption(value: 2, label: 'Tags'),
          ],
          scope: scope,
          onScopeChanged: (value) => setState(() => scope = value),
          suggestions: [
            FrostSearchSuggestionGroup(
              title: 'Recent',
              items: [FrostSearchSuggestion(label: 'First', onSelected: () {})],
            ),
          ],
        ),
      ),
    );
    expect(find.text('All'), findsNothing);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    final input = tester.getRect(find.byType(FrostTextField));
    expect(panel.top, closeTo(tester.getRect(find.byType(FrostPicker<int>)).bottom, .01));
    expect(panel.width, input.width);
    expect(find.text('Recent'), findsOneWidget);
    expect(focus.hasFocus, isTrue);
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(scope, 2);
    controller.text = 'query';
    focus.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.byType(FrostPopoverSurface), findsNothing);
    controller.clear();
    await tester.pumpAndSettle();
    expect(find.text('All'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard submits raw query initially, selects once, Esc retains focus and Down reopens separately', (tester) async {
    final controller = TextEditingController(text: 'raw');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final calls = <String>[];
    await setup(
      tester,
      FrostSearchInput(
        controller: controller,
        focusNode: focus,
        placeholder: 'Search',
        onSubmitted: (value) => calls.add(value),
        suggestions: [
          FrostSearchSuggestionGroup(
            items: [
              FrostSearchSuggestion(label: 'First', onSelected: () => calls.add('first')),
              FrostSearchSuggestion(label: 'Last', onSelected: () => calls.add('last')),
            ],
          ),
        ],
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['raw', 'last']);
    expect(focus.hasFocus, isTrue);
    expect(row('First'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['raw', 'last', 'raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls.last, 'first');
    controller.text = 'new';
    await tester.pumpAndSettle();
    expect(row('First'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(row('First'), findsNothing);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('removing current or earlier suggestion retains panel, focus and the correct keyboard identity', (tester) async {
    final controller = TextEditingController(text: 'query');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final calls = <String>[];
    final items = <FrostSearchSuggestion>[];
    StateSetter? update;
    for (final label in ['A', 'B', 'C']) {
      late FrostSearchSuggestion item;
      item = FrostSearchSuggestion(label: label, onSelected: () => calls.add(label), onRemove: () => update!(() => items.remove(item)));
      items.add(item);
    }
    await setup(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return FrostSearchInput(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            suggestions: [FrostSearchSuggestionGroup(title: 'Recent', items: List.of(items))],
          );
        },
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row('A'), matching: find.byType(FrostButton)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(row('B'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['B']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row('B'), matching: find.byType(FrostButton)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls.last, 'C');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row('C'), matching: find.byType(FrostButton)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('scope insertion and supplied suggestions have correct cold-frame anchor and no IME interception', (tester) async {
    final controller = TextEditingController(text: 'query');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var withScope = false, withSuggestions = false;
    StateSetter? update;
    var selected = 0, submitted = 0;
    await setup(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return FrostSearchInput<int>(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) => submitted++,
            scopes: withScope ? const [FrostPickerOption(value: 1, label: 'All')] : null,
            scope: 1,
            onScopeChanged: (_) {},
            suggestions: withSuggestions
                ? [
                    FrostSearchSuggestionGroup(
                      items: [FrostSearchSuggestion(label: 'Term', onSelected: () => selected++)],
                    ),
                  ]
                : [],
          );
        },
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    update!(() {
      withScope = true;
      withSuggestions = true;
    });
    await tester.pump();
    expect(tester.getRect(find.byType(FrostPopoverSurface)).top, tester.getRect(find.byType(FrostPicker<int>)).bottom);
    expect(tester.getSize(find.byType(FrostPopoverSurface)).width, tester.getSize(find.byType(FrostTextField)).width);
    controller.value = const TextEditingValue(text: 'query', selection: TextSelection.collapsed(offset: 5), composing: TextRange(start: 0, end: 5));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, 0);
    expect(submitted, 0);
    expect(controller.value.composing, const TextRange(start: 0, end: 5));
    expect(tester.takeException(), isNull);
  });
  testWidgets('opening another menu dismisses suggestions without stealing its focus back', (tester) async {
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await setup(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FrostSearchInput(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            suggestions: [
              FrostSearchSuggestionGroup(
                items: [FrostSearchSuggestion(label: 'Term', onSelected: () {})],
              ),
            ],
          ),
          const SizedBox(height: 200),
          FrostToolbarMenuButton(
            label: 'Menu',
            entries: [FrostMenuAction('Action', onSelected: () {})],
          ),
        ],
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(row('Term'), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(row('Term'), findsNothing);
    expect(find.text('Action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mouse deletes another item while keyboard highlight and input announcement remain aligned', (tester) async {
    final controller = TextEditingController(text: 'query'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final items = <FrostSearchSuggestion>[];
    StateSetter? update;
    for (final label in ['A', 'B', 'C']) {
      late FrostSearchSuggestion item;
      item = FrostSearchSuggestion(label: label, onSelected: () {}, onRemove: () => update!(() => items.remove(item)));
      items.add(item);
    }
    await setup(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return FrostSearchInput(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            suggestions: [FrostSearchSuggestionGroup(items: List.of(items))],
          );
        },
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.descendant(of: row('C'), matching: find.byType(FrostButton))));
    await tester.pump();
    await tester.tap(
      find.descendant(of: row('C'), matching: find.byType(FrostButton)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.byType(EditableText)).getSemanticsData().hint, 'A 1 / 2');
    semantics.dispose();
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact suggestions remain anchored, lazy and within keyboard viewport; active item is announced by input', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final semantics = tester.ensureSemantics();

    await setup(
      tester,
      FrostSearchInput(
        controller: controller,
        focusNode: focus,
        placeholder: 'Search',
        onSubmitted: (_) {},
        suggestions: [
          FrostSearchSuggestionGroup(
            title: 'Suggestions',
            items: [for (var i = 0; i < 900; i++) FrostSearchSuggestion(label: 'Suggestion $i', onSelected: () {})],
          ),
        ],
      ),
      width: 390,
      keyboard: 260,
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byType(FrostListRow).evaluate().length, lessThan(30));
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    expect(panel.height, lessThanOrEqualTo(170));
    expect(panel.bottom, lessThanOrEqualTo(340));
    expect(panel.width, 390);
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final editable = tester.getSemantics(find.byType(EditableText));
    expect(editable.getSemanticsData().hint, contains('Suggestion 0'));
    expect(editable.getSemanticsData().hint, contains('1 / 900'));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
