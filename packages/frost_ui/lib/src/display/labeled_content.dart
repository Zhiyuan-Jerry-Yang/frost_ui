import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '../lists/_row_layout.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/divider.dart';
import '../primitives/path_text.dart';
import '../primitives/text.dart';

/// A label and exactly one value or structural control. The shared list-row
/// layout moves the value below the label on the very first constrained frame.
class FrostLabeledContent extends StatefulWidget {
  const FrostLabeledContent({required this.label, this.value, this.content, super.key}) : assert((value == null) != (content == null));
  final String label;
  final String? value;
  final Widget? content;
  @override
  State<FrostLabeledContent> createState() => _LabeledContentState();
}

class _LabeledContentState extends State<FrostLabeledContent> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = frostControlGeometry(context, FrostControlSize.compact, role: FrostTextRole.callout);
    return MergeSemantics(
      child: Semantics(
        label: widget.label,
        value: widget.value,
        excludeSemantics: widget.value != null,
        child: FrostMotionSize(
          duration: FrostMotion.duration(context, FrostMotion.layoutFade),
          alignment: AlignmentDirectional.topStart,
          child: FrostLayoutCrossfade(
            layoutIdentity: _identity,
            settleDuration: Duration.zero,
            child: FrostRowLayout(
              identity: _identity,
              contentIdentity: (widget.label, widget.value, widget.content?.key),
              minimumHeight: geometry.height,
              verticalInset: geometry.verticalInset,
              inset: EdgeInsets.zero,
              direction: Directionality.of(context),
              children: [
                FrostRowSlot(
                  id: FrostRowPart.text,
                  child: ExcludeSemantics(
                    child: FrostText(widget.label, role: FrostTextRole.callout, tone: FrostTextTone.secondary, numeric: true),
                  ),
                ),
                FrostRowSlot(
                  id: FrostRowPart.value,
                  child: widget.content ?? FrostText(widget.value!, role: FrostTextRole.callout, tone: FrostTextTone.primary, numeric: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FrostKeyValue {
  const FrostKeyValue({required this.label, required this.value}) : _path = false;

  /// A full original filesystem or gallery-relative path, with path wrapping.
  const FrostKeyValue.path({required this.label, required this.value}) : _path = true;
  final String label, value;
  final bool _path;
}

class FrostKeyValueList extends StatelessWidget {
  const FrostKeyValueList({required this.entries, this.dividers = false, super.key});
  final List<FrostKeyValue> entries;
  final bool dividers;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, entry) in entries.indexed) ...[
        if (dividers && index > 0) const FrostDivider(),
        if (entry._path)
          FrostLabeledContent(
            label: entry.label,
            content: FrostPathText(entry.value, role: FrostTextRole.callout, tone: FrostTextTone.primary, selectable: true),
          )
        else
          FrostLabeledContent(label: entry.label, value: entry.value),
      ],
    ],
  );
}
