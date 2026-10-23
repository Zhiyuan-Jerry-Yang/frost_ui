import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../feedback/skeleton.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/_media_shape.dart';
import '../primitives/icon.dart';
import '../primitives/media_frame.dart';
import '../primitives/text.dart';
import '_avatar_size.dart';

export '_avatar_size.dart' show FrostAvatarSize;

// The initials fit the square inscribed in a circle, even at larger text scales.

const _maximumInitials = 2;

const _smallIcon = 16.0, _regularIcon = 18.0, _largeIcon = 22.0, _xlargeIcon = 28.0;

/// A circular media frame with a readable placeholder.
/// [image] uses FrostMediaFrame's loading, fade and error fallback. [child]
/// owns loading and failures; the library only clips, strokes and supplies its
/// background. Both may be absent, but they cannot be provided together.
class FrostAvatar extends StatelessWidget {
  factory FrostAvatar.skeleton({required FrostAvatarSize size}) => _SkeletonAvatar(size);
  const FrostAvatar({this.image, this.child, this.initials, this.size = FrostAvatarSize.regular, required this.semanticLabel, super.key})
    : assert(image == null || child == null);
  final ImageProvider? image;
  final Widget? child;
  final String? initials;
  final FrostAvatarSize size;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final effectiveSize = FrostAvatarSizeScope.of(context) ?? size;
    final dimension = frostAvatarDimension(effectiveSize);
    final (iconSize, role) = switch (effectiveSize) {
      FrostAvatarSize.small => (_smallIcon, FrostTextRole.caption),
      FrostAvatarSize.regular => (_regularIcon, FrostTextRole.footnote),
      FrostAvatarSize.large => (_largeIcon, FrostTextRole.callout),
      FrostAvatarSize.xlarge => (_xlargeIcon, FrostTextRole.headline),
    };
    final text = initials?.characters.take(_maximumInitials).toString();
    Widget placeholder() => FrostLayoutCrossfade(
      layoutIdentity: (text, size),
      child: ColoredBox(
        color: tokens.fill,
        child: Center(
          child: text == null || text.isEmpty
              ? FrostIcon(FrostIconSet.of(context).user, size: iconSize, color: tokens.textTertiary)
              : SizedBox.square(
                  dimension: dimension * frostAvatarInscribedScale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: FrostText(text, role: role, tone: FrostTextTone.tertiary, numeric: true),
                  ),
                ),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: FrostSkeletonShape(
        shape: const CircleBorder(),
        child: SizedBox.square(
          dimension: dimension,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.fill, shape: BoxShape.circle),
            child: FrostMediaCircle(
              child: image == null
                  ? FrostMediaFrame(child: child ?? placeholder())
                  : FrostMediaFrame(image: image, placeholderBuilder: (_, _) => placeholder(), errorBuilder: (_, _) => placeholder()),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonAvatar extends FrostAvatar {
  const _SkeletonAvatar(FrostAvatarSize size) : super(size: size, semanticLabel: '');
  @override
  Widget build(BuildContext context) => FrostAvatar(
    size: size,
    semanticLabel: FrostScope.labelsOf(context).loading,
    child: FrostSkeletonLeaf(
      child: ColoredBox(color: FrostThemeTokens.of(context).fill, child: const SizedBox.expand()),
    ).frostSkeleton(true),
  );
}
