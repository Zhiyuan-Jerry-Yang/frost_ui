import 'package:flutter/material.dart';

import '_layout_scope.dart';
import 'density.dart';
import 'metrics.dart';

/// Named spacing scale. Static values serve const/default arguments; of
/// resolves window layout and density-dependent values for a widget tree.
abstract final class FrostGap {
  static const inline = 4.0;
  static const related = 8.0;
  static const group = 12.0;
  static const section = 24.0;
  static const rowInset = 16.0;
  static const hitInset = 8.0;
  static const panelInset = 16.0;
  static const grid = 8.0;

  static ({double inline, double related, double group, double section, double rowInset, double hitInset, double panelInset, double page, double grid}) of(
    BuildContext context,
  ) {
    final wide = FrostAdaptiveLayoutData.horizontalOf(context);
    final shrink = FrostDensity.of(context).name == FrostDensity.compact.name ? inline : 0.0;
    return (
      inline: inline,
      related: related,
      group: group - shrink,
      section: wide ? 32 : section,
      rowInset: rowInset - shrink,
      hitInset: wide ? 12 : hitInset,
      panelInset: (wide ? 20.0 : panelInset) - shrink,
      page: FrostMetrics.browseInset(MediaQuery.sizeOf(context).width),
      grid: grid,
    );
  }
}
