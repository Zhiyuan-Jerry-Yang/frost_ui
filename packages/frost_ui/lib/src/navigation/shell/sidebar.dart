part of 'shell.dart';

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.secondaryDestinations,
    required this.selectedSecondaryIndex,
    required this.metrics,
    required this.itemForm,
    required this.progress,
    required this.controls,
    this.backControl,

    required this.onDestinationSelected,
    required this.onSecondarySelected,
    required this.moreButtonFocus,
  });

  final List<FrostNavDestination> destinations;
  final int? selectedIndex;
  final List<FrostNavDestination> secondaryDestinations;
  final int? selectedSecondaryIndex;
  final FrostNavigationMetrics metrics;
  final FrostNavItemForm itemForm;
  final double progress;
  final Widget controls;
  final Widget? backControl;

  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onSecondarySelected;
  final FocusNode moreButtonFocus;

  static const _innerPadding = 8.0;
  // Keep the final destination clear of the fading edge in short windows.
  static const _navigationScrollTailSpace = 88.0;

  /// One stationary icon axis shared by navigation and the title-row Back.
  static double iconAxis(FrostNavigationMetrics metrics, double progress) => metrics.railWidth / 2;

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    // The flush form keeps More and the secondary group at the bottom, apart
    // from the destinations; the tile form keeps them after the list.
    final secondaryAtBottom = itemForm == FrostNavItemForm.indicator;
    final Widget? secondary = secondaryDestinations.isEmpty
        ? null
        : Stack(
            alignment: Alignment.topLeft,
            children: [
              IgnorePointer(
                ignoring: progress > .25,
                child: ExcludeFocus(
                  excluding: progress > .25,
                  child: Opacity(
                    opacity: (1 - progress * 4).clamp(0.0, 1.0),
                    child: Builder(
                      builder: (buttonContext) {
                        void open() => _showMore(buttonContext, secondaryDestinations, selectedSecondaryIndex, onSecondarySelected, moreButtonFocus);
                        return Focus(
                          focusNode: moreButtonFocus,
                          skipTraversal: true,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent || (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.space)) {
                              return KeyEventResult.ignored;
                            }
                            open();
                            return KeyEventResult.handled;
                          },
                          child: FrostNavItem(
                            form: itemForm,
                            indicatorInset: _innerPadding,
                            label: labels.more,
                            icon: icons.more,
                            selected: selectedSecondaryIndex != null,
                            progress: progress,
                            onTap: open,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: progress <= .25,
                child: ExcludeFocus(
                  excluding: progress <= .25,
                  // While collapsed the hidden group takes no
                  // height, so a list that fits never scrolls; it
                  // grows with the sidebar as it expands.
                  child: ClipRect(
                    // Settled open, the items may mark selection on the panel edge.
                    clipBehavior: progress >= 1 ? Clip.none : Clip.hardEdge,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: progress.clamp(0.0, 1.0),
                      child: Opacity(
                        opacity: ((progress - .25) * 4 / 3).clamp(0.0, 1.0),
                        child: Column(
                          children: [
                            // Secondary destinations get a quiet group
                            // divider so they do not read as primary.
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: FrostGap.group),
                              child: FrostDivider(),
                            ),
                            const SizedBox(height: FrostGap.related),
                            for (final (index, destination) in secondaryDestinations.indexed) ...[
                              _DestinationItem(
                                destination: destination,
                                child: FrostNavItem(
                                  form: itemForm,
                                  indicatorInset: _innerPadding,
                                  label: destination.label,
                                  icon: destination.icon,
                                  selected: selectedSecondaryIndex == index,
                                  progress: progress,
                                  labelOpacity: ((progress - .85) / .15).clamp(0.0, 1.0),
                                  onTap: () => onSecondarySelected(index),
                                ),
                              ),
                              const SizedBox(height: FrostGap.inline),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
    return _SidebarIconAxis(
      value: metrics.railWidth / 2 - _innerPadding,
      itemWidth: metrics.expandedWidth - 2 * _innerPadding,
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeBottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: FrostGap.related),
          child: Column(
            children: [
              if (backControl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _innerPadding),
                  child: backControl,
                ),
              const SizedBox(height: FrostGap.inline),
              Expanded(
                child: _EdgeFadeScrollView(
                  // The list spans the whole panel so an item can mark its
                  // selection on the panel edge; the items keep the inset.
                  padding: const EdgeInsets.fromLTRB(_innerPadding, 0, _innerPadding, _navigationScrollTailSpace),
                  children: [
                    for (var index = 0; index < destinations.length; index++) ...[
                      if (index > 0) const SizedBox(height: FrostGap.inline),
                      _DestinationItem(
                        destination: destinations[index],
                        child: FrostNavItem(
                          form: itemForm,
                          indicatorInset: _innerPadding,
                          label: destinations[index].label,
                          icon: destinations[index].icon,
                          selected: selectedIndex == index,
                          progress: progress,
                          onTap: () => onDestinationSelected(index),
                        ),
                      ),
                    ],
                    if (secondary != null && !secondaryAtBottom) ...[
                      // Same rhythm as the primary items while collapsed; the
                      // expanded secondary group gets room for its divider.
                      SizedBox(height: lerpDouble(4, 16, progress)),
                      secondary,
                    ],
                  ],
                ),
              ),
              if (secondary != null && secondaryAtBottom)
                Padding(padding: const EdgeInsets.fromLTRB(_innerPadding, FrostGap.inline, _innerPadding, 0), child: secondary),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: metrics.railWidth,
                  child: Center(child: controls),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short-height windows scroll the navigation list without a scrollbar; the
/// edges fade so clipped items read as more content rather than a cut.
class _EdgeFadeScrollView extends StatefulWidget {
  const _EdgeFadeScrollView({required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  State<_EdgeFadeScrollView> createState() => _EdgeFadeScrollViewState();
}

class _EdgeFadeScrollViewState extends State<_EdgeFadeScrollView> {
  static const _fadeExtent = 20.0;
  bool _fadeTop = false;
  bool _fadeBottom = false;

  bool _update(ScrollMetrics metrics) {
    final top = metrics.extentBefore > 0.5;
    final bottom = metrics.extentAfter > 0.5;
    if (top != _fadeTop || bottom != _fadeBottom) {
      setState(() {
        _fadeTop = top;
        _fadeBottom = bottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final list = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _update(notification.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _update(notification.metrics),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView(primary: false, padding: widget.padding, children: widget.children),
        ),
      ),
    );
    if (!_fadeTop && !_fadeBottom) return list;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final edge = (_fadeExtent / math.max(1.0, bounds.height)).clamp(0.0, .5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_fadeTop ? Colors.transparent : FrostMask.opaque, FrostMask.opaque, FrostMask.opaque, _fadeBottom ? Colors.transparent : FrostMask.opaque],
          stops: [0, edge, 1 - edge, 1],
        ).createShader(bounds);
      },
      child: list,
    );
  }
}

/// Navigation destination in one of the [FrostNavItemForm]s. One animation
/// progress drives size, positions and the state marks so nothing jumps.
class FrostNavItem extends StatelessWidget {
  const FrostNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.form = FrostNavItemForm.tile,
    this.indicatorInset = 0,
    this.progress = 0,
    this.labelOpacity = 1,
    super.key,
  }) : _showsLabel = true;

  const FrostNavItem._back({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.progress,
    required this.form,
    required this.indicatorInset,
    super.key,
  }) : selected = false,
       labelOpacity = 0,
       _showsLabel = false;

  final bool _showsLabel;
  final String label;
  final FrostIconData icon;
  final bool selected;
  final FrostNavItemForm form;

  /// How far the item sits inside the sidebar's edge; the
  /// [FrostNavItemForm.indicator] bar is drawn that far out, on the edge.
  final double indicatorInset;
  final double progress;
  final double labelOpacity;
  final VoidCallback? onTap;

  /// Icon start in the expanded indicator row: the expansion button
  /// above and below centre on the same axis.
  static const _indicatorIconStart = 13.0;
  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final Widget item;
    if (form == FrostNavItemForm.tile) {
      item = FrostNavigationTile(
        label: label,
        icon: icon,
        selected: selected,
        onTap: onTap,
        progress: progress,
        labelOpacity: labelOpacity,
        showsLabel: _showsLabel,
        iconAxis: _SidebarIconAxis.maybeOf(context) ?? 24,
        physicalIconAxis: _SidebarIconAxis.maybeOf(context) != null,
        expandedLayoutWidth: _SidebarIconAxis.itemWidthOf(context),
      );
    } else {
      final tokens = FrostThemeTokens.of(context);
      item = FrostSelectionFeedback(
        selected: selected,
        foreground: selected ? tokens.accent : tokens.textSecondary,
        background: tokens.selectionFill.withValues(alpha: 0),
        builder: (context, ink, fill, scale) => _buildIndicator(context, ink, scale),
      );
    }
    return onTap == null ? ExcludeFocus(child: Opacity(opacity: .38, child: item)) : item;
  }

  Widget _buildIndicator(BuildContext context, Color ink, Animation<double> scale) {
    final tokens = FrostThemeTokens.of(context);
    final density = FrostDensity.of(context);
    final amount = progress.clamp(0.0, 1.0);
    final style = FrostTypography.of(context)
        .style(FrostTextRole.callout)
        .copyWith(color: ink, fontWeight: FrostTypography.of(context).style(selected ? FrostTextRole.headline : FrostTextRole.callout).fontWeight);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelHeight = painter.height;
    painter.dispose();
    final height = math.max(density.controlHeight, labelHeight + 16);

    final item = Semantics(
      button: true,
      selected: _showsLabel ? selected : null,
      enabled: _showsLabel ? null : onTap != null,
      label: FrostDestinationStatus.labelOf(context, label),
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FrostClickSurface(
            feedback: FrostClickFeedback.quiet,
            borderRadius: BorderRadius.circular(FrostRadius.md),
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final expandedWidth = _SidebarIconAxis.itemWidthOf(context);
                final fixedAxis = _SidebarIconAxis.maybeOf(context);
                final physicalLeft = fixedAxis == null ? lerpDouble((width - _iconSize) / 2, _indicatorIconStart, amount)! : fixedAxis - _iconSize / 2;
                final physicalRtl = fixedAxis != null && Directionality.of(context) == TextDirection.rtl;
                final iconStart = physicalRtl ? (expandedWidth ?? width) - physicalLeft - _iconSize : physicalLeft;
                final labelStart = physicalLeft + _iconSize + 12;
                return SizedBox(
                  width: double.infinity,
                  height: height,
                  child: FrostNavigationContent(
                    expandedWidth: expandedWidth,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PositionedDirectional(
                          start: iconStart,
                          top: (height - _iconSize) / 2,
                          child: ScaleTransition(
                            scale: scale,
                            child: FrostDestinationStatus.decorateIcon(
                              context,
                              FrostIcon(icon, size: _iconSize, color: ink),
                              expansion: amount,
                            ),
                          ),
                        ),
                        if (_showsLabel && amount > 0)
                          PositionedDirectional(
                            start: physicalRtl ? 8 : labelStart,
                            end: physicalRtl ? labelStart : 8,
                            top: (height - labelHeight) / 2,
                            child: Opacity(
                              // The label appears once the row has room for it.
                              opacity: ((amount - .4) / .6).clamp(0.0, 1.0) * labelOpacity,
                              child: LayoutBuilder(
                                builder: (context, constraints) => Row(
                                  children: [
                                    Expanded(
                                      child: FrostSkeletonText(
                                        child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: style),
                                      ),
                                    ),
                                    if (FrostDestinationStatus.of(context) case final status?)
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                                        child: FrostDestinationTrailing(status: status, ink: ink),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // The selection bar sits on the sidebar's edge, so it never
          // reads as part of the hover shape.
          PositionedDirectional(
            start: -indicatorInset,
            top: (height - 24) / 2,
            width: FrostMetrics.selectionIndicatorWidth,
            height: 24,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: FrostMotion.duration(context, FrostMotion.hover),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.keyGraphicOn(tokens.surface),
                  borderRadius: const BorderRadiusDirectional.horizontal(
                    end: Radius.circular(FrostMetrics.selectionIndicatorWidth),
                  ).resolve(Directionality.of(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // Collapsed, the label is only in the tooltip. The tooltip stays in the
    // tree either way so the hover state survives the expansion.
    return TooltipVisibility(
      visible: !_showsLabel || amount < .5,
      child: FrostTooltip(message: label, excludeFromSemantics: true, child: item),
    );
  }
}

Future<void> _showMore(
  BuildContext context,
  List<FrostNavDestination> destinations,
  int? selectedIndex,
  ValueChanged<int> onSelected,
  FocusNode buttonFocus,
) async {
  buttonFocus.requestFocus();
  await showFrostValueSheet<int>(
    context: context,
    title: FrostScope.labelsOf(context).more,
    items: [for (final (index, destination) in destinations.indexed) FrostPickerOption(value: index, label: destination.label, icon: destination.icon)],
    value: selectedIndex,
    onSelected: onSelected,
  );
  if (context.mounted && buttonFocus.canRequestFocus) buttonFocus.requestFocus();
}

// Internal metadata keeps arbitrary/custom rail widths on one stationary axis.
class _SidebarIconAxis extends InheritedWidget {
  const _SidebarIconAxis({required this.value, required this.itemWidth, required super.child});
  final double value, itemWidth;
  static double? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SidebarIconAxis>()?.value;
  static double? itemWidthOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SidebarIconAxis>()?.itemWidth;
  @override
  bool updateShouldNotify(_SidebarIconAxis oldWidget) => value != oldWidget.value || itemWidth != oldWidget.itemWidth;
}

// A distinct internal widget preserves the public destination item type for
// callers that inspect their navigation targets; rendering remains shared.
class _SidebarBack extends FrostNavItem {
  const _SidebarBack({
    required super.label,
    required super.icon,
    required super.onTap,
    required super.progress,
    required super.form,
    required super.indicatorInset,
    super.key,
  }) : super._back();
}
