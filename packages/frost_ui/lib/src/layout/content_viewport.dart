import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../primitives/_page_outline.dart';
import '../primitives/keyline.dart';
import '_content_padding.dart';
import '_page_scroll_behavior.dart';
import 'column_placement.dart';

/// Measures content in the space remaining after window navigation.
class FrostContentViewport extends StatelessWidget {
  const FrostContentViewport({required this.child, this.navigationReserve, super.key});
  final Widget child;
  final double? navigationReserve;

  @override
  Widget build(BuildContext context) {
    final reserve = navigationReserve ?? FrostContentColumnBudget.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => FrostContentColumnBudget(
        reservedWidth: reserve,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(FrostPageOutline.contentWidth(context, constraints.maxWidth), constraints.maxHeight)),
          child: ScrollConfiguration(behavior: FrostPageScrollBehavior(ScrollConfiguration.of(context)), child: child),
        ),
      ),
    );
  }
}

/// Keeps responsive column counts stable while the user opens the sidebar.
/// The count still follows the window, text scale, and each grid's own inset.
class FrostContentColumnBudget extends InheritedWidget {
  const FrostContentColumnBudget({required this.reservedWidth, required super.child, super.key});

  final double reservedWidth;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostContentColumnBudget>()?.reservedWidth ?? 0;

  static double columnWidth(BuildContext context, double availableWidth) => math.max(0, availableWidth - of(context));

  @override
  bool updateShouldNotify(FrostContentColumnBudget oldWidget) => reservedWidth != oldWidget.reservedWidth;
}

/// A page's content column: start-aligned, at most [maxWidth] wide, and inset by
/// [FrostMetrics.columnPadding] so every page shares the same edges.
class FrostContentColumn extends StatelessWidget {
  const FrostContentColumn({required this.child, this.maxWidth = FrostMetrics.contentMaxWidth, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = FrostColumnPlacement.columnPadding(context, constraints.maxWidth, maxWidth: maxWidth);
        return _ContentKeyline(
          insets: insets,
          child: FrostBleedBoundary(
            child: Padding(padding: insets, child: child),
          ),
        );
      },
    );
  }
}

/// [FrostContentColumn] for a sliver inside a scroll view; the scroll view itself
/// stays full width so its scrollbar remains at the window edge.
class FrostSliverContentColumn extends StatelessWidget {
  const FrostSliverContentColumn({required this.sliver, this.maxWidth = FrostMetrics.contentMaxWidth, super.key});

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final insets = FrostColumnPlacement.columnPadding(context, constraints.crossAxisExtent, maxWidth: maxWidth);
        return _ContentKeyline(
          insets: insets,
          child: FrostSliverBleedBoundary(
            child: SliverPadding(padding: insets, sliver: sliver),
          ),
        );
      },
    );
  }
}

/// Box and sliver columns expose the same alignment and bleed budget.
class _ContentKeyline extends StatelessWidget {
  const _ContentKeyline({required this.insets, required this.child});
  final EdgeInsets insets;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return FrostKeyline(
      leadingRoom: rtl ? insets.right : insets.left,
      trailingRoom: rtl ? insets.left : insets.right,
      edgeDistanceStart: rtl ? insets.right : insets.left,
      edgeDistanceEnd: rtl ? insets.left : insets.right,
      contentStart: rtl ? insets.right : insets.left,
      insideContainer: false,
      child: FrostPageOutline.content(context, FrostContentPadding(padding: null, child: child)),
    );
  }
}
