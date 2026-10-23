import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/rolling_text.dart';
import '../primitives/presence.dart';

// Count geometry and the cap marker are independent of the action underneath.
const _badgeHeight = 16.0;
const _badgeInset = 4.0;
const _badgeCornerInset = 4.0;
// Translate by half the badge's measured size to align its center to the corner.
const _centerTranslation = .5;
const _capSuffix = '+';

enum FrostCountBadgeTone { accent, negative }

/// A count that preserves the previous digits while disappearing.
class FrostCountBadge extends StatefulWidget {
  const FrostCountBadge({required this.count, this.max = 99, this.tone = FrostCountBadgeTone.accent, super.key});
  final int count, max;
  final FrostCountBadgeTone tone;
  @override
  State<FrostCountBadge> createState() => _FrostCountBadgeState();
}

class _FrostCountBadgeState extends State<FrostCountBadge> {
  late int _shownCount = widget.count;
  @override
  void didUpdateWidget(FrostCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > 0) _shownCount = widget.count;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final negative = widget.tone == FrostCountBadgeTone.negative;
    final style = FrostTypography.of(context).style(FrostTextRole.caption, numeric: true);
    final height = frostControlTextGeometry(baseHeight: _badgeHeight, style: style, textScaler: MediaQuery.textScalerOf(context)).height;
    return FrostPresence(
      visible: widget.count > 0,
      child: Semantics(
        value: _shownCount.toString(),
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: FrostMotion.duration(context, FrostMotion.hover),
          curve: FrostMotion.hoverCurve,
          constraints: BoxConstraints(minWidth: _badgeHeight, minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: _badgeInset),
          decoration: ShapeDecoration(color: negative ? tokens.negativeFill : tokens.actionFill, shape: FrostRadius.shape(context, height / 2)),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FrostRollingText(
              _shownCount > widget.max ? '${widget.max}$_capSuffix' : _shownCount.toString(),
              style: style.copyWith(color: negative ? tokens.onNegative : tokens.onAction),
            ),
          ),
        ),
      ),
    );
  }
}

extension FrostBadgeX on Widget {
  /// Places a decorative count at the top trailing corner, merging its value
  /// into this widget's existing semantics instead of adding a second node.
  Widget frostBadge(int count, {int max = 99, FrostCountBadgeTone tone = FrostCountBadgeTone.accent}) => _BadgeSemantics(
    count: count,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        this,
        PositionedDirectional(
          top: _badgeCornerInset,
          end: _badgeCornerInset,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Builder(
                builder: (context) => FractionalTranslation(
                  translation: Offset(Directionality.of(context) == TextDirection.ltr ? _centerTranslation : -_centerTranslation, -_centerTranslation),
                  child: FrostCountBadge(count: count, max: max, tone: tone),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// Flutter's MergeSemantics keeps only the first nonempty value. Append the
// count explicitly at semantics assembly so an existing child value survives.
class _BadgeSemantics extends SingleChildRenderObjectWidget {
  const _BadgeSemantics({required this.count, required super.child});
  final int count;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBadgeSemantics(count, Directionality.of(context));
  @override
  void updateRenderObject(BuildContext context, _RenderBadgeSemantics renderObject) {
    final direction = Directionality.of(context);
    if (renderObject.count == count && renderObject.direction == direction) return;
    renderObject.count = count;
    renderObject.direction = direction;
    renderObject.markNeedsSemanticsUpdate();
  }
}

class _RenderBadgeSemantics extends RenderProxyBox {
  _RenderBadgeSemantics(this.count, this.direction);
  int count;
  TextDirection direction;
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.isMergingSemanticsOfDescendants = true;
    config.textDirection = direction;
  }

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    final values = {config.value, for (final child in children) child.getSemanticsData().value}..remove('');
    if (count > 0) values.add(count.toString());
    super.assembleSemanticsNode(node, config.copy()..value = values.join(' '), children);
  }
}
