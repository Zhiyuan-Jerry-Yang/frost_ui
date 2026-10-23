import 'package:flutter/widgets.dart';

import '../foundation/radius.dart';
import '../primitives/surface.dart';

// Popover contents use a separate inset from dense menu items.
const frostPopoverContentInset = 16.0;

/// Shared material for arbitrary anchored content, including passive previews.
class FrostPopoverSurface extends StatelessWidget {
  const FrostPopoverSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => FrostSurface(
    role: FrostSurfaceRole.overlay,
    borderRadius: FrostRadius.borderRadius(FrostRadius.xl),
    child: Padding(padding: const EdgeInsets.all(frostPopoverContentInset), child: child),
  );
}
