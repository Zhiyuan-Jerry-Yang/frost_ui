import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../lists/list_row.dart';
import '../motion/_user_selection_draw.dart';
import '_choice_mark.dart';

/// An entire list row toggles one checkbox and exposes one checked/mixed node.
class FrostCheckboxRow extends StatelessWidget {
  const FrostCheckboxRow({required this.title, this.subtitle, required this.value, required this.onChanged, this.tristate = false, super.key})
    : assert(tristate || value != null);
  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && FrostControlScope.enabledOf(context);
    return FrostUserSelectionDraw(
      selected: value,
      onActivate: enabled ? () => onChanged?.call(frostNextCheckboxValue(value, tristate)) : null,
      builder: (context, trigger, activate) => Semantics(
        label: title,
        value: subtitle,
        checked: value == true,
        mixed: tristate ? value == null : null,
        enabled: enabled,
        onTap: enabled ? activate : null,
        excludeSemantics: true,
        child: FrostListRow(
          title: title,
          subtitle: subtitle,
          leading: FrostChoiceMark(value: value, drawTrigger: trigger),
          enabled: enabled,
          onPressed: enabled ? activate : null,
        ),
      ),
    );
  }
}
