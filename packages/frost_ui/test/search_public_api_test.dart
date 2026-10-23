import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('search extension compiles from widgets and frost_ui only', () {
    final controller = TextEditingController(), focus = FocusNode();
    final widget = FrostSearchInput<int>(
      controller: controller,
      focusNode: focus,
      placeholder: 'Search',
      loading: true,
      message: 'Loading matches',
      onSubmitted: (_) {},
      scopes: const [FrostPickerOption(value: 1, label: 'All')],
      scope: 1,
      onScopeChanged: (_) {},
      suggestions: [
        FrostSearchSuggestionGroup(
          title: 'Recent',
          items: [FrostSearchSuggestion(label: 'Term', icon: null, dataColor: 1, detail: 'Detail', value: '42', onSelected: () {}, onRemove: () {})],
        ),
      ],
    );
    expect(widget, isA<Widget>());
    controller.dispose();
    focus.dispose();
  });
}
