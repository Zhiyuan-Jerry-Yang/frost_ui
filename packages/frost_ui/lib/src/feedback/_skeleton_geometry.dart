import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';
// A single bridge to the dependency's painting context; effects, scheduling,
// and shaders remain owned by skeletonizer. No canvas or package code is copied.
// ignore: implementation_imports -- SkeletonizerPainter exposes this context; the bridge only reads its shared shader.
import 'package:skeletonizer/src/painting/skeletonizer_painting_context.dart';

import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/skeleton_style.dart';

const _minimumTextBoneGap = 4.0;

/// Keeps the real paragraph and its state/layout; replaces only its paint.
class FrostSkeletonText extends StatelessWidget {
  const FrostSkeletonText({required this.child, this.painter, this.textLength, super.key});
  final Widget child;
  final TextPainter? painter;
  final int? textLength;
  @override
  Widget build(BuildContext context) {
    final enabled = Skeletonizer.maybeOf(context)?.enabled == true;
    final style = enabled ? FrostScope.configOf(context).skeleton ?? const FrostSkeletonStyle() : const FrostSkeletonStyle();
    return _TextBone(
      enabled: enabled,
      factor: style.textHeightFactor,
      radius: style.textRadius ?? FrostRadius.xs,
      painter: painter,
      textLength: textLength,
      child: child,
    );
  }
}

class _TextBone extends SingleChildRenderObjectWidget {
  const _TextBone({required this.enabled, required this.factor, required this.radius, required this.painter, required this.textLength, required super.child});
  final bool enabled;
  final double factor, radius;
  final TextPainter? painter;
  final int? textLength;
  @override
  RenderFrostSkeletonText createRenderObject(BuildContext context) => RenderFrostSkeletonText(enabled, factor, radius, painter, textLength);
  @override
  void updateRenderObject(BuildContext context, RenderFrostSkeletonText render) {
    render
      ..enabled = enabled
      ..factor = factor
      ..radius = radius
      ..painter = painter
      ..textLength = textLength
      ..markNeedsLayout();
  }
}

/// Internal geometry is exposed only to library tests, never through frost_ui.
class RenderFrostSkeletonText extends RenderProxyBox {
  RenderFrostSkeletonText(this.enabled, this.factor, this.radius, this.painter, this.textLength);
  bool enabled;
  double factor, radius;
  TextPainter? painter;
  int? textLength;
  List<Rect> bones = const [];

  RenderBox? _paragraph(RenderObject node) {
    if (node is RenderParagraph || node is RenderEditable) return node as RenderBox;
    RenderBox? result;
    node.visitChildren((child) {
      result ??= _paragraph(child);
    });
    return result;
  }

