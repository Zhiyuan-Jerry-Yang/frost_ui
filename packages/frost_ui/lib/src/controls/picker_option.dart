import 'package:flutter/widgets.dart';

import '../foundation/icon_data.dart';

/// One value option across menus, segments, inline rows and color palettes.
/// color is palette data; other styles deliberately ignore it.
@immutable
class FrostPickerOption<T> {
  const FrostPickerOption({required this.value, required this.label, this.icon, this.subtitle, this.enabled = true, this.color});
  final T value;
  final String label;
  final FrostIconData? icon;
  final String? subtitle;
  final bool enabled;
  final Color? color;
}
