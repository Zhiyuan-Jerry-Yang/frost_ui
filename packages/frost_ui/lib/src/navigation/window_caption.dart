import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frost_window/frost_window.dart' show FrostCaptionAction, FrostCaptionIcon, FrostCaptionMode, FrostCaptionStyle;

import '../foundation/color_math.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../layout/window_caption_scope.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/caption_glyph.dart';

abstract final class FrostCaptionMetrics {
  /// Windows caption controls keep the platform's 46 logical-pixel width.
  static const buttonWidth = 46.0;

  /// The existing native caption glyph geometry in logical pixels.
  static const glyphSize = 10.0;

  static const linuxButtonWidth = 36.0;
  static const linuxButtonSize = 28.0;
  static const linuxGlyphSize = 16.0;
}

/// Platform caption controls, stretched to their title row's height.
class FrostCaptionButtons extends StatelessWidget {
  const FrostCaptionButtons({this.side = FrostCaptionSide.right, super.key});
  final FrostCaptionSide side;

  @override
  Widget build(BuildContext context) {
    final window = FrostWindowCaptionScope.windowOf(context);
    if (window == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: window,
      builder: (context, _) {
        final state = window.captionState;
        final labels = FrostScope.labelsOf(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.failed && side == FrostCaptionSide.right)
              _CaptionButton(label: labels.retry, kind: FrostCaptionGlyphKind.retry, state: state, onPressed: window.retry),
            for (final action
                in state.mode != FrostCaptionMode.client ? <FrostCaptionAction>[] : (side == FrostCaptionSide.left ? state.leftButtons : state.rightButtons))
              switch (action) {
                FrostCaptionAction.minimize => _CaptionButton(
                  label: labels.minimize,
                  kind: FrostCaptionGlyphKind.minimize,
                  state: state,
                  onPressed: window.minimize,
                ),
                FrostCaptionAction.maximize => FrostCaptionRegion(
                  kind: FrostHitKind.maximize,
                  child: _CaptionButton(
                    label: state.maximized ? labels.restore : labels.maximize,
                    kind: state.maximized ? FrostCaptionGlyphKind.restore : FrostCaptionGlyphKind.maximize,
                    state: state,
                    onPressed: window.toggleMaximized,
                  ),
                ),
                FrostCaptionAction.close => _CaptionButton(label: labels.close, kind: FrostCaptionGlyphKind.close, state: state, onPressed: window.close),
              },
          ],
        );
      },
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({required this.label, required this.kind, required this.state, required this.onPressed});
  final String label;
  final FrostCaptionGlyphKind kind;
  final FrostCaptionState state;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    if (state.style != FrostCaptionStyle.windows) {
      return _LinuxCaptionButton(label: label, kind: kind, state: state, onPressed: onPressed);
    }
    final tokens = FrostThemeTokens.of(context);
    final mediaInk = FrostOnMediaChromeScope.inkOf(context);
    final danger = kind == FrostCaptionGlyphKind.close;
    final maximize = kind == FrostCaptionGlyphKind.maximize || kind == FrostCaptionGlyphKind.restore;
    return SizedBox(
      width: FrostCaptionMetrics.buttonWidth,
      child: IconButton(
        tooltip: label,
        onPressed: () => unawaited(onPressed()),
        icon: Semantics(
          label: label,
          child: Builder(
            builder: (context) => FrostCaptionGlyph(kind, color: IconTheme.of(context).color!, size: FrostCaptionMetrics.glyphSize),
          ),
        ),
        style: ButtonStyle(
          // The Windows exception owns its background and square focus ring.
          backgroundBuilder: (context, states, child) => child ?? const SizedBox.shrink(),
          minimumSize: const WidgetStatePropertyAll(Size.zero),
          maximumSize: const WidgetStatePropertyAll(Size.infinite),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final color = danger && (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed))
                ? FrostCaptionColors.onClose
                : mediaInk ?? tokens.textPrimary;
            return color.withValues(alpha: state.active ? 1 : .6);
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(color: frostShowsFocus(states) ? mediaInk ?? tokens.focus : Colors.transparent, width: FrostMetrics.focusBorderWidth),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            final hovered = states.contains(WidgetState.hovered) || (maximize && state.maximizeHovered);
            final pressed = states.contains(WidgetState.pressed) || (maximize && state.maximizePressed && state.maximizeHovered);
            if (!hovered && !pressed) return Colors.transparent;
            if (danger) return pressed ? FrostCaptionColors.closePressed : FrostCaptionColors.closeHover;
            return mediaInk == null ? (pressed ? tokens.fillStrong : tokens.fillSubtle) : mediaInk.withValues(alpha: pressed ? .12 : .08);
          }),
        ),
      ),
    );
  }
}

