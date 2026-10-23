import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../motion/layout_crossfade.dart';

/// A phase has one live tree. The previous painted frame fades away without
/// retaining scroll positions, provider leases, GlobalKeys or input targets.
/// This also makes an interrupted return to a phase safe in nested tab views.
class FrostLoadStateSwitcher extends StatelessWidget {
  const FrostLoadStateSwitcher({required this.child, this.phase, this.animateSize = false, super.key});
  final Object? phase;
  final Widget child;
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    final duration = FrostMotion.duration(context, FrostMotion.reveal);
    final switcher = FrostLayoutCrossfade(
      layoutIdentity: phase ?? (child.runtimeType, child.key),
      duration: duration,
      settleDuration: Duration.zero,
      child: child,
    );
    return animateSize ? FrostMotionSize(duration: duration, curve: Curves.easeInOutCubic, alignment: Alignment.topCenter, child: switcher) : switcher;
  }
}
