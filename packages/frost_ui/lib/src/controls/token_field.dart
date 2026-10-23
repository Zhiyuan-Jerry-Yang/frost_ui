import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import 'text_field.dart';

enum FrostTokenTone { accent, positive, caution, negative, neutral }

@immutable
class FrostTokenRule {
  const FrostTokenRule({required this.pattern, required this.tone});
  final RegExp pattern;
  final FrostTokenTone tone;
  @override
  bool operator ==(Object other) =>
      other is FrostTokenRule &&
      other.pattern.pattern == pattern.pattern &&
      other.pattern.isCaseSensitive == pattern.isCaseSensitive &&
      other.pattern.isMultiLine == pattern.isMultiLine &&
      other.pattern.isUnicode == pattern.isUnicode &&
      other.pattern.isDotAll == pattern.isDotAll &&
      other.tone == tone;
  @override
  int get hashCode => Object.hash(pattern.pattern, pattern.isCaseSensitive, pattern.isMultiLine, pattern.isUnicode, pattern.isDotAll, tone);
}

/// Owns token rules as well as the editing value; painting never rewrites IME state.
class FrostTokenEditingController extends TextEditingController {
  FrostTokenEditingController({super.text, List<FrostTokenRule> rules = const []}) : _rules = List.of(rules);
  List<FrostTokenRule> _rules;
  List<FrostTokenRule> get rules => List.unmodifiable(_rules);
  set rules(List<FrostTokenRule> value) {
    if (listEquals(_rules, value)) return;
    _rules = List.of(value);
    notifyListeners();
  }

  Iterable<_TokenRange> _completedRanges(String text) sync* {
    // Highlighting and whole-token deletion share the same completed-word rule.
    for (final match in RegExp(r'\S+(?=\s)').allMatches(text)) {
      for (final rule in _rules) {
        if (rule.pattern.hasMatch(match.group(0)!)) {
          yield _TokenRange(match.start, match.end, rule.tone);
          break;
        }
      }
    }
  }

  /// A character backspace at a completed token's end selects its whole body.
  /// The next backspace is an ordinary selection deletion, preserving Flutter's
  /// undo history. Composing, word deletion and unfinished words are untouched.
  @override
  set value(TextEditingValue next) {
    final previous = super.value, selection = super.value.selection;
    bool composing(TextEditingValue v) => v.isComposingRangeValid && !v.composing.isCollapsed;
    if (!composing(previous) &&
        !composing(next) &&
        selection.isValid &&
        selection.isCollapsed &&
        selection.extentOffset > 0 &&
        next.selection.isValid &&
        next.selection.isCollapsed) {
      final end = selection.extentOffset;
      if (end <= previous.text.length) {
        final removed = previous.text.substring(0, end).characters.last.length, start = end - removed;
        if (next.selection.extentOffset == start && next.text == previous.text.replaceRange(start, end, '')) {
          for (final range in _completedRanges(previous.text)) {
            if (range.end == end) {
              super.value = previous.copyWith(
                selection: TextSelection(baseOffset: range.start, extentOffset: range.end),
              );
              return;
            }
          }
        }
      }
    }
    super.value = next;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final ranges = _completedRanges(text).toList();
    final composing = value.composing;
    final hasComposing = withComposing && value.isComposingRangeValid && !composing.isCollapsed;
    if (ranges.isEmpty && !hasComposing) return TextSpan(style: style, text: text);
    final tokens = FrostThemeTokens.of(context);
    final children = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      var boundary = text.length;
      TextStyle? segmentStyle;
      for (final range in ranges) {
        if (range.start > index && range.start < boundary) boundary = range.start;
        if (range.end > index && range.end < boundary) boundary = range.end;
        if (index >= range.start && index < range.end) {
          segmentStyle = TextStyle(
            color: switch (range.tone) {
              FrostTokenTone.accent => tokens.accentInk,
              FrostTokenTone.positive => tokens.positiveInk,
              FrostTokenTone.caution => tokens.cautionInk,
              FrostTokenTone.negative => tokens.negativeInk,
              FrostTokenTone.neutral => tokens.textSecondary,
            },
            fontWeight: FrostTypography.of(context).style(FrostTextRole.callout).fontWeight,
          );
        }
      }
      if (hasComposing) {
        if (composing.start > index && composing.start < boundary) boundary = composing.start;
        if (composing.end > index && composing.end < boundary) boundary = composing.end;
        if (index >= composing.start && index < composing.end) {
          segmentStyle = (segmentStyle ?? const TextStyle()).copyWith(decoration: TextDecoration.underline);
        }
      }
      children.add(TextSpan(text: text.substring(index, boundary), style: segmentStyle));
      index = boundary;
    }
    return TextSpan(style: style, children: children);
  }
}

class _TokenRange {
  const _TokenRange(this.start, this.end, this.tone);
  final int start, end;
  final FrostTokenTone tone;
}

/// Typed token editing with the same chrome and lifecycle as [FrostTextField].
class FrostTokenField extends FrostTextField {
  const FrostTokenField({
    required FrostTokenEditingController controller,
    super.focusNode,
    super.label,
    super.placeholder,
    super.help,
    super.error,
    super.leading,
    super.trailing,
    super.clearable,
    super.size,
    super.monospace,
    super.obscureText,
    super.readOnly,
    super.enabled,
    super.autofocus,
    super.minLines,
    super.maxLines,
    super.keyboardType,
    super.textInputAction,
    super.onChanged,
    super.onSubmitted,
    super.onEditingComplete,
    super.onTap,
    super.onTapOutside,
    super.scrollController,
    super.key,
  }) : super(controller: controller);
}
