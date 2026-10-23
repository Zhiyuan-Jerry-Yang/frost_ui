import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/spring.dart';

// The visual spacing is independent of the shared pointer/touch hit height.
const _dotDiameter = 6.0;
const _dotSpacing = 6.0;
const _selectedWidth = 16.0;
const _maximumDotCount = 10;
const _onMediaInactiveOpacity = .4;

/// Compact page feedback: dots through ten pages, then a localized counter.
///
/// A selectable indicator has one target-height hit band. Its horizontal
/// partitions meet midway between the actual dot centers, with half a gap
/// beyond each end. RTL mirrors both painting and selection.
class FrostPageIndicator extends StatelessWidget {
  const FrostPageIndicator({required this.count, required this.current, this.onSelected, this.onMedia = false, super.key})
    : assert(count >= 0),
      assert(count == 0 || (current >= 0 && current < count));
  final int count;
  final int current;
  final ValueChanged<int>? onSelected;
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final tokens = FrostThemeTokens.of(context);
    final active = onMedia ? tokens.onMediaInk : tokens.textPrimary;
    final inactive = onMedia ? tokens.onMediaInk.withValues(alpha: _onMediaInactiveOpacity) : tokens.textTertiary;
    final value = FrostScope.labelsOf(context).pageOf(current + 1, count);
    return Semantics(
      container: true,
      value: value,
      increasedValue: onSelected != null && current < count - 1 ? FrostScope.labelsOf(context).pageOf(current + 2, count) : null,
      decreasedValue: onSelected != null && current > 0 ? FrostScope.labelsOf(context).pageOf(current, count) : null,
      onIncrease: onSelected != null && current < count - 1 ? () => onSelected!(current + 1) : null,
      onDecrease: onSelected != null && current > 0 ? () => onSelected!(current - 1) : null,
      excludeSemantics: true,
      child: count > _maximumDotCount
          ? FrostSkeletonText(
              child: Text(value, style: FrostTypography.of(context).style(FrostTextRole.callout, numeric: true).copyWith(color: active)),
            )
          : FrostSpringBuilder(
              value: current.toDouble(),
              spring: FrostMotion.snappy,
              builder: (context, progress, _) {
                final position = progress.clamp(0.0, (count - 1).toDouble());
                final widths = List.generate(count, (index) => _dotDiameter + (_selectedWidth - _dotDiameter) * (1 - (position - index).abs()).clamp(0.0, 1.0));
                final centers = <double>[];
                var offset = 0.0;
                for (final width in widths) {
                  centers.add(offset + width / 2);
                  offset += width + _dotSpacing;
                }
                final total = offset - _dotSpacing;
                final pillWidth = widths.reduce(math.max);
                final pillStart = position * (_dotDiameter + _dotSpacing) + (_selectedWidth - pillWidth) / 2;
                final visual = SizedBox(
                  width: total,
                  height: _dotDiameter,
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          for (var index = 0; index < count; index++) ...[
                            if (index > 0) const SizedBox(width: _dotSpacing),
                            SizedBox(
                              width: widths[index],
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: inactive, borderRadius: FrostRadius.borderRadius(FrostRadius.full(_dotDiameter))),
                                  child: const SizedBox(width: _dotDiameter, height: _dotDiameter),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      PositionedDirectional(
                        start: pillStart,
                        top: 0,
                        width: pillWidth,
                        height: _dotDiameter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: active, borderRadius: FrostRadius.borderRadius(FrostRadius.full(_dotDiameter))),
                        ),
                      ),
                    ],
                  ),
                );
                if (onSelected == null) return visual;
                final rtl = Directionality.of(context) == TextDirection.rtl;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: (details) {
                      final x = (rtl ? total + _dotSpacing - details.localPosition.dx : details.localPosition.dx) - _dotSpacing / 2;
                      var nearest = 0;
                      for (var index = 1; index < count; index++) {
                        if ((centers[index] - x).abs() < (centers[nearest] - x).abs()) nearest = index;
                      }
                      onSelected!(nearest);
                    },
                    child: SizedBox(
                      width: total + _dotSpacing,
                      height: FrostDensity.of(context).targetHeight,
                      child: Center(child: visual),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
