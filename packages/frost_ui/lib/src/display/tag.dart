import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../feedback/_skeleton_geometry.dart';
import '../feedback/skeleton.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '_tag_metrics.dart';
import 'data_dot.dart';

// Content tags are smaller than actions; their targets still use shared rules.
const _tagMaxWidth = 240.0;

/// A content label, optionally selectable and interactive.
class FrostTag extends StatelessWidget {
  /// Explicit content determines bones only; semantics use the loading label.
  factory FrostTag.skeleton({required String label}) => _SkeletonTag(label);
  const FrostTag({required this.label, this.detail, this.onPressed, this.selected, this.dataColor, this.contextMenu = const [], super.key});
  final String label;
  final String? detail;
  final VoidCallback? onPressed;
  final bool? selected;
  final int? dataColor;
  final List<FrostMenuEntry> contextMenu;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final density = FrostDensity.of(context);
    final touch = density.heightFor(FrostControlSize.regular) == FrostControlSize.regular.visualHeight(touch: true);
    final geometry = frostControlTextGeometry(
      baseHeight: touch ? frostTagTouchHeight : frostTagPointerHeight,
      style: FrostTypography.of(context).style(FrostTextRole.footnote),
      textScaler: MediaQuery.textScalerOf(context),
    );
    Widget control = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _tagMaxWidth),
      child: FrostButtonControl(
        label: [label, ?detail].join(' '),
        onPressed: onPressed,
        selected: selected,
        presentation: FrostButtonPresentation.content,
        textRole: FrostTextRole.footnote,
        geometry: FrostButtonGeometry(
          horizontalInset: frostTagInset,
          verticalInset: 0,
          minimumWidth: 0,
          alignment: MainAxisAlignment.start,
          visualHeight: geometry.height,
          cornerRadius: FrostRadius.sm,
        ),
        labelWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dataColor case final index?) ...[FrostDataDot(index), const SizedBox(width: frostDataDotGap)],
            Flexible(
              child: _TagText(
                direction: Directionality.of(context),
                children: [
                  FrostSkeletonText(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                  if (detail case final detail?)
                    AnimatedDefaultTextStyle(
                      style: FrostTypography.of(context).style(FrostTextRole.footnote).copyWith(color: tokens.textSecondary),
                      duration: FrostMotion.duration(context, FrostMotion.hover),
                      child: FrostSkeletonText(child: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (contextMenu.isNotEmpty) control = FrostContextMenuRegion(entries: contextMenu, child: control);
    return FrostSkeletonShape(shape: FrostRadius.shape(context, FrostRadius.sm), visualHeight: geometry.height, child: control);
  }
}

class _SkeletonTag extends FrostTag {
  const _SkeletonTag(String label) : super(label: label);
  @override
  Widget build(BuildContext context) => super.build(context).frostSkeleton(true);
}

// Measure the primary label first, so detail yields its space before the label.
// This also shrink-wraps short tags without a LayoutBuilder's infinite intrinsic
// width, and uses the actual paragraphs (including nonlinear text scaling).
class _TagText extends MultiChildRenderObjectWidget {
  const _TagText({required this.direction, required super.children});
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTagText(direction);
  @override
  void updateRenderObject(BuildContext context, _RenderTagText renderObject) => renderObject.direction = direction;
}

class _TagTextParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTagText extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  _RenderTagText(this._direction);
  TextDirection _direction;
  set direction(TextDirection value) {
    if (_direction != value) {
      _direction = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TagTextParentData) child.parentData = _TagTextParentData();
  }

  Size _measure(BoxConstraints constraints, {required bool dry}) {
    final label = firstChild!;
    Size measure(RenderBox child, BoxConstraints limits) {
      if (dry) return child.getDryLayout(limits);
      child.layout(limits, parentUsesSize: true);
      return child.size;
    }

    final labelSize = measure(label, BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight));
    final detail = childAfter(label);
    final gap = detail == null || constraints.maxWidth - labelSize.width <= FrostGap.inline ? 0.0 : FrostGap.inline;
    final detailSize = detail == null
        ? Size.zero
        : measure(detail, BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - labelSize.width - gap), maxHeight: constraints.maxHeight));
    final size = constraints.constrain(Size(labelSize.width + gap + detailSize.width, math.max(labelSize.height, detailSize.height)));
    if (!dry) {
      (label.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
        _direction == TextDirection.ltr ? 0 : size.width - labelSize.width,
        (size.height - labelSize.height) / 2,
      );
      if (detail != null) {
        (detail.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
          _direction == TextDirection.ltr ? labelSize.width + gap : 0,
          (size.height - detailSize.height) / 2,
        );
      }
    }
    return size;
  }

  @override
  void performLayout() => size = _measure(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, dry: true);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
