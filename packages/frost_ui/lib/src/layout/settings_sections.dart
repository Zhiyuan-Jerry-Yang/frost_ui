import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../navigation/_navigation_tile.dart';
import '../primitives/_page_outline.dart';
import '../primitives/divider.dart';
import '../primitives/keyline.dart';
import '_content_padding.dart';
import 'auto_scaffold.dart';
import 'column_placement.dart';
import 'content_viewport.dart';
import 'grouped_settings_list.dart';
import 'pinned_chrome.dart';

// Builder navigation and content limits include their own page insets.
const _builderNavigationWidth = 236.0, _builderContentMaxWidth = 640.0;
// The content keyline is 32 points beyond the one-physical-pixel divider.
const _builderContentInset = 32.0;

/// Settings split into sections: a section list beside the selected group on
/// wide windows, every group in one list otherwise.
class FrostSettingsSections extends StatefulWidget {
  const FrostSettingsSections({required this.labels, required this.groups, this.status, super.key})
    : _controlledIndex = null,
      _onSelected = null,
      _sectionBuilder = null,
      icons = null,
      compactNavigationBuilder = null,
      header = null,
      section = null,
      onNavigate = null,
      assert(labels.length == groups.length);

  /// A controlled section navigator. Sufficient local space builds the selected
  /// content beside a 236-point navigation pane and a hairline, with a 32-point
  /// gap to the content keyline and a 640-point content limit. The section owns
  /// its full-width scroll view; put FrostContentColumn inside that viewport
  /// (or FrostSliverContentColumn around slivers) to consume the shared keyline.
  /// Its first row aligns with the first navigation row.
  /// Narrow available space shows only navigation; [onSelected] should push the
  /// corresponding section page. Content is first built on a wide window and
  /// stays mounted while that window narrows. Supply a finite-height body.
  const FrostSettingsSections.builder({
    required this.labels,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required IndexedWidgetBuilder sectionBuilder,
    this.icons,
    this.compactNavigationBuilder,
    this.header,
    this.section,
    this.onNavigate,
    this.status,
    super.key,
  }) : groups = const [],
       _controlledIndex = selectedIndex,
       // Public non-null callbacks coexist with the legacy constructor.
       // ignore: prefer_initializing_formals
       _onSelected = onSelected,
       // ignore: prefer_initializing_formals
       _sectionBuilder = sectionBuilder,
       assert(icons == null || icons.length == labels.length),
       assert(labels.length == 0 ? selectedIndex == 0 : selectedIndex >= 0 && selectedIndex < labels.length);

  final int? _controlledIndex;
  final ValueChanged<int>? _onSelected;
  final IndexedWidgetBuilder? _sectionBuilder;
  final List<String> labels;

  /// Optional navigation icons, in exactly the same order as [labels].
  final List<FrostIconData>? icons;

  /// Replaces only the narrow navigation. Compose grouped settings rows
  /// with current values and badges, and use the same controlled [onSelected]
  /// callback held by the caller to open each section. Receives finite height.
  final WidgetBuilder? compactNavigationBuilder;

  /// Shared page chrome above navigation and the split panes.
  final Widget? header;

  /// The routed section page, displayed when the split panes cannot fit.
  /// Its own header replaces [header]. Wide windows keep the selected pane.
  final Widget? section;

  /// Narrow navigation opens a section route instead of replacing a pane.
  /// When omitted, the existing controlled onSelected callback is used.
  final ValueChanged<int>? onNavigate;
  final List<List<Widget>> groups;

  /// A row kept above the selected group on wide windows and above all
  /// groups otherwise, such as a pending save or a sync state.
  final Widget? status;

  @override
  State<FrostSettingsSections> createState() => _SettingsSectionsState();
}

class _SettingsSectionsState extends State<FrostSettingsSections> {
  static const _sectionListWidth = 200.0;

  int _selected = 0;
  bool _builtSection = false;
  final List<FocusNode> _sectionFocus = [];

  @override
  void initState() {
    super.initState();
    _syncFocus();
  }

  void _syncFocus() {
    while (_sectionFocus.length < widget.labels.length) {
      _sectionFocus.add(FocusNode());
    }
    while (_sectionFocus.length > widget.labels.length) {
      _sectionFocus.removeLast().dispose();
    }
    if (_selected >= widget.labels.length) _selected = 0;
  }

  @override
  void didUpdateWidget(FrostSettingsSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
  }

