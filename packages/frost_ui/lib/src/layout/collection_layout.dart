import 'package:flutter/widgets.dart';

import '../display/stat.dart';
import '../foundation/spacing.dart';
import '_template_scroll.dart';

/// A collection header with scrolling tools, uncontained stats and slivers.
/// For selection, use Column(children: [Expanded(child: thisLayout),
/// FrostSelectionBar(selection: selection, allItems: items)]). Keep this
/// layout's key stable so bottom-slot resizing preserves its scroll position.
/// A Stack overlay instead requires the caller to reserve the bar's height.
class FrostCollectionLayout extends StatelessWidget {
  const FrostCollectionLayout({required this.header, required this.slivers, this.toolbar, this.stats = const [], super.key});
  final Widget header;
  final Widget? toolbar;
  final List<FrostStat> stats;
  final List<Widget> slivers;
  @override
  Widget build(BuildContext context) => FrostTemplateScroll(
    header: header,
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostTemplateOptional(child: toolbar),
            FrostTemplateOptional(
              child: stats.isEmpty
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(top: toolbar == null ? FrostGap.section : FrostGap.group, bottom: slivers.isEmpty ? 0 : FrostGap.section),
                      child: FrostStatStrip(stats: stats),
                    ),
            ),
          ],
        ),
      ),
      ...slivers,
    ],
  );
}