  @override
  void performLayout() {
    super.performLayout();
    bones = const [];
    if (!enabled || child == null) return;
    final paragraph = _paragraph(child!);
    final measured = painter;
    if (paragraph == null && measured == null) return;
    final InlineSpan text;
    final TextScaler scaler;
    final List<TextBox> Function(TextSelection) boxesFor;
    if (measured != null) {
      text = measured.text!;
      scaler = measured.textScaler;
      boxesFor = (selection) => measured.getBoxesForSelection(selection, boxHeightStyle: BoxHeightStyle.includeLineSpacingMiddle);
    } else if (paragraph is RenderParagraph) {
      text = paragraph.text;
      scaler = paragraph.textScaler;
      boxesFor = (selection) => paragraph.getBoxesForSelection(selection, boxHeightStyle: BoxHeightStyle.includeLineSpacingMiddle);
    } else {
      final editable = paragraph as RenderEditable;
      text = editable.text!;
      scaler = editable.textScaler;
      boxesFor = editable.getBoxesForSelection;
    }
    final length = textLength ?? text.toPlainText().length;
    final lines = <Rect>[];
    // Selection boxes with line spacing have the same vertical frame for every
    // styled run on a line. Use that frame rather than accessing a private
    // TextPainter or reconstructing the paragraph with different constraints.
    int lineKey(Rect box) {
      for (var index = 0; index < lines.length; index++) {
        if ((lines[index].center.dy - box.center.dy).abs() < .001) return index;
      }
      lines.add(box);
      return lines.length - 1;
    }

    for (final box in boxesFor(TextSelection(baseOffset: 0, extentOffset: length))) {
      final rect = box.toRect();
      if (rect.width <= 0) continue;
      final key = lineKey(rect);
      lines[key] = lines[key].expandToInclude(rect);
    }
    final keys = List<int>.generate(lines.length, (index) => index)..sort((a, b) => lines[a].top.compareTo(lines[b].top));
    final transform = measured == null ? paragraph!.getTransformTo(this) : Matrix4.identity();
    final paragraphHeight = measured == null ? paragraph!.size.height : size.height;
    final fonts = <int, double>{};
    var cursor = 0;
    void visit(InlineSpan span, TextStyle inherited) {
      final style = inherited.merge(span.style);
      if (span is TextSpan) {
        final end = cursor + (span.text?.length ?? 0);
        if (end > cursor && cursor < length) {
          for (final box in boxesFor(TextSelection(baseOffset: cursor, extentOffset: math.min(end, length)))) {
            if (box.right <= box.left) continue;
            final key = lineKey(box.toRect());
            final font = scaler.scale(style.fontSize ?? text.style?.fontSize ?? 14);
            fonts[key] = math.max(fonts[key] ?? 0, font);
          }
        }
        cursor = end;
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      } else {
        cursor += span.toPlainText().length;
      }
    }

    visit(text, const TextStyle());
    bones = [
      for (var index = 0; index < keys.length; index++)
        () {
          final line = lines[keys[index]];
          final fontSize = fonts[keys[index]] ?? scaler.scale(text.style?.fontSize ?? 14);
          final top = index == 0 ? 0.0 : (lines[keys[index - 1]].center.dy + line.center.dy) / 2;
          final bottom = index == keys.length - 1 ? paragraphHeight : (line.center.dy + lines[keys[index + 1]].center.dy) / 2;
          // Two half-gaps inside every line guarantee four between adjacent
          // frames, even with zero inter-line spacing or very tight leading.
          final height = math.min(fontSize * factor, math.max(0.0, bottom - top - _minimumTextBoneGap));
          return MatrixUtils.transformRect(transform, Rect.fromLTWH(line.left, (top + bottom - height) / 2, line.width, height));
        }(),
    ];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!enabled || context is! SkeletonizerPaintingContext) {
      super.paint(context, offset);
      return;
    }
    context.createDefaultContext(offset & size, (canvasContext, _) {
      for (final bone in bones) {
        canvasContext.canvas.drawRRect(RRect.fromRectAndRadius(bone.shift(offset), Radius.circular(radius)), context.shaderPaint);
      }
    });
  }
}

/// Whole containers retain their real geometry but never paint inner bones.
class FrostSkeletonShape extends SingleChildRenderObjectWidget {
  const FrostSkeletonShape({required this.shape, required super.child, this.visualHeight, this.active = true, super.key});
  final ShapeBorder shape;
  final double? visualHeight;
  final bool active;
  @override
  RenderFrostSkeletonShape createRenderObject(BuildContext context) => RenderFrostSkeletonShape(shape, Directionality.of(context), visualHeight, active);
  @override
  void updateRenderObject(BuildContext context, RenderFrostSkeletonShape renderObject) {
    renderObject
      ..shape = shape
      ..visualHeight = visualHeight
      ..active = active
      ..direction = Directionality.of(context)
      ..markNeedsPaint();
  }
}

class RenderFrostSkeletonShape extends RenderProxyBox {
  RenderFrostSkeletonShape(this.shape, this.direction, this.visualHeight, this.active);
  ShapeBorder shape;
  double? visualHeight;
  bool active;
  TextDirection direction;
  @override
  void paint(PaintingContext context, Offset offset) {
    if (!active || context is! SkeletonizerPaintingContext) {
      super.paint(context, offset);
      return;
    }
    context.createDefaultContext(offset & size, (canvasContext, _) {
      canvasContext.canvas.drawPath(
        shape.getOuterPath(
          Rect.fromCenter(center: (offset & size).center, width: size.width, height: math.min(visualHeight ?? size.height, size.height)),
          textDirection: direction,
        ),
        context.shaderPaint,
      );
    });
  }
}
