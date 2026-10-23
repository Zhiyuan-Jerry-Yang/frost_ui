part of 'pinned_chrome.dart';

/// Which outer corners a [FrostPinnedChromeGlass] rounds. Bars that are pinned
/// directly above one another share one outline: the upper one rounds its
/// top corners, the lower one its bottom corners.
enum FrostPinnedChromeCorners { all, top, bottom }

/// The glass behind a pinned bar, shown while content passes beneath it,
/// with the bar's own content as [child].
///
/// With the floating desktop sidebar the bar floats the same way: rounded,
/// and inset so it sits the sidebar's margin away from both the sidebar and
/// the window edge. The bar's content keeps its full-width layout but is
/// clipped to the glass shape, so hover highlights never spill past the
/// rounded corners; outside the shape the window background covers whatever
/// scrolls beneath, so no sliver of content shows around the panel.
/// Other desktop sidebars use a band across the whole content sheet, closed
/// by a separator below and clipped by the sheet's upper corners.
/// Compact layouts keep an edge-to-edge bar under the status bar.
class FrostPinnedChromeGlass extends StatelessWidget {
  const FrostPinnedChromeGlass({required this.opacity, this.child, this.animate = true, this.corners = FrostPinnedChromeCorners.all, super.key});

  final double opacity;
  final Widget? child;

  /// Ease [opacity] changes; pass false when it already follows scrolling.
  final bool animate;
  final FrostPinnedChromeCorners corners;

  /// Gap between floating panels and between a panel and the window edge.
  static const floatingMargin = 8.0;

  // Shell already reserves the side gap and the window's trailing margin.
  // Only the vertical floating margins belong to the pinned bar itself.
  EdgeInsetsDirectional _panelInsets(BuildContext context) => EdgeInsetsDirectional.only(
    top: corners == FrostPinnedChromeCorners.bottom || FrostWindowCaptionScope.windowOf(context) == null ? 0 : floatingMargin,
    bottom: corners == FrostPinnedChromeCorners.top ? 0 : floatingMargin,
  );

  /// How far the glass sits inside the bar's edges: the floating margins on
  /// desktop, none on compact edge-to-edge bars. Content anchored to the
  /// bar's ends (a back or action button, a title) adds this to its usual
  /// inset so it keeps the same distance from the glass edge as it would
  /// from a screen edge. Rows already on the content column need nothing.
  static EdgeInsetsDirectional insetsOf(BuildContext context) => _floats(context)
      ? EdgeInsetsDirectional.only(top: FrostWindowCaptionScope.windowOf(context) == null ? 0 : floatingMargin, bottom: floatingMargin)
      : EdgeInsetsDirectional.zero;

  static bool _floats(BuildContext context) =>
      FrostAutoScaffold.usesHorizontalLayoutOf(context) && (FrostShellNavigationScope.maybeOf(context)?.floatingChrome ?? false);

  BorderRadius get _radius {
    const radius = Radius.circular(FrostRadius.lg);
    return switch (corners) {
      FrostPinnedChromeCorners.all => const BorderRadius.all(radius),
      FrostPinnedChromeCorners.top => const BorderRadius.vertical(top: radius),
      FrostPinnedChromeCorners.bottom => const BorderRadius.vertical(bottom: radius),
    };
  }

  @override
  Widget build(BuildContext context) {
    final floating = _floats(context);
    final Widget material;
    if (floating) {
      final insets = _panelInsets(context);
      final paintInsets = insets.resolve(Directionality.of(context)).copyWith(right: FrostPageOutline.channelOf(context));
      final shape = _InsetShape(insets: paintInsets, borderRadius: _radius);
      material = Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: paintInsets,
            child: FrostSurface(
              role: FrostSurfaceRole.chrome,
              borderRadius: _radius,
              join: switch (corners) {
                FrostPinnedChromeCorners.all => FrostSurfaceJoin.none,
                FrostPinnedChromeCorners.top => FrostSurfaceJoin.below,
                FrostPinnedChromeCorners.bottom => FrostSurfaceJoin.above,
              },
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
      final materialOpacity = FrostScope.solidSurfaces(context) ? 1.0 : 0.6 + 0.4 * opacity.clamp(0.0, 1.0);
      final layer = IgnorePointer(
        child: animate
            ? FrostAnimatedMaterialReveal(
                materialOnly: true,
                contentOnly: false,
                opacity: materialOpacity,
                duration: FrostMotion.duration(context, FrostMotion.hover),
                child: material,
              )
            : FrostMaterialReveal(materialOnly: true, opacity: materialOpacity, child: material),
      );
      return Stack(
        fit: StackFit.passthrough,
        children: [
          // Keep the area around the panel opaque; only the panel material
          // follows idle/scroll opacity, never the content or its margins.
          Positioned.fill(
            child: ClipPath(
              clipper: shape.outside(),
              child: const FrostSurface(role: FrostSurfaceRole.base, child: SizedBox.expand()),
            ),
          ),
          Positioned.fill(child: layer),
          if (child case final child?)
            ClipPath(
              clipper: shape,
              child: Padding(padding: insets, child: child),
            ),
        ],
      );
    }
    // The sampling surface needs the page's own outline. An ancestor clip alone
    // can leave a square backdrop-filter corner in native GPU composition.
    final inheritedRadius = FrostPageOutline.of(context);
    final band = FrostSurface(
      role: FrostSurfaceRole.chrome,
      borderRadius: BorderRadius.only(topLeft: inheritedRadius.topLeft, topRight: inheritedRadius.topRight),
      edge: FrostSurfaceEdge.none,
      elevated: false,
      child: SizedBox.expand(),
    );
    {
      // A full-width band: the column's band, closed below by a
      // hairline unless another bar continues it.
      final line = FrostThemeTokens.of(context).separator;
      material = Builder(
        builder: (context) {
          // The separator belongs to this material reveal, not to its content.
          // A normal decoration does not consume material-only reveal scopes.
          final progress = FrostMaterialRevealScope.maybeOf(context)?.progress ?? 1;
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: corners == FrostPinnedChromeCorners.top
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: line.withValues(alpha: line.a * progress),
                        width: 1 / MediaQuery.devicePixelRatioOf(context),
                      ),
                    ),
            ),
            child: band,
          );
        },
      );
    }
    final layer = IgnorePointer(
      child: animate
          ? FrostAnimatedMaterialReveal(
              materialOnly: true,
              contentOnly: false,
              opacity: opacity,
              duration: FrostMotion.duration(context, FrostMotion.hover),
              child: material,
            )
          : FrostMaterialReveal(materialOnly: true, opacity: opacity, child: material),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(right: FrostPageOutline.channelOf(context), child: layer),
        ?child,
      ],
    );
  }
}

/// The floating glass shape: the bar's rect inset by [insets], rounded by
/// [borderRadius]. [outside] clips to everything in the bar except it.
class _InsetShape extends CustomClipper<Path> {
  const _InsetShape({required this.insets, required this.borderRadius, this.inverse = false});

  final EdgeInsets insets;
  final BorderRadius borderRadius;
  final bool inverse;

  _InsetShape outside() => _InsetShape(insets: insets, borderRadius: borderRadius, inverse: true);

  @override
  Path getClip(Size size) {
    final panel = Path()..addRRect(borderRadius.toRRect(insets.deflateRect(Offset.zero & size)));
    if (!inverse) return panel;
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), panel);
  }

  @override
  bool shouldReclip(_InsetShape oldClipper) => insets != oldClipper.insets || borderRadius != oldClipper.borderRadius || inverse != oldClipper.inverse;
}
