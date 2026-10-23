import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';

/// Chooses the first candidate whose natural width fits, or the last fallback.
/// Candidates need finite natural widths (for example shrink-wrapped rows).
/// All candidates stay mounted; inactive candidates cannot receive input, focus
/// or semantics and their tickers are paused. Each candidate has a single mounted subtree,
/// avoiding a second live copy of its controllers or focus nodes.
class FrostFit extends StatefulWidget {
  const FrostFit({required this.candidates, super.key}) : assert(candidates.length > 0);
  final List<WidgetBuilder> candidates;
  @override
  State<FrostFit> createState() => _FitState();
}

class _FitState extends State<FrostFit> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostLayoutCrossfade(
    layoutIdentity: _identity,
    child: _FitLayout(
      identity: _identity,
      direction: Directionality.of(context),
      children: [
        for (final builder in widget.candidates)
          LayoutBuilder(
            builder: (context, constraints) {
              final visible = (constraints as _FitConstraints).visible;
              return ExcludeFocus(
                excluding: !visible,
                child: ExcludeSemantics(
                  excluding: !visible,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: TickerMode(
                      enabled: visible,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

class _FitConstraints extends BoxConstraints {
  _FitConstraints(BoxConstraints original, {required this.visible})
    : super(minWidth: original.minWidth, maxWidth: original.maxWidth, minHeight: original.minHeight, maxHeight: original.maxHeight);
  final bool visible;
  @override
  bool operator ==(Object other) => other is _FitConstraints && super == other && visible == other.visible;
  @override
  int get hashCode => Object.hash(super.hashCode, visible);
}

class _FitData extends ContainerBoxParentData<RenderBox> {}

class _FitLayout extends MultiChildRenderObjectWidget {
  const _FitLayout({required this.identity, required this.direction, required super.children});
  final FrostLayoutIdentity identity;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFit(this);
  @override
  void updateRenderObject(BuildContext context, _RenderFit renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderFit extends RenderBox with ContainerRenderObjectMixin<RenderBox, _FitData>, RenderBoxContainerDefaultsMixin<RenderBox, _FitData> {
  _RenderFit(this.config);
  _FitLayout config;
  RenderBox? _visible;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitData) child.parentData = _FitData();
  }

  @override
  void performLayout() {
    final items = getChildrenAsList();
    var selected = items.length - 1;
    var found = false;
    for (var index = 0; index < items.length; index++) {
      final child = items[index];
      child.layout(_FitConstraints(BoxConstraints(maxHeight: constraints.maxHeight), visible: identical(child, _visible)), parentUsesSize: true);
      if (!found && child.size.width <= constraints.maxWidth) {
        selected = index;
        found = true;
      }
    }
    config.identity.update(selected, viewport: constraints);
    if (!identical(_visible, items[selected])) markNeedsSemanticsUpdate();
    if (_visible != null && !identical(_visible, items[selected])) {
      _visible!.layout(_FitConstraints(BoxConstraints(maxHeight: constraints.maxHeight), visible: false), parentUsesSize: true);
    }
    _visible = items[selected]..layout(_FitConstraints(constraints, visible: true), parentUsesSize: true);
    size = constraints.constrain(_visible!.size);
    (_visible!.parentData! as _FitData).offset = Offset(config.direction == TextDirection.ltr ? 0 : size.width - _visible!.size.width, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_visible case final child?) context.paintChild(child, offset + (child.parentData! as _FitData).offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _visible;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: (child.parentData! as _FitData).offset,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visible case final child?) visitor(child);
  }
}
