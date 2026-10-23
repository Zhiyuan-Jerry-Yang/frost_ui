import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../controls/buttons.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/divider.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import '_modal_route.dart';

// Shared modal geometry: content insets and the gap before actions.
const frostModalInset = 20.0;
const frostModalActionGap = 20.0;
const frostModalViewportInset = 24.0;
const frostModalCompactInset = 16.0;
const frostAlertWidth = 400.0;
const frostDialogWidth = 480.0;
const frostWideDialogWidth = 640.0;

class FrostModalSurface extends StatelessWidget {
  const FrostModalSurface({required this.width, required this.child, super.key});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = FrostModalRouteScope.maybeOf(context)?.compact ?? FrostSizeClass.of(context) == FrostSizeClass.compact;
    final horizontal = compact ? frostModalCompactInset : frostModalViewportInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        frostModalViewportInset + media.padding.top,
        horizontal,
        frostModalViewportInset + media.viewInsets.bottom + media.padding.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: compact ? math.max(0, media.size.width - horizontal * 2) : width),
          child: FrostSurface(role: FrostSurfaceRole.sheet, borderRadius: FrostRadius.borderRadius(FrostRadius.xl), child: child),
        ),
      ),
    );
  }
}

class FrostModalHeader extends StatelessWidget {
  const FrostModalHeader({this.title, this.role = FrostTextRole.title2, this.showsCloseButton = false, super.key});
  final String? title;
  final FrostTextRole role;
  final bool showsCloseButton;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: title == null ? const SizedBox.shrink() : FrostText(title!, role: role, tone: FrostTextTone.primary),
      ),
      if (showsCloseButton) ...[
        const SizedBox(width: FrostGap.related),
        FrostButton.icon(
          icon: FrostIconSet.of(context).close,
          label: FrostScope.labelsOf(context).close,
          size: FrostControlSize.compact,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ],
  );
}

/// The controller always belongs to the modal, including lazy content slots.
class FrostModalFrame extends StatefulWidget {
  const FrostModalFrame({
    required this.content,
    this.header,
    this.footer,
    this.leading,
    this.headerGap = FrostGap.group,
    this.topInset = frostModalInset,
    this.horizontalInset = frostModalInset,
    this.bottomInset = frostModalInset,
    this.scrollable = true,
    this.scrollController,
    super.key,
  });
  final Widget content;
  final Widget? header, footer, leading;
  final double headerGap, topInset, bottomInset, horizontalInset;
  final bool scrollable;
  final ScrollController? scrollController;

  @override
  State<FrostModalFrame> createState() => _FrostModalFrameState();
}

class _FrostModalFrameState extends State<FrostModalFrame> with TickerProviderStateMixin {
  late final _ownedScroll = ScrollController();
  late final _topFade = AnimationController(vsync: this);
  late final _bottomFade = AnimationController(vsync: this);
  ScrollController get _scroll => widget.scrollController ?? _ownedScroll;

  @override
  void dispose() {
    _ownedScroll.dispose();
    _topFade.dispose();
    _bottomFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(widget.horizontalInset, widget.topInset, widget.horizontalInset, widget.bottomInset),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.leading case final leading?) ...[leading, const SizedBox(height: FrostGap.related)],
        if (widget.header case final header?) ...[header, SizedBox(height: widget.headerGap)],
        Flexible(
          child: Stack(
            children: [
              PrimaryScrollController(
                controller: _scroll,
                // Lazy slotted scrollables use the supplied controller on all
                // platforms, rather than only on mobile platforms.
                automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
                // Dialog safe area and sheet detents have already kept this slot
                // below the system top. Nested pinned content must not add it again.
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: widget.scrollable ? SingleChildScrollView(controller: _scroll, child: widget.content) : widget.content,
                ),
              ),
              if (widget.header != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FrostModalScrollDivider(controller: _scroll, animation: _topFade, atTop: true),
                ),
              if (widget.footer != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FrostModalScrollDivider(controller: _scroll, animation: _bottomFade, atTop: false),
                ),
            ],
          ),
        ),
        if (widget.footer case final footer?) ...[const SizedBox(height: frostModalActionGap), footer],
      ],
    ),
  );
}

/// Opacity is resolved from real scroll metrics at paint time on the cold
/// frame. Subsequent scroll events drive the same render layer over 140 ms;
/// no build or post-layout state write is needed to discover overflow.
class FrostModalScrollDivider extends SingleChildRenderObjectWidget {
  const FrostModalScrollDivider({required this.controller, required this.animation, required this.atTop, super.key}) : super(child: const FrostDivider());
  final ScrollController controller;
  final AnimationController animation;
  final bool atTop;

  @override
  RenderFrostModalScrollDivider createRenderObject(BuildContext context) => RenderFrostModalScrollDivider(controller, animation, atTop);

  @override
  void updateRenderObject(BuildContext context, RenderFrostModalScrollDivider renderObject) => renderObject.update(controller, animation, atTop);
}

