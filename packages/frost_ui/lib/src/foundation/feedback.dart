import 'package:flutter/material.dart';

import '_focus_modality.dart';
import 'color_math.dart';
import 'metrics.dart';
import 'tokens.dart';

enum FrostFeedbackRole { primary, secondary, quiet }

/// Mouse feedback and keyboard focus are independent of the page layout.
bool frostShowsFocus(Set<WidgetState> states) =>
    states.contains(WidgetState.focused) && FrostInputModality.instance.keyboard && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

final frostClickCursor = WidgetStateProperty.resolveWith<MouseCursor>(
  (states) => states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click,
);

Color frostFeedbackSurface(FrostThemeTokens tokens, Set<WidgetState> states, {Color resting = Colors.transparent}) {
  // Transparent black interpolates through dark RGB values before compositing.
  // Preserve the surface's RGB at zero alpha so entry/exit only changes opacity.
  final idle = resting.a == 0 ? tokens.fillSubtle.withValues(alpha: 0) : resting;
  if (states.contains(WidgetState.disabled)) return idle;
  if (states.contains(WidgetState.pressed)) return tokens.fillStrong;
  if (states.contains(WidgetState.hovered)) return tokens.fillSubtle;
  return idle;
}

/// Material does not animate its background color. Keep its base stable and
/// animate a separate, clipped layer beneath button content instead.
Color frostButtonRestingSurface(FrostThemeTokens tokens, Set<WidgetState> states, {Color resting = Colors.transparent}) => resting;

Color frostButtonStateLayer(FrostThemeTokens tokens, Set<WidgetState> states, FrostFeedbackRole role) {
  final disabled = states.contains(WidgetState.disabled);
  final pressed = states.contains(WidgetState.pressed);
  final hovered = states.contains(WidgetState.hovered);
  return switch (role) {
    // A dark wash under a white label, a light one under a dark label
    // (dropped for the rare accent where it would lower that below 4.5:1).
    FrostFeedbackRole.primary => solidWashColor(tokens.actionFill).withValues(
      alpha: disabled
          ? 0
          : solidOverlayAlpha(
              tokens.actionFill,
              pressed
                  ? .08
                  : hovered
                  ? .04
                  : 0,
            ),
    ),
    FrostFeedbackRole.secondary || FrostFeedbackRole.quiet =>
      disabled
          ? tokens.fillSubtle.withValues(alpha: 0)
          : pressed
          ? tokens.fillStrong
          : hovered
          ? tokens.fillSubtle
          : tokens.fillSubtle.withValues(alpha: 0),
  };
}

Widget frostButtonFeedbackBackground(BuildContext context, Set<WidgetState> states, Widget? child) =>
    _frostButtonFeedbackBackground(context, states, child, FrostFeedbackRole.quiet);

Widget frostPrimaryButtonFeedbackBackground(BuildContext context, Set<WidgetState> states, Widget? child) =>
    _frostButtonFeedbackBackground(context, states, child, FrostFeedbackRole.primary);

Widget frostSecondaryButtonFeedbackBackground(BuildContext context, Set<WidgetState> states, Widget? child) =>
    _frostButtonFeedbackBackground(context, states, child, FrostFeedbackRole.secondary);

Widget _frostButtonFeedbackBackground(BuildContext context, Set<WidgetState> states, Widget? child, FrostFeedbackRole role) {
  return Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: Builder(
            builder: (context) {
              // This context is inside the button's resolved Material, so
              // local shapes (including segmented edges and caption buttons)
              // take precedence over the global theme.
              final material = context.findAncestorWidgetOfExactType<Material>();
              final shape = material?.shape ?? RoundedRectangleBorder(borderRadius: material?.borderRadius ?? BorderRadius.zero);
              return ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: AnimatedContainer(
                  duration: FrostMotion.duration(context, FrostMotion.hover),
                  curve: FrostMotion.hoverCurve,
                  color: frostButtonStateLayer(FrostThemeTokens.of(context), states, role),
                ),
              );
            },
          ),
        ),
      ),
      child ?? const SizedBox.shrink(),
    ],
  );
}

ButtonStyle frostFeedbackStyle(FrostThemeTokens tokens, {BorderSide restingSide = BorderSide.none}) => ButtonStyle(
  mouseCursor: frostClickCursor,
  backgroundBuilder: frostButtonFeedbackBackground,
  splashFactory: NoSplash.splashFactory,
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  backgroundColor: WidgetStateProperty.resolveWith((states) => frostButtonRestingSurface(tokens, states)),
  side: WidgetStateProperty.resolveWith((states) => frostFeedbackBorder(tokens, states, restingSide: restingSide)),
);

ButtonStyle frostSecondaryButtonStyle(FrostThemeTokens tokens) => ButtonStyle(
  mouseCursor: frostClickCursor,
  backgroundBuilder: frostSecondaryButtonFeedbackBackground,
  backgroundColor: WidgetStatePropertyAll(tokens.surfaceInset),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  side: WidgetStateProperty.resolveWith((states) => frostFeedbackBorder(tokens, states)),
);

BorderSide frostFeedbackBorder(FrostThemeTokens tokens, Set<WidgetState> states, {BorderSide restingSide = BorderSide.none}) {
  if (states.contains(WidgetState.disabled)) return restingSide;
  if (frostShowsFocus(states)) return BorderSide(color: tokens.focus, width: FrostMetrics.focusBorderWidth);
  return restingSide;
}
