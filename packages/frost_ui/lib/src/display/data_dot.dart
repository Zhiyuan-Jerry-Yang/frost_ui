import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/tokens.dart';

// Tags and search suggestions share categorical dot geometry and transitions.
const frostDataDotSize = 6.0;
const frostDataDotGap = 6.0;

/// A categorical marker shared by tags, suggestions and application lists.
/// The adjacent label supplies its meaning and semantics. The index wraps
/// through the active theme categorical palette; color changes animate in place.
class FrostDataDot extends StatelessWidget {
  const FrostDataDot(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return FrostSkeletonShape(
      shape: const CircleBorder(),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: tokens.categorical[index % tokens.categorical.length]),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        builder: (_, color, _) => Container(
          width: frostDataDotSize,
          height: frostDataDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
