import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';

// Metadata punctuation is shared by visual and spoken representations.
const _metaSeparator = ' · ';

/// Breaks only between items. An item wider than the available width can be
/// scrolled horizontally on its own instead of splitting or truncating it.
class FrostMetaLine extends StatelessWidget {
  const FrostMetaLine({required this.items, super.key});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    final values = items.where((item) => item.isNotEmpty).toList();
    final style = FrostTypography.of(context).style(FrostTextRole.subheadline, numeric: true).copyWith(color: FrostThemeTokens.of(context).textSecondary);
    return Semantics(
      label: values.join(_metaSeparator),
      excludeSemantics: true,
      child: Wrap(
        children: [
          for (final (index, item) in values.indexed)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FrostSkeletonText(child: Text([item, if (index < values.length - 1) _metaSeparator].join(), style: style, softWrap: false)),
            ),
        ],
      ),
    );
  }
}
