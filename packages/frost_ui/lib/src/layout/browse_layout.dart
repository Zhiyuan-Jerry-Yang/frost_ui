import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/refresh_indicator.dart';
import '../foundation/metrics.dart';
import '../primitives/_page_outline.dart';
import '_content_padding.dart';
import '_template_scroll.dart';
import 'column_placement.dart';
import 'content_viewport.dart';

/// Media collections can meet the panel edge while text keeps the page keyline.
enum FrostBrowseContentInset { keyline, edge }

/// A fixed page header above scrolling filters and application-owned slivers.
/// The template supplies the shared content column and its alignment keyline.
/// For selection, use Column(children: [Expanded(child: thisLayout),
/// FrostSelectionBar(selection: selection, allItems: items)]). Keep this
/// layout's key stable so bottom-slot resizing preserves its scroll position.
/// A Stack overlay instead requires the caller to reserve the bar's height.
class FrostBrowseLayout extends StatelessWidget {
  const FrostBrowseLayout({
    required this.header,
    required this.slivers,
    this.filterBar,
    this.preloadExtent = 480,
    this.empty,
    this.isEmpty = false,
    this.maxWidth = FrostMetrics.contentMaxWidth,
    this.contentInset = FrostBrowseContentInset.keyline,
    super.key,
  }) : assert(maxWidth > 0);
  final Widget header;

  /// Distance before a paged section end at which another page may load.
  final double preloadExtent;
  final Widget? filterBar, empty;
  final List<Widget> slivers;
  final bool isEmpty;

  /// Outer content-column limit shared by the header, filters and slivers.
  /// Use double.infinity for fluid media collections; page insets still apply.
  final double maxWidth;

  /// Edge removes only the media slivers' page inset, without negative margins.
  /// Header and filter text retain the keyline. Keep prose/status slivers in a
  /// FrostSliverContentColumn when mixing them into an edge media collection.
  final FrostBrowseContentInset contentInset;
  @override
  Widget build(BuildContext context) => FrostTemplateScroll(
    header: header,
    maxWidth: maxWidth,
    layoutIdentity: isEmpty,
    scrollViewBuilder: (slivers) => FrostLoadingScrollView(slivers: slivers, preloadExtent: preloadExtent),
    insetSlivers: false,
    slivers: [
      FrostSliverContentColumn(
        maxWidth: maxWidth,
        sliver: SliverToBoxAdapter(child: FrostTemplateOptional(child: filterBar)),
      ),
      if (isEmpty)
        FrostSliverContentColumn(
          maxWidth: maxWidth,
          sliver: SliverFillRemaining(hasScrollBody: false, child: Center(child: empty)),
        )
      else if (contentInset == FrostBrowseContentInset.keyline)
        FrostSliverContentColumn(
          maxWidth: maxWidth,
          sliver: SliverMainAxisGroup(slivers: slivers),
        )
      else
        _EdgeSliverColumn(
          maxWidth: maxWidth,
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
    ],
  );
}

/// Retain the configured width cap/placement; remove only the page text inset.
class _EdgeSliverColumn extends StatelessWidget {
  const _EdgeSliverColumn({required this.maxWidth, required this.sliver});
  final double maxWidth;
  final Widget sliver;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final textInset = FrostMetrics.browseInset(FrostPageOutline.contentWidth(context, constraints.crossAxisExtent));
      final column = FrostColumnPlacement.columnPadding(context, constraints.crossAxisExtent, maxWidth: maxWidth);
      return SliverPadding(
        padding: EdgeInsets.only(left: math.max(0, column.left - textInset), right: math.max(0, column.right - textInset)),
        sliver: FrostPageOutline.content(context, FrostContentPadding(padding: null, child: sliver)),
      );
    },
  );
}
