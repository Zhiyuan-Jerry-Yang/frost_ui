import 'package:flutter/material.dart';

import 'color_math.dart';
import 'tokens.dart';

enum FrostAccentSeverity { allowed, warning, rejected }

@immutable
class FrostAccentValidation {
  const FrostAccentValidation(this.severity, this.minimumContrast);
  final FrostAccentSeverity severity;
  final double minimumContrast;
  bool get canApply => severity != FrostAccentSeverity.rejected;
}

/// Parses an opaque six-digit HEX colour, with or without a leading `#`.
Color? parseAccentHex(String input) {
  final value = input.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value, radix: 16));
}

String accentHex(Color color) => color.toARGB32().toRadixString(16).substring(2).toUpperCase();

/// Checks [candidate] against every surface of the three [brightness]
/// palettes. Below 1.5:1 it is rejected, below 2:1 it needs confirmation.
/// Pure black and white are rejected outright: an accent that matches the
/// text colour no longer marks anything.
/// Presets, custom previews, submission and stored values share this check.
FrostAccentValidation validateAccent(Color candidate, Brightness brightness, FrostPalettes palettes) {
  final raw = candidate.toARGB32();
  if (candidate.a < 1 || raw == 0xFF000000 || raw == 0xFFFFFFFF) return const FrostAccentValidation(FrostAccentSeverity.rejected, 0);
  var minimum = double.infinity;
  for (final tone in FrostTone.values) {
    final palette = palettes.palette(brightness, tone, candidate);
    for (final surface in [
      palette.canvas,
      palette.surface,
      palette.surfaceRaised,
      palette.surfaceInset,
      palette.surfaceMuted,
      palette.hoverSurface,
      palette.pressedSurface,
    ]) {
      final contrast = colorContrast(candidate, surface);
      if (contrast < minimum) minimum = contrast;
    }
  }
  if (minimum < 1.5) return FrostAccentValidation(FrostAccentSeverity.rejected, minimum);
  // Filled controls resolve their own foreground from the exact accent. The
  // paired black/white alternatives guarantee at least 4.5 on an opaque fill.
  if (colorContrast(candidate, readableOnAccent(candidate)) < 4.5) {
    return FrostAccentValidation(FrostAccentSeverity.rejected, minimum);
  }
  return FrostAccentValidation(minimum < 2 ? FrostAccentSeverity.warning : FrostAccentSeverity.allowed, minimum);
}

/// The user's appearance choice: display mode, and a tone and accent saved
/// separately for each brightness. Follow-system mode uses the neutral tone
/// without erasing the saved manual tones. Persistence belongs to the app;
/// [toRecord] and [fromRecord] give it a stable map form.
@immutable
class FrostAppearance {
  const FrostAppearance({
    required this.lightAccent,
    required this.darkAccent,
    this.mode = ThemeMode.system,
    this.darkModeColor = FrostDarkModeColor.darkGray,
    this.lightTone = FrostTone.neutral,
    this.darkTone = FrostTone.neutral,
    this.lightCustomAccent,
    this.darkCustomAccent,
  });

  /// The initial appearance of an app with [palettes].
  FrostAppearance.initial(FrostPalettes palettes) : this(lightAccent: palettes.lightDefaultAccent, darkAccent: palettes.darkDefaultAccent);

  final ThemeMode mode;
  final FrostDarkModeColor darkModeColor;

  bool isBlackFor(Brightness brightness) => brightness == Brightness.dark && darkModeColor == FrostDarkModeColor.black;
  final FrostTone lightTone, darkTone;
  final Color lightAccent, darkAccent;

  /// The most recent custom colour of each brightness, kept while a preset is
  /// selected so it can be chosen again.
  final Color? lightCustomAccent, darkCustomAccent;

  @override
  bool operator ==(Object other) =>
      other is FrostAppearance &&
      other.mode == mode &&
      other.darkModeColor == darkModeColor &&
      other.lightTone == lightTone &&
      other.darkTone == darkTone &&
      other.lightAccent == lightAccent &&
      other.darkAccent == darkAccent &&
      other.lightCustomAccent == lightCustomAccent &&
      other.darkCustomAccent == darkCustomAccent;

