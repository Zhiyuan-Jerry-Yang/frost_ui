import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('new input APIs require only widgets.dart', () {
    final widgets = <Widget>[
      FrostCheckbox(value: false, onChanged: (_) {}, semanticLabel: 'Checkbox'),
      FrostCheckboxRow(title: 'Row', value: null, tristate: true, onChanged: (_) {}),
      FrostPicker<int>.inline(
        options: const [FrostPickerOption(value: 1, label: 'One')],
        value: 1,
        onChanged: (_) {},
        label: 'Choice',
      ),
      FrostStepper(value: 1, onChanged: (_) {}, semanticLabel: 'Stepper'),
      FrostNumberField(value: 1, onChanged: (_) {}),
      FrostSlider(value: .5, onChanged: (_) {}, semanticLabel: 'Slider'),
      const FrostTextArea(showsCount: true),
      const FrostTextField.secure(),
      FrostEmptyState.search(query: 'Query', onClear: () {}),
    ];
    expect(widgets, hasLength(9));
  });
  test('6B semantic and form APIs compile with widgets.dart alone', () {
    const option = FrostPickerOption(value: 1, label: 'One', subtitle: 'Detail', enabled: false, color: Color(0xffabcdef));
    final controller = FrostFormController();
    final widgets = <Widget>[
      const FrostPicker(options: [option], value: null, onChanged: null, label: 'Auto', size: FrostControlSize.compact, error: 'Error'),
      const FrostPicker.menu(options: [option], value: 1, onChanged: null, label: 'Menu', error: 'Error'),
      const FrostPicker.segmented(options: [option], value: 1, onChanged: null, label: 'Segments', iconOnly: false, error: 'Error'),
      const FrostPicker.inline(options: [option], value: 1, onChanged: null, label: 'Inline', error: 'Error'),
      const FrostPicker.palette(options: [option], value: 1, onChanged: null, label: 'Palette', error: 'Error'),
      const FrostToggle(value: false, onChanged: null, label: 'Switch'),
      const FrostToggle(value: false, onChanged: null, label: 'Checkbox', style: FrostToggleStyle.checkbox),
      const FrostToggle(value: false, onChanged: null, label: 'Button', style: FrostToggleStyle.button, icon: FrostIconData.glyph(IconData(1))),
      FrostForm(
        controller: controller,
        errorSummary: 'Summary',
        onSubmit: () async => true,
        children: const [FrostFormSection(title: 'Section', children: [])],
      ),
      const FrostNumberField(value: 1, onChanged: null, error: 'Error'),
    ];
    expect(widgets, hasLength(10));
    expect(FrostPickerStyle.values, hasLength(5));
    expect(FrostToggleStyle.values, hasLength(3));
    controller.dispose();
  });
}
