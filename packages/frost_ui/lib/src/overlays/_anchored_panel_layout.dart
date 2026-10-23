import 'dart:math' as math;
import 'package:flutter/widgets.dart';

// Menus and popovers share this viewport margin and anchor gap (zero).
const frostAnchoredPanelMargin = 8.0;
const frostAnchoredPanelGap = Offset.zero;

class FrostAnchoredPanelLayout extends SingleChildLayoutDelegate {
  const FrostAnchoredPanelLayout({required this.anchor, required this.offset, required this.below, required this.margin, this.insets = EdgeInsets.zero});

  final Rect anchor;
  final Offset offset;
  final bool below;
  final double margin;
  final EdgeInsets insets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = math.max(0.0, constraints.maxHeight - insets.vertical - margin * 2);
    final room = math.min(
      available,
      math.max(constraints.maxHeight - insets.bottom - anchor.bottom - offset.dy - margin, anchor.top - insets.top - offset.dy - margin),
    );
    return BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - insets.horizontal - margin * 2), maxHeight: math.max(0, room));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final desiredLeft = anchor.left + offset.dx;
    final flipLeft = anchor.isEmpty && desiredLeft + childSize.width > size.width - margin;
    final left = (flipLeft ? anchor.left - offset.dx - childSize.width : desiredLeft)
        .clamp(insets.left + margin, math.max(insets.left + margin, size.width - insets.right - childSize.width - margin))
        .toDouble();
    final fitsBelow = anchor.bottom + offset.dy + childSize.height <= size.height - insets.bottom - margin;
    final top = (fitsBelow ? anchor.bottom + offset.dy : anchor.top - offset.dy - childSize.height)
        .clamp(insets.top + margin, math.max(insets.top + margin, size.height - insets.bottom - childSize.height - margin))
        .toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(FrostAnchoredPanelLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      offset != oldDelegate.offset ||
      below != oldDelegate.below ||
      margin != oldDelegate.margin ||
      insets != oldDelegate.insets;
}
