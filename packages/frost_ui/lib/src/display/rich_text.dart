import 'package:flutter/material.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_reader_style.dart';
import '../primitives/click_surface.dart';
import '_rich_text_parser.dart';

// Inline code padding is independent of text scaling.
const _codeHorizontalInset = 4.0;
const _codeVerticalInset = 2.0;

/// Selectable text with a small Markdown subset. Links and social targets are
/// delegated to the application; this widget never launches a URL or a route.
class FrostRichText extends StatefulWidget {
  const FrostRichText({required this.text, this.onLink, this.onMention, this.onHashtag, this.role = FrostTextRole.body, this.selectable = true, super.key});
  final String text;
  final ValueChanged<Uri>? onLink;
  final ValueChanged<String>? onMention, onHashtag;
  final FrostTextRole role;
  final bool selectable;
  @override
  State<FrostRichText> createState() => FrostRichTextState();
}

/// Internal state type, absent from frost_ui.dart's exports.
class FrostRichTextState extends State<FrostRichText> {
  late FrostRichDocument document = FrostRichDocument(widget.text);
  @override
  void didUpdateWidget(FrostRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) document = FrostRichDocument(widget.text);
  }

  Widget _content(BuildContext context) {
    final typography = FrostTypography.of(context), tokens = FrostThemeTokens.of(context);
    final base = FrostReaderStyle.apply(context, widget.role, typography.style(widget.role)).copyWith(color: tokens.textPrimary);
    return FrostSkeletonText(
      child: RichText(
        textScaler: MediaQuery.textScalerOf(context),
        selectionRegistrar: widget.selectable ? SelectionContainer.maybeOf(context) : null,
        selectionColor: tokens.selectionFill,
        text: TextSpan(style: base, children: [for (final node in document.nodes) _span(context, node, base, typography)]),
      ),
    );
  }

  InlineSpan _span(BuildContext context, FrostRichNode node, TextStyle base, FrostTypography typography) {
    var style = node.code ? FrostReaderStyle.apply(context, widget.role, typography.style(widget.role, monospace: true)).copyWith(color: base.color) : base;
    if (node.bold) style = style.copyWith(fontWeight: typography.style(FrostTextRole.headline).fontWeight);
    if (node.italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (node.code) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: FrostThemeTokens.of(context).fillSubtle, shape: FrostRadius.shape(context, FrostRadius.xs)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _codeHorizontalInset, vertical: _codeVerticalInset),
            child: FrostSkeletonText(child: Text(node.text, style: style)),
          ),
        ),
      );
    }
    final callback = switch (node.target) {
      FrostRichTarget.link => widget.onLink == null ? null : () => widget.onLink!(Uri.parse(node.value!)),
      FrostRichTarget.mention => widget.onMention == null ? null : () => widget.onMention!(node.value!),
      FrostRichTarget.hashtag => widget.onHashtag == null ? null : () => widget.onHashtag!(node.value!),
      null => null,
    };
    if (node.target == null) return TextSpan(text: node.text, style: style);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _RichAction(
        text: node.text,
        style: style.copyWith(color: FrostThemeTokens.of(context).accentInk),
        onTap: callback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.selectable ? SelectionArea(child: Builder(builder: _content)) : _content(context);
}

class _RichAction extends StatefulWidget {
  const _RichAction({required this.text, required this.style, required this.onTap});
  final String text;
  final TextStyle style;
  final VoidCallback? onTap;
  @override
  State<_RichAction> createState() => _RichActionState();
}

class _RichActionState extends State<_RichAction> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: Semantics(
      link: true,

      onTap: widget.onTap,
      child: FrostClickSurface(
        onTap: widget.onTap,
        customBorder: FrostRadius.shape(context, FrostRadius.xs),
        child: FrostSkeletonText(
          child: Text(widget.text, style: widget.style.copyWith(decoration: _hover ? TextDecoration.underline : TextDecoration.none)),
        ),
      ),
    ),
  );
}
