import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '_media_contrast.dart';
import 'color_math.dart';
import 'tokens.dart';

// Bounds come from the existing blurred sample, never a second decode.
const frostAmbientIntensityStep = .05;
const frostAmbientBlockSide = 4;
const _ambientMaterialCacheCapacity = 128;
const frostAmbientDarkArtworkOpacity = .34;
const frostAmbientLightArtworkOpacity = .40;
const frostAmbientArtworkSaturation = .7;
// Keep the exact original matrix shared by measurement and painting.
const frostAmbientSaturationMatrix = <double>[.7639, .2145, .0216, 0, 0, .0639, .9145, .0216, 0, 0, .0639, .2145, .7216, 0, 0, 0, 0, 0, 1, 0];

/// Immutable pixels owned alongside the cached pre-blurred image.
class FrostAmbientSample {
  FrostAmbientSample(this.width, this.height, this.pixels);
  final int width, height;
  final List<Color> pixels;
  final _materials = <Object, FrostAmbientMaterials>{};
  final _fullStrengthMasks = <Object, double>{};
  int resolutions = 0;

  FrostAmbientMaterials resolve(FrostThemeTokens tokens, double intensity, double aspectRatio) {
    final bucket = (intensity / frostAmbientIntensityStep).ceil().clamp(0, 20);
    // Aspect affects cover cropping and the window-anchored accent washes.
    final aspect = aspectRatio;
    final key = (tokens.brightness, tokens.tone, tokens.canvas, tokens.surface, tokens.textPrimary, tokens.textSecondary, tokens.accent, bucket, aspect);
    if (_materials[key] case final cached?) return cached;
    if (_materials.length >= _ambientMaterialCacheCapacity) _materials.clear();
    resolutions++;
    final intensities = bucket == 0 ? [0.0] : [(bucket - 1) * frostAmbientIntensityStep, bucket * frostAmbientIntensityStep];
    final backgrounds = <Color>[];
    for (final strength in intensities) {
      backgrounds.addAll(_backgrounds(tokens, strength, aspect));
    }
    final maskKey = (tokens.brightness, tokens.tone, tokens.canvas, tokens.surface, tokens.textPrimary, tokens.textSecondary, tokens.accent, aspect);
    var mask = _fullStrengthMasks[maskKey];
    if (mask == null) {
      if (_fullStrengthMasks.length >= _ambientMaterialCacheCapacity) _fullStrengthMasks.clear();
      // Keep the full-strength readable endpoint unchanged. Re-solving a weaker
      // mask for each slider value would cancel the reduced artwork/wash alpha.
      // Canvas is included so interpolation toward it stays inside this bound.
      final fullBackgrounds = [tokens.canvas, ..._backgrounds(tokens, 1 - frostAmbientIntensityStep, aspect), ..._backgrounds(tokens, 1, aspect)];
      mask = _minimumMask(tokens, [_channelBound(fullBackgrounds, tokens.isDark)]);
      _fullStrengthMasks[maskKey] = mask;
    }
    final masked = backgrounds.map((c) => Color.alphaBlend(tokens.canvas.withValues(alpha: mask), c)).toList(growable: false);
    final worst = _channelBound(masked, tokens.isDark);
    return _materials[key] = FrostAmbientMaterials(mask: mask, background: worst);
  }

