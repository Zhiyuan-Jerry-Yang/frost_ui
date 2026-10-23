import 'package:flutter/widgets.dart';

import '../foundation/_control_dimming.dart';
import '../foundation/_focus_modality.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '../motion/_spring_size.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/_focus_outline.dart';
import '../surface/_window_background.dart';
import '_field_layout.dart';
import '_field_options.dart';

/// Shared field paint and geometry for text, segmented time and readonly paths.
/// Editors own their input; this frame owns the single disabled opacity.
class FrostFieldFrame extends StatefulWidget {
  const FrostFieldFrame({
    required this.child,
    required this.size,
    required this.enabled,
    required this.focused,
    required this.invalid,
    this.multiline = false,
    super.key,
  });
  final Widget child;
  final FrostControlSize size;
  final bool enabled, focused, invalid, multiline;
  @override
  State<FrostFieldFrame> createState() => _FrostFieldFrameState();
}

class _FrostFieldFrameState extends State<FrostFieldFrame> {
  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  void _modalityChanged() {
    if (mounted) setState(() {});
  }

  void _highlightChanged(FocusHighlightMode _) => _modalityChanged();
  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FrostFieldFrame(:child, :size, :enabled, :focused, :invalid, :multiline) = widget;
    final tokens = FrostThemeTokens.of(context), geometry = frostControlGeometry(context, size);
    final composer = FrostFieldOptions.of(context)?.appearance == FrostFieldAppearance.composer;
    final shape = FrostRadius.shape(context, composer ? FrostRadius.md : FrostRadius.forHeight(geometry.height)) as OutlinedBorder;
    final focusInk = tokens.negativeInk.withValues(alpha: invalid ? 1 : 0);
    final contents = ConstrainedBox(
      constraints: BoxConstraints(minHeight: geometry.height),
      child: FrostAnimatedMaterialReveal(
        opacity: enabled ? 1 : .38,
        duration: FrostMotion.duration(context, FrostMotion.hover),
        child: FrostControlDimming(
          disabled: !enabled,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: frostFieldInset(size)),
            child: multiline ? child : SizedBox(height: geometry.height, child: child),
          ),
        ),
      ),
    );
    final fill = composer ? tokens.fillSubtle : tokens.fill;
    final background = frostHasTranslucentWindowBase(context) ? Color.alphaBlend(fill, tokens.surface) : fill;
    final frame = AnimatedContainer(
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      decoration: ShapeDecoration(color: background, shape: shape),
      foregroundDecoration: ShapeDecoration(
        shape: shape.copyWith(
          side: BorderSide(color: focusInk, width: FrostMetrics.fieldFocusWidth, strokeAlign: BorderSide.strokeAlignInside),
        ),
      ),
      child: composer ? FrostSpringSize(child: contents) : contents,
    );
    final visual = CustomPaint(
      foregroundPainter: enabled && frostShowsFocus({if (focused) WidgetState.focused})
          ? FrostFocusOutlinePainter(shape, tokens.focus, FrostMetrics.focusBorderWidth, Directionality.of(context))
          : null,
      child: frame,
    );
    return composer
        ? visual
        : FrostMotionSize(duration: FrostMotion.duration(context, FrostMotion.layoutFade), alignment: AlignmentDirectional.topStart, child: visual);
  }
}
