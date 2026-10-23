import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../motion/rolling_text.dart';
import '../primitives/_local_scroll_view.dart';
import '../primitives/divider.dart';
import '../primitives/text.dart';

// Stat captions sit closer than related controls; separators have roomy sides.
const _captionGap = 2.0;
const _separatorInset = 16.0;

class FrostStat extends StatelessWidget {
  /// Explicit content determines bones only; semantics use the loading label.
  factory FrostStat.skeleton({required String value, required String? unit, required String? caption}) =>
      _SkeletonStat(value: value, unit: unit, caption: caption);
  const FrostStat({required this.value, required this.caption, this.unit, super.key});
  final String value, caption;
  final String? unit;
  @override
  Widget build(BuildContext context) => Semantics(
    label: caption,
    value: [value, ?unit].join(' '),
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: FrostGap.inline,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            FrostLocalScrollView(
              scrollDirection: Axis.horizontal,
              child: FrostRollingText(
                value,
                style: FrostTypography.of(context).style(FrostTextRole.value, numeric: true).copyWith(color: FrostThemeTokens.of(context).textPrimary),
              ),
            ),
            if (unit != null) FrostText(unit!, role: FrostTextRole.subheadline, tone: FrostTextTone.secondary, numeric: true),
          ],
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: _captionGap),
          FrostText(caption, role: FrostTextRole.caption, tone: FrostTextTone.secondary, numeric: true),
        ],
      ],
    ),
  );
}

class _SkeletonStat extends FrostStat {
  const _SkeletonStat({required super.value, required super.unit, required String? caption}) : super(caption: caption ?? '');
  @override
  Widget build(BuildContext context) => super.build(context).frostSkeleton(true);
}

/// Measures actual stats before choosing a single row or a two-column grid.
/// A single row packs each stat at its natural width from the directional start.
class FrostStatStrip extends StatefulWidget {
  const FrostStatStrip({required this.stats, super.key});
  final List<FrostStat> stats;
  @override
  State<FrostStatStrip> createState() => _StatStripState();
}

class _StatStripState extends State<FrostStatStrip> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMotionSize(
    duration: FrostMotion.duration(context, FrostMotion.layoutFade),
    alignment: AlignmentDirectional.topStart,
    child: FrostLayoutCrossfade(
      layoutIdentity: _identity,
      settleDuration: Duration.zero,
      child: _StatLayout(
        identity: _identity,
        contentIdentity: Object.hashAll(widget.stats.map((stat) => (stat.value, stat.caption, stat.unit))),
        count: widget.stats.length,
        direction: Directionality.of(context),
        separatorWidth: 1 / MediaQuery.devicePixelRatioOf(context),
        children: [
          ...widget.stats,
          for (var i = 1; i < widget.stats.length; i++) const FrostDivider(axis: Axis.vertical),
        ],
      ),
    ),
  );
}

class _Data extends ContainerBoxParentData<RenderBox> {
  bool visible = true;
}

class _StatLayout extends MultiChildRenderObjectWidget {
  const _StatLayout({
    required this.identity,
    required this.contentIdentity,
    required this.count,
    required this.direction,
    required this.separatorWidth,
    required super.children,
  });
  final FrostLayoutIdentity identity;
  final int contentIdentity, count;
  final TextDirection direction;
  final double separatorWidth;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStats(this);
  @override
  void updateRenderObject(BuildContext context, _RenderStats renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderStats extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderStats(this.config);
  _StatLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  Size _layout(BoxConstraints limits, {required bool dry}) {
    final all = getChildrenAsList(), stats = all.take(config.count).toList(), dividers = all.skip(config.count).toList();
    if (stats.isEmpty) return limits.constrain(Size.zero);
    // Wrap's intrinsic width omits its spacing. Measure the actual natural
    // layout so a value and its unit still fit together when no extra is added.
    final preferred = [for (final child in stats) child.getDryLayout(const BoxConstraints()).width];
    final separator = _separatorInset * 2 + config.separatorWidth;
    final naturalWidth = preferred.fold(0.0, (a, b) => a + b) + separator * dividers.length;
    final width = limits.hasBoundedWidth ? limits.maxWidth : naturalWidth;
    final inline = naturalWidth <= width;
    if (!dry) config.identity.update((config.contentIdentity, inline), viewport: limits);
    Size measure(RenderBox child, double width, [double? height]) {
      final c = BoxConstraints.tightFor(width: width, height: height);
      if (dry) return child.getDryLayout(c);
      child.layout(c, parentUsesSize: true);
      return child.size;
    }

    void place(RenderBox child, double x, double y, double childWidth, {bool visible = true}) {
      if (dry) return;
      final data = child.parentData! as _Data;
      data.visible = visible;
      data.offset = Offset(config.direction == TextDirection.ltr ? x : width - x - childWidth, y);
    }

    var height = 0.0;
    if (inline) {
      final sizes = [for (var i = 0; i < stats.length; i++) measure(stats[i], preferred[i])];
      height = sizes.fold(0.0, (h, s) => math.max(h, s.height));
      var x = 0.0;
      for (var i = 0; i < stats.length; i++) {
        place(stats[i], x, 0, sizes[i].width);
        x += sizes[i].width;
        if (i < dividers.length) {
          measure(dividers[i], config.separatorWidth, height);
          place(dividers[i], x + _separatorInset, 0, config.separatorWidth);
          x += separator;
        }
      }
    } else {
      final cell = math.max(0.0, (width - FrostGap.group) / 2);
      for (var i = 0; i < stats.length; i += 2) {
        final a = measure(stats[i], cell), b = i + 1 < stats.length ? measure(stats[i + 1], cell) : Size.zero;
        place(stats[i], 0, height, cell);
        if (i + 1 < stats.length) place(stats[i + 1], cell + FrostGap.group, height, cell);
        height += math.max(a.height, b.height) + (i + 2 < stats.length ? FrostGap.group : 0);
      }
      for (final child in dividers) {
        measure(child, 0, 0);
        place(child, 0, 0, 0, visible: false);
      }
    }
    return limits.constrain(Size(width, height));
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);
  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in getChildrenAsList()) {
      final data = child.parentData! as _Data;
      if (data.visible) context.paintChild(child, offset + data.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in getChildrenAsList()) {
      if ((child.parentData! as _Data).visible) visitor(child);
    }
  }
}
