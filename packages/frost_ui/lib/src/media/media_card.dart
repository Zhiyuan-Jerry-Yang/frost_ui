import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_selection_presentation.dart';
import '../motion/_user_selection_draw.dart';
import '../motion/spring.dart';
import '../overlays/_additional_menu_entries.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_media_image_registry.dart';
import '../primitives/_media_selection.dart';
import '../primitives/_media_shape.dart';
import '../primitives/click_surface.dart';
import '../primitives/media_frame.dart';
import '../primitives/presence.dart';
import '../primitives/status_glyph.dart';
import '../primitives/text.dart';

// Media overlays and the footer share an eight-pixel separation.
const _mediaInset = 8.0;
const _checkDiameter = 20.0;
const _checkOutlineWidth = 1.5;
const _checkIconSize = 16.0;
const _selectionHiddenScale = .92;

/// A media boundary with independent corner controls and an unscaled footer.
/// [media] owns image loading. Without [aspectRatio], its natural height wins.
class FrostMediaCard extends StatelessWidget {
  /// Pass an explicit ratio, or null only with a finite parent height.
  /// Missing runtime geometry throws FlutterError in debug; no shape is guessed.
  factory FrostMediaCard.skeleton({required double? aspectRatio, required String? footer}) => _SkeletonMediaCard(aspectRatio: aspectRatio, footerText: footer);
  const FrostMediaCard({
    required this.media,
    this.aspectRatio,
    this.topStart,
    this.topEnd,
    this.bottomStart,
    this.bottomEnd,
    this.footer,
    this.onPressed,
    this.selected,
    this.contextMenu = const [],
    this.semanticLabel,
    super.key,
  }) : assert(aspectRatio == null || (aspectRatio > 0 && aspectRatio < double.infinity));

