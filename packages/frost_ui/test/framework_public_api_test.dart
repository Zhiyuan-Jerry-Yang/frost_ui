import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart' as frost;

// The prefix prevents flutter_test or another import from masking a missing
// barrel export. This fixture imports no Material/Cupertino library or helper.
frost.ThemeData _buildTheme(frost.FrostConfig config) =>
    frost.FrostTheme.build(config: config, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en'));

void main() {
  test('appearance modes are available through the Frost barrel', () {
    const appearance = frost.FrostAppearance(mode: frost.ThemeMode.dark, lightAccent: Color(0xff007aff), darkAccent: Color(0xff0a84ff));
    expect(appearance.mode, frost.ThemeMode.dark);
    expect(appearance.copyWith(mode: frost.ThemeMode.light).mode, frost.ThemeMode.light);
    expect(appearance.copyWith(mode: frost.ThemeMode.system).mode, frost.ThemeMode.system);
  });

  test('public theme and feedback signatures require no Material import', () {
    final palettes = frost.FrostPalettes.pink;
    final tokens = palettes.palette(Brightness.light, frost.FrostTone.neutral, palettes.defaultAccent(Brightness.light));
    final frost.ButtonStyle feedback = frost.frostFeedbackStyle(tokens);
    final frost.ButtonStyle secondary = frost.frostSecondaryButtonStyle(tokens);
    const frost.ThemeExtension<frost.FrostDensity> density = frost.FrostDensity.compact;
    final frost.ThemeData theme = frost.ThemeData(extensions: [density]);
    expect(feedback.side, isNotNull);
    expect(secondary.backgroundColor, isNotNull);
    expect(theme.extension<frost.FrostDensity>(), same(density));
    expect(density.lerp(frost.FrostDensity.comfortable, 1), frost.FrostDensity.comfortable);
    expect(_buildTheme, isA<frost.ThemeData Function(frost.FrostConfig)>());
  });

  test('refresh and editable input signatures require no Material import', () async {
    var refreshes = 0;
    Future<void> refresh() async {
      refreshes++;
    }

    final frost.RefreshCallback callback = refresh;
    final indicator = frost.FrostDotsRefreshIndicator(onRefresh: callback, child: const SizedBox());
    const field = frost.FrostTextField(textInputAction: frost.TextInputAction.search);
    await indicator.onRefresh();
    expect(refreshes, 1);
    expect(field.textInputAction, frost.TextInputAction.search);
  });

  test('existing Material and keyboard exports remain directly usable', () {
    const time = frost.TimeOfDay(hour: 14, minute: 15);
    final range = frost.DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 17));
    const shortcut = frost.FrostShortcut(frost.LogicalKeyboardKey.keyC, primary: true);
    final tabs = frost.TabController(length: 2, vsync: const TestVSync());
    final widgets = <Widget>[
      frost.FrostTimePicker(value: time, onChanged: (_) {}, label: 'Time'),
      frost.FrostDateRangePicker(value: range, onChanged: (_) {}, label: 'Range'),
      frost.DefaultTabController(
        length: 2,
        child: frost.TabBarView(controller: tabs, children: const [SizedBox(), SizedBox()]),
      ),
      frost.FrostShortcuts(bindings: {shortcut: () {}}, child: const SizedBox()),
    ];
    expect(widgets, hasLength(4));
    tabs.dispose();
  });
}
