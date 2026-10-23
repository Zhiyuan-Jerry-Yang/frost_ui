import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';

// Shared by shelves and thumbnail strips; fades reveal at most 24 logical pixels.
const _scrollFadeExtent = 24.0;

/// Reads final scroll geometry when painting, including the first layout.
class FrostScrollEdgeFade extends StatelessWidget {
  const FrostScrollEdgeFade({required this.controller, required this.child, this.repaint, super.key});
  final ScrollController controller;
  final Listenable? repaint;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?repaint]),
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final position = controller.hasClients && controller.position.hasContentDimensions ? controller.position : null;
        final limit = math.min(_scrollFadeExtent, rect.width / 2);
        final before = (position?.extentBefore ?? 0).clamp(0.0, limit);
        final after = (position?.extentAfter ?? 0).clamp(0.0, limit);
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final left = rtl ? after : before, right = rtl ? before : after;
        final opaque = FrostThemeTokens.of(context).canvas.withValues(alpha: 1), clear = opaque.withValues(alpha: 0);
        return LinearGradient(
          colors: [left == 0 ? opaque : clear, opaque, opaque, right == 0 ? opaque : clear],
          stops: [0, rect.width == 0 ? 0 : left / rect.width, rect.width == 0 ? 1 : 1 - right / rect.width, 1],
        ).createShader(rect);
      },
      child: child,
    ),
    child: child,
  );
}
