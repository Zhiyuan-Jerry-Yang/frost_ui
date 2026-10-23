// Internal transition file for ChoiceToggle (phase 4) and Select (phase 6).
// Delete this file after both consumers have migrated.
import 'package:flutter/material.dart';

import '../foundation/radius.dart';
import '../foundation/scope.dart';

/// A filled surface with a separate inside edge; merged in phase 2.
class FrostRoundedSurface extends StatelessWidget {
  const FrostRoundedSurface({
    super.key,
    required this.color,
    required this.borderColor,
    required this.child,
    this.radius = FrostRadius.sm,
    this.borderWidth = 1,
  });
  final Color color;
  final Color borderColor;
  final Widget child;
  final double radius;
  final double borderWidth;
  @override
  Widget build(BuildContext context) {
    final shape = FrostRadius.shape(context, radius) as OutlinedBorder;
    final content = Material(type: MaterialType.transparency, child: child);
    final corners = FrostRadius.borderRadius(radius);
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: shape),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape.copyWith(
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
        ),
        position: DecorationPosition.foreground,
        child: FrostScope.configOf(context).continuousCorners
            ? ClipRSuperellipse(borderRadius: corners, clipBehavior: Clip.antiAlias, child: content)
            : ClipRRect(borderRadius: corners, clipBehavior: Clip.antiAlias, child: content),
      ),
    );
  }
}
