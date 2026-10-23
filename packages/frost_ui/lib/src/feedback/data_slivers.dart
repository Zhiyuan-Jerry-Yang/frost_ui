import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:loading_more_list/loading_more_list.dart';

import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../layout/content_viewport.dart';
import '../layout/waterfall_grid.dart';
import 'empty_state.dart';
import 'list_source.dart';
import 'loading_more_indicator.dart';
import 'refresh_indicator.dart';

export 'loading_more_indicator.dart' show FrostLoadingMoreIndicator;

/// A source-owned paged list. Mix with arbitrary slivers in FrostLoadingScrollView.
/// The page creates/disposes [source]; this widget never copies its items.
class FrostSliverDataList<T> extends StatelessWidget {
  const FrostSliverDataList({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.empty,
    this.padding,
    this.itemExtent,
    this.autoLoadMore = true,
    super.key,
  });
  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;

  /// Explicit first-load geometry; next pages use the shared three-dot footer.
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final bool autoLoadMore;
  @override
  Widget build(BuildContext context) => _PagedSliver<T>(
    source: source,
    firstLoadSkeleton: firstLoadSkeleton,
    empty: empty,
    autoLoadMore: autoLoadMore,
    contentBuilder: (context) {
      final delegate = SliverChildBuilderDelegate((context, index) => itemBuilder(context, source[index], index), childCount: source.length);
      final content = itemExtent == null ? SliverList(delegate: delegate) : SliverFixedExtentList(delegate: delegate, itemExtent: itemExtent!);
      return padding == null ? content : SliverPadding(padding: padding!, sliver: content);
    },
  );
}

/// The shared, state-preserving media waterfall with source-owned pagination.
class FrostSliverDataWaterfallGrid<T> extends StatelessWidget {
  const FrostSliverDataWaterfallGrid({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.empty,
    this.preferredTileWidth = FrostMetrics.gridExtent,
    this.crossAxisSpacing = FrostGap.grid,
    this.mainAxisSpacing = FrostGap.grid,
    this.padding,
    this.columns,
    this.maxColumns,
    this.autoLoadMore = true,
    super.key,
  });
  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final double preferredTileWidth, crossAxisSpacing, mainAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final int? columns, maxColumns;
  final bool autoLoadMore;
  @override
  Widget build(BuildContext context) => _PagedSliver<T>(
    source: source,
    firstLoadSkeleton: firstLoadSkeleton,
    empty: empty,
    autoLoadMore: autoLoadMore,
    contentBuilder: (_) => FrostSliverWaterfallGrid<T>(
      items: source.items,
      itemBuilder: itemBuilder,
      preferredTileWidth: preferredTileWidth,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      padding: padding,
      columns: columns,
      maxColumns: maxColumns,
    ),
  );
}

/// Equal-height cards in fixed rows; the footer always spans the whole row.
class FrostSliverDataGrid<T> extends StatelessWidget {
  const FrostSliverDataGrid({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.empty,
    required this.minTileWidth,
    required this.tileHeight,
    this.spacing = FrostGap.grid,
    super.key,
  });
  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final double minTileWidth, spacing;
  final double Function(BuildContext context, double tileWidth) tileHeight;
  static ({EdgeInsets padding, int columns, double tileWidth}) geometry(
    BuildContext context,
    double crossAxisExtent, {
    required double minTileWidth,
    double spacing = FrostGap.grid,
  }) {
    final padding = frostBrowseGridPadding(crossAxisExtent);
    final width = crossAxisExtent - padding.horizontal;
    final count = frostFittedColumnCount(
      width: FrostContentColumnBudget.columnWidth(context, width),
      minTileWidth: minTileWidth,
      gap: spacing,
      textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    return (padding: padding, columns: count, tileWidth: (width - spacing * (count - 1)) / count);
  }

  @override
  Widget build(BuildContext context) => _PagedSliver<T>(
    source: source,
    firstLoadSkeleton: firstLoadSkeleton,
    empty: empty,
    autoLoadMore: true,
    contentBuilder: (_) => SliverLayoutBuilder(
      builder: (context, constraints) {
        final layout = geometry(context, constraints.crossAxisExtent, minTileWidth: minTileWidth, spacing: spacing);
        return SliverPadding(
          padding: layout.padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: tileHeight(context, layout.tileWidth),
            ),
            delegate: SliverChildBuilderDelegate((context, index) => itemBuilder(context, source[index], index), childCount: source.length),
          ),
        );
      },
    ),
  );
}

