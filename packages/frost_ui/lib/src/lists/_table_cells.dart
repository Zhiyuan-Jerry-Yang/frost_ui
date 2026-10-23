import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Measures all cells in a visible row once, without asking arbitrary cell
/// widgets (which may contain LayoutBuilder) for intrinsic dimensions.
class FrostTableCells extends MultiChildRenderObjectWidget {
  const FrostTableCells({
    required this.widths,
    required this.numeric,
    required this.minimumHeight,
    required this.verticalInset,
    required this.horizontalInset,
    required this.direction,
    required super.children,
    super.key,
  });
  final List<double> widths;
  final List<bool> numeric;
  final double minimumHeight, verticalInset, horizontalInset;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _Cells(this);
  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) => (renderObject as _Cells).spec = this;
}

class _CellData extends ContainerBoxParentData<RenderBox> {}

class _Cells extends RenderBox with ContainerRenderObjectMixin<RenderBox, _CellData>, RenderBoxContainerDefaultsMixin<RenderBox, _CellData> {
  _Cells(this._spec);
  FrostTableCells _spec;
  set spec(FrostTableCells value) {
    _spec = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CellData) child.parentData = _CellData();
  }

  Size _measure(BoxConstraints constraints, bool dry) {
    var height = _spec.minimumHeight;
    var index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final width = math.max(0.0, _spec.widths[index++] - 2 * _spec.horizontalInset);
      final limit = BoxConstraints(maxWidth: width);
      final measured = dry ? child.getDryLayout(limit) : (child..layout(limit, parentUsesSize: true)).size;
      height = math.max(height, measured.height + 2 * _spec.verticalInset);
    }
    return constraints.constrain(Size(_spec.widths.fold(0.0, (a, b) => a + b), height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, true);
  @override
  void performLayout() {
    size = _measure(constraints, false);
    var start = 0.0, index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final width = _spec.widths[index];
      final remaining = math.max(0.0, width - 2 * _spec.horizontalInset - child.size.width);
      final logicalX = start + _spec.horizontalInset + (_spec.numeric[index] ? remaining : 0);
      (child.parentData! as _CellData).offset = Offset(
        _spec.direction == TextDirection.ltr ? logicalX : size.width - logicalX - child.size.width,
        (size.height - child.size.height) / 2,
      );
      start += width;
      index++;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
