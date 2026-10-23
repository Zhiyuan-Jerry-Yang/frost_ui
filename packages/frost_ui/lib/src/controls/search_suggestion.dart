import 'package:flutter/foundation.dart';

import '../foundation/icon_data.dart';

/// A suggestion's data and application callbacks; the panel retains input focus.
class FrostSearchSuggestion {
  const FrostSearchSuggestion({
    required this.label,
    this.icon,
    this.dataColor,
    this.detail,
    this.inlineDetail = false,
    this.value,
    required this.onSelected,
    this.onRemove,
  });
  final String label;
  final FrostIconData? icon;

  /// Category index into the current theme, using the same dot as FrostTag.
  /// When supplied, this marker takes the leading place of [icon].
  final int? dataColor;
  final String? detail;

  /// Uses FrostListRow.inlineSubtitle: the full label takes precedence over an
  /// ellipsized, single-line detail. Complete detail remains in semantics.
  final bool inlineDetail;

  /// Trailing metadata, with the shared row's wrapping and accessibility rules.
  final String? value;
  final VoidCallback onSelected;
  final VoidCallback? onRemove;
}

class FrostSearchSuggestionGroup {
  const FrostSearchSuggestionGroup({this.title, required this.items});
  final String? title;
  final List<FrostSearchSuggestion> items;
}