  final Widget media;
  final double? aspectRatio;
  final Widget? topStart;
  final Widget? topEnd;
  final Widget? bottomStart;
  final Widget? bottomEnd;
  final Widget? footer;
  final VoidCallback? onPressed;
  final bool? selected;
  final List<FrostMenuEntry> contextMenu;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final selection = FrostSelectionPresentation.of(context);
    final selected = selection == null ? this.selected : (selection.active ? selection.selected : null);
    final VoidCallback? activate = selection == null ? onPressed : () => selection.activate(onPressed);
    return FrostMediaImageHost(
      builder: (context, images) => FrostUserSelectionDraw(
        selected: selected,
        trigger: selection?.drawTrigger,
        // Shared selection owns whether this was a single input or a bulk change.
        trackInput: selection == null,
        onActivate: activate,
        builder: (context, trigger, activate) {
          Widget picture = FrostClickSurfaceVisuals.unclipped(
            scalesOnPress: true,
            mediaImages: images,
            child: FrostClickSurface(
              onTap: activate,
              onLongPress: selection?.longPress,
              feedback: FrostClickFeedback.media,
              customBorder: FrostRadius.shape(context, FrostRadius.lg),
              child: Semantics(
                container: true,
                button: activate != null,
                selected: selected,
                label: semanticLabel,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FrostMediaFrame(
                        aspectRatio: aspectRatio,
                        child: Builder(
                          builder: (context) => FrostInteractionScale(
                            mediaImages: images,
                            value: FrostClickSurface.hoveredOf(context) ? FrostMetrics.mediaHoverZoom : 1,
                            child: FrostMediaInnerStroke(
                              enabled: false,
                              child: FrostMediaImageRegistryScope(registry: images, child: media),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (topStart case final child?) PositionedDirectional(top: _mediaInset, start: _mediaInset, child: child),
                    PositionedDirectional(
                      top: _mediaInset,
                      end: _mediaInset,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FrostPresence(
                            visible: selected != null,
                            child: Padding(
                              padding: EdgeInsetsDirectional.only(end: topEnd == null ? 0 : _mediaInset),
                              child: _SelectionCircle(selected: selected == true, drawTrigger: trigger),
                            ),
                          ),
                          ?topEnd,
                        ],
                      ),
                    ),
                    if (bottomStart case final child?) PositionedDirectional(bottom: _mediaInset, start: _mediaInset, child: child),
                    if (bottomEnd case final child?) PositionedDirectional(bottom: _mediaInset, end: _mediaInset, child: child),
                    FrostMediaSelectionRing(selected: selected == true, radius: FrostRadius.lg, width: frostMediaCardRingWidth),
                  ],
                ),
              ),
            ),
          );
          final entries = [...contextMenu, ...FrostAdditionalMenuEntries.of(context)];
          if (entries.isNotEmpty) picture = FrostContextMenuRegion(entries: entries, child: picture);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              picture,
              if (footer case final footer?) ...[const SizedBox(height: _mediaInset), footer],
            ],
          );
        },
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected, required this.drawTrigger});
  final bool selected;
  final Object? drawTrigger;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _checkDiameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: FrostMotion.duration(context, FrostMotion.hover),
              builder: (context, opacity, child) => Stack(
                fit: StackFit.expand,
                children: [
                  // Retiring the outline prevents its white antialiased edge
                  // from bleeding through the selected fill at the same bounds.
                  CustomPaint(
                    painter: FrostMediaSelectionCirclePainter(fill: tokens.onMediaScrim, outline: tokens.onMediaInk, opacity: 1 - opacity),
                  ),
                  Opacity(
                    opacity: opacity,
                    child: FrostSpringBuilder(
                      value: selected ? 1 : _selectionHiddenScale,
                      spring: FrostMotion.snappy,
                      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                      child: child,
                    ),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: FrostMediaSelectionCirclePainter(fill: tokens.actionFill),
                child: Center(
                  child: _MediaCheck(selected: selected, trigger: drawTrigger, color: tokens.onAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal vector paint; never a clipped bitmap or a package export.
class FrostMediaSelectionCirclePainter extends CustomPainter {
  const FrostMediaSelectionCirclePainter({required this.fill, this.outline, this.opacity = 1});
  final Color fill;
  final Color? outline;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final radius = size.shortestSide / 2, center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = fill.withValues(alpha: fill.a * opacity)
        ..isAntiAlias = true,
    );
    if (outline case final color?) {
      canvas.drawCircle(
        center,
        radius - _checkOutlineWidth / 2,
        Paint()
          ..color = color.withValues(alpha: color.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _checkOutlineWidth
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(FrostMediaSelectionCirclePainter oldDelegate) =>
      fill != oldDelegate.fill || outline != oldDelegate.outline || opacity != oldDelegate.opacity;
}

class _MediaCheck extends StatefulWidget {
  const _MediaCheck({required this.selected, required this.trigger, required this.color});
  final bool selected;
  final Object? trigger;
  final Color color;
  @override
  State<_MediaCheck> createState() => _MediaCheckState();
}

class _MediaCheckState extends State<_MediaCheck> {
  bool _draw = false;
  @override
  void initState() {
    super.initState();
    _draw = widget.selected && frostFreshUserSelection(widget.trigger);
  }

  @override
  void didUpdateWidget(_MediaCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) _draw = widget.selected && widget.trigger != null && widget.trigger != oldWidget.trigger;
  }

  @override
  Widget build(BuildContext context) => FrostStatusGlyphAnimation(
    kind: FrostStatusGlyphKind.success,
    size: _checkIconSize,
    color: widget.color,
    visible: true,
    replay: widget.selected ? widget.trigger : null,
    animateChanges: _draw,
    drawOnMount: _draw,
    duration: frostSelectionDrawDuration,
  );
}

class _SkeletonMediaCard extends FrostMediaCard {
  _SkeletonMediaCard({required super.aspectRatio, required String? footerText})
    : _footerText = footerText,
      super(
        media: const SizedBox.expand(),
        footer: footerText == null ? null : FrostText(footerText, role: FrostTextRole.subheadline, numeric: true, maxLines: 1),
      );
  final String? _footerText;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(() {
        if (aspectRatio == null && !constraints.hasBoundedHeight) {
          throw FlutterError('FrostMediaCard.skeleton requires aspectRatio when the parent height is unbounded.');
        }
        return true;
      }());
      final title = TextPainter(
        text: TextSpan(text: _footerText, style: FrostTypography.of(context).style(FrostTextRole.subheadline, numeric: true)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout(maxWidth: constraints.maxWidth);
      final footerHeight = footer == null ? 0.0 : _mediaInset + title.height;
      title.dispose();
      return Semantics(
        label: FrostScope.labelsOf(context).loading,
        excludeSemantics: true,
        child: FrostMediaCard(
          aspectRatio: aspectRatio,
          media: SizedBox(
            height: aspectRatio == null ? (constraints.maxHeight - footerHeight).clamp(0.0, double.infinity) : null,
            // The shading picture must be recorded inside the media clip,
            // exactly as for the standalone frame. Wrapping the whole card
            // lets skeletonizer's picture layer escape the rounded boundary.
            child: FrostMediaFrame.skeleton(aspectRatio: null),
          ),
          footer: footer?.frostSkeleton(true),
        ),
      );
    },
  );
}
