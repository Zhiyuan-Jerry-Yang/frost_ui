import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../controls/_toolbar_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../overlays/menu_anchor.dart';
import '../overlays/menu_entry.dart';
import '../primitives/keyline.dart';

class FrostToolbarMenuButton extends StatelessWidget {
  /// Icon-only menus retain [label] for accessibility and tooltips and use
  /// the same geometry as toolbar action icons.
  const FrostToolbarMenuButton({required this.label, required this.entries, this.icon, this.tooltip, this.valueLabel, this.showsLabel = true, super.key})
    : assert(showsLabel || icon != null);
  final String label;
  final List<FrostMenuEntry> entries;
  final FrostIconData? icon;
  final String? tooltip;

  /// Current value of a named selector; the trigger shows this value while
  /// accessibility retains both the purpose and the current selection.
  final String? valueLabel;
  final bool showsLabel;

  String get _semanticLabel => valueLabel == null ? label : [label, valueLabel].join(', ');

  @override
  Widget build(BuildContext context) => FrostMenuAnchor(
    entries: entries,
    builder: (context, focus, toggle) => FrostToolbarControl(
      label: valueLabel ?? label,
      semanticLabel: _semanticLabel,
      icon: icon,
      showsLabel: showsLabel,
      chevron: showsLabel,
      focusNode: focus,
      onPressed: entries.isEmpty ? null : toggle,
      tooltip: tooltip ?? (valueLabel != null || FrostToolbarLeadingScope.of(context) ? _semanticLabel : null),
      truncates: showsLabel && FrostToolbarLeadingScope.of(context),
    ),
  );
}

class FrostTitleMenu extends StatelessWidget {
  const FrostTitleMenu({required this.title, required this.entries, super.key});
  final String title;
  final List<FrostMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final trigger = FrostMenuAnchor(
      entries: entries,
      builder: (context, focus, toggle) => FrostToolbarControl(
        label: title,
        role: FrostTextRole.headline,
        tooltip: title,
        chevron: true,
        focusNode: focus,
        onPressed: entries.isEmpty ? null : toggle,
        truncates: true,
      ),
    );
    if (FrostControlScope.toolbarOf(context)) return trigger;
    final inset = FrostGap.of(context).hitInset;
    return IntrinsicWidth(
      child: FrostBleed(
        amount: inset,
        child: Builder(
          builder: (context) {
            final snap = FrostBleed.snappedOf(context);
            final keyline = FrostKeyline.maybeOf(context);
            return Padding(
              padding: EdgeInsetsDirectional.only(
                start: snap.start ? math.max(0.0, (keyline?.edgeDistanceStart ?? 0) - inset) : 0,
                end: snap.end ? math.max(0.0, (keyline?.edgeDistanceEnd ?? 0) - inset) : 0,
              ),
              child: trigger,
            );
          },
        ),
      ),
    );
  }
}

/// Internal compact control shared by toolbar actions and menu triggers.
/// Kept out of the package's exports.
class FrostToolbarControl extends StatelessWidget {
  const FrostToolbarControl({
    required this.label,
    required this.onPressed,
    this.icon,
    this.showsLabel = true,
    this.chevron = false,
    this.role = FrostTextRole.callout,
    this.tooltip,
    this.semanticLabel,
    this.focusNode,
    this.truncates = false,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final FrostIconData? icon;
  final bool showsLabel, chevron, truncates;
  final FrostTextRole role;
  final String? tooltip, semanticLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    // A graphic-only action is an icon button, not a short text button. Using
    // text geometry aligned the final glyph differently and left a one-sided
    // press plate inside the touch target.
    final graphicOnly = !showsLabel && icon != null && !chevron;
    return FrostButtonControl(
      iconStyle: graphicOnly ? FrostIconButtonStyle.plain : null,
      label: label,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      icon: icon,
      showsLabel: showsLabel,
      chevron: chevron ? FrostButtonChevron.down : FrostButtonChevron.none,
      variant: FrostButtonVariant.plain,
      size: FrostControlSize.compact,
      textRole: role,
      tooltip: tooltip,
      focusNode: focusNode,
      truncates: truncates,
      geometry: graphicOnly ? null : frostToolbarButtonGeometry(context),
    );
  }
}
