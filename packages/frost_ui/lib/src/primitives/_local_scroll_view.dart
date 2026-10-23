import 'package:flutter/widgets.dart';

/// Inline content keeps its offset only while mounted. PageStorage belongs to
/// the enclosing page, whose vertical offset is invalid for an inline scroller.
class FrostLocalScrollView extends StatefulWidget {
  const FrostLocalScrollView({required this.child, this.scrollDirection = Axis.horizontal, this.reverse = false, super.key});
  final Widget child;
  final Axis scrollDirection;
  final bool reverse;
  @override
  State<FrostLocalScrollView> createState() => _LocalScrollViewState();
}

class _LocalScrollViewState extends State<FrostLocalScrollView> {
  final _scroll = ScrollController(keepScrollOffset: false);
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(controller: _scroll, scrollDirection: widget.scrollDirection, reverse: widget.reverse, child: widget.child);
}
