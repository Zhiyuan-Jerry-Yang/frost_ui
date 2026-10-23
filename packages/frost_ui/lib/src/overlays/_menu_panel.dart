import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/_menu_metrics.dart';
import '../foundation/radius.dart';
import '../primitives/surface.dart';

/// One material, corner and scrolling path for every kind of menu panel.
class FrostMenuPanel extends StatelessWidget {
  const FrostMenuPanel({required this.children, this.triggerWidth, super.key});
  final List<Widget> children;
  final double? triggerWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Value menus match their trigger and may grow beyond the ordinary cap.
      // Both kinds yield to the overlay's available viewport width.
      final maximum = triggerWidth == null ? math.min(FrostMenuMetrics.maximumWidth, constraints.maxWidth) : constraints.maxWidth;
      final minimum = math.min(math.max(FrostMenuMetrics.minimumWidth, triggerWidth ?? 0), maximum);
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minimum, maxWidth: maximum),
        child: FrostSurface(
          role: FrostSurfaceRole.overlay,
          borderRadius: BorderRadius.circular(FrostRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(FrostMenuMetrics.panelInset),
            child: SingleChildScrollView(
              // An overlay owns its scrolling instead of joining the page's
              // PrimaryScrollController (RefreshView supplies one on all OSes).
              primary: false,
              child: IntrinsicWidth(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      );
    },
  );
}
