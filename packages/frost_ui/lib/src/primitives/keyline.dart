import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The nearest content alignment and the space available outside it.
class FrostKeyline extends InheritedWidget {
  const FrostKeyline({
    required this.leadingRoom,
    required this.trailingRoom,
    required this.edgeDistanceStart,
    required this.edgeDistanceEnd,
    required this.insideContainer,
    required this.contentStart,
    required super.child,
    super.key,
  });
  final double leadingRoom;
  final double trailingRoom;
  final double edgeDistanceStart;
  final double edgeDistanceEnd;
  final bool insideContainer;
  final double contentStart;
  static FrostKeyline? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostKeyline>();
  @override
  bool updateShouldNotify(FrostKeyline oldWidget) =>
      leadingRoom != oldWidget.leadingRoom ||
      trailingRoom != oldWidget.trailingRoom ||
      edgeDistanceStart != oldWidget.edgeDistanceStart ||
      edgeDistanceEnd != oldWidget.edgeDistanceEnd ||
      insideContainer != oldWidget.insideContainer ||
      contentStart != oldWidget.contentStart;
}

/// Direction-aware viewport contact for descendants that shape their corners.
@immutable
class FrostBleedSnap {
  const FrostBleedSnap({required this.start, required this.end});
  static const none = FrostBleedSnap(start: false, end: false);
  final bool start;
  final bool end;
}

class _BleedScope extends InheritedWidget {
  const _BleedScope({required this.snap, this.provider, this.startUsed = 0, this.endUsed = 0, this.start = 0, this.end = 0, required super.child});
  final FrostKeyline? provider;
  final double startUsed, endUsed;
  final double start, end;
  final FrostBleedSnap snap;
  @override
  bool updateShouldNotify(_BleedScope oldWidget) =>
      snap.start != oldWidget.snap.start ||
      snap.end != oldWidget.snap.end ||
      provider != oldWidget.provider ||
      startUsed != oldWidget.startUsed ||
      endUsed != oldWidget.endUsed ||
      start != oldWidget.start ||
      end != oldWidget.end;
}

/// Library-only resolved outsets, including viewport snapping. Consumers pad
/// by what was actually granted, rather than guessing or spending room twice.
EdgeInsetsGeometry frostBleedOutsetsOf(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<_BleedScope>();
  return EdgeInsetsDirectional.only(start: scope?.start ?? 0, end: scope?.end ?? 0);
}

/// Extends a full-width row into the nearest keyline's available margin.
class FrostBleed extends StatelessWidget {
  const FrostBleed({required this.amount, required this.child, super.key}) : assert(amount >= 0);
  final double amount;
  final Widget child;
  static FrostBleedSnap snappedOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_BleedScope>()?.snap ?? FrostBleedSnap.none;
  @override
  Widget build(BuildContext context) {
    final keyline = FrostKeyline.maybeOf(context);
    if (keyline == null || keyline.insideContainer) return _BleedScope(snap: FrostBleedSnap.none, child: child);
    final previous = context.dependOnInheritedWidgetOfExactType<_BleedScope>();
    final sameProvider = identical(previous?.provider, keyline);
    final usedStart = sameProvider ? previous!.startUsed : 0.0;
    final usedEnd = sameProvider ? previous!.endUsed : 0.0;
    (double, bool) side(double room, double edge) {
      var extent = math.min(amount, room);
      final snap = edge - extent <= 4 && edge <= room;
      if (snap) extent = edge;
      return (extent, snap);
    }

    final (start, snapStart) = side(math.max(0, keyline.leadingRoom - usedStart), math.max(0, keyline.edgeDistanceStart - usedStart));
    final (end, snapEnd) = side(math.max(0, keyline.trailingRoom - usedEnd), math.max(0, keyline.edgeDistanceEnd - usedEnd));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return _BleedScope(
      snap: FrostBleedSnap(start: snapStart, end: snapEnd),
      provider: keyline,
      startUsed: usedStart + start,
      endUsed: usedEnd + end,
      start: start,
      end: end,
      child: _BleedLayout(left: rtl ? end : start, right: rtl ? start : end, child: child),
    );
  }
}

