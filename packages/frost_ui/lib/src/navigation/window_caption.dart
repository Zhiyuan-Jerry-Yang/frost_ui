import '../primitives/_on_media_chrome_scope.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/feedback.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart';
import 'package:frost_ui/src/primitives/caption_glyph.dart';

abstract final class FrostCaptionMetrics {
  /// Windows caption controls keep the platform's 46 logical-pixel width.
  static const buttonWidth = 46.0;

  /// The existing native caption glyph geometry in logical pixels.
  static const glyphSize = 10.0;
}

/// Platform caption controls, stretched to their title row's height.
class FrostCaptionButtons extends StatelessWidget {
  const FrostCaptionButtons({super.key});

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
            if (state.failed) _CaptionButton(label: labels.retry, kind: FrostCaptionGlyphKind.retry, state: state, onPressed: window.retry),
            _CaptionButton(label: labels.minimize, kind: FrostCaptionGlyphKind.minimize, state: state, onPressed: window.minimize),
            FrostCaptionRegion(
              kind: FrostHitKind.maximize,
              child: _CaptionButton(
                label: state.maximized ? labels.restore : labels.maximize,
                kind: state.maximized ? FrostCaptionGlyphKind.restore : FrostCaptionGlyphKind.maximize,
                state: state,
                onPressed: window.toggleMaximized,
              ),
            ),
            _CaptionButton(label: labels.close, kind: FrostCaptionGlyphKind.close, state: state, onPressed: window.close),
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