class RenderFrostModalScrollDivider extends RenderProxyBox {
  RenderFrostModalScrollDivider(this._controller, this._animation, this._atTop);
  ScrollController _controller;
  AnimationController _animation;
  bool _atTop;
  double _lastPaintedOpacity = 0;
  double get paintedOpacity => _animation.isAnimating ? _animation.value : _target;
  double _destination = 0;
  double get _target {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) return 0;
    final position = _controller.position;
    return (_atTop ? position.pixels > position.minScrollExtent : position.pixels < position.maxScrollExtent) ? 1 : 0;
  }

  void update(ScrollController controller, AnimationController animation, bool atTop) {
    if (attached) _unlisten();
    _controller = controller;
    _animation = animation;
    _atTop = atTop;
    if (attached) _listen();
    markNeedsPaint();
  }

  void _listen() {
    _controller.addListener(_scrollChanged);
    _animation.addListener(markNeedsPaint);
  }

  void _unlisten() {
    _controller.removeListener(_scrollChanged);
    _animation.removeListener(markNeedsPaint);
  }

  void _scrollChanged() {
    if (_target == (_animation.isAnimating ? _destination : _lastPaintedOpacity)) return;
    _destination = _target;
    _animation.stop();
    _animation.value = _lastPaintedOpacity;
    _animation.animateTo(_target, duration: FrostMotion.hover, curve: FrostMotion.hoverCurve);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _lastPaintedOpacity = paintedOpacity;
    if (paintedOpacity == 0) return;
    context.pushOpacity(offset, (paintedOpacity * 255).round(), super.paint);
  }
}

/// Reorders the same buttons, measures their natural width, then lays them out
/// at full width if necessary. Both arrangements are correct on the first pass.
class FrostModalActionBar extends MultiChildRenderObjectWidget {
  const FrostModalActionBar({
    required this.horizontalOrder,
    required this.verticalOrder,
    this.forceVertical = false,
    this.leadingIndex,
    required super.children,
    super.key,
  });
  final List<int> horizontalOrder, verticalOrder;
  final bool forceVertical;
  final int? leadingIndex;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderActionBar(horizontalOrder, verticalOrder, forceVertical, leadingIndex, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) =>
      (renderObject as _RenderActionBar).update(horizontalOrder, verticalOrder, forceVertical, leadingIndex, Directionality.of(context));
}

class _ActionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderActionBar extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _ActionParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _ActionParentData> {
  _RenderActionBar(this._horizontal, this._vertical, this._forceVertical, this._leadingIndex, this._direction);
  List<int> _horizontal, _vertical;
  bool _forceVertical;
  int? _leadingIndex;
  TextDirection _direction;
  List<RenderBox> _visualOrder = [];

  void update(List<int> horizontal, List<int> vertical, bool forceVertical, int? leadingIndex, TextDirection direction) {
    _horizontal = horizontal;
    _vertical = vertical;
    _forceVertical = forceVertical;
    _leadingIndex = leadingIndex;
    _direction = direction;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ActionParentData) child.parentData = _ActionParentData();
  }

  Size _layout(BoxConstraints constraints) {
    final children = getChildrenAsList();
    if (children.isEmpty) return constraints.constrain(Size.zero);
    final sizes = [for (final child in children) (child..layout(const BoxConstraints(), parentUsesSize: true)).size];
    final naturalWidth = sizes.fold(0.0, (sum, size) => sum + size.width) + FrostGap.related * (children.length - 1);
    final vertical = _forceVertical || naturalWidth > constraints.maxWidth;
    final order = vertical ? _vertical : _horizontal;
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : naturalWidth;
    var height = 0.0;
    if (vertical) {
      for (final index in order) {
        final child = children[index];
        final childConstraints = BoxConstraints.tightFor(width: width);
        child.layout(childConstraints, parentUsesSize: true);
        final childSize = child.size;
        (child.parentData! as _ActionParentData).offset = Offset(0, height);
        height += childSize.height + FrostGap.related;
      }
      height -= FrostGap.related;
    } else {
      height = sizes.fold(0.0, (value, size) => math.max(value, size.height));
      final trailing = order.where((index) => index != _leadingIndex).toList();
      final trailingWidth = trailing.fold(0.0, (sum, index) => sum + sizes[index].width) + math.max(0, trailing.length - 1) * FrostGap.related;
      var x = width - trailingWidth;
      for (final index in order) {
        final child = children[index];
        final start = index == _leadingIndex ? 0.0 : x;
        final left = _direction == TextDirection.ltr ? start : width - start - sizes[index].width;
        (child.parentData! as _ActionParentData).offset = Offset(left, (height - sizes[index].height) / 2);
        if (index != _leadingIndex) x += sizes[index].width + FrostGap.related;
      }
    }
    _visualOrder = [for (final index in order) children[index]];
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() => size = _layout(constraints);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => _visualOrder.forEach(visitor);
}
