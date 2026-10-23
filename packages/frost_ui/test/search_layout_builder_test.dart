import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';

void main() {
  final suggestions = [
    FrostSearchSuggestionGroup(
      items: [
        FrostSearchSuggestion(label: 'First', onSelected: () {}),
        FrostSearchSuggestion(label: 'Last', onSelected: () {}),
      ],
    ),
  ];

  void viewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  testWidgets('page builder supplies a finite body list below the only 48 header and keyboard inset', (tester) async {
    viewport(tester);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47),
            viewPadding: EdgeInsets.only(top: 47),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: FrostSearchInput(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            suggestions: suggestions,
            layoutBuilder: (context, field, list) => FrostPinnedChrome(
              chrome: FrostPageHeader(middle: field),
              body: Builder(
                builder: (context) => Padding(
                  padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: MediaQuery.viewInsetsOf(context).bottom),
                  child: list ?? const Text('Unfocused content'),
                ),
              ),
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    expect(find.text('Unfocused content'), findsOneWidget);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byType(FrostPageHeader), findsOneWidget);
    expect(tester.getSize(find.byType(FrostPageHeader)).height, 48);
    expect(tester.getTopLeft(find.byType(FrostPageHeader)).dy, 47);
    expect(find.byType(FrostPopoverSurface), findsNothing);
    final list = tester.getRect(find.byWidgetPredicate((w) => w is FrostList));
    expect(list.top, 95);
    expect(list.bottom, lessThanOrEqualTo(544));
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page and overlay switches retain the same EditableText State, selection, composing and focus', (tester) async {
    viewport(tester);
    final controller = FrostTokenEditingController(text: 'sky cloud'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var inline = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topCenter,
              child: FrostSearchInput(
                controller: controller,
                focusNode: focus,
                placeholder: 'Search',
                onSubmitted: (_) {},
                suggestions: suggestions,
                layoutBuilder: inline
                    ? (context, field, list) => Column(
                        children: [
                          SizedBox(height: 48, child: field),
                          Expanded(child: list ?? const SizedBox()),
                        ],
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    controller.value = const TextEditingValue(text: 'sky cloud', selection: TextSelection.collapsed(offset: 5), composing: TextRange(start: 4, end: 9));
    await tester.pump();
    final editing = controller.value;
    final original = tester.state(find.byType(EditableText));
    for (final target in [true, false, true]) {
      update(() => inline = target);
      await tester.pump();
      expect(tester.state(find.byType(EditableText)), same(original));
      expect(controller.value, editing);
      expect(focus.hasFocus, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(FrostPopoverSurface), target ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('composed search anchors to its field inside an offset nested Navigator', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Row(
          children: [
            const SizedBox(width: 220),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => FrostSearchInput(
                    controller: controller,
                    focusNode: focus,
                    placeholder: 'Search',
                    onSubmitted: (_) {},
                    suggestions: suggestions,
                    layoutBuilder: (context, field, list) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 20),
                          child: SizedBox(width: 400, child: field),
                        ),
                        const Expanded(child: SizedBox.expand()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(FrostTextField));
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    expect(field.left, 244);
    expect(panel.left, field.left);
    expect(panel.width, field.width);
    expect(panel.top, greaterThanOrEqualTo(field.bottom));
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty page suggestions are null even for loading and message; no placeholder is injected', (tester) async {
    viewport(tester);
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Widget? supplied;
    await tester.pumpWidget(
      frostTestApp(
        FrostSearchInput(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: (_) {},
          loading: true,
          message: 'Status',
          layoutBuilder: (context, field, list) {
            supplied = list;
            return Column(
              children: [
                field,
                if (list != null) Expanded(child: list) else const Text('Normal page'),
              ],
            );
          },
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(supplied, isNull);
    expect(find.text('Normal page'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('body list keeps Enter, Escape, separate Down reopen, announcements and input focus', (tester) async {
    viewport(tester);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        FrostSearchInput(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: calls.add,
          suggestions: [
            FrostSearchSuggestionGroup(
              items: [
                FrostSearchSuggestion(label: 'First', onSelected: () => calls.add('First')),
                FrostSearchSuggestion(label: 'Last', onSelected: () => calls.add('Last')),
              ],
            ),
          ],
          layoutBuilder: (context, field, list) => Column(
            children: [
              field,
              if (list != null) Expanded(child: list),
            ],
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, ['raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(semantics.getSemanticsData().hint, contains('Last 2 / 2'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['raw', 'Last']);
    expect(find.byWidgetPredicate((w) => w is FrostList), findsNothing);
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, ['raw', 'Last', 'raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is FrostList), findsNothing);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
