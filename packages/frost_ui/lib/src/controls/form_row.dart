import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../lists/_row_layout.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';

/// A label and options share a row only when both natural widths fit. Otherwise
/// options move below the label on the very first layout. The same children,
/// focus and editing state survive reflow. Use finite natural-width content.
class FrostFormRow extends StatefulWidget {
  const FrostFormRow({required this.label, required this.control, super.key});
  final Widget label, control;
  @override
  State<FrostFormRow> createState() => _FormRowState();
}

class _FormRowState extends State<FrostFormRow> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMotionSize(
    duration: FrostMotion.duration(context, FrostMotion.layoutFade),
    child: FrostLayoutCrossfade(
      layoutIdentity: _identity,
      child: FrostRowLayout(
        identity: _identity,
        contentIdentity: (widget.label.key, widget.control.key),
        minimumHeight: 0,
        verticalInset: 0,
        inset: EdgeInsets.zero,
        stackedGap: FrostGap.related,
        direction: Directionality.of(context),
        children: [
          FrostRowSlot(id: FrostRowPart.text, includeSemantics: true, child: widget.label),
          FrostRowSlot(id: FrostRowPart.value, includeSemantics: true, child: widget.control),
        ],
      ),
    ),
  );
}
