import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '../motion/_layout_identity.dart';

// Shared row flow: an eight-point inline gap and two-point stacked gap.
const _rowIconGap = 8.0;
const _rowTextGap = 2.0;

enum FrostRowPart { selection, leading, text, value, end }

class _RowParentData extends ContainerBoxParentData<RenderBox> {
  FrostRowPart? part;
}

class FrostRowSlot extends ParentDataWidget<_RowParentData> {
  FrostRowSlot({required this.id, required Widget child, bool includeSemantics = false, super.key})
    : super(child: includeSemantics ? child : ExcludeSemantics(child: child));
  final FrostRowPart id;
  @override
  Type get debugTypicalAncestorWidgetClass => FrostRowLayout;
  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _RowParentData;
    if (data.part != id) {
      data.part = id;
      renderObject.parent?.markNeedsLayout();
    }
  }
}

class FrostRowLayout extends MultiChildRenderObjectWidget {
  const FrostRowLayout({
    required this.identity,
    required this.contentIdentity,
    required this.minimumHeight,
    required this.verticalInset,
    required this.inset,
    required this.direction,
    this.keepValueInline = false,
    this.minimumInlineTextWidth = 0,
    this.stackedGap = _rowTextGap,
    required super.children,
    super.key,
  });
  final FrostLayoutIdentity identity;
  final Object contentIdentity;
  final double minimumHeight, verticalInset, stackedGap;
  final EdgeInsets inset;
  final TextDirection direction;
  final bool keepValueInline;
  final double minimumInlineTextWidth;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRow(this);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderRow).update(this);
}

class _RenderRow extends RenderBox with ContainerRenderObjectMixin<RenderBox, _RowParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderRow(this.spec);
  FrostRowLayout spec;
  void update(FrostRowLayout value) {
    spec = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) child.parentData = _RowParentData();
  }

  Size _measure(BoxConstraints limits, {required bool dry}) {
    final parts = <FrostRowPart, RenderBox>{};
    visitChildren((child) {
      final box = child as RenderBox;
      parts[(box.parentData! as _RowParentData).part!] = box;
    });
    Size measure(FrostRowPart part, double width) {
      final child = parts[part];
      if (child == null) return Size.zero;
      final constraints = BoxConstraints(maxWidth: math.max(0, width));
      if (dry) return child.getDryLayout(constraints);
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    }

    final width = limits.hasBoundedWidth
        ? limits.maxWidth
        : parts.values.fold(0.0, (sum, child) => sum + child.getMaxIntrinsicWidth(double.infinity)) + spec.inset.horizontal;
    final available = math.max(0.0, width - spec.inset.horizontal);
    final end = measure(FrostRowPart.end, available);
    final selection = measure(FrostRowPart.selection, math.max(0, available - end.width));
    final leading = measure(FrostRowPart.leading, math.max(0, available - end.width - selection.width));
    final leadingWidth = selection.width + (parts.containsKey(FrostRowPart.leading) ? leading.width + _rowIconGap : 0.0);
    final endWidth = parts.containsKey(FrostRowPart.end) ? end.width + FrostGap.related : 0.0;
    final textWidth = math.max(0.0, available - leadingWidth - endWidth);
    final value = measure(FrostRowPart.value, textWidth);
    // Both preferred widths come from real render children, including text
    // scaling and custom trailing content. Decide on the cold layout itself.
    final inline =
        parts.containsKey(FrostRowPart.value) &&
        ((spec.keepValueInline && (spec.minimumInlineTextWidth == 0 || textWidth >= value.width + FrostGap.related + spec.minimumInlineTextWidth)) ||
            (!spec.keepValueInline &&
                parts[FrostRowPart.text]!.getMaxIntrinsicWidth(double.infinity) +
                        parts[FrostRowPart.value]!.getMaxIntrinsicWidth(double.infinity) +
                        FrostGap.related <=
                    textWidth));
    if (!dry) spec.identity.update((spec.contentIdentity, inline), viewport: limits);
    final text = measure(FrostRowPart.text, inline ? math.max(0, textWidth - value.width - FrostGap.related) : textWidth);
    final blockHeight = inline || !parts.containsKey(FrostRowPart.value) ? text.height : text.height + spec.stackedGap + value.height;
    final height = math.max(
      spec.minimumHeight,
      [blockHeight + spec.verticalInset * 2, leading.height, selection.height, end.height, inline ? value.height : 0.0].reduce(math.max),
    );
    final size = limits.constrain(Size(width, height));
    if (!dry) {
      void place(FrostRowPart part, double start, double top) {
        final child = parts[part];
        if (child == null) return;
        final x = spec.direction == TextDirection.ltr ? spec.inset.left + start : size.width - spec.inset.right - start - child.size.width;
        (child.parentData! as _RowParentData).offset = Offset(x, top);
      }

      final top = (size.height - blockHeight) / 2;
      place(FrostRowPart.selection, 0, (size.height - selection.height) / 2);
      place(FrostRowPart.leading, selection.width, (size.height - leading.height) / 2);
      place(FrostRowPart.text, leadingWidth, top);
      place(
        FrostRowPart.value,
        inline ? available - endWidth - value.width : leadingWidth,
        inline ? (size.height - value.height) / 2 : top + text.height + spec.stackedGap,
      );
      place(FrostRowPart.end, available - end.width, (size.height - end.height) / 2);
    }
    return size;
  }

  @override
  void performLayout() => size = _measure(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, dry: true);
  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = spec.inset.horizontal;
    visitChildren((child) {
      width += (child as RenderBox).getMaxIntrinsicWidth(height) + FrostGap.related;
    });
    return width;
  }

  @override
  double computeMinIntrinsicWidth(double height) => spec.inset.horizontal;
  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
