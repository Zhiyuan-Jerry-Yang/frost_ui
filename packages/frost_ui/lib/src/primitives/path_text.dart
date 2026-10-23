import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_path_selection.dart';
import 'text.dart';

/// A full path wrapped after separators, preserving its original copy/semantics.
/// The root and first directory stay together unless that whole fragment itself
/// exceeds the line. Oversized fragments split at grapheme boundaries, balancing
/// a short final remainder. No display controls or line breaks enter copied data.
/// Like FrostPathField, selecting any portion selects the complete path.
class FrostPathText extends StatefulWidget {
  const FrostPathText(this.path, {this.role = FrostTextRole.body, this.tone, this.selectable = false, super.key});
  final String path;
  final FrostTextRole role;
  final FrostTextTone? tone;
  final bool selectable;
  @override
  State<FrostPathText> createState() => _PathTextState();
}

class _PathTextState extends State<FrostPathText> {
  late final _selection = FrostPathSelection(() => widget.path);
  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(frostTextStyle(context, widget.role, widget.tone, numeric: true));
    final child = SelectionContainer(
      delegate: _selection,
      child: Builder(
        builder: (context) => FrostSkeletonText(
          child: _PathParagraph(
            path: widget.path,
            style: style,
            scaler: MediaQuery.textScalerOf(context),
            align: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
            registrar: SelectionContainer.maybeOf(context),
            selectionColor: Theme.of(context).textSelectionTheme.selectionColor ?? FrostThemeTokens.of(context).selectionFill,
          ),
        ),
      ),
    );
    return widget.selectable ? SelectionArea(child: child) : child;
  }
}

class _PathParagraph extends LeafRenderObjectWidget {
  const _PathParagraph({
    required this.path,
    required this.style,
    required this.scaler,
    required this.align,
    required this.registrar,
    required this.selectionColor,
  });
  final String path;
  final TextStyle style;
  final TextScaler scaler;
  final TextAlign align;
  final SelectionRegistrar? registrar;
  final Color selectionColor;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPathParagraph(this);
  @override
  void updateRenderObject(BuildContext context, _RenderPathParagraph object) => object.update(this);
}

class _RenderPathParagraph extends RenderProxyBox {
  _RenderPathParagraph(this.config)
    : super(
        RenderParagraph(
          TextSpan(text: config.path, style: config.style, semanticsLabel: config.path),
          textDirection: TextDirection.ltr,
          softWrap: false,
          textScaler: config.scaler,
          textAlign: config.align,
          registrar: config.registrar,
          selectionColor: config.selectionColor,
        ),
      );
  _PathParagraph config;
  RenderParagraph get paragraph => child! as RenderParagraph;
  void update(_PathParagraph value) {
    config = value;
    paragraph.textScaler = value.scaler;
    paragraph.textAlign = value.align;
    paragraph.registrar = value.registrar;
    paragraph.selectionColor = value.selectionColor;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextPainter painter(String value) => TextPainter(
    text: TextSpan(text: value, style: config.style),
    textDirection: TextDirection.ltr,
    textScaler: config.scaler,
  )..layout();
  double width(String value) {
    final p = painter(value);
    final result = p.width;
    p.dispose();
    return result;
  }

  String wrap(double limit) {
    final value = config.path;
    if (!limit.isFinite || width(value) <= limit) return value;
    final parts = RegExp(r'[^\\/]*[\\/]|[^\\/]+$').allMatches(value).map((m) => m[0]!).toList();
    if (parts.isEmpty) return value;
    var root = 1;
    if (RegExp(r'^(?:[a-zA-Z]:[\\/]|[\\/]|~[\\/])$').hasMatch(parts.first)) root = math.min(2, parts.length);
    if (value.startsWith(r'\\')) root = math.min(5, parts.length);
    final units = [parts.take(root).join(), ...parts.skip(root)];
    final lines = <String>[];
    var line = '';
    for (final unit in units) {
      if (width(line + unit) <= limit) {
        line += unit;
        continue;
      }
      if (line.isNotEmpty) {
        lines.add(line);
        line = '';
      }
      if (width(unit) <= limit) {
        line = unit;
        continue;
      }
      final characters = unit.characters.toList();
      final chunks = <List<String>>[];
      var start = 0;
      while (start < characters.length) {
        var low = 1, high = characters.length - start, count = 1;
        while (low <= high) {
          final middle = (low + high) ~/ 2;
          if (width(characters.skip(start).take(middle).join()) <= limit) {
            count = middle;
            low = middle + 1;
          } else {
            high = middle - 1;
          }
        }
        chunks.add(characters.skip(start).take(count).toList());
        start += count;
      }
      if (chunks.length > 1 && chunks.last.length <= 2) {
        final previous = chunks[chunks.length - 2], last = chunks.last;
        final move = (previous.length - last.length) ~/ 2;
        if (move > 0) {
          last.insertAll(0, previous.sublist(previous.length - move));
          previous.removeRange(previous.length - move, previous.length);
        }
      }
      lines.addAll(chunks.take(chunks.length - 1).map((c) => c.join()));
      line = chunks.last.join();
    }
    if (line.isNotEmpty) lines.add(line);
    return lines.join('\n');
  }

  @override
  void dispose() {
    final owned = child!;
    child = null;
    owned.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    // The public layout callback permits updating this owned paragraph before
    // laying it out, without a post-frame widget rebuild or stale first frame.
    invokeLayoutCallback<BoxConstraints>((constraints) {
      paragraph.text = TextSpan(text: wrap(constraints.maxWidth), style: config.style, semanticsLabel: config.path);
    });
    child!.layout(constraints, parentUsesSize: true);
    size = child!.size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final p = painter(wrap(constraints.maxWidth));
    final size = constraints.constrain(p.size);
    p.dispose();
    return size;
  }

  @override
  double computeMaxIntrinsicWidth(double height) => width(config.path);
  @override
  double computeMinIntrinsicWidth(double height) => config.path.characters.fold(0.0, (size, c) => math.max(size, width(c)));
  @override
  double computeMinIntrinsicHeight(double width) => computeDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);
  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final p = painter(wrap(constraints.maxWidth));
    final value = p.computeDistanceToActualBaseline(baseline);
    p.dispose();
    return value;
  }
}
