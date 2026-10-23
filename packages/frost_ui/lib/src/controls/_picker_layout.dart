part of 'picker.dart';

class _PickerLayoutHandle {
  FrostPickerStyle style = FrostPickerStyle.menu;
}

class _PickerConstraints extends BoxConstraints {
  _PickerConstraints(BoxConstraints original, this.style)
    : super(minWidth: original.minWidth, maxWidth: original.maxWidth, minHeight: original.minHeight, maxHeight: original.maxHeight);
  final FrostPickerStyle style;
  @override
  bool operator ==(Object other) => other is _PickerConstraints && super == other && style == other.style;
  @override
  int get hashCode => Object.hash(super.hashCode, style);
}

class _PickerParentData extends ContainerBoxParentData<RenderBox> {}

class _PickerAutoLayout extends MultiChildRenderObjectWidget {
  const _PickerAutoLayout({required this.identity, required this.handle, required this.direction, required super.children});
  final FrostLayoutIdentity identity;
  final _PickerLayoutHandle handle;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPickerAuto(this);
  @override
  void updateRenderObject(BuildContext context, _RenderPickerAuto renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderPickerAuto extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _PickerParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _PickerParentData> {
  _RenderPickerAuto(this.config);
  _PickerAutoLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PickerParentData) child.parentData = _PickerParentData();
  }

  @override
  void performLayout() {
    firstChild!.layout(BoxConstraints(maxHeight: constraints.maxHeight), parentUsesSize: true);
    final style = firstChild!.size.width <= constraints.maxWidth ? FrostPickerStyle.segmented : FrostPickerStyle.menu;
    config.handle.style = style;
    config.identity.update(style, viewport: constraints);
    lastChild!.layout(_PickerConstraints(constraints, style), parentUsesSize: true);
    size = constraints.constrain(lastChild!.size);
    (lastChild!.parentData! as _PickerParentData).offset = Offset(config.direction == TextDirection.ltr ? 0 : size.width - lastChild!.size.width, 0);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => firstChild!.getMaxIntrinsicHeight(width);
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => context.paintChild(lastChild!, offset + (lastChild!.parentData! as _PickerParentData).offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final data = lastChild!.parentData! as _PickerParentData;
    return result.addWithPaintOffset(
      offset: data.offset,
      position: position,
      hitTest: (result, transformed) => lastChild!.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => visitor(lastChild!);
}