class _BleedLayout extends SingleChildRenderObjectWidget {
  const _BleedLayout({required this.left, required this.right, required super.child});
  final double left, right;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleed(left, right);
  @override
  void updateRenderObject(BuildContext context, _RenderBleed renderObject) => renderObject.update(left, right);
}

class _RenderBleed extends RenderShiftedBox {
  _RenderBleed(this.left, this.right) : super(null);
  double left, right;
  _BleedBoundaryHost? _boundary;
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    RenderObject? ancestor = parent;
    while (ancestor != null && ancestor is! _BleedBoundaryHost) {
      ancestor = ancestor.parent;
    }
    _boundary = ancestor as _BleedBoundaryHost?;
    _boundary?.bleeds.add(this);
  }

  @override
  void detach() {
    _boundary?.bleeds.remove(this);
    _boundary = null;
    super.detach();
  }

  void update(double newLeft, double newRight) {
    if (left == newLeft && right == newRight) return;
    left = newLeft;
    right = newRight;
    markNeedsLayout();
  }

  BoxConstraints childConstraints(BoxConstraints constraints) {
    final extra = left + right;
    return BoxConstraints(
      minWidth: constraints.hasBoundedWidth ? constraints.maxWidth + extra : constraints.minWidth + extra,
      maxWidth: constraints.maxWidth + extra,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child!.getDryLayout(childConstraints(constraints));
    return constraints.constrain(Size(math.max(0, childSize.width - left - right), childSize.height));
  }

  @override
  void performLayout() {
    child!.layout(childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(Size(math.max(0, child!.size.width - left - right), child!.size.height));
    (child!.parentData! as BoxParentData).offset = Offset(-left, 0);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hit = hitTestChildren(result, position: position);
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

/// Library-only directional bleed. Explicit text alignment spends only the
/// requested padding, without snapping farther toward the viewport edge.
class FrostButtonEdgeBleed extends StatelessWidget {
  const FrostButtonEdgeBleed({required this.amount, required this.start, required this.child, super.key});
  final double amount;
  final bool start;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final keyline = FrostKeyline.maybeOf(context);
    if (keyline == null) return child;
    final previous = context.dependOnInheritedWidgetOfExactType<_BleedScope>();
    final same = identical(previous?.provider, keyline);
    final usedStart = same ? previous!.startUsed : 0.0;
    final usedEnd = same ? previous!.endUsed : 0.0;
    final leading = start ? math.min(amount, math.max(0.0, keyline.leadingRoom - usedStart)) : 0.0;
    final trailing = start ? 0.0 : math.min(amount, math.max(0.0, keyline.trailingRoom - usedEnd));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return _BleedScope(
      snap: FrostBleedSnap.none,
      provider: keyline,
      startUsed: usedStart + leading,
      endUsed: usedEnd + trailing,
      start: leading,
      end: trailing,
      child: _BleedLayout(left: rtl ? trailing : leading, right: rtl ? leading : trailing, child: child),
    );
  }
}

/// Library-only boundary outside a keyline's Padding. A painted bleed can be
/// outside an intervening Align/Row's layout bounds; route those edge hits to
/// the registered bleed rather than losing them in an otherwise empty margin.
/// This adds no paint layer and does not bypass the container's outer clip.
class FrostBleedBoundary extends SingleChildRenderObjectWidget {
  const FrostBleedBoundary({required super.child, super.key});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleedBoundary();
}

mixin _BleedBoundaryHost on RenderObject {
  final bleeds = <_RenderBleed>{};
  bool hitBleeds(BoxHitTestResult result, Offset position) {
    for (final bleed in bleeds.toList().reversed) {
      if (!bleed.attached || !bleed.hasSize) continue;
      final hit = result.addWithPaintTransform(
        transform: bleed.getTransformTo(this),
        position: position,
        hitTest: (result, point) => !(Offset.zero & bleed.size).contains(point) && bleed.hitTest(result, position: point),
      );
      if (hit) return true;
    }
    return false;
  }
}

class _RenderBleedBoundary extends RenderProxyBox with _BleedBoundaryHost {
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => super.hitTestChildren(result, position: position) || hitBleeds(result, position);
}

/// Sliver equivalent; retains laziness and keeps the scrollbar at the viewport.
class FrostSliverBleedBoundary extends SingleChildRenderObjectWidget {
  const FrostSliverBleedBoundary({required super.child, super.key});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliverBleedBoundary();
}

class _RenderSliverBleedBoundary extends RenderProxySliver with _BleedBoundaryHost {
  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    if (super.hitTestChildren(result, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition)) return true;
    final position = switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
      AxisDirection.down => Offset(crossAxisPosition, mainAxisPosition),
      AxisDirection.up => Offset(crossAxisPosition, geometry!.paintExtent - mainAxisPosition),
      AxisDirection.right => Offset(mainAxisPosition, crossAxisPosition),
      AxisDirection.left => Offset(geometry!.paintExtent - mainAxisPosition, crossAxisPosition),
    };
    return hitBleeds(BoxHitTestResult.wrap(result), position);
  }
}

