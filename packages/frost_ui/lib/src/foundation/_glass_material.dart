import 'dart:ui';
import '_media_contrast.dart';
import 'color_math.dart';

// Deliberately lower than the old .88/.92 paint. These are floors, not an
// assumption about a palette's contrast; the shared solver checks both float
// and eight-bit framebuffer colors against the worst possible backdrop.
const frostGlassLightFillMinimum = .6;
const frostGlassDarkFillMinimum = .7;
const frostGlassSaturation = 1.25;
const _glassInkCacheLimit = 64;
final _glassInks = <(Color, Color, double, double), Color>{};

double frostGlassFillOpacity(Color surface, Color ink, bool dark) => frostContrastScrimOpacity(
  surface: surface,
  ink: ink,
  worst: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
  minimum: dark ? frostGlassDarkFillMinimum : frostGlassLightFillMinimum,
);

Color frostGlassInk(Color surface, Color primary, bool dark, double minimumAlpha, double contrast) {
  final background = Color.alphaBlend(
    surface.withValues(alpha: frostGlassFillOpacity(surface, primary, dark)),
    dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
  );
  final key = (background, primary, minimumAlpha, contrast);
  if (_glassInks[key] case final cached?) return cached;
  if (_glassInks.length >= _glassInkCacheLimit) _glassInks.clear();
  bool passes(double a) {
    final ink = primary.withValues(alpha: a);
    return colorContrast(Color.alphaBlend(ink, background), background) >= contrast &&
        colorContrast(Color(Color.alphaBlend(ink, background).toARGB32()), Color(background.toARGB32())) >= contrast;
  }

  var low = minimumAlpha, high = 1.0;
  if (passes(low)) return _glassInks[key] = primary.withValues(alpha: low);
  for (var i = 0; i < 18; i++) {
    final mid = (low + high) / 2;
    if (passes(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _glassInks[key] = primary.withValues(alpha: high);
}

/// Filter alpha that makes a fixed static blur fade as a whole with its fill.
/// With fill alpha a*p, the filtered contribution is exactly p*(1-a);
/// the remaining contribution is the unfiltered backdrop, never extra frost.
double frostGlassFilterOpacity(double progress, double fillAlpha) => fillAlpha >= 1 ? 0 : progress * (1 - fillAlpha) / (1 - fillAlpha * progress);

ImageFilter frostGlassFilter({required double sigma, required double opacity}) {
  const s = frostGlassSaturation, r = .2126 * (1 - s), g = .7152 * (1 - s), b = .0722 * (1 - s);
  return ImageFilter.compose(
    // Process color/alpha before sampling. Processing an already blurred hard
    // media edge produced visible quantized bands in desktop chrome.
    outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
    inner: ColorFilter.matrix([r + s, g, b, 0, 0, r, g + s, b, 0, 0, r, g, b + s, 0, 0, 0, 0, 0, opacity, 0]),
  );
}

// WinUI Common_themeresources_any.xaml LayerFillColorDefault and
// CardBackgroundFillColorDefault, used only over an actual translucent base.
Color frostWindowLayerFill(bool dark) => dark ? const Color(0x4C3A3A3A) : const Color(0x80FFFFFF);
Color frostWindowCardFill(bool dark) => dark ? const Color(0x0DFFFFFF) : const Color(0xB3FFFFFF);

// Navigation stays legible over moving text even when a platform sampler is
// weak or temporarily deferred. Bound the residual black/white contrast, not
// just the foreground ink contrast. This is a conservative cross-platform floor.
const frostNavigationBackdropContrastMaximum = 1.3;
final _navigationFills = <(Color, double), double>{};
double frostNavigationGlassFillOpacity(Color surface, double minimum) {
  final key = (surface, minimum);
  if (_navigationFills[key] case final cached?) return cached;
  if (_navigationFills.length >= _glassInkCacheLimit) _navigationFills.clear();
  bool obscures(double alpha) {
    final fill = surface.withValues(alpha: alpha);
    final black = Color.alphaBlend(fill, const Color(0xFF000000));
    final white = Color.alphaBlend(fill, const Color(0xFFFFFFFF));
    return colorContrast(black, white) <= frostNavigationBackdropContrastMaximum &&
        colorContrast(Color(black.toARGB32()), Color(white.toARGB32())) <= frostNavigationBackdropContrastMaximum;
  }

  if (obscures(minimum)) return _navigationFills[key] = minimum;
  var low = minimum, high = 1.0;
  for (var i = 0; i < 18; i++) {
    final mid = (low + high) / 2;
    if (obscures(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _navigationFills[key] = high;
}
