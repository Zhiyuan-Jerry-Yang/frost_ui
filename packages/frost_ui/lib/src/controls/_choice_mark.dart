import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';
import '../motion/_user_selection_draw.dart';
import '../motion/spring.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/click_surface.dart';
import '../primitives/status_glyph.dart';

// Selection marks keep their geometry in both density columns. Stroke points
// are fractions of the approved 20-point square, independent of pixel ratio.
const frostChoiceExtent = 20.0;
const _strokeWidth = 2.0, _radioDotDiameter = 8.0;
const _dashStart = Offset(6 / 20, 10 / 20), _dashEnd = Offset(14 / 20, 10 / 20);

bool? frostNextCheckboxValue(bool? value, bool tristate) => switch (value) {
  false => true,
  true => tristate ? null : false,
  null => false,
};

enum FrostChoiceKind { checkbox, radio }

/// Paint shared by standalone checkboxes and the leading marks in list rows.
/// Rows supply the only interaction/disabled layer; marks never add a second.
class FrostChoiceMark extends StatefulWidget {
  const FrostChoiceMark({required this.value, this.kind = FrostChoiceKind.checkbox, this.states = const {}, this.drawTrigger, super.key});
  final bool? value;
  final FrostChoiceKind kind;
  final Set<WidgetState> states;
  final Object? drawTrigger;
  @override
  State<FrostChoiceMark> createState() => _ChoiceMarkState();
}

class _ChoiceMarkState extends State<FrostChoiceMark> {
  bool _userChange = false;
  @override
  void initState() {
    super.initState();
    _userChange = frostFreshUserSelection(widget.drawTrigger);
  }

  static const _pop = AlwaysStoppedAnimation<double>(1);
  @override
  void didUpdateWidget(FrostChoiceMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _userChange = widget.drawTrigger != null && widget.drawTrigger != oldWidget.drawTrigger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final shape = widget.kind == FrostChoiceKind.radio ? const CircleBorder() : FrostRadius.shape(context, FrostRadius.xs);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = widget.kind == FrostChoiceKind.radio
        ? FrostMotion.duration(context, FrostMotion.feedback)
        : !_userChange
        ? Duration.zero
        : reduced
        ? frostStatusReducedDuration
        : widget.value == true
        ? frostSelectionDrawDuration
        : FrostMotion.feedback;
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) => Transform.scale(scale: _pop.value, child: child),
      child: AnimatedContainer(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        decoration: ShapeDecoration(color: widget.value == false ? tokens.fillStrong : tokens.actionFill, shape: shape),
        child: FrostClickFeedbackVisual(
          states: widget.states,
          feedback: FrostClickFeedback.quiet,
          shape: shape,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: tokens.onAction),
            duration: FrostMotion.duration(context, FrostMotion.hover),
            builder: (context, ink, _) => TweenAnimationBuilder<double>(
              tween: Tween(begin: _userChange && widget.value == true ? 0 : null, end: widget.value == true ? 1 : 0),
              duration: duration,
              builder: (context, check, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: widget.value == null ? 1 : 0),
                duration: duration,
                builder: (context, mixed, _) => FrostSpringBuilder(
                  value: widget.value == true ? 1 : 0,
                  spring: FrostMotion.snappy,
                  builder: (context, dot, _) => CustomPaint(
                    size: const Size.square(frostChoiceExtent),
                    painter: FrostChoicePainter(
                      kind: widget.kind,
                      ink: ink!,
                      check: check,
                      mixed: mixed,
                      dot: dot.clamp(0, 1),
                      fadeCheck: reduced || !_userChange || widget.value != true,
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

/// Internal painter exposed to source-level drawing tests, never package users.
class FrostChoicePainter extends CustomPainter {
  const FrostChoicePainter({required this.kind, required this.ink, required this.check, required this.mixed, required this.dot, this.fadeCheck = false});
  final FrostChoiceKind kind;
  final Color ink;
  final double check, mixed, dot;
  final bool fadeCheck;
  @override
  void paint(Canvas canvas, Size size) {
    if (kind == FrostChoiceKind.radio) {
      if (dot > 0) {
        canvas.drawCircle(
          size.center(Offset.zero),
          _radioDotDiameter / 2 * dot,
          Paint()
            ..color = ink
            ..isAntiAlias = true,
        );
      }
      return;
    }
    Offset point(Offset fraction) => Offset(fraction.dx * size.width, fraction.dy * size.height);
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    if (check > 0) {
      frostPaintStatusGlyph(canvas, size, FrostStatusGlyphKind.success, fadeCheck ? ink.withValues(alpha: ink.a * check) : ink, fadeCheck ? 1 : check);
    }
    if (mixed > 0) {
      canvas.drawLine(point(_dashStart), Offset.lerp(point(_dashStart), point(_dashEnd), mixed)!, paint);
    }
  }

  @override
  bool shouldRepaint(FrostChoicePainter oldDelegate) =>
      kind != oldDelegate.kind ||
      ink != oldDelegate.ink ||
      check != oldDelegate.check ||
      mixed != oldDelegate.mixed ||
      dot != oldDelegate.dot ||
      fadeCheck != oldDelegate.fadeCheck;
}