// Keep Linux theme integration bounded: symbolic system icons, Adwaita geometry,
// and Breeze's hover treatment. Arbitrary GTK/KWin decoration themes cannot be
// reproduced reliably on application-owned backgrounds (Electron's WCO tradeoff).
class _LinuxCaptionButton extends StatelessWidget {
  const _LinuxCaptionButton({required this.label, required this.kind, required this.state, required this.onPressed});
  final String label;
  final FrostCaptionGlyphKind kind;
  final FrostCaptionState state;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final mediaInk = FrostOnMediaChromeScope.inkOf(context);
    final ink = (mediaInk ?? tokens.textPrimary).withValues(alpha: state.active ? 1 : .6);
    final breeze = state.style == FrostCaptionStyle.breeze;
    final close = kind == FrostCaptionGlyphKind.close;
    final icon = switch (kind) {
      FrostCaptionGlyphKind.minimize => FrostCaptionIcon.minimize,
      FrostCaptionGlyphKind.maximize => FrostCaptionIcon.maximize,
      FrostCaptionGlyphKind.restore => FrostCaptionIcon.restore,
      FrostCaptionGlyphKind.close => FrostCaptionIcon.close,
      FrostCaptionGlyphKind.retry => null,
    };
    final bytes = state.icons[icon];
    Widget fallback(Color color) => SizedBox.square(
      dimension: FrostCaptionMetrics.linuxGlyphSize,
      child: Center(
        child: FrostCaptionGlyph(kind, color: color, size: FrostCaptionMetrics.linuxGlyphSize - FrostGap.inline),
      ),
    );
    Color background(Set<WidgetState> states) {
      final pressed = states.contains(WidgetState.pressed);
      final hovered = states.contains(WidgetState.hovered);
      if (breeze && close && (hovered || pressed)) return pressed ? FrostCaptionColors.closePressed : FrostCaptionColors.closeHover;
      if (breeze && (hovered || pressed)) return ink;
      if (mediaInk != null) {
        return mediaInk.withValues(
          alpha: pressed
              ? .2
              : hovered
              ? .14
              : close
              ? .08
              : 0,
        );
      }
      return pressed
          ? tokens.fillStrong
          : hovered || close
          ? tokens.fillSubtle
          : Colors.transparent;
    }

    return SizedBox(
      width: FrostCaptionMetrics.linuxButtonWidth,
      child: Center(
        child: IconButton(
          tooltip: label,
          onPressed: () => unawaited(onPressed()),
          style: ButtonStyle(
            fixedSize: const WidgetStatePropertyAll(Size.square(FrostCaptionMetrics.linuxButtonSize)),
            minimumSize: const WidgetStatePropertyAll(Size.square(FrostCaptionMetrics.linuxButtonSize)),
            maximumSize: const WidgetStatePropertyAll(Size.square(FrostCaptionMetrics.linuxButtonSize)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const WidgetStatePropertyAll(CircleBorder()),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
            backgroundColor: WidgetStateProperty.resolveWith(background),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (breeze && (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed))) {
                return close ? FrostCaptionColors.onClose : solidLabelTone(ink);
              }
              return ink;
            }),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(color: frostShowsFocus(states) ? mediaInk ?? tokens.focus : Colors.transparent, width: FrostMetrics.focusBorderWidth),
            ),
          ),
          icon: ExcludeSemantics(
            child: Builder(
              builder: (context) {
                final color = IconTheme.of(context).color!;
                return bytes == null
                    ? fallback(color)
                    : Image.memory(
                        bytes,
                        width: FrostCaptionMetrics.linuxGlyphSize,
                        height: FrostCaptionMetrics.linuxGlyphSize,
                        color: color,
                        colorBlendMode: BlendMode.srcIn,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => fallback(color),
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks content whose owner has already placed it below the caption row.
class FrostCaptionClearance extends InheritedWidget {
  const FrostCaptionClearance({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostCaptionClearance>() != null;
  @override
  bool updateShouldNotify(FrostCaptionClearance oldWidget) => false;
}

/// Keeps top-of-window controls clear of measured native window buttons.
/// Apply at the full-width header boundary, before ordinary content gutters.
class FrostNativeCaptionPadding extends StatelessWidget {
  const FrostNativeCaptionPadding({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rect = FrostWindowCaptionScope.stateOf(context)?.nativeControls ?? Rect.zero;
    if (FrostCaptionClearance.of(context) || rect.isEmpty) return child;
    return FrostCaptionClearance(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: rect.bottom + FrostGap.related),
        child: Padding(
          padding: EdgeInsets.only(left: rect.right + FrostGap.related),
          child: child,
        ),
      ),
    );
  }
}
