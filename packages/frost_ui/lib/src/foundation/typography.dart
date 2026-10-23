import 'package:flutter/material.dart';

/// Semantic text hierarchy; platform selects the wide column in phase 1.
enum FrostTextRole { hero, value, title1, title2, headline, body, callout, subheadline, footnote, caption }

@immutable
class FrostTypography extends ThemeExtension<FrostTypography> {
  const FrostTypography._(this._styles, this._monospace);

  factory FrostTypography({required TargetPlatform platform, TextStyle base = const TextStyle(), String? monospace}) {
    final wide = switch (platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    // Roles describe type metrics only; each component owns its foreground.
    // Construct an allow-list because copyWith(null) cannot clear paint fields.
    final fontBase = TextStyle(
      inherit: true,
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      fontStyle: base.fontStyle,
      fontFeatures: base.fontFeatures,
      fontVariations: base.fontVariations,
      wordSpacing: base.wordSpacing,
      textBaseline: base.textBaseline,
      locale: base.locale,
      leadingDistribution: base.leadingDistribution,
    );
    return FrostTypography._(
      Map.unmodifiable({
        FrostTextRole.hero: fontBase.copyWith(fontSize: wide ? 48 : 40, fontWeight: FontWeight.w300, height: 1.1, letterSpacing: 0),
        FrostTextRole.value: fontBase.copyWith(fontSize: wide ? 28 : 26, fontWeight: FontWeight.w400, height: 1.15, letterSpacing: 0),
        FrostTextRole.title1: fontBase.copyWith(fontSize: wide ? 28 : 24, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: 0),
        FrostTextRole.title2: fontBase.copyWith(fontSize: wide ? 20 : 18, fontWeight: FontWeight.w600, height: 1.35, letterSpacing: 0),
        FrostTextRole.headline: fontBase.copyWith(fontSize: wide ? 15 : 15, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0),
        FrostTextRole.body: fontBase.copyWith(fontSize: wide ? 15 : 16, fontWeight: FontWeight.w400, height: 1.55, letterSpacing: 0),
        FrostTextRole.callout: fontBase.copyWith(fontSize: wide ? 14 : 14, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0),
        FrostTextRole.subheadline: fontBase.copyWith(fontSize: wide ? 13 : 13, fontWeight: FontWeight.w400, height: 1.45, letterSpacing: 0),
        FrostTextRole.footnote: fontBase.copyWith(fontSize: wide ? 12 : 12, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: 0),
        FrostTextRole.caption: fontBase.copyWith(fontSize: wide ? 11 : 11, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: .2),
      }),
      TextStyle(
        fontFamily:
            monospace ??
            switch (platform) {
              TargetPlatform.windows => 'Consolas',
              TargetPlatform.macOS || TargetPlatform.iOS => 'Menlo',
              _ => 'monospace',
            },
        fontFamilyFallback: [?base.fontFamily, ...?base.fontFamilyFallback],
      ),
    );
  }

  final Map<FrostTextRole, TextStyle> _styles;
  final TextStyle _monospace;

  TextStyle style(FrostTextRole role, {bool numeric = false, bool monospace = false}) {
    final result = monospace ? _styles[role]!.copyWith(fontFamily: _monospace.fontFamily, fontFamilyFallback: _monospace.fontFamilyFallback) : _styles[role]!;
    return numeric ? result.copyWith(fontFeatures: [...?result.fontFeatures, const FontFeature.tabularFigures()]) : result;
  }

  static FrostTypography of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<FrostTypography>() ?? FrostTypography(platform: theme.platform, base: theme.textTheme.bodyMedium ?? const TextStyle());
  }

  @override
  FrostTypography copyWith() => this;

  @override
  FrostTypography lerp(covariant FrostTypography? other, double t) => other == null
      ? this
      : FrostTypography._(
          Map.unmodifiable({for (final role in FrostTextRole.values) role: TextStyle.lerp(style(role), other.style(role), t)!}),
          TextStyle.lerp(_monospace, other._monospace, t)!,
        );
}
