import 'package:flutter/widgets.dart';

import '../display/_avatar_size.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';

// Avatars overlap by a quarter of their diameter, with an outside surface ring.
const _overlapFraction = .25;
const _separatorWidth = 2.0;
// Outside rings contribute on both sides of the group bounds.
const _separatorExtent = _separatorWidth * 2;

class FrostAvatarStack extends StatelessWidget {
  const FrostAvatarStack({required this.avatars, this.max = 3, this.label, this.size = FrostAvatarSize.small, required this.semanticLabel, super.key})
    : assert(max > 0);
  final List<Widget> avatars;
  final int max;
  final String? label;
  final FrostAvatarSize size;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) {
    final diameter = frostAvatarDimension(size), step = diameter * (1 - _overlapFraction);
    final visible = avatars.take(max).toList(), remaining = avatars.length - visible.length;
    final tokens = FrostThemeTokens.of(context);
    final surface = FrostSurfaceScope.maybeOf(context)?.background ?? tokens.canvas;
    final children = <Widget>[
      ...visible,
      if (remaining > 0)
        DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.fillSubtle),
          child: Transform.translate(
            // Centre the count in the exposed part, away from the preceding avatar.
            offset: Offset(diameter * _overlapFraction / 2 * (Directionality.of(context) == TextDirection.rtl ? -1 : 1), 0),
            child: Center(
              child: SizedBox(
                width: diameter * frostAvatarInscribedScale - diameter * _overlapFraction,
                height: diameter * frostAvatarInscribedScale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: FrostText('+$remaining', role: FrostTextRole.caption, tone: FrostTextTone.primary, numeric: true),
                ),
              ),
            ),
          ),
        ),
    ];
    final groupWidth = diameter + step * (children.length - 1) + _separatorExtent;
    final description = [semanticLabel, ?label, if (remaining > 0) '+$remaining'].join(' ');
    return Semantics(
      label: description,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (children.isNotEmpty)
            FrostAvatarSizeScope(
              size: size,
              child: SizedBox(
                width: groupWidth,
                height: diameter + _separatorExtent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = children.length - 1; index >= 0; index--)
                      PositionedDirectional(
                        start: _separatorWidth + step * index,
                        top: _separatorWidth,
                        width: diameter,
                        height: diameter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Seal translucent fills so earlier avatars cover later ones.
                            color: surface,
                            border: Border.all(color: surface, width: _separatorWidth, strokeAlign: BorderSide.strokeAlignOutside),
                          ),
                          child: ClipOval(clipBehavior: Clip.antiAlias, child: children[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (label != null) ...[
            if (children.isNotEmpty) const SizedBox(width: FrostGap.related),
            Flexible(
              child: FrostText(label!, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
            ),
          ],
        ],
      ),
    );
  }
}
