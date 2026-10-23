import 'dart:ui';

import 'package:flutter/material.dart';

import '../foundation/_ambient_material.dart';
import '../foundation/_glass_material.dart';
import '../foundation/_media_contrast.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '../surface/_window_background.dart';
import '../surface/ambient_backdrop.dart';
import '_on_media_chrome_scope.dart';
import '_page_outline.dart';
import '_shape_fill.dart';
import '_surface_geometry.dart';
import 'keyline.dart';

enum FrostSurfaceRole {
  chrome,
  panel,
  glassPanel,
  overlay,
  reading,
  base,
  sheet,
  module,

  /// Dark media controls in either page theme. Uses onMediaScrim/onMediaInk,
  /// chrome blur/reveal, and an opaque scrim with reduced transparency.
  /// Place onMedia icon buttons inside; no page-theme colour override is made.
  onMediaChrome,
}

/// The local surface after transparency preferences and composition.
class FrostSurfaceScope extends InheritedWidget {
  const FrostSurfaceScope({required this.isGlass, required this.background, required super.child, super.key});
  final bool isGlass;
  final Color background;
  static FrostSurfaceScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostSurfaceScope>();
  @override
  bool updateShouldNotify(FrostSurfaceScope oldWidget) => isGlass != oldWidget.isGlass || background != oldWidget.background;
}

enum FrostSurfaceEdge { material, none }

/// The side where a surface continues straight into a neighbouring one, the
/// two reading as one panel (a pinned header above its tab bar). That side
/// has square corners, no edge line and casts no shadow onto the other.
enum FrostSurfaceJoin { none, above, below }

/// A bounded material layer. Blur is confined to this surface, never to an
/// entire scrolling list or an opaque page background.
class FrostSurface extends StatefulWidget {
  const FrostSurface({
    required this.role,
    required this.child,
    this.borderRadius,
    this.edge = FrostSurfaceEdge.material,
    this.elevated = true,
    this.join = FrostSurfaceJoin.none,
    super.key,
  });

  final FrostSurfaceRole role;
  final Widget child;

  /// Zero radius on onMediaChrome denotes a continuous media band and omits
  /// the rim, highlight and shadow. Rounded media cards retain their edges.
  final BorderRadiusGeometry? borderRadius;
  final FrostSurfaceEdge edge;

  /// Chrome stacked directly above another chrome layer omits its shadow so
  /// the two read as one bar.
  final bool elevated;
  final FrostSurfaceJoin join;

  @override
  State<FrostSurface> createState() => _FrostSurfaceState();
}

