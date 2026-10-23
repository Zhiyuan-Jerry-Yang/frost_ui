import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/presence.dart';
import 'content_viewport.dart';
import 'pinned_chrome.dart';

/// Shared page chrome and sliver column composition, without new materials.
class FrostTemplateScroll extends StatelessWidget {
  const FrostTemplateScroll({
    required this.header,
    required this.slivers,
    this.layoutIdentity = false,
    this.scrollViewBuilder,
    this.insetSlivers = true,
    this.maxWidth = FrostMetrics.contentMaxWidth,
    super.key,
  });
  final Widget header;
  final Widget Function(List<Widget> slivers)? scrollViewBuilder;
  final Object layoutIdentity;
  final List<Widget> slivers;
  final double maxWidth;
  final bool insetSlivers;
  @override
  Widget build(BuildContext context) => FrostPinnedChrome(
    chrome: FrostContentColumn(maxWidth: maxWidth, child: header),
    body: FrostLayoutCrossfade(
      // A new page controller owns a different content/offset cache. Recreate
      // only the viewport; header anchors/focus and open filters stay mounted.
      key: ObjectKey(PrimaryScrollController.maybeOf(context)),
      layoutIdentity: layoutIdentity,
      settleDuration: Duration.zero,
      child: _scrollView([
        const FrostChromeSpacer(),
        for (final sliver in slivers)
          if (insetSlivers) FrostSliverContentColumn(maxWidth: maxWidth, sliver: sliver) else sliver,
      ]),
    ),
  );

  Widget _scrollView(List<Widget> slivers) => scrollViewBuilder?.call(slivers) ?? CustomScrollView(slivers: slivers);
}

/// Keeps the outgoing slot alive while Presence collapses its measured height.
class FrostTemplateOptional extends StatefulWidget {
  const FrostTemplateOptional({required this.child, super.key});
  final Widget? child;
  @override
  State<FrostTemplateOptional> createState() => _OptionalState();
}

class _OptionalState extends State<FrostTemplateOptional> {
  Widget? _last;
  @override
  void initState() {
    super.initState();
    _last = widget.child;
  }

  @override
  void didUpdateWidget(FrostTemplateOptional oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) _last = widget.child;
  }

  @override
  Widget build(BuildContext context) => FrostPresence(
    visible: widget.child != null,
    effect: FrostPresenceEffect.expand,
    alignment: AlignmentDirectional.topStart,
    child: _last ?? const SizedBox.shrink(),
  );
}
