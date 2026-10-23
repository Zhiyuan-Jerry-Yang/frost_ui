import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/_menu_metrics.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/typography.dart';
import 'menu_anchor.dart';

/// Internal input mechanism; callers describe menu entries instead of styles.
class FrostMenuItem extends StatelessWidget {
  const FrostMenuItem({
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.closeOnActivate = true,
    this.onHover,
    super.key,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus, closeOnActivate;
  final ValueChanged<bool>? onHover;
  @override
  Widget build(BuildContext context) {
    final close = context.getInheritedWidgetOfExactType<FrostMenuScope>()?.close;
    final geometry = frostControlGeometry(context, FrostMenuMetrics.sizeOf(context), role: FrostTextRole.callout);
    final radius = math.min(FrostRadius.inner(FrostRadius.lg, FrostMenuMetrics.panelInset), FrostRadius.forHeight(geometry.height));
    // MenuItemButton closes RawMenuAnchor children when another root item loses
    // focus. TextButton keeps the same style/input mechanism without that policy.
    return TextButton(
      focusNode: focusNode,
      autofocus: autofocus,
      onHover: onHover,
      onPressed: onPressed == null
          ? null
          : () {
              if (closeOnActivate) close?.call();
              onPressed!();
            },
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, geometry.height)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: FrostMenuMetrics.rowInset, vertical: geometry.verticalInset)),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(FrostRadius.shape(context, radius) as OutlinedBorder),
      ).merge(MenuButtonTheme.of(context).style),
      child: AnimatedOpacity(opacity: onPressed == null ? .38 : 1, duration: FrostMotion.duration(context, FrostMotion.hover), child: child),
    );
  }
}
