import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('6C value types and all four fields need no Material import', () {
    const time = TimeOfDay(hour: 14, minute: 15);
    final range = DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 16));
    final widgets = <Widget>[
      FrostDateRangePicker(value: range, onChanged: (_) {}, label: 'Range'),
      FrostTimePicker(value: time, onChanged: (_) {}, label: 'Time', minuteStep: 15),
      FrostDatePicker(value: range.start, onChanged: (_) {}, label: 'Date', clearable: true),
      FrostPathField(
        path: 'V:/Downloads',
        label: 'Directory',
        placeholder: 'Choose a directory',
        help: 'Help',
        error: 'Error',
        onChoose: () async {},
        onReveal: () {},
      ),
    ];
    expect(time.hour, 14);
    expect(range.start, DateTime(2026, 10, 1));
    expect(widgets, hasLength(4));
  });
}
