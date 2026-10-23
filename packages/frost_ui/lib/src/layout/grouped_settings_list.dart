import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../lists/grouped_section.dart';
import '../primitives/_page_outline.dart';
import 'column_placement.dart';

class FrostGroupedSettingsList extends StatelessWidget {
  const FrostGroupedSettingsList({required this.groups, this.horizontalPadding, super.key});

  final List<List<Widget>> groups;

  /// Defaults to the shared content column; a split settings pane passes the
  /// part of the column its list occupies.
  final EdgeInsets? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.sizeOf(context).width >= 600 ? FrostGap.of(context).section : FrostGap.of(context).page;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = horizontalPadding == null
            ? FrostColumnPlacement.columnPadding(context, constraints.maxWidth, maxWidth: FrostMetrics.settingsMaxWidth)
            : horizontalPadding!.copyWith(right: horizontalPadding!.right + FrostPageOutline.channelOf(context));
        return ListView.separated(
          primary: false,
          padding: EdgeInsets.fromLTRB(
            horizontal.left,
            topPadding + MediaQuery.paddingOf(context).top,
            horizontal.right,
            FrostGap.of(context).section + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: groups.length,
          separatorBuilder: (_, _) => SizedBox(height: FrostGap.of(context).section),
          itemBuilder: (context, groupIndex) {
            final items = groups[groupIndex];
            return FrostGroupedSection(children: items);
          },
        );
      },
    );
  }
}
