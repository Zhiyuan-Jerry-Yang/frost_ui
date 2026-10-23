import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';

import '../controls/_copy_feedback.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';

/// Selectable, wrapping display text whose button and context menu always copy
/// [text], even when [display] is a shortened or differently formatted value.
class FrostCopyable extends StatelessWidget {
  const FrostCopyable({required this.text, this.display, this.monospace = false, super.key});
  final String text;
  final String? display;
  final bool monospace;
  @override
  Widget build(BuildContext context) => FrostCopyFeedback(
    text: text,
    builder: (context, copied, copy) => FrostContextMenuRegion(
      entries: [FrostMenuAction(FrostScope.labelsOf(context).copy, onSelected: copy)],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FrostSkeletonText(
              child: SelectableText(
                display ?? text,
                contextMenuBuilder: null,
                style: FrostTypography.of(context).style(FrostTextRole.body, monospace: monospace).copyWith(color: FrostThemeTokens.of(context).textPrimary),
              ),
            ),
          ),
          const SizedBox(width: FrostGap.related),
          FrostCopyFeedbackButton(copied: copied, onCopy: copy),
        ],
      ),
    ),
  );
}
