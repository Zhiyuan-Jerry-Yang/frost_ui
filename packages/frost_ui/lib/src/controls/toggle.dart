import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../lists/list_row.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/icon.dart';
import '_button_control.dart';
import '_button_types.dart';
import 'checkbox_row.dart';

/// switchRow spells the switch style without using Dart's reserved keyword.
enum FrostToggleStyle { switchRow, checkbox, button }

/// One boolean value with row, checkbox or selected icon-button presentation.
class FrostToggle extends StatelessWidget {
  const FrostToggle({
    required this.value,
    required this.onChanged,
    required this.label,
    this.style = FrostToggleStyle.switchRow,
    this.subtitle,
    this.icon,
    this.selectedIcon,
    super.key,
  }) : assert(style != FrostToggleStyle.button || icon != null),
       assert(style != FrostToggleStyle.button || subtitle == null);
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final FrostToggleStyle style;
  final String? subtitle;
  final FrostIconData? icon, selectedIcon;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && FrostControlScope.enabledOf(context);
    return switch (style) {
      FrostToggleStyle.switchRow => FrostListRow.toggle(title: label, subtitle: subtitle, icon: icon, value: value, onChanged: enabled ? onChanged : null),
      FrostToggleStyle.checkbox => FrostCheckboxRow(title: label, subtitle: subtitle, value: value, onChanged: enabled ? (next) => onChanged!(next!) : null),
      FrostToggleStyle.button => FrostButtonControl(
        label: label,
        onPressed: enabled ? () => onChanged!(!value) : null,
        icon: icon,
        iconStyle: FrostIconButtonStyle.plain,
        selected: value,
        iconWidget: FrostLayoutCrossfade(
          settleDuration: Duration.zero,
          layoutIdentity: value ? selectedIcon ?? icon! : icon!,
          child: FrostIcon(value ? selectedIcon ?? icon! : icon!),
        ),
      ),
    };
  }
}
