import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/density.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_selection_feedback.dart';
import '../overlays/tooltip.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '_destination_status.dart';

/// Internal tile shared by the shell rail and the settings section list.
class FrostNavigationTile extends StatelessWidget {
  const FrostNavigationTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.focusNode,
    this.progress = 1,
    this.labelOpacity = 1,
    this.showsLabel = true,
    this.iconAxis = 24,
    this.physicalIconAxis = false,
    this.expandedLayoutWidth,
    super.key,
  });
  final String label;
  final FrostIconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final double progress, labelOpacity, iconAxis;
  final bool showsLabel, physicalIconAxis;

  /// Shell-only fixed text layout; the animated target reveals this rectangle.
  final double? expandedLayoutWidth;

  // Preserve the shell's icon axis and its collapsed square during expansion.
  static const _collapsedExtent = 40.0;
  static const _collapsedIconStart = 9.0;
  double get _expandedIconStart => iconAxis - _iconSize / 2;
  static const _iconSize = 22.0;
  static const _iconLabelGap = 12.0;
  static const _labelEndInset = 8.0;

  double _width(BoxConstraints constraints, double progress) => lerpDouble(_collapsedExtent, expandedLayoutWidth ?? constraints.maxWidth, progress)!;
  double _iconLeft(BoxConstraints constraints, double progress) {
    if (expandedLayoutWidth != null) return _expandedIconStart;
    if (physicalIconAxis) return iconAxis - (constraints.maxWidth - _width(constraints, progress)) / 2 - _iconSize / 2;
    return lerpDouble(_collapsedIconStart, _expandedIconStart, progress)!;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final amount = progress.clamp(0.0, 1.0);
    final style = FrostTypography.of(context).style(FrostTextRole.callout);
    final expandedHeight = frostControlTextGeometry(
      baseHeight: FrostDensity.of(context).targetHeight,
      style: style,
      textScaler: MediaQuery.textScalerOf(context),
    ).height;
    final height = lerpDouble(_collapsedExtent, expandedHeight, amount)!;
    final radius = BorderRadius.circular(lerpDouble(FrostRadius.md, FrostRadius.sm, amount)!);
    return FrostSelectionFeedback(
      selected: selected,
      foreground: selected ? tokens.selectionInk : tokens.textSecondary,
      background: selected ? tokens.selectionFill : tokens.selectionFill.withValues(alpha: 0),
      builder: (context, ink, fill, scale) => LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: AlignmentDirectional.center,
          child: SizedBox(
            width: _width(constraints, amount),
            height: height,
            child: TooltipVisibility(
              visible: !showsLabel || amount < .5,
              child: FrostTooltip(
                message: label,
                excludeFromSemantics: true,
                child: Semantics(
                  button: true,
                  selected: showsLabel ? selected : null,
                  enabled: showsLabel ? null : onTap != null,
                  label: FrostDestinationStatus.labelOf(context, label),
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: fill, borderRadius: radius),
                    child: FrostClickSurface(
                      focusNode: focusNode,
                      borderRadius: radius,
                      onTap: onTap,
                      child: FrostNavigationContent(
                        expandedWidth: expandedLayoutWidth,
                        horizontalOffset: expandedLayoutWidth == null ? 0 : -(constraints.maxWidth - _width(constraints, amount)) / 2,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (icon case final graphic?)
                              PositionedDirectional(
                                start: physicalIconAxis && Directionality.of(context) == TextDirection.rtl
                                    ? (expandedLayoutWidth ?? _width(constraints, amount)) - _iconLeft(constraints, amount) - _iconSize
                                    : _iconLeft(constraints, amount),
                                top: (height - _iconSize) / 2,
                                child: ScaleTransition(
                                  scale: scale,
                                  child: FrostDestinationStatus.decorateIcon(
                                    context,
                                    FrostIcon(graphic, size: _iconSize, color: ink),
                                    expansion: amount,
                                  ),
                                ),
                              ),
                            if (showsLabel && amount > 0)
                              PositionedDirectional(
                                start: physicalIconAxis && Directionality.of(context) == TextDirection.rtl
                                    ? _labelEndInset
                                    : (physicalIconAxis ? _iconLeft(constraints, amount) : _expandedIconStart) + (icon == null ? 0 : _iconSize + _iconLabelGap),
                                end: physicalIconAxis && Directionality.of(context) == TextDirection.rtl
                                    ? _iconLeft(constraints, amount) + (icon == null ? 0 : _iconSize + _iconLabelGap)
                                    : _labelEndInset,
                                top: 0,
                                bottom: 0,
                                child: Opacity(
                                  opacity: ((amount - .4) / .6).clamp(0.0, 1.0) * labelOpacity,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) => Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: AlignmentDirectional.centerStart,
                                            child: FrostSkeletonText(
                                              child: Text(
                                                label,
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.fade,
                                                style: style.copyWith(color: ink),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (FrostDestinationStatus.of(context) case final status?)
                                          ConstrainedBox(
                                            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                                            child: FrostDestinationTrailing(status: status, ink: ink),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal shared viewport for fixed sidebar content. Settings tiles omit the
/// expanded width and retain their ordinary local layout. The state layer and
/// hit target keep their animated width; only their content is revealed.
class FrostNavigationContent extends StatelessWidget {
  const FrostNavigationContent({required this.expandedWidth, required this.child, this.horizontalOffset = 0, super.key});
  final double? expandedWidth;
  final double horizontalOffset;
  final Widget child;
  @override
  Widget build(BuildContext context) => expandedWidth == null
      ? child
      : ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: expandedWidth,
            maxWidth: expandedWidth,
            child: Transform.translate(offset: Offset(horizontalOffset, 0), child: child),
          ),
        );
}