  @override
  int get hashCode => Object.hash(mode, darkModeColor, lightTone, darkTone, lightAccent, darkAccent, lightCustomAccent, darkCustomAccent);

  FrostTone toneFor(Brightness brightness) => brightness == Brightness.light ? lightTone : darkTone;
  FrostTone effectiveToneFor(Brightness brightness) => mode == ThemeMode.system || isBlackFor(brightness) ? FrostTone.neutral : toneFor(brightness);
  Color accentFor(Brightness brightness) => brightness == Brightness.light ? lightAccent : darkAccent;
  Color? customAccentFor(Brightness brightness) => brightness == Brightness.light ? lightCustomAccent : darkCustomAccent;

  FrostAppearance copyWith({
    ThemeMode? mode,
    FrostDarkModeColor? darkModeColor,
    FrostTone? lightTone,
    FrostTone? darkTone,
    Color? lightAccent,
    Color? darkAccent,
    Color? lightCustomAccent,
    Color? darkCustomAccent,
  }) => FrostAppearance(
    mode: mode ?? this.mode,
    darkModeColor: darkModeColor ?? this.darkModeColor,
    lightTone: lightTone ?? this.lightTone,
    darkTone: darkTone ?? this.darkTone,
    lightAccent: lightAccent ?? this.lightAccent,
    darkAccent: darkAccent ?? this.darkAccent,
    lightCustomAccent: lightCustomAccent ?? this.lightCustomAccent,
    darkCustomAccent: darkCustomAccent ?? this.darkCustomAccent,
  );

  Map<String, Object?> toRecord() => {
    'version': 1,
    'mode': mode.name,
    'darkModeColor': darkModeColor.name,
    'lightTone': lightTone.name,
    'darkTone': darkTone.name,
    'lightAccent': accentHex(lightAccent),
    'darkAccent': accentHex(darkAccent),
    'lightCustomAccent': lightCustomAccent == null ? null : accentHex(lightCustomAccent!),
    'darkCustomAccent': darkCustomAccent == null ? null : accentHex(darkCustomAccent!),
  };

  /// Reads a [toRecord] map. Unknown or invalid fields fall back one by one;
  /// a stored accent that no longer passes [validateAccent] returns to the
  /// palettes' default. An unreadable record uses [fallbackMode].
  static FrostAppearance fromRecord(Object? input, FrostPalettes palettes, {ThemeMode fallbackMode = ThemeMode.system}) {
    if (input is! Map || input['version'] != 1) return FrostAppearance.initial(palettes).copyWith(mode: fallbackMode);
    T pickEnum<T extends Enum>(Object? value, List<T> values, T fallback) {
      for (final item in values) {
        if (item.name == value) return item;
      }
      return fallback;
    }

    Color? safeColor(Object? value, Brightness brightness) {
      final color = value is String ? parseAccentHex(value) : null;
      return color != null && validateAccent(color, brightness, palettes).canApply ? color : null;
    }

    return FrostAppearance(
      mode: pickEnum(input['mode'], ThemeMode.values, ThemeMode.system),
      darkModeColor: pickEnum(input['darkModeColor'], FrostDarkModeColor.values, FrostDarkModeColor.darkGray),
      lightTone: pickEnum(input['lightTone'], FrostTone.values, FrostTone.neutral),
      darkTone: pickEnum(input['darkTone'], FrostTone.values, FrostTone.neutral),
      lightAccent: safeColor(input['lightAccent'], Brightness.light) ?? palettes.lightDefaultAccent,
      darkAccent: safeColor(input['darkAccent'], Brightness.dark) ?? palettes.darkDefaultAccent,
      lightCustomAccent: safeColor(input['lightCustomAccent'], Brightness.light),
      darkCustomAccent: safeColor(input['darkCustomAccent'], Brightness.dark),
    );
  }
}
