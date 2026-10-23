import 'package:flutter/material.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/icon_data.dart';
import '../foundation/radius.dart';

// Keep the public icon entry point stable while configuration stays below paint.
export '../foundation/icon_data.dart' show FrostIconData, FrostGlyphIcon, FrostIconSet;

/// Draws a [FrostIconData] at the [IconTheme] size and colour unless given.
/// Pair decorative icons with a labelled control; give [semanticLabel] only
/// when the icon itself conveys information outside a labelled control.
class FrostIcon extends StatelessWidget {
  const FrostIcon(this.icon, {this.size, this.color, this.semanticLabel, super.key});

  final FrostIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 20;
    final resolvedColor = color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return FrostSkeletonShape(
      shape: FrostRadius.shape(context, FrostRadius.xs),
      child: switch (icon) {
        FrostGlyphIcon(:final data) => Icon(data, size: resolvedSize, color: resolvedColor, semanticLabel: semanticLabel),
      },
    );
  }
}
