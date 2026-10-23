import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/skeleton_style.dart';
import '../foundation/tokens.dart';
import '../motion/layout_crossfade.dart';
import '_skeleton_geometry.dart';

/// Shared token-based effect for component skeletons and app-owned layouts.
PaintingEffect frostSkeletonEffect(BuildContext context) {
  final tokens = FrostThemeTokens.of(context);
  final style = FrostScope.configOf(context).skeleton ?? const FrostSkeletonStyle();
  assert(style.period > Duration.zero, 'FrostSkeletonStyle.period must be positive.');
  final color = style.color?.call(tokens) ?? tokens.fill;
  final highlight = style.highlightColor?.call(tokens) ?? tokens.fillStrong;
  if (MediaQuery.disableAnimationsOf(context) || style.effect == FrostSkeletonEffect.solid) return SolidColorEffect(color: color);
  return switch (style.effect) {
    FrostSkeletonEffect.pulse => PulseEffect(from: color, to: highlight, duration: style.period),
    FrostSkeletonEffect.shimmer => ShimmerEffect(
      baseColor: color,
      highlightColor: highlight,
      duration: style.period,
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
    ),
    FrostSkeletonEffect.solid => SolidColorEffect(color: color),
  };
}

SkeletonizerConfigData frostSkeletonConfig(BuildContext context) => SkeletonizerConfigData(
  brightness: Theme.of(context).brightness,
  effectResolver: (_) => frostSkeletonEffect(context),
  textBorderRadius: TextBoneBorderRadius(BorderRadius.circular(FrostScope.configOf(context).skeleton?.textRadius ?? FrostRadius.xs)),
);

extension FrostSkeletonX on Widget {
  /// Paints this real layout as bones immediately. Switching retains child
  /// state and crossfades pixels without keeping a second interactive subtree.
  /// Use FrostText / FrostText.rich for configurable text geometry. Native
  /// Text in an app-owned subtree keeps skeletonizer's default geometry and
  /// does not guarantee the Frost bone spacing rules. Custom canvas content
  /// must supply its own explicit shape. Adjacent inline parts need at least
  /// FrostGap.inline in the real layout.
  Widget frostSkeleton(bool loading) => _ComponentSkeleton(loading: loading, child: this);
}

class _ComponentSkeleton extends StatefulWidget {
  const _ComponentSkeleton({required this.loading, required this.child});
  final bool loading;
  final Widget child;
  @override
  State<_ComponentSkeleton> createState() => _ComponentSkeletonState();
}

class _ComponentSkeletonState extends State<_ComponentSkeleton> {
  // Skeletonizer changes its render wrapper when disabled. This anchor keeps
  // even unkeyed application state alive across that reparenting.
  final _content = GlobalKey();
  @override
  Widget build(BuildContext context) => Semantics(
    container: widget.loading,
    label: widget.loading ? FrostScope.labelsOf(context).loading : null,
    excludeSemantics: widget.loading,
    child: ExcludeFocus(
      excluding: widget.loading,
      child: FrostLayoutCrossfade(
        layoutIdentity: widget.loading,
        duration: FrostMotion.reveal,
        settleDuration: Duration.zero,
        child: Skeletonizer(
          enabled: widget.loading,
          enableSwitchAnimation: false,
          effect: frostSkeletonEffect(context),
          textBoneBorderRadius: TextBoneBorderRadius(BorderRadius.circular(FrostScope.configOf(context).skeleton?.textRadius ?? FrostRadius.xs)),
          child: KeyedSubtree(key: _content, child: widget.child),
        ),
      ),
    ),
  );
}

/// Internal annotation for whole media placeholders, preserving their clips.
class FrostSkeletonLeaf extends StatelessWidget {
  const FrostSkeletonLeaf({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => FrostSkeletonShape(shape: const RoundedRectangleBorder(), child: child);
}
