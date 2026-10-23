import 'package:flutter/material.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_reader_style.dart';
import '_on_media_chrome_scope.dart';
import 'surface.dart';

enum FrostTextTone { primary, secondary, tertiary, quaternary, accent, positive, caution, negative, info }

/// Semantic typography whose colour belongs to its caller unless [tone] is set.
class FrostText extends StatelessWidget {
  const FrostText(
    this.data, {
    this.role = FrostTextRole.body,
    this.tone,
    this.numeric = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.selectable = false,
    this.semanticsLabel,
    super.key,
  }) : span = null;

  const FrostText.rich(
    InlineSpan this.span, {
    this.role = FrostTextRole.body,
    this.tone,
    this.numeric = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.selectable = false,
    this.semanticsLabel,
    super.key,
  }) : data = null;

  final String? data;
  final InlineSpan? span;
  final FrostTextRole role;
  final FrostTextTone? tone;
  final bool numeric;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool selectable;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final style = frostTextStyle(context, role, tone, numeric: numeric);
    if (selectable) {
      final content = span;
      return content == null
          ? FrostSkeletonText(
              child: SelectableText(data!, style: style, maxLines: maxLines, textAlign: textAlign, semanticsLabel: semanticsLabel),
            )
          : FrostSkeletonText(
              child: SelectableText.rich(
                content is TextSpan ? content : TextSpan(children: [content]),
                style: style,
                maxLines: maxLines,
                textAlign: textAlign,
                semanticsLabel: semanticsLabel,
              ),
            );
    }
    return span == null
        ? FrostSkeletonText(
            child: Text(data!, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, semanticsLabel: semanticsLabel),
          )
        : FrostSkeletonText(
            child: Text.rich(span!, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, semanticsLabel: semanticsLabel),
          );
  }
}

/// Library-only shared text role, reader style and semantic ink resolution.
TextStyle frostTextStyle(BuildContext context, FrostTextRole role, FrostTextTone? tone, {bool numeric = false}) {
  final tokens = FrostThemeTokens.of(context);
  final mediaInk = FrostOnMediaChromeScope.inkOf(context);
  final glass = FrostSurfaceScope.maybeOf(context)?.isGlass ?? false;
  final color = switch (tone) {
    null => null,
    FrostTextTone.primary => mediaInk ?? tokens.textPrimary,
    FrostTextTone.secondary => mediaInk ?? (glass ? tokens.textSecondaryGlass : tokens.textSecondary),
    FrostTextTone.tertiary => mediaInk ?? (glass ? tokens.textTertiaryGlass : tokens.textTertiary),
    FrostTextTone.quaternary => mediaInk ?? tokens.textQuaternary,
    FrostTextTone.accent => tokens.accentInk,
    FrostTextTone.positive => tokens.positiveInk,
    FrostTextTone.caution => tokens.cautionInk,
    FrostTextTone.negative => tokens.negativeInk,
    FrostTextTone.info => tokens.infoInk,
  };
  return FrostReaderStyle.apply(context, role, FrostTypography.of(context).style(role, numeric: numeric)).copyWith(color: color);
}
