import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart' show frostButtonTextInset;
import '../controls/buttons.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/keyline.dart';

/// A section title with same-row compact actions. Content stays on its keyline;
/// the last button's content edge spends its own padding outside that line.
class FrostSectionHeader extends StatelessWidget {
  const FrostSectionHeader({required this.title, this.actionLabel, this.onAction, this.trailing = const [], super.key});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) {
    final geometry = frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.headline);
    final actions = <Widget>[
      if (onAction != null)
        FrostButton.quiet(
          edgeAlignment: FrostButtonEdgeAlignment.end,
          label: actionLabel ?? FrostScope.labelsOf(context).showAll,
          size: FrostControlSize.compact,
          onPressed: onAction,
        ),
      ...trailing,
    ];
    final last = actions.lastOrNull;
    final edge = switch (last) {
      FrostButton(:final style, :final size) when style != null =>
        (math.max((size ?? FrostControlSize.compact).height(context), FrostDensity.of(context).targetHeight) - (size ?? FrostControlSize.compact).iconSize) / 2,
      FrostButton(:final size) => frostButtonTextInset(size ?? FrostControlSize.compact),
      _ => 0.0,
    };
    Widget contents(BuildContext context) {
      final granted = frostBleedOutsetsOf(context).resolve(Directionality.of(context));
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final start = rtl ? granted.right : granted.left;
      final end = rtl ? granted.left : granted.right;
      return Padding(
        padding: EdgeInsetsDirectional.only(start: start, end: math.max(0, end - edge)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: geometry.height),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
                  child: FrostSkeletonText(
                    child: Text(
                      title,
                      style: FrostTypography.of(context).style(FrostTextRole.headline).copyWith(color: FrostThemeTokens.of(context).textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: FrostGap.related),
                // The header spends the edge budget once; plain text buttons must
                // not spend it again from inside the trailing structural group.
                FrostKeyline(
                  leadingRoom: 0,
                  trailingRoom: 0,
                  edgeDistanceStart: 0,
                  edgeDistanceEnd: 0,
                  insideContainer: true,
                  contentStart: 0,
                  child: FrostControlScope(
                    size: FrostControlSize.compact,
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return FrostButtonEdgeBleed(
      amount: edge,
      start: false,
      child: FrostMotionSize(
        duration: FrostMotion.duration(context, FrostMotion.layoutFade),
        alignment: AlignmentDirectional.topStart,
        child: Builder(builder: contents),
      ),
    );
  }
}
