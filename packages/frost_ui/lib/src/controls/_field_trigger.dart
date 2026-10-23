import 'package:flutter/widgets.dart';

import '../foundation/_control_dimming.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '_button_control.dart';
import '_button_types.dart';
import '_field_layout.dart';
import '_field_options.dart';

/// The content-field trigger shared by value, date and range selectors.
class FrostFieldTrigger extends StatelessWidget {
  const FrostFieldTrigger({
    required this.label,
    required this.value,
    required this.onPressed,
    required this.focus,
    this.size,
    this.help,
    this.error,
    this.leading,
    this.trailing,
    this.chevron = FrostButtonChevron.none,
    super.key,
  });
  final String label, value;
  final VoidCallback? onPressed;
  final FocusNode focus;
  final FrostControlSize? size;
  final String? help, error;
  final FrostIconData? leading;
  final Widget? trailing;
  final FrostButtonChevron chevron;
  @override
  Widget build(BuildContext context) {
    final selectedSize = size ?? FrostControlScope.sizeOf(context);
    final geometry = frostControlGeometry(context, selectedSize), enabled = onPressed != null && FrostControlScope.enabledOf(context);
    return FrostFieldOptions(
      invalid: error != null,
      child: FrostFieldLayout(
        label: label,
        help: help,
        error: error,
        enabled: enabled,
        child: FrostButtonControl(
          label: value,
          icon: leading,
          focusNode: focus,
          onPressed: enabled ? onPressed : null,
          size: selectedSize,
          variant: FrostButtonVariant.standard,
          textRole: FrostTextRole.body,
          presentation: FrostButtonPresentation.field,
          chevron: chevron,
          geometry: FrostButtonGeometry(
            horizontalInset: frostFieldInset(selectedSize),
            verticalInset: geometry.verticalInset,
            minimumWidth: 0,
            alignment: MainAxisAlignment.start,
            visualHeight: geometry.height,
          ),
          truncates: false,
          wrapsLabel: true,
          trailing: trailing == null ? null : FrostControlDimming(disabled: !enabled, child: trailing!),
        ),
      ),
    );
  }
}