  @override
  void dispose() {
    for (final node in _sectionFocus) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _moveFocus(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    final index = _sectionFocus.indexWhere((node) => node.hasFocus);
    if (delta == 0 || index < 0) return KeyEventResult.ignored;
    final target = (index + delta).clamp(0, _sectionFocus.length - 1);
    _sectionFocus[target].requestFocus();
    if (_sectionFocus[target].context case final targetContext?) Scrollable.ensureVisible(targetContext);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget._sectionBuilder != null) return _controlled(context, constraints);
        if (widget.groups.isEmpty || !FrostAutoScaffold.usesHorizontalLayoutOf(context) || constraints.maxWidth < 720) {
          return FrostGroupedSettingsList(
            groups: [
              if (widget.status case final status?) [status],
              ...widget.groups,
            ],
          );
        }
        // The section list and the groups share the pages' content column:
        // the list starts at the column's left edge and the groups end at its
        // right edge, while the groups' scroll view still reaches the window
        // edge for its scrollbar.
        final column = FrostMetrics.columnPadding(constraints.maxWidth, maxWidth: FrostMetrics.settingsMaxWidth);
        return SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: column.left + _sectionListWidth,
                child: Focus(
                  onKeyEvent: _moveFocus,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(column.left, FrostGap.of(context).section, 0, FrostGap.of(context).section),
                    itemCount: widget.labels.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: FrostGap.inline),
                      child: FrostNavigationTile(
                        label: widget.labels[index],
                        selected: _selected == index,
                        focusNode: _sectionFocus[index],
                        onTap: () => setState(() => _selected = index),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: FrostGap.of(context).section),
              Expanded(
                child: FrostGroupedSettingsList(
                  key: PageStorageKey('settings-$_selected'),
                  groups: [
                    if (widget.status case final status?) [status],
                    widget.groups[_selected],
                  ],
                  horizontalPadding: EdgeInsets.only(right: column.right),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _controlled(BuildContext context, BoxConstraints constraints) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();
    // Navigation plus a readable form column and their real keyline gap.
    const minimumFormWidth = 320.0;
    final wide = constraints.maxWidth >= _builderNavigationWidth + _builderContentInset + minimumFormWidth + FrostGap.of(context).page;
    _builtSection |= wide;
    final gap = FrostGap.of(context);
    final selected = widget._controlledIndex!;
    final dividerWidth = 1 / MediaQuery.devicePixelRatioOf(context);
    final panes = FrostBleedBoundary(
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: wide ? _builderNavigationWidth : constraints.maxWidth,
            child: !wide && widget.compactNavigationBuilder != null
                ? widget.compactNavigationBuilder!(context)
                : Focus(
                    onKeyEvent: _moveFocus,
                    child: ListView.builder(
                      primary: false,
                      padding: EdgeInsets.fromLTRB(
                        wide ? FrostGap.related : gap.page,
                        wide ? 0 : gap.section,
                        (wide ? FrostGap.related : gap.page) + (wide ? 0 : FrostPageOutline.channelOf(context)),
                        wide ? 0 : gap.section,
                      ),
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: FrostGap.inline),
                        child: FrostNavigationTile(
                          label: widget.labels[index],
                          selected: wide && selected == index,
                          icon: widget.icons?[index],
                          focusNode: _sectionFocus[index],
                          onTap: () => (wide ? widget._onSelected! : widget.onNavigate ?? widget._onSelected!)(index),
                        ),
                      ),
                    ),
                  ),
          ),
          if (wide)
            PositionedDirectional(
              start: _builderNavigationWidth,
              top: 0,
              bottom: 0,
              width: dividerWidth,
              child: const FrostDivider(axis: Axis.vertical),
            ),
          // Keep the same content slot and bounded geometry even while hidden.
          // Narrowing the window must not dispose the currently mounted section.
          PositionedDirectional(
            key: const ValueKey('settings-section-content'),
            start: wide ? _builderNavigationWidth + dividerWidth : 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: Offstage(
              offstage: !wide,
              child: FrostColumnPlacement(
                alignment: Directionality.of(context) == TextDirection.ltr ? FrostColumnAlignment.start : FrostColumnAlignment.end,
                maxWidth: _builderContentMaxWidth + _builderContentInset + FrostMetrics.browseInset(constraints.maxWidth),
                child: FrostContentPadding(
                  padding: EdgeInsetsDirectional.only(start: _builderContentInset, end: FrostMetrics.browseInset(constraints.maxWidth)),
                  child: !_builtSection
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.status case final status?) FrostContentColumn(child: status),
                            Expanded(
                              child: KeyedSubtree(key: ValueKey(selected), child: widget._sectionBuilder!(context, selected)),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final Widget body;
    if (!wide && widget.section != null) {
      body = widget.section!;
    } else if (widget.header != null) {
      body = FrostPinnedChrome(
        chrome: FrostContentColumn(maxWidth: double.infinity, child: widget.header!),
        body: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: panes,
          ),
        ),
      );
    } else {
      body = panes;
    }
    return ColoredBox(
      color: FrostThemeTokens.of(context).canvas.withValues(alpha: wide ? 0 : 1),
      child: body,
    );
  }
}
