import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../controls/_close_control.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/density.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_tag_metrics.dart';

// The centered separator is punctuation, not a translated UI message.
const _filterSeparator = ' · ';

/// An active filter, with independent body and clear actions.
class FrostFilterChip extends StatefulWidget {
  const FrostFilterChip({required this.label, this.value, this.onPressed, this.onClear, super.key});
  final String label;
  final String? value;
  final VoidCallback? onPressed, onClear;
  @override
  State<FrostFilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<FrostFilterChip> {
  final _bodyFocus = FocusNode();
  String get label => widget.label;
  String? get value => widget.value;
  VoidCallback? get onPressed => widget.onPressed;
  VoidCallback? get onClear => widget.onClear;
  @override
  void dispose() {
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = FrostDensity.of(context);
    final touch = density.heightFor(FrostControlSize.regular) == FrostControlSize.regular.visualHeight(touch: true);
    final text = [label, ?value].join(_filterSeparator);
    final style = FrostTypography.of(context).style(FrostTextRole.footnote, numeric: true);
    final geometry = frostControlTextGeometry(
      baseHeight: touch ? frostTagTouchHeight : frostTagPointerHeight,
      style: style,
      textScaler: MediaQuery.textScalerOf(context),
    );
    return GestureDetector(
      // Extend the body action to its density target without making the
      // selected visual taller or adding another semantics/focus node.
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: onPressed == null
          ? null
          : () {
              _bodyFocus.requestFocus();
              onPressed!();
            },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: density.targetHeight),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: FrostThemeTokens.of(context).selectionFill, shape: FrostRadius.shape(context, FrostRadius.sm)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FrostButtonControl(
                    label: text,
                    labelWidget: FrostSkeletonText(
                      child: Text(text, style: style.copyWith(color: FrostThemeTokens.of(context).selectionInk)),
                    ),
                    onPressed: onPressed,
                    focusNode: _bodyFocus,
                    selected: true,
                    presentation: FrostButtonPresentation.content,
                    textRole: FrostTextRole.footnote,
                    size: FrostControlSize.compact,
                    chevron: onPressed == null ? FrostButtonChevron.none : FrostButtonChevron.down,
                    truncates: false,
                    wrapsLabel: true,
                    geometry: FrostButtonGeometry(
                      horizontalInset: frostTagInset,
                      verticalInset: 0,
                      minimumWidth: 0,
                      alignment: MainAxisAlignment.start,
                      visualHeight: geometry.height,
                      maximumHitHeight: geometry.height,
                      cornerRadius: FrostRadius.sm,
                    ),
                  ),
                ),
                if (onClear != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: FrostGap.inline),
                    child: FrostCloseControl(
                      label: FrostScope.labelsOf(context).clearText,
                      onPressed: onClear!,
                      foreground: FrostThemeTokens.of(context).selectionInk,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
