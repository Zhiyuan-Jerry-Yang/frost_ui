import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/slider.dart';
import '../foundation/_media_contrast.dart';
import '../foundation/density.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_material_reveal.dart';
import '../motion/rolling_text.dart';
import '../primitives/surface.dart';

// The fade precedes the entire readable control region.
const frostVideoGradientExtent = 24.0;

/// Paint derives the mask from the child's actual first-frame height.
class FrostVideoBar extends StatelessWidget {
  const FrostVideoBar({required this.play, required this.current, required this.total, required this.slider, required this.trailing, super.key});
  final Widget play, slider;
  final String current, total;
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final style = FrostTypography.of(context).style(FrostTextRole.footnote, numeric: true).copyWith(color: tokens.onMediaInk);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Reserve the duration's digit count so seeking back does not shift controls.
    final timeWidth = math.max(textWidth(current), textWidth(total));
    Widget time(String value) => SizedBox(
      width: timeWidth,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FrostRollingText(value, style: style),
      ),
    );
    final controls = [play, time(current), time(total), ...trailing];
    final buttonWidth = math.max(FrostControlSize.compact.height(context), FrostDensity.of(context).targetHeight);
    final fixed = buttonWidth * (trailing.length + 1) + timeWidth * 2;
    return CustomPaint(
      painter: FrostVideoScrimPainter(
        frostOnMediaChromeColor(tokens).withValues(alpha: frostOnMediaChromeOpacity(tokens) * (FrostMaterialRevealScope.maybeOf(context)?.progress ?? 1)),
      ),
      child: FrostSurface(
        role: FrostSurfaceRole.onMediaChrome,
        borderRadius: BorderRadius.zero,
        elevated: false,
        edge: FrostSurfaceEdge.none,
        child: Padding(
          padding: const EdgeInsets.all(FrostGap.related),
          child: LayoutBuilder(
            builder: (context, limits) {
              if (fixed + FrostGap.related * controls.length + frostSliderMinimumTrackWidth <= limits.maxWidth) {
                return Row(
                  children: [
                    play,
                    const SizedBox(width: FrostGap.related),
                    time(current),
                    const SizedBox(width: FrostGap.related),
                    Expanded(child: slider),
                    const SizedBox(width: FrostGap.related),
                    time(total),
                    for (final control in trailing) ...[const SizedBox(width: FrostGap.related), control],
                  ],
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  slider,
                  const SizedBox(height: FrostGap.related),
                  Wrap(spacing: FrostGap.related, runSpacing: FrostGap.related, crossAxisAlignment: WrapCrossAlignment.center, children: controls),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Only the 24-point extension is painted here. The control region itself
/// belongs to FrostSurface.onMediaChrome and its shared reveal/solid path.
class FrostVideoScrimPainter extends CustomPainter {
  const FrostVideoScrimPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, -frostVideoGradientExtent, size.width, frostVideoGradientExtent);
    final shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0), color]).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(FrostVideoScrimPainter oldDelegate) => color != oldDelegate.color;
}
