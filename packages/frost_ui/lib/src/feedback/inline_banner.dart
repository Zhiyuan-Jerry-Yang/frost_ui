import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/status_glyph.dart';
import '../primitives/text.dart';

// Banners use compact semantic icons, inset by one group gap.
const _bannerInset = 12.0, _bannerIconSize = 18.0, _bannerTextGap = 2.0;

enum FrostBannerTone { info, positive, caution, negative }

/// Inline feedback. Use FrostPresence(expand) at the call site for insertion
/// and removal; actions reflow in layout and the dismiss control stays on top.
class FrostInlineBanner extends StatelessWidget {
  const FrostInlineBanner({required this.tone, required this.message, this.title, this.actionLabel, this.onAction, this.onDismiss, super.key});
  final FrostBannerTone tone;
  final String message;
  final String? title, actionLabel;
  final VoidCallback? onAction, onDismiss;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context), icons = FrostIconSet.of(context);
    final (tint, ink, kind) = switch (tone) {
      FrostBannerTone.info => (tokens.infoTint, tokens.infoInk, null),
      FrostBannerTone.positive => (tokens.positiveTint, tokens.positiveInk, FrostStatusGlyphKind.success),
      FrostBannerTone.caution => (tokens.cautionTint, tokens.cautionInk, FrostStatusGlyphKind.warning),
      FrostBannerTone.negative => (tokens.negativeTint, tokens.negativeInk, FrostStatusGlyphKind.failure),
    };
    return Semantics(
      container: true,
      liveRegion: tone == FrostBannerTone.caution || tone == FrostBannerTone.negative,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: tint),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        builder: (context, color, _) => DecoratedBox(
          decoration: ShapeDecoration(color: color, shape: FrostRadius.shape(context, FrostRadius.lg)),
          child: FrostBleedBoundary(
            child: FrostKeyline(
              leadingRoom: _bannerInset,
              trailingRoom: _bannerInset,
              edgeDistanceStart: _bannerInset,
              edgeDistanceEnd: _bannerInset,
              insideContainer: true,
              contentStart: _bannerInset,
              child: _BannerLayout(
                contentIdentity: (title, message, tone),
                direction: Directionality.of(context),
                lineHeight:
                    FrostTypography.of(context).style(FrostTextRole.callout).height! *
                    MediaQuery.textScalerOf(context).scale(FrostTypography.of(context).style(FrostTextRole.callout).fontSize!),
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: ink),
                    duration: FrostMotion.duration(context, FrostMotion.hover),
                    curve: FrostMotion.hoverCurve,
                    builder: (_, color, _) => kind == null
                        ? FrostIcon(icons.info, size: _bannerIconSize, color: color)
                        : FrostStatusGlyph(kind: kind, size: _bannerIconSize, color: color, animate: false),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title case final text?) ...[
                        FrostText(text, role: FrostTextRole.callout, tone: FrostTextTone.primary),
                        const SizedBox(height: _bannerTextGap),
                      ],
                      FrostText(message, role: FrostTextRole.callout, tone: FrostTextTone.primary),
                    ],
                  ),
                  if (actionLabel case final label?)
                    FrostButton(
                      edgeAlignment: FrostButtonEdgeAlignment.end,
                      label: label,
                      onPressed: onAction,
                      variant: FrostButtonVariant.plain,
                      size: FrostControlSize.compact,
                    )
                  else
                    const SizedBox.shrink(),
                  if (onDismiss != null)
                    FrostButton.icon(icon: icons.close, label: FrostScope.labelsOf(context).dismiss, onPressed: onDismiss, size: FrostControlSize.compact)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Data extends ContainerBoxParentData<RenderBox> {}

class _BannerLayout extends StatefulWidget {
  const _BannerLayout({required this.direction, required this.lineHeight, required this.contentIdentity, required this.children});
  final TextDirection direction;
  final double lineHeight;
  final Object contentIdentity;
  final List<Widget> children;
  @override
  State<_BannerLayout> createState() => _BannerLayoutState();
}

class _BannerLayoutState extends State<_BannerLayout> {
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
      child: _BannerRender(
        direction: widget.direction,
        lineHeight: widget.lineHeight,
        identity: _identity,
        contentIdentity: widget.contentIdentity,
        children: widget.children,
      ),
    ),
  );
}

class _BannerRender extends MultiChildRenderObjectWidget {
  const _BannerRender({required this.direction, required this.lineHeight, required this.identity, required this.contentIdentity, required super.children});
  final TextDirection direction;
  final double lineHeight;
  final FrostLayoutIdentity identity;
  final Object contentIdentity;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBanner(this);
  @override
  void updateRenderObject(BuildContext context, _RenderBanner renderObject) => renderObject.update(this);
}

class _RenderBanner extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderBanner(this.spec);
  _BannerRender spec;
  void update(_BannerRender value) {
    spec = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  @override
  void performLayout() {
    final icon = firstChild!, text = childAfter(icon)!, action = childAfter(text)!, close = lastChild!;
    final width = math.max(0.0, constraints.maxWidth - _bannerInset * 2);
    icon.layout(const BoxConstraints.tightFor(width: _bannerIconSize, height: _bannerIconSize), parentUsesSize: true);
    close.layout(BoxConstraints(maxWidth: math.max(0, width - _bannerIconSize - FrostGap.related)), parentUsesSize: true);
    final endGap = close.size.width > 0 ? FrostGap.related : 0.0;
    final textStart = _bannerIconSize + FrostGap.related;
    final available = math.max(0.0, width - textStart - close.size.width - endGap);
    action.layout(BoxConstraints(maxWidth: available), parentUsesSize: true);
    final actionGap = action.size.width > 0 ? FrostGap.related : 0.0;
    final below = action.size.width > 0 && text.getMaxIntrinsicWidth(double.infinity) + action.size.width + actionGap > available;
    text.layout(BoxConstraints(maxWidth: math.max(0, available - (below ? 0 : action.size.width + actionGap))), parentUsesSize: true);
    final contentHeight = below ? text.size.height + actionGap + action.size.height : math.max(text.size.height, action.size.height);
    final height = math.max(math.max(_bannerIconSize, close.size.height), contentHeight);
    size = constraints.constrain(Size(width + _bannerInset * 2, height + _bannerInset * 2));
    spec.identity.update((spec.contentIdentity, below, text.size, close.size, action.size), viewport: size);
    void place(RenderBox child, double x, double y) =>
        (child.parentData! as _Data).offset = Offset(_bannerInset + (spec.direction == TextDirection.ltr ? x : width - x - child.size.width), _bannerInset + y);
    final singleLine = !below && text.size.height <= spec.lineHeight.ceilToDouble();
    place(icon, 0, singleLine ? (height - _bannerIconSize) / 2 : math.max(0, (spec.lineHeight - _bannerIconSize) / 2));
    place(text, textStart, singleLine ? (height - text.size.height) / 2 : 0);
    place(
      action,
      below ? textStart : textStart + available - action.size.width,
      below ? text.size.height + actionGap : math.max(0, ((singleLine ? height : text.size.height) - action.size.height) / 2),
    );
    place(close, width - close.size.width, singleLine ? (height - close.size.height) / 2 : 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
