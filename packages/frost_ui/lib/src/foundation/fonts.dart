import 'package:flutter/material.dart';

import 'scope.dart';

@immutable
class FrostFontChain {
  const FrostFontChain({required this.family, required this.fallbacks});

  final String family;
  final List<String> fallbacks;
}

/// Regional CJK glyph set a piece of text should be drawn with.
enum FrostContentScript { japanese, simplifiedChinese, traditionalChinese }

/// Font selection for interface and content text.
///
/// The app bundles its own CJK subsets and names their families here; the
/// library ships no font files. The bundled families draw Latin and CJK text
/// alike on every platform, so pages look the same everywhere. The
/// platform's own CJK fonts remain as fallbacks for characters outside the
/// bundled subsets, and the platform's colour emoji font is always kept in
/// the chain.
@immutable
class FrostFonts {
  const FrostFonts({required this.japanese, required this.simplifiedChinese, this.traditionalChinese, this.defaultScript, this.monospace});

  /// Optional bundled monospace family; otherwise typography uses the platform default.
  final String? monospace;

  /// Bundled family with Japanese regional forms.
  final String japanese;

  /// Bundled family with Simplified Chinese forms. It also draws Traditional
  /// Chinese when [traditionalChinese] is null.
  final String simplifiedChinese;

  /// Optional bundled family with Traditional Chinese forms.
  final String? traditionalChinese;

  /// Regional forms for content whose script cannot be told from its text,
  /// usually the language most of the app's content is in. When null such
  /// content follows the interface language, which suits apps whose content
  /// comes in any language.
  final FrostContentScript? defaultScript;

  FrostFontChain resolve({required TargetPlatform platform, required Locale locale}) {
    final chinese = locale.languageCode == 'zh';
    final traditional = chinese && _usesTraditional(locale);
    final family = !chinese
        ? japanese
        : traditional
        ? traditionalChinese ?? simplifiedChinese
        : simplifiedChinese;
    final other = chinese ? japanese : simplifiedChinese;
    return FrostFontChain(family: family, fallbacks: [other, ..._platformFallbacks(platform, locale)]);
  }

  /// [style] with the locale and CJK fallback order for [text]'s own script,
  /// so a Simplified Chinese title does not mix Japanese and Chinese glyphs.
  /// Interface text keeps following the interface language.
  TextStyle contentStyle(TargetPlatform platform, Locale interfaceLocale, String text, [TextStyle? style]) {
    final locale = switch (detectContentScript(text) ?? defaultScript) {
      final script? => _localeFor(script),
      null => interfaceLocale,
    };
    final fonts = resolve(platform: platform, locale: locale);
    return (style ?? const TextStyle()).copyWith(locale: locale, fontFamily: fonts.family, fontFamilyFallback: fonts.fallbacks);
  }

  static bool _usesTraditional(Locale locale) => locale.scriptCode == 'Hant' || const {'HK', 'MO', 'TW'}.contains(locale.countryCode);

  List<String> _platformFallbacks(TargetPlatform platform, Locale locale) => switch (platform) {
    TargetPlatform.linux => [
      ..._cjkFallbacks(locale, jp: 'Noto Sans CJK JP', simplified: 'Noto Sans CJK SC', traditional: 'Noto Sans CJK TC'),
      'Noto Color Emoji',
      'Symbola',
    ],
    TargetPlatform.windows => [
      ..._cjkFallbacks(locale, jp: 'Yu Gothic UI', simplified: 'Microsoft YaHei UI', traditional: 'Microsoft JhengHei UI'),
      'Segoe UI Emoji',
      'Segoe UI Symbol',
    ],
    TargetPlatform.macOS ||
    TargetPlatform.iOS => [..._cjkFallbacks(locale, jp: 'Hiragino Sans', simplified: 'PingFang SC', traditional: 'PingFang TC'), 'Apple Color Emoji'],
    TargetPlatform.android || TargetPlatform.fuchsia => [
      ..._cjkFallbacks(locale, jp: 'Noto Sans CJK JP', simplified: 'Noto Sans CJK SC', traditional: 'Noto Sans CJK TC'),
      'Noto Color Emoji',
    ],
  };

