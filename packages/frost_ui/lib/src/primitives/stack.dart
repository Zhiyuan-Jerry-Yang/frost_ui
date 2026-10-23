import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import 'divider.dart';

enum FrostGapSize { none, inline, related, group, section, grid }

/// A row or column with density-aware semantic gaps.
class FrostStack extends StatelessWidget {
  const FrostStack.vertical({
    required this.children,
    this.gap = FrostGapSize.related,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.dividers = false,
    super.key,
  }) : axis = Axis.vertical;
  const FrostStack.horizontal({
    required this.children,
    this.gap = FrostGapSize.related,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
    this.dividers = false,
    super.key,
  }) : axis = Axis.horizontal;

  final List<Widget> children;
  final FrostGapSize gap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final bool dividers;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final spacing = FrostGap.of(context);
    final distance = switch (gap) {
      FrostGapSize.none => 0.0,
      FrostGapSize.inline => spacing.inline,
      FrostGapSize.related => spacing.related,
      FrostGapSize.group => spacing.group,
      FrostGapSize.section => spacing.section,
      FrostGapSize.grid => spacing.grid,
    };
    Widget space(double value) => axis == Axis.vertical ? SizedBox(height: value) : SizedBox(width: value);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        if (dividers) {
          items.addAll([space(distance / 2), FrostDivider(axis: axis == Axis.vertical ? Axis.horizontal : Axis.vertical), space(distance / 2)]);
        } else {
          items.add(space(distance));
        }
      }
      items.add(children[i]);
    }
    final flex = Flex(
      direction: axis,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: items,
    );
    return dividers && axis == Axis.horizontal ? IntrinsicHeight(child: flex) : flex;
  }
}
