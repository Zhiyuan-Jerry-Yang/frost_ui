import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/rolling_text.dart';
import '_field_options.dart';
import 'text_field.dart';

// Count punctuation is numeric presentation, supplied without localized prose.
const _countSeparator = ' / ';

/// A growing multiline field. maxLength affects the counter only: input is
/// never truncated. The editor scrolls internally after reaching maxLines.
class FrostTextArea extends StatefulWidget {
  const FrostTextArea({
    this.controller,
    this.focusNode,
    this.label,
    this.placeholder,
    this.help,
    this.error,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxLength,
    this.showsCount = false,
    this.enabled = true,
    this.onChanged,
    super.key,
  }) : assert(minLines > 0 && maxLines >= minLines),
       assert(maxLength == null || maxLength >= 0);
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label, placeholder, help, error;
  final int minLines, maxLines;
  final int? maxLength;
  final bool showsCount, enabled;
  final ValueChanged<String>? onChanged;
  @override
  State<FrostTextArea> createState() => _TextAreaState();
}

class _TextAreaState extends State<FrostTextArea> {
  late TextEditingController _controller = widget.controller ?? TextEditingController();
  @override
  void didUpdateWidget(FrostTextArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final previous = _controller;
      _controller = widget.controller ?? TextEditingController.fromValue(previous.value);
      if (oldWidget.controller == null) previous.dispose();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final count = _controller.text.characters.length, maximum = widget.maxLength;
      final tokens = FrostThemeTokens.of(context);
      final counter = maximum == null ? '$count' : '$count$_countSeparator$maximum';
      return FrostFieldOptions(
        supportingTrailing: widget.showsCount
            ? FrostRollingText(
                counter,
                style: FrostTypography.of(
                  context,
                ).style(FrostTextRole.footnote, numeric: true).copyWith(color: maximum != null && count > maximum ? tokens.negativeInk : tokens.textSecondary),
              )
            : null,
        child: FrostTextField(
          controller: _controller,
          focusNode: widget.focusNode,
          label: widget.label,
          placeholder: widget.placeholder,
          help: widget.help,
          error: widget.error,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: TextInputType.multiline,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
        ),
      );
    },
  );
}
