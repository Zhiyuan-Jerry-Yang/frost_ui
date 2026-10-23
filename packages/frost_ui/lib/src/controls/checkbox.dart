import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../motion/_user_selection_draw.dart';
import '_choice_mark.dart';
import '_input_surface.dart';

// Standalone marks dim once; row variants delegate dimming to the shared row.
const _disabledOpacity = .38;

/// A checkbox with a density-sized hit area. A null [semanticLabel] delegates
/// semantics to an enclosing row without creating a second checked node.
class FrostCheckbox extends StatelessWidget {
  const FrostCheckbox({required this.value, required this.onChanged, this.tristate = false, required this.semanticLabel, super.key})
    : assert(tristate || value != null);
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && FrostControlScope.enabledOf(context);
    return FrostUserSelectionDraw(
      selected: value,
      onActivate: enabled ? () => onChanged?.call(frostNextCheckboxValue(value, tristate)) : null,
      builder: (context, trigger, activate) {
        final control = FrostInputSurface(
          onTap: enabled ? activate : null,
          builder: (context, states) => AnimatedOpacity(
            opacity: enabled ? 1 : _disabledOpacity,
            duration: FrostMotion.duration(context, FrostMotion.hover),
            child: SizedBox.square(
              dimension: FrostDensity.of(context).targetHeight,
              child: Center(
                child: FrostChoiceMark(value: value, states: states, drawTrigger: trigger),
              ),
            ),
          ),
        );
        return semanticLabel == null
            ? ExcludeSemantics(child: control)
            : Semantics(
                label: semanticLabel,
                checked: value == true,
                mixed: tristate ? value == null : null,
                enabled: enabled,
                onTap: enabled ? activate : null,
                excludeSemantics: true,
                child: control,
              );
      },
    );
  }
}