class _FrostSurfaceState extends State<FrostSurface> {
  // Theme, transparency and window-material changes can insert or remove
  // decoration wrappers. Retain the actual content rather than remounting
  // forms, focus nodes, scroll views or media beneath those paint changes.
  final _content = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final role = widget.role, join = widget.join;
    final mediaChrome = role == FrostSurfaceRole.onMediaChrome;
    // A square media surface is a continuous band, not a floating card.
    // Its rim and shadow would draw a spurious line across the media.
    final mediaBand = mediaChrome && frostSurfaceRadius(widget).resolve(Directionality.of(context)) == BorderRadius.zero;
    final edge = mediaBand ? FrostSurfaceEdge.none : widget.edge;
    final elevated = !mediaBand && widget.elevated;
    final outline = FrostPageOutline.maybeOf(context);
    final channel = role == FrostSurfaceRole.panel && outline != null && !outline.channelClaimed ? outline.scrollbarChannel : 0.0;
    final retained = KeyedSubtree(key: _content, child: widget.child);
    final child = channel > 0 ? outline!.consumeSurface(retained) : retained;
    final tokens = FrostThemeTokens.of(context);
    final reveal = FrostMaterialRevealScope.maybeOf(context);
    final ownsReveal = reveal != null && !reveal.claimed;
    final materialProgress = ownsReveal ? reveal.progress : 1.0;
    Widget revealContent(Widget content) => ownsReveal ? reveal.consume(context, content) : content;
    final highContrast = MediaQuery.highContrastOf(context);
    final solid = FrostScope.solidSurfaces(context);
    final translucentWindow = frostHasTranslucentWindowBase(context);
    final actualWindow = FrostWindowBackgroundScope.maybeOf(context)?.background;
    final behind = FrostSurfaceScope.maybeOf(context)?.background ?? actualWindow ?? tokens.canvas;
    final radius = frostSurfaceRadius(widget);
    final continuous = FrostScope.configOf(context).continuousCorners && join == FrostSurfaceJoin.none;
    if (role == FrostSurfaceRole.base && translucentWindow) {
      return FrostSurfaceScope(
        isGlass: false,
        background: behind,
        child: FrostSurfaceGeometry(radius: radius, continuous: continuous, child: revealContent(child)),
      );
    }
    if (role == FrostSurfaceRole.base) {
      final background = tokens.isDark ? tokens.canvas : Color.alphaBlend(tokens.fillSubtle, tokens.canvas);
      return FrostSurfaceScope(
        isGlass: false,
        background: background,
        child: FrostSurfaceGeometry(
          radius: radius,
          continuous: continuous,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: context.findAncestorWidgetOfExactType<FrostAmbientBackdropHost>() == null
                    ? ColoredBox(color: tokens.canvas.withValues(alpha: materialProgress))
                    : FrostContentFade(opacity: materialProgress, child: const FrostAmbientBackdrop()),
              ),
              if (!tokens.isDark)
                Positioned.fill(
                  child: ColoredBox(color: tokens.fillSubtle.withValues(alpha: tokens.fillSubtle.a * materialProgress)),
                ),
              revealContent(child),
            ],
          ),
        ),
      );
    }
    OutlinedBorder shapeFor([BorderSide side = BorderSide.none]) =>
        continuous ? RoundedSuperellipseBorder(borderRadius: radius, side: side) : RoundedRectangleBorder(borderRadius: radius, side: side);
    // WinUI LayerFillColorDefault / CardBackgroundFillColorDefault. These
    // layers tint a shared ambient/Mica base without another blur.
    final referenceFill = switch (role) {
      FrostSurfaceRole.panel when translucentWindow => frostWindowLayerFill(tokens.isDark),
      FrostSurfaceRole.module when translucentWindow => frostWindowCardFill(tokens.isDark),
      _ => null,
    };
    final windowFill = referenceFill == null || actualWindow == null
        ? referenceFill
        : frostReadableWindowFill(tokens, referenceFill, behind, tokens.textSecondary);
    final color =
        windowFill ??
        switch (role) {
          FrostSurfaceRole.glassPanel || FrostSurfaceRole.overlay => tokens.surfaceRaised,
          FrostSurfaceRole.module => Color.alphaBlend(tokens.fillSubtle, behind),
          FrostSurfaceRole.onMediaChrome => frostOnMediaChromeBase(tokens),
          _ => tokens.surface,
        };
    final glass = mediaChrome || role == FrostSurfaceRole.chrome || role == FrostSurfaceRole.glassPanel || role == FrostSurfaceRole.overlay;
    final baseAlpha =
        windowFill?.a ??
        (mediaChrome
            ? frostOnMediaChromeOpacity(tokens)
            : glass
            ? frostGlassFillOpacity(color, tokens.textPrimary, tokens.isDark)
            : 1.0);
    final alpha = role == FrostSurfaceRole.chrome ? frostNavigationGlassFillOpacity(color, baseAlpha) : baseAlpha;
    final targetSigma = solid
        ? 0.0
        : switch (role) {
            FrostSurfaceRole.chrome || FrostSurfaceRole.onMediaChrome => 18.0,
            FrostSurfaceRole.glassPanel => 14.0,
            FrostSurfaceRole.overlay => 24.0,
            _ => 0.0,
          };
    // Nested sampling still follows R2's deferred 0 to target blur, with no
    // sampler below a content opacity layer. The outer reveal keeps its
    // static sigma and fades the filtered contribution, not the blur radius.
    final sigma = targetSigma * FrostContentRevealScope.blurFactorOf(context);
    // A light glass panel over a pale canvas is almost the same colour, so it
    // keeps one neutral separating line. That line is functional, not the
    // decorative edge that [FrostSurfaceEdge.none] removes from interactive groups.
    final separatesFromCanvas = role == FrostSurfaceRole.glassPanel && !tokens.isDark && !solid;
    // With reduced transparency the opaque fill already sets a panel apart,
    // so its edge is a soft 1px line, not a full-strength one; only high
    // contrast keeps a strong 1.5px outline.
    final targetBorderColor = mediaBand || role == FrostSurfaceRole.module
        ? null
        : highContrast
        ? (mediaChrome ? tokens.onMediaInk : tokens.textSecondary)
        : separatesFromCanvas
        ? tokens.edgeHairline
        : edge == FrostSurfaceEdge.none
        ? null
        : switch (role) {
            FrostSurfaceRole.onMediaChrome => solid ? tokens.onMediaInk.withValues(alpha: tokens.edgeHairline.a) : null,
            FrostSurfaceRole.chrome || FrostSurfaceRole.glassPanel => solid ? tokens.panelEdge : null,
            FrostSurfaceRole.overlay => solid ? tokens.line : tokens.edgeHairline,
            FrostSurfaceRole.sheet => tokens.edgeHairline,
            FrostSurfaceRole.panel || FrostSurfaceRole.reading || FrostSurfaceRole.base || FrostSurfaceRole.module => null,
          };
    final borderColor = targetBorderColor?.withValues(alpha: targetBorderColor.a * materialProgress);
    // The upper piece of a joined panel would shade the lower one.
    final targetShadow = !elevated || join == FrostSurfaceJoin.below
        ? const <BoxShadow>[]
        : switch (role) {
            FrostSurfaceRole.chrome ||
            FrostSurfaceRole.onMediaChrome ||
            FrostSurfaceRole.glassPanel ||
            FrostSurfaceRole.overlay ||
            FrostSurfaceRole.sheet => [...tokens.shadowAmbient, ...tokens.shadowContact],
            _ => const <BoxShadow>[],
          };

    final shadow = [for (final value in targetShadow) value.copyWith(color: value.color.withValues(alpha: value.color.a * materialProgress))];
    final highlight =
        (mediaChrome || role == FrostSurfaceRole.chrome || role == FrostSurfaceRole.glassPanel) &&
        edge == FrostSurfaceEdge.material &&
        !solid &&
        !separatesFromCanvas;
    final borderWidth = role == FrostSurfaceRole.sheet
        ? 1 / MediaQuery.devicePixelRatioOf(context)
        : highContrast
        ? 1.5
        : 1 / MediaQuery.devicePixelRatioOf(context);
    final highlightWidth = 1 / MediaQuery.devicePixelRatioOf(context);
    final highlightColor = tokens.edgeHighlight.withValues(alpha: tokens.edgeHighlight.a * materialProgress);
    Widget scopedChild = child;
    if (const {FrostSurfaceRole.sheet, FrostSurfaceRole.module, FrostSurfaceRole.panel, FrostSurfaceRole.glassPanel}.contains(role)) {
      // Surface owns no padding. Composed containers provide their own nested
      // content keyline when they add padding.
      scopedChild = FrostKeyline(
        leadingRoom: 0,
        trailingRoom: 0,
        edgeDistanceStart: 0,
        edgeDistanceEnd: 0,
        insideContainer: true,
        contentStart: 0,
        child: scopedChild,
      );
    }
    scopedChild = revealContent(scopedChild);
    if (role == FrostSurfaceRole.sheet && tokens.isDark) {
      scopedChild = Stack(
        fit: StackFit.passthrough,
        children: [
          scopedChild,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1 / MediaQuery.devicePixelRatioOf(context),
            child: IgnorePointer(child: ColoredBox(color: highlightColor)),
          ),
        ],
      );
    }
    final inner = Material(
      type: MaterialType.transparency,
      child: mediaChrome
          ? FrostOnMediaChromeScope(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: tokens.onMediaInk),
                child: IconTheme.merge(
                  data: IconThemeData(color: tokens.onMediaInk),
                  child: scopedChild,
                ),
              ),
            )
          : frostWithoutOnMediaChrome(scopedChild),
    );
    final targetFill = color.withValues(alpha: solid ? 1 : alpha);
    final fill = targetFill.withValues(alpha: targetFill.a * materialProgress);
    // A joined surface leaves its edge lines open on the joined side, which
    // a box border cannot do; other surfaces use plain borders.
    Widget decorate(Color fill, Widget body) {
      if (join != FrostSurfaceJoin.none) {
        return DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: radius),
          child: CustomPaint(
            foregroundPainter: _JoinedEdgePainter(
              radius: radius.resolve(Directionality.of(context)),
              join: join,
              strokes: [if (borderColor != null) (color: borderColor, width: borderWidth), if (highlight) (color: highlightColor, width: highlightWidth)],
            ),
            child: body,
          ),
        );
      }
      final shape = shapeFor(borderColor == null ? BorderSide.none : BorderSide(color: borderColor, width: borderWidth));
      final rectangular = frostNeedsClippedFill(shape, Directionality.maybeOf(context) ?? TextDirection.ltr);
      Widget outlined = highlight
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: shapeFor(BorderSide(color: highlightColor, width: highlightWidth)),
              ),
              child: body,
            )
          : body;
      if (rectangular && borderColor != null) {
        outlined = DecoratedBox(
          decoration: ShapeDecoration(shape: shape),
          child: outlined,
        );
      }
      // The existing surface clip owns the outline; avoid Impeller's asymmetric fill.
      return DecoratedBox(
        decoration: rectangular ? BoxDecoration(color: fill) : ShapeDecoration(color: fill, shape: shape),
        child: outlined,
      );
    }

    Widget buildContent(Color fill) => channel == 0
        ? decorate(fill, inner)
        : Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(right: channel, child: decorate(fill, const SizedBox.expand())),
              inner,
            ],
          );
    final content = windowFill == null
        ? buildContent(fill)
        : TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: fill),
            duration: FrostMotion.duration(context, FrostMotion.hover),
            curve: FrostMotion.hoverCurve,
            builder: (context, color, _) => buildContent(color!),
          );
    Widget layered = content;
    if (glass) {
      layered = BackdropFilter(
        filter: sigma == 0 ? ImageFilter.blur() : frostGlassFilter(sigma: sigma, opacity: frostGlassFilterOpacity(materialProgress, alpha)),
        blendMode: BlendMode.srcOver,
        enabled: sigma > 0 && materialProgress > 0,
        child: content,
      );
    }
    Widget shaded = DecoratedBox(
      decoration: ShapeDecoration(shape: shapeFor(), shadows: shadow),
      child: channel > 0
          ? ClipPath(
              clipper: FrostPageViewportClip(radius: radius.resolve(Directionality.of(context)), continuous: continuous, channel: channel),
              child: layered,
            )
          : continuous
          ? ClipRSuperellipse(borderRadius: radius, clipBehavior: Clip.antiAlias, child: layered)
          : ClipRRect(borderRadius: radius, clipBehavior: Clip.antiAlias, child: layered),
    );
    if (join == FrostSurfaceJoin.above && shadow.isNotEmpty) {
      // Keep the lower piece's shadow off the piece it continues from.
      shaded = ClipRect(
        clipper: const _BelowTopEdge(),
        child: FrostSurfaceGeometry(radius: radius, continuous: continuous, child: shaded),
      );
    }
    return FrostSurfaceScope(
      // Semantic ink follows the target material, including deferred sampling.
      isGlass: targetSigma > 0,
      background: Color.alphaBlend(targetFill, behind),
      child: FrostGlassRegistration(
        enabled: targetSigma > 0,
        child: FrostSurfaceGeometry(radius: radius, continuous: continuous, child: shaded),
      ),
    );
  }
}