  Iterable<Color> _backgrounds(FrostThemeTokens tokens, double strength, double ratio) sync* {
    if (strength == 0) {
      yield tokens.canvas;
      return;
    }
    final window = Size(math.max(ratio, .01), 1);
    final fit = applyBoxFit(BoxFit.cover, Size(width.toDouble(), height.toDouble()), window);
    final source = Alignment.center.inscribe(fit.source, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    for (var y = 0; y < height; y += frostAmbientBlockSide) {
      for (var x = 0; x < width; x += frostAmbientBlockSide) {
        final block = Rect.fromLTRB(
          x.toDouble(),
          y.toDouble(),
          math.min(width, x + frostAmbientBlockSide).toDouble(),
          math.min(height, y + frostAmbientBlockSide).toDouble(),
        );
        final visible = block.intersect(source);
        if (visible.isEmpty) continue;
        final colors = <Color>[];
        for (var py = y; py < math.min(height, y + frostAmbientBlockSide); py++) {
          for (var px = x; px < math.min(width, x + frostAmbientBlockSide); px++) {
            final picture = _desaturate(pixels[py * width + px]);
            colors.add(
              Color.alphaBlend(
                picture.withValues(alpha: picture.a * strength * (tokens.isDark ? frostAmbientDarkArtworkOpacity : frostAmbientLightArtworkOpacity)),
                tokens.canvas,
              ),
            );
          }
        }
        // Component bounds retain bright/dark islands; averaging would hide
        // them. Scan every block so custom transparent layouts are covered too.
        final base = _channelBound(colors, tokens.isDark);
        Offset position(Offset point) => Offset((point.dx - source.left) / source.width * window.width, (point.dy - source.top) / source.height);
        final windowBlock = Rect.fromPoints(position(visible.topLeft), position(visible.bottomRight));
        yield* _washBounds(base, tokens, strength, windowBlock, window);
      }
    }
  }
}

Color _channelBound(Iterable<Color> colors, bool brightest) {
  var r = brightest ? 0.0 : 1.0, g = r, b = r;
  for (final color in colors) {
    r = brightest ? math.max(r, color.r) : math.min(r, color.r);
    g = brightest ? math.max(g, color.g) : math.min(g, color.g);
    b = brightest ? math.max(b, color.b) : math.min(b, color.b);
  }
  return Color.from(alpha: 1, red: r, green: g, blue: b);
}

Color _desaturate(Color c) {
  final m = frostAmbientSaturationMatrix;
  return Color.from(
    alpha: c.a,
    red: m[0] * c.r + m[1] * c.g + m[2] * c.b,
    green: m[5] * c.r + m[6] * c.g + m[7] * c.b,
    blue: m[10] * c.r + m[11] * c.g + m[12] * c.b,
  );
}

Iterable<Color> _washBounds(Color background, FrostThemeTokens tokens, double intensity, Rect block, Size window) sync* {
  (double, double) bounds(Offset center, double radius, double opacity) {
    final nearest = Offset(center.dx.clamp(block.left, block.right), center.dy.clamp(block.top, block.bottom));
    final farthest = [block.topLeft, block.topRight, block.bottomLeft, block.bottomRight].map((point) => (point - center).distance).reduce(math.max);
    double alpha(double distance) => (1 - distance / radius).clamp(0.0, 1.0) * opacity * intensity;
    return (alpha(farthest), alpha((nearest - center).distance));
  }

  final (aMin, aMax) = bounds(Offset(window.width * .12, 0), window.longestSide * .62, tokens.isDark ? .16 : .12);
  final (bMin, bMax) = bounds(Offset(window.width, window.height), window.longestSide * .55, tokens.isDark ? .10 : .08);
  final wash = ambientAccent(tokens.accent);
  final counter = HSLColor.fromColor(wash);
  // Include each gradient's exact block extrema, even when its peak falls
  // between sample centers. Combined bounds cover every bilinear pixel.
  for (final a in [aMin, aMax]) {
    for (final b in [bMin, bMax]) {
      yield Color.alphaBlend(counter.withHue((counter.hue + 38) % 360).toColor().withValues(alpha: b), Color.alphaBlend(wash.withValues(alpha: a), background));
    }
  }
}

double _minimumMask(FrostThemeTokens tokens, List<Color> backgrounds) {
  var alpha = 0.0;
  for (final background in backgrounds) {
    // Preserve both semantic inks. The shared solver also checks 8-bit output.
    for (final ink in [tokens.textSecondary, tokens.textPrimary]) {
      alpha = math.max(alpha, frostContrastScrimOpacity(surface: tokens.canvas, ink: ink, worst: background, minimum: 0));
    }
  }
  return alpha;
}

class FrostAmbientMaterials {
  const FrostAmbientMaterials({required this.mask, required this.background});
  final double mask;
  final Color background;
}

// Preserve the WinUI wash as a floor, adding a local surface backing only
// where the actual window background would otherwise make its ink unreadable.
Color frostReadableWindowFill(FrostThemeTokens tokens, Color floor, Color behind, Color ink) {
  final painted = Color.alphaBlend(floor, behind);
  final backing = frostContrastScrimOpacity(surface: Color.alphaBlend(floor, tokens.surface), ink: ink, worst: painted, minimum: 0);
  return Color.alphaBlend(floor, tokens.surface.withValues(alpha: backing));
}

// Transparent artwork leaves only the existing canvas and the same two washes.
// Reuse the actual-sample solver/cache, including theme, intensity and aspect.
final _ambientAccentSample = FrostAmbientSample(1, 1, [const Color(0x00000000)]);
FrostAmbientMaterials frostAmbientAccentMaterial(FrostThemeTokens tokens, double intensity, double aspect) =>
    _ambientAccentSample.resolve(tokens, intensity, aspect);