class _PagedSliver<T> extends StatefulWidget {
  const _PagedSliver({required this.source, required this.contentBuilder, required this.firstLoadSkeleton, this.empty, required this.autoLoadMore});
  final FrostListSource<T> source;
  final WidgetBuilder contentBuilder;
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final bool autoLoadMore;
  @override
  State<_PagedSliver<T>> createState() => _PagedSliverState<T>();
}

class _PagedSliverState<T> extends State<_PagedSliver<T>> {
  late _PagedConfig<T> _config = _makeConfig();
  _PagedConfig<T> _makeConfig() => _PagedConfig<T>(widget.source, () => widget, () => mounted);
  @override
  void didUpdateWidget(_PagedSliver<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _config = _makeConfig();
  }

  @override
  Widget build(BuildContext context) => LoadingMoreSliverList<T>(_config);
}

// Use the package's public renderer extension: registration and preload still
// belong to LoadingMoreCustomScrollView; there is no second item/state bridge.
class _PagedConfig<T> extends SliverListConfig<T> {
  _PagedConfig(this.source, this.current, this.isMounted)
    : super(sourceList: source, itemBuilder: (context, item, index) => const SizedBox.shrink(), autoRefresh: true, lock: false, showNoMore: true);
  final FrostListSource<T> source;
  final _PagedSliver<T> Function() current;
  final bool Function() isMounted;
  bool get _active => isMounted() && identical(current().source, source);
  @override
  bool get hasMore => _active && source.hasMore;
  @override
  bool get isLoading => _active && source.busy;
  @override
  bool get hasError => _active && source.lastError != null;
  @override
  bool get autoLoadMore => _active && current().autoLoadMore;
  Future<bool> _safe(Future<bool> Function() action) async {
    // Package preload can run while a sliver is laying out. Request writes
    // start after that frame, never from a build or render callback.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      await SchedulerBinding.instance.endOfFrame;
    } else {
      await Future<void>.value();
    }
    return _active ? action() : false;
  }

  @override
  Future<bool> refresh([bool notifyStateChanged = false]) => _safe(() => source.refresh(notifyStateChanged));
  @override
  Future<bool> loadMore() => _safe(source.loadMore);
  @override
  Widget buildContent(BuildContext context) {
    final widget = current();
    switch (source.phase) {
      case FrostLoadPhase.loading:
        if (!source.busy) refresh(true);
        return SliverToBoxAdapter(child: widget.firstLoadSkeleton);
      case FrostLoadPhase.error:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: FrostPagedError(key: ObjectKey(source), source: source, placement: FrostPagedErrorPlacement.page),
        );
      case FrostLoadPhase.empty:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: widget.empty ?? FrostEmptyState(icon: FrostIconSet.of(context).empty, title: FrostScope.labelsOf(context).noItems),
        );
      case FrostLoadPhase.content:
        return SliverMainAxisGroup(
          slivers: [
            widget.contentBuilder(context),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final near = constraints.remainingCacheExtent > 0;
                if (near && autoLoadMore && source.hasMore && !source.busy && source.lastError == null) loadMore();
                return SliverToBoxAdapter(
                  child: TickerMode(
                    enabled: near,
                    child: FrostLoadingMoreIndicator(source: source),
                  ),
                );
              },
            ),
          ],
        );
    }
  }
}
