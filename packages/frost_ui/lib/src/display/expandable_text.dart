import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/spring.dart';
import '../primitives/click_surface.dart';

// A fixed fade keeps long translations from consuming more body text.
const frostExpandableTextFadeWidth = 24.0;

/// Measures overflow during layout. Uncontrolled by default; a supplied expanded
/// value needs onExpandedChanged to enable the inline action.
class FrostExpandableText extends StatefulWidget {
  const FrostExpandableText({required this.text, this.maxLines = 3, this.role = FrostTextRole.body, this.expanded, this.onExpandedChanged, super.key})
    : assert(maxLines > 0);
  final String text;
  final int maxLines;
  final FrostTextRole role;
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;
  @override
  State<FrostExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<FrostExpandableText> {
  bool _expanded = false;
  bool get expanded => widget.expanded ?? _expanded;
  @override
  void didUpdateWidget(FrostExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != null && widget.expanded == null) _expanded = oldWidget.expanded!;
  }

  void _toggle() {
    final next = !expanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tokens = FrostThemeTokens.of(context);
      final style = FrostTypography.of(context).style(widget.role).copyWith(color: tokens.textPrimary);
      final scaler = MediaQuery.textScalerOf(context), direction = Directionality.of(context);
      final plain = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: widget.maxLines,
      );
      plain.layout(maxWidth: constraints.maxWidth);
      final overflows = plain.didExceedMaxLines;
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : plain.maxIntrinsicWidth;
      final plainHeight = plain.height;
      plain.dispose();
      if (!overflows) return _frame(width, plainHeight, FrostSkeletonText(child: Text(widget.text, style: style)));
      final label = expanded ? FrostScope.labelsOf(context).collapseText : FrostScope.labelsOf(context).expandText;
      final actionStyle = style.copyWith(color: tokens.accentInk);
      final actionPainter = TextPainter(
        text: TextSpan(text: label, style: actionStyle),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final actionSize = Size(math.min(width, actionPainter.width), actionPainter.height);
      actionPainter.dispose();
      final placeholder = PlaceholderDimensions(
        size: Size(math.min(width, actionSize.width + FrostGap.inline), actionSize.height),
        alignment: PlaceholderAlignment.bottom,
      );
      TextPainter measure(String text, {int? maxLines}) =>
          TextPainter(
              text: TextSpan(
                style: style,
                children: [
                  TextSpan(text: text),
                  const WidgetSpan(alignment: PlaceholderAlignment.bottom, child: SizedBox()),
                ],
              ),
              textDirection: direction,
              textScaler: scaler,
              maxLines: maxLines,
            )
            ..setPlaceholderDimensions([placeholder])
            ..layout(maxWidth: width);
      var body = widget.text;
      if (!expanded) {
        final graphemes = widget.text.characters.toList();
        var lower = 0, upper = graphemes.length;
        while (lower < upper) {
          final middle = (lower + upper + 1) ~/ 2;
          final probe = measure(graphemes.take(middle).join().trimRight(), maxLines: widget.maxLines);
          final fits = !probe.didExceedMaxLines;
          probe.dispose();
          if (fits) {
            lower = middle;
          } else {
            upper = middle - 1;
          }
        }
        body = graphemes.take(lower).join().trimRight();
      }
      final painter = measure(body);
      final box = painter.inlinePlaceholderBoxes!.single.toRect();
      final rtl = direction == TextDirection.rtl;
      final actionRect = Rect.fromLTWH(rtl ? box.left : box.right - actionSize.width, box.top, actionSize.width, actionSize.height);
      final fade = expanded
          ? null
          : Rect.fromLTRB(
              rtl ? box.right : math.max(0, box.left - frostExpandableTextFadeWidth),
              box.top,
              rtl ? math.min(width, box.right + frostExpandableTextFadeWidth) : box.left,
              box.bottom,
            );
      final height = painter.height;
      final enabled = widget.expanded == null || widget.onExpandedChanged != null;
      final content = SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: body,
                child: FrostSkeletonText(
                  painter: painter,
                  textLength: body.length,
                  child: _PaintedText(painter: painter, fade: fade, rtl: rtl, mask: tokens.canvas),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: actionRect,
              child: Semantics(
                label: label,
                button: true,
                expanded: expanded,
                enabled: enabled,
                excludeSemantics: true,
                onTap: enabled ? _toggle : null,
                child: FrostClickSurface(
                  onTap: enabled ? _toggle : null,
                  customBorder: FrostRadius.shape(context, FrostRadius.xs),
                  child: FrostSkeletonText(child: Text(label, style: actionStyle)),
                ),
              ),
            ),
          ],
        ),
      );
      return _frame(width, height, content);
    },
  );
  Widget _frame(double width, double height, Widget child) => FrostSpringBuilder(
    value: height,
    spring: FrostMotion.standard,
    child: SizedBox(width: width, height: height, child: child),
    builder: (context, value, child) => ClipRect(
      child: SizedBox(
        width: width,
        height: math.max(0, value),
        child: OverflowBox(alignment: AlignmentDirectional.topStart, minHeight: height, maxHeight: height, child: child),
      ),
    ),
  );
}

class _PaintedText extends StatefulWidget {
  const _PaintedText({required this.painter, required this.fade, required this.rtl, required this.mask});
  final TextPainter painter;
  final Rect? fade;
  final bool rtl;
  final Color mask;
  @override
  State<_PaintedText> createState() => _PaintedTextState();
}

class _PaintedTextState extends State<_PaintedText> {
  @override
  void didUpdateWidget(_PaintedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.painter, widget.painter)) oldWidget.painter.dispose();
  }

  @override
  void dispose() {
    widget.painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: FrostExpandableTextPainter(widget.painter, widget.fade, widget.rtl, widget.mask));
}

class FrostExpandableTextPainter extends CustomPainter {
  const FrostExpandableTextPainter(this.text, this.fade, this.rtl, this.mask);
  final TextPainter text;
  final Rect? fade;
  final bool rtl;
  final Color mask;
  @override
  void paint(Canvas canvas, Size size) {
    if (fade != null && !fade!.isEmpty) canvas.saveLayer(Offset.zero & size, Paint());
    text.paint(canvas, Offset.zero);
    if (fade case final rect? when !rect.isEmpty) {
      final solid = mask.withValues(alpha: 1), clear = mask.withValues(alpha: 0);
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(colors: rtl ? [clear, solid] : [solid, clear]).createShader(rect),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FrostExpandableTextPainter oldDelegate) =>
      text != oldDelegate.text || fade != oldDelegate.fade || rtl != oldDelegate.rtl || mask != oldDelegate.mask;
}
