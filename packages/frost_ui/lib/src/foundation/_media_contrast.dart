import 'package:flutter/painting.dart';

import 'color_math.dart';
import 'tokens.dart';

// Match other foundation caches and retain eight-bit framebuffer precision.
const _contrastCacheLimit = 64;
const _contrastSearchSteps = 18;
const _mediaTextContrast = 4.5;
const _lightMediaScrimMinimum = .6;
// Dark media backgrounds must stay visually recessed, beyond the text-only
// contrast threshold. This does not change the window ambient host intensity.
const _darkMediaScrimMinimum = .88;
const _onMediaChromeMinimum = .5;
// A black scrim cannot separate a media band over black. Lift it with existing
// media ink so the full band remains visible, without a second surface/token.
const _mediaChromeInkLift = .08;
final _mediaScrims = <(Color, Color, Color, double), double>{};

/// Shared by ambient surfaces and video controls. Cache the actual theme
/// colors, including intermediate tones, rather than solving in each build.
double frostContrastScrimOpacity({required Color surface, required Color ink, required Color worst, required double minimum}) {
  final key = (surface, ink, worst, minimum);
  if (_mediaScrims[key] case final cached?) return cached;
  if (_mediaScrims.length >= _contrastCacheLimit) _mediaScrims.clear();
  bool passes(double opacity) {
    final background = Color.alphaBlend(surface.withValues(alpha: opacity), worst);
    return colorContrast(ink, background) >= _mediaTextContrast && colorContrast(ink, Color(background.toARGB32())) >= _mediaTextContrast;
  }

  if (passes(minimum)) return _mediaScrims[key] = minimum;
  var low = minimum, high = 1.0;
  for (var step = 0; step < _contrastSearchSteps; step++) {
    final mid = (low + high) / 2;
    if (passes(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _mediaScrims[key] = high;
}

double frostMediaScrimOpacity(FrostThemeTokens tokens) => frostContrastScrimOpacity(
  surface: tokens.surface,
  ink: tokens.textPrimary,
  worst: tokens.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
  minimum: tokens.isDark ? _darkMediaScrimMinimum : _lightMediaScrimMinimum,
);

/// One readable media-control material, independent of the page brightness.
/// Respect the configured scrim alpha as a floor and solve over a white frame.
Color frostOnMediaChromeBase(FrostThemeTokens tokens) =>
    Color.alphaBlend(tokens.onMediaInk.withValues(alpha: _mediaChromeInkLift), tokens.onMediaScrim.withValues(alpha: 1));

double frostOnMediaChromeOpacity(FrostThemeTokens tokens) => frostContrastScrimOpacity(
  surface: frostOnMediaChromeBase(tokens),
  ink: tokens.onMediaInk,
  worst: const Color(0xFFFFFFFF),
  minimum: tokens.onMediaScrim.a.clamp(_onMediaChromeMinimum, 1.0),
);

Color frostOnMediaChromeColor(FrostThemeTokens tokens) => frostOnMediaChromeBase(tokens).withValues(alpha: frostOnMediaChromeOpacity(tokens));