/// A joined surface's edge lines, drawn just inside its outline and left
/// open on the joined side, so two pieces meet without a line between them.
class _JoinedEdgePainter extends CustomPainter {
  const _JoinedEdgePainter({required this.radius, required this.strokes, required this.join});

  final BorderRadius radius;
  final List<({Color color, double width})> strokes;
  final FrostSurfaceJoin join;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final inset = stroke.width / 2;
      final outline = radius.toRRect(Offset.zero & size).deflate(inset);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..color = stroke.color;
      canvas.drawPath(_openPath(outline), paint);
    }
  }

  Path _openPath(RRect outline) {
    // Joined sides have square corners, so the open side is a straight edge
    // between the two side lines.
    final (from, to) = join == FrostSurfaceJoin.below ? (outline.bottom, outline.top) : (outline.top, outline.bottom);
    final corner = join == FrostSurfaceJoin.below ? outline.tlRadiusY : outline.blRadiusY;
    final towards = to > from ? 1.0 : -1.0;
    return Path()
      ..moveTo(outline.left, from)
      ..lineTo(outline.left, to - towards * corner)
      ..arcToPoint(Offset(outline.left + corner, to), radius: Radius.circular(corner), clockwise: towards < 0)
      ..lineTo(outline.right - corner, to)
      ..arcToPoint(Offset(outline.right, to - towards * corner), radius: Radius.circular(corner), clockwise: towards < 0)
      ..lineTo(outline.right, from);
  }

  @override
  bool shouldRepaint(_JoinedEdgePainter oldDelegate) => radius != oldDelegate.radius || strokes != oldDelegate.strokes || join != oldDelegate.join;
}

class _BelowTopEdge extends CustomClipper<Rect> {
  const _BelowTopEdge();

  // Generous room for the shadow's blur on the other three sides.
  static const _shadowRoom = 64.0;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-_shadowRoom, 0, size.width + _shadowRoom, size.height + _shadowRoom);

  @override
  bool shouldReclip(_BelowTopEdge oldClipper) => false;
}
