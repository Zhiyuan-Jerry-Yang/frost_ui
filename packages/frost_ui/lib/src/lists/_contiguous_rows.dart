import 'package:flutter/widgets.dart';

import '../primitives/_measured_keyline.dart';
import '../primitives/divider.dart';
import '_row_scope.dart';

/// Shared row placement for a section and multi-row controls inside a section.
/// A nested group lends its last text anchor to the enclosing separator.
class FrostContiguousRows extends StatefulWidget {
  const FrostContiguousRows({required this.children, required this.corners, this.lastTextAnchor, super.key});
  final List<Widget> children;
  final BorderRadius corners;
  final GlobalKey? lastTextAnchor;
  @override
  State<FrostContiguousRows> createState() => _ContiguousRowsState();
}

class _ContiguousRowsState extends State<FrostContiguousRows> {
  final _anchors = <GlobalKey>[];
  void _syncAnchors() {
    while (_anchors.length < widget.children.length) {
      _anchors.add(GlobalKey());
    }
    if (_anchors.length > widget.children.length) _anchors.removeRange(widget.children.length, _anchors.length);
  }

  @override
  void initState() {
    super.initState();
    _syncAnchors();
  }

  @override
  void didUpdateWidget(FrostContiguousRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnchors();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < widget.children.length; index++) ...[
        FrostRowPlacement(
          textAnchor: index == widget.children.length - 1 ? widget.lastTextAnchor ?? _anchors[index] : _anchors[index],
          corners: BorderRadius.only(
            topLeft: index == 0 ? widget.corners.topLeft : Radius.zero,
            topRight: index == 0 ? widget.corners.topRight : Radius.zero,
            bottomLeft: index == widget.children.length - 1 ? widget.corners.bottomLeft : Radius.zero,
            bottomRight: index == widget.children.length - 1 ? widget.corners.bottomRight : Radius.zero,
          ),
          child: widget.children[index],
        ),
        if (index < widget.children.length - 1)
          FrostMeasuredKeyline(
            target: _anchors[index],
            child: const FrostDivider(inset: FrostDividerInset.keyline),
          ),
      ],
    ],
  );
}
