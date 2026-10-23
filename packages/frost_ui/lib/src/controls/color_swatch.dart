import 'package:flutter/material.dart';

import '../foundation/color_math.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../motion/_selection_feedback.dart';
import '../motion/spring.dart';
import '../overlays/tooltip.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '_input_surface.dart';

// Palette and custom actions share one visual and interaction implementation.
const _swatchDiameter = 24.0, _swatchRingWidth = 2.0, _swatchRingGap = 2.0;
const _swatchHoverScale = 1.08, _swatchDisabledOpacity = .38;

/// A labelled data-colour swatch sharing palette geometry and feedback.
/// Optional icons describe an unconfigured/custom action on a neutral fill.
/// Once configured, omit icon to retain the chosen colour when unselected.
/// Selection uses the same contrast-derived check and ring as Picker.palette.
/// Every activation invokes onPressed, including an already selected swatch.
class FrostColorSwatch extends StatelessWidget {
  const FrostColorSwatch({required this.color, required this.label, this.selected = false, this.icon, this.onPressed, this.focusNode, super.key})
    : assert(label != '');
  final Color color;
  final String label;
  final bool selected;
  final FrostIconData? icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final enabled = onPressed != null && FrostControlScope.enabledOf(context);
    final fill = icon != null && !selected ? tokens.fill : color;
    final dark = FrostScope.configOf(context).palettes.palette(Brightness.light, tokens.tone, tokens.accent).textPrimary;
    return FrostTooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        checked: selected,
        enabled: enabled,
        inMutuallyExclusiveGroup: true,
        onTap: enabled ? onPressed : null,
        excludeSemantics: true,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : _swatchDisabledOpacity,
          duration: FrostMotion.duration(context, FrostMotion.hover),
          child: FrostInputSurface(
            onTap: enabled ? onPressed : null,
            focusNode: focusNode,
            builder: (context, states) => FrostSpringBuilder(
              value: enabled && states.contains(WidgetState.hovered) && !states.contains(WidgetState.pressed) ? _swatchHoverScale : 1,
              spring: FrostMotion.snappy,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: FrostClickFeedbackVisual(
                states: states,
                feedback: FrostClickFeedback.media,
                shape: const CircleBorder(),
                clipsContent: false,
                scalesOnPress: false,
                child: FrostSelectionFeedback(
                  selected: selected,
                  foreground: swatchCheckInk(fill, dark),
                  background: fill,
                  builder: (context, ink, color, pop) => SizedBox.square(
                    dimension: _swatchDiameter,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        if (icon != null && !selected)
                          Center(
                            child: FrostIcon(icon!, size: FrostControlSize.compact.iconSize, color: tokens.textSecondary),
                          ),
                        AnimatedOpacity(
                          opacity: selected ? 1 : 0,
                          duration: FrostMotion.duration(context, FrostMotion.hover),
                          child: CustomPaint(
                            foregroundPainter: _SwatchRingPainter(color),
                            child: Center(
                              child: ScaleTransition(
                                scale: pop,
                                child: FrostIcon(FrostIconSet.of(context).check, size: FrostControlSize.compact.iconSize, color: ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwatchRingPainter extends CustomPainter {
  const _SwatchRingPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    _swatchDiameter / 2 + _swatchRingGap + _swatchRingWidth / 2,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _swatchRingWidth,
  );
  @override
  bool shouldRepaint(_SwatchRingPainter oldDelegate) => color != oldDelegate.color;
}