/// Library-only painted ink marker; no Widget type inspection is required.
class FrostButtonInkBounds extends SingleChildRenderObjectWidget {
  const FrostButtonInkBounds({required this.inset, required this.automatic, required super.child, super.key});
  final double inset;
  final bool automatic;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderButtonInkBounds(inset, automatic);
  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    final marker = renderObject as _RenderButtonInkBounds;
    marker.inset = inset;
    marker.automatic = automatic;
    marker.markNeedsLayout();
  }
}

class _RenderButtonInkBounds extends RenderProxyBox {
  _RenderButtonInkBounds(this.inset, this.automatic);
  double inset;
  bool automatic;
  Rect layoutBounds = Rect.zero;
  @override
  void performLayout() {
    super.performLayout();
    layoutBounds = Rect.fromLTWH(0, 0, size.width, size.height);
  }
}

/// Aligns the last shared plain icon in an arbitrary trailing composition.
/// Layout width and sibling button spacing stay intact. Only the complete
/// trailing cluster moves into its available keyline margin; hit testing and
/// focus use that same offset, including beyond the row's normal bounds.
class FrostRowTrailingAlignment extends SingleChildRenderObjectWidget {
  const FrostRowTrailingAlignment({required this.enabled, required super.child, super.key});
  final bool enabled;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowTrailing(enabled, Directionality.of(context), FrostKeyline.maybeOf(context)?.trailingRoom ?? 0);
  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    final trailing = renderObject as _RenderRowTrailing;
    trailing.enabled = enabled;
    trailing.direction = Directionality.of(context);
    trailing.room = FrostKeyline.maybeOf(context)?.trailingRoom ?? 0;
    trailing.markNeedsLayout();
  }
}

class _RenderRowTrailing extends _RenderBleed {
  _RenderRowTrailing(this.enabled, this.direction, this.room) : super(0, 0);
  bool enabled;
  TextDirection direction;
  double room;
  @override
  Size computeDryLayout(BoxConstraints constraints) => child!.getDryLayout(constraints);
  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child!.size);
    final data = child!.parentData! as BoxParentData;
    data.offset = Offset.zero;
    if (!enabled || room == 0) return;
    _RenderButtonInkBounds? last;
    Rect? bounds;
    final rtl = direction == TextDirection.rtl;
    void find(RenderObject object, Offset offset) {
      if (object is RenderOffstage && object.offstage) return;
      if (object is _RenderButtonInkBounds && object.hasSize) {
        // Alignment follows layout, not a Presence/press paint transform.
        // Reading descendant Transform.size during ancestor layout is invalid.
        final rect = object.layoutBounds.shift(offset);
        if (bounds == null || (rtl ? rect.left < bounds!.left : rect.right > bounds!.right)) {
          last = object;
          bounds = rect;
        }
        return;
      }
      object.visitChildren((child) {
        final data = child.parentData;
        find(child, offset + (data is BoxParentData ? data.offset : Offset.zero));
      });
    }

    find(child!, Offset.zero);
    if (last?.automatic != true) return;
    final gap = rtl ? bounds!.left : size.width - bounds!.right;
    final amount = math.min(room, math.max(0.0, gap + last!.inset));
    data.offset = Offset(rtl ? -amount : amount, 0);
  }
}