  List<String> _cjkFallbacks(Locale locale, {required String jp, required String simplified, required String traditional}) {
    if (locale.languageCode == 'ja') return [jp, simplified, traditional];
    if (locale.languageCode == 'zh') {
      return _usesTraditional(locale) ? [traditional, simplified, jp] : [simplified, traditional, jp];
    }
    return switch (defaultScript) {
      FrostContentScript.japanese || null => [jp, simplified, traditional],
      FrostContentScript.simplifiedChinese => [simplified, traditional, jp],
      FrostContentScript.traditionalChinese => [traditional, simplified, jp],
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FrostFonts &&
      other.japanese == japanese &&
      other.simplifiedChinese == simplifiedChinese &&
      other.traditionalChinese == traditionalChinese &&
      other.defaultScript == defaultScript &&
      other.monospace == monospace;

  @override
  int get hashCode => Object.hash(japanese, simplifiedChinese, traditionalChinese, defaultScript, monospace);
}

// Common characters whose simplified and traditional forms differ. A text is
// Chinese only when it contains Han characters and no kana; the variant is
// whichever set it hits more often.
const _simplifiedOnly = '们这说对时会过发经还进门问间长东车书马鸟获风纪级费许为么们个来国说时过后发样实动现点见给关还没种话当进边问题开员学爱让认该应这吗页头电热听写达义钱层据图联场团单节论处总观类将带资证务战际设导标该让岁历复杂获几无块专两严丽举乐乡买亏亚产亲们众优伤传伦伪';
const _traditionalOnly = '們這說對時會過發經還進門問間長東車書馬鳥獲風紀級費許為麼個來國後樣實動現點見給關沒種話當邊問題開員學愛讓認該應嗎頁頭電熱聽寫達義錢層據圖聯場團單節論處總觀類將帶資證務戰際設導標歲歷複雜幾無塊專兩嚴麗舉樂鄉買虧亞產親眾優傷傳倫偽';

// A character listed in both sets counts for neither.
final _simplifiedSet = _simplifiedOnly.runes.toSet().difference(_traditionalOnly.runes.toSet());
final _traditionalSet = _traditionalOnly.runes.toSet().difference(_simplifiedOnly.runes.toSet());

/// Classifies text by script. Kana, including halfwidth katakana, means Japanese; otherwise Han text with
/// simplified-only or traditional-only characters is Chinese. Anything
/// undecidable returns null.
FrostContentScript? detectContentScript(String text) {
  var han = false;
  var simplified = 0;
  var traditional = 0;
  for (final rune in text.runes) {
    if ((rune >= 0x3040 && rune <= 0x30FF) || (rune >= 0x31F0 && rune <= 0x31FF) || (rune >= 0xFF66 && rune <= 0xFF9F)) {
      return FrostContentScript.japanese;
    }
    if (rune >= 0x4E00 && rune <= 0x9FFF) {
      han = true;
      if (_simplifiedSet.contains(rune)) simplified++;
      if (_traditionalSet.contains(rune)) traditional++;
    }
  }
  if (!han || simplified == traditional) return null;
  return simplified > traditional ? FrostContentScript.simplifiedChinese : FrostContentScript.traditionalChinese;
}

Locale _localeFor(FrostContentScript script) => switch (script) {
  FrostContentScript.simplifiedChinese => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  FrostContentScript.traditionalChinese => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  FrostContentScript.japanese => const Locale('ja'),
};

/// [FrostFonts.contentStyle] with the fonts of the nearest [FrostScope].
TextStyle frostContentTextStyle(BuildContext context, String text, [TextStyle? style]) =>
    FrostScope.configOf(context).fonts.contentStyle(Theme.of(context).platform, Localizations.localeOf(context), text, style);
