import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';

/// A token-spaced, direction-aware flow layout.
class FrostWrap extends StatelessWidget {
  const FrostWrap({required this.children, this.compact = false, super.key});
  final List<Widget> children;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final gaps = FrostGap.of(context), gap = compact ? gaps.inline : gaps.related;
    return Wrap(spacing: gap, runSpacing: gap, alignment: WrapAlignment.start, children: children);
  }
}
