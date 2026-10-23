import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/sizes.dart';
import '../overlays/tooltip.dart';
import '../primitives/icon.dart';

// These gaps match the shared compact/regular button label geometry.
const _compactGap = 6.0;
const _regularGap = 8.0;

enum FrostLabelStyle { titleAndIcon, titleOnly, iconOnly }

/// Library-only presentation selected by the toolbar's same-frame planner.
class FrostLabelPresentation extends InheritedWidget {
  const FrostLabelPresentation({required this.compact, required super.child, super.key});
  final bool compact;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostLabelPresentation>()?.compact ?? false;
  @override
  bool updateShouldNotify(FrostLabelPresentation oldWidget) => compact != oldWidget.compact;
}

/// An inherited text style paired with an optional decorative icon.
class FrostLabel extends StatelessWidget {
  const FrostLabel({required this.title, this.icon, this.style, super.key});
  final String title;
  final FrostIconData? icon;
  final FrostLabelStyle? style;
  @override
  Widget build(BuildContext context) {
    final automatic = style == null && FrostControlScope.toolbarOf(context);
    final mode = automatic && FrostLabelPresentation.of(context) ? FrostLabelStyle.iconOnly : style ?? FrostLabelStyle.titleAndIcon;
    final size = FrostControlScope.sizeOf(context);
    final textStyle = DefaultTextStyle.of(context).style;
    Widget content = _LabelLayout(
      mode: mode,
      automatic: automatic,
      direction: Directionality.of(context),
      gap: size == FrostControlSize.compact ? _compactGap : _regularGap,
      children: [
        if (icon != null && mode != FrostLabelStyle.titleOnly) FrostIcon(icon!, size: size.iconSize, color: textStyle.color),
        FrostSkeletonText(
          child: Text(
            title,
            style: textStyle.copyWith(fontFeatures: [...?textStyle.fontFeatures, const FontFeature.tabularFigures()]),
            maxLines: automatic && icon == null ? 1 : null,
            overflow: automatic && icon == null ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        ),
      ],
    );
    if (icon != null && (automatic || mode == FrostLabelStyle.iconOnly)) content = FrostTooltip(message: title, excludeFromSemantics: true, child: content);
    return Semantics(label: title, excludeSemantics: true, child: content);
  }
}

class _Data extends ContainerBoxParentData<RenderBox> {}

class _LabelLayout extends MultiChildRenderObjectWidget {
  const _LabelLayout({required this.mode, required this.automatic, required this.direction, required this.gap, required super.children});
  final FrostLabelStyle mode;
  final bool automatic;
  final TextDirection direction;
  final double gap;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLabel(this);
  @override
  void updateRenderObject(BuildContext context, _RenderLabel renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderLabel extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderLabel(this.config);
  _LabelLayout config;
  bool _iconOnly = false;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  Size _layout(BoxConstraints limits, {required bool dry}) {
    final children = getChildrenAsList(), text = children.last, icon = children.length > 1 ? children.first : null;
    Size measure(RenderBox child, BoxConstraints constraints) {
      if (dry) return child.getDryLayout(constraints);
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    }

    final iconSize = icon == null ? Size.zero : measure(icon, const BoxConstraints());
    final preferred = text.getMaxIntrinsicWidth(double.infinity) + (icon == null ? 0 : iconSize.width + config.gap);
    final iconOnly = icon != null && (config.mode == FrostLabelStyle.iconOnly || config.automatic && limits.maxWidth < preferred);
    final textSize = measure(text, BoxConstraints(maxWidth: iconOnly ? 0 : math.max(0, limits.maxWidth - (icon == null ? 0 : iconSize.width + config.gap))));
    final result = limits.constrain(
      Size(
        iconOnly ? iconSize.width : textSize.width + (icon == null ? 0 : iconSize.width + config.gap),
        math.max(iconSize.height, iconOnly ? 0 : textSize.height),
      ),
    );
    if (!dry) {
      _iconOnly = iconOnly;
      void place(RenderBox child, double start) {
        (child.parentData! as _Data).offset = Offset(
          config.direction == TextDirection.ltr ? start : result.width - start - child.size.width,
          (result.height - child.size.height) / 2,
        );
      }

      if (icon != null) place(icon, 0);
      place(text, icon == null ? 0 : iconSize.width + config.gap);
    }
    return result;
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);
  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = getChildrenAsList();
    return children.length == 1
        ? children.last.getMaxIntrinsicWidth(height)
        : config.mode == FrostLabelStyle.iconOnly
        ? children.first.getMaxIntrinsicWidth(height)
        : children.fold(0.0, (sum, child) => sum + child.getMaxIntrinsicWidth(height)) + config.gap;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      config.automatic && childCount > 1 ? firstChild!.getMinIntrinsicWidth(height) : computeMaxIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in getChildrenAsList()) {
      if (_iconOnly && child == lastChild) continue;
      context.paintChild(child, offset + (child.parentData! as _Data).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
