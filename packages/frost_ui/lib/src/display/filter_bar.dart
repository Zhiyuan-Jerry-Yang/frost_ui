import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../primitives/_scroll_edge_fade.dart';
import '../primitives/presence.dart';
import 'filter_chip.dart';

/// Active filters in one scrolling row. Place this in the scrolling content,
/// below the page header; clearing the last chip collapses the whole row.
class FrostFilterBar extends StatefulWidget {
  const FrostFilterBar({required this.chips, this.onClearAll, super.key});
  final List<FrostFilterChip> chips;
  final VoidCallback? onClearAll;
  @override
  State<FrostFilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FrostFilterBar> {
  final _scroll = ScrollController();
  List<FrostFilterChip> _lastChips = const [];
  @override
  void initState() {
    super.initState();
    _lastChips = widget.chips;
  }

  @override
  void didUpdateWidget(FrostFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retain geometry while the last row animates out.
    if (widget.chips.isNotEmpty) _lastChips = widget.chips;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostPresence(
    visible: widget.chips.isNotEmpty,
    effect: FrostPresenceEffect.expand,
    alignment: AlignmentDirectional.topStart,
    child: Row(
      children: [
        Expanded(
          child: FrostScrollEdgeFade(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < _lastChips.length; index++) ...[if (index > 0) const SizedBox(width: FrostGap.related), _lastChips[index]],
                ],
              ),
            ),
          ),
        ),
        if (widget.onClearAll != null) ...[
          const SizedBox(width: FrostGap.related),
          FrostButton(
            label: FrostScope.labelsOf(context).clearAll,
            onPressed: widget.onClearAll,
            variant: FrostButtonVariant.plain,
            size: FrostControlSize.compact,
          ),
        ],
      ],
    ),
  );
}
