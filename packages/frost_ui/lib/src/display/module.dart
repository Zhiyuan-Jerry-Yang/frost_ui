import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../motion/rolling_text.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';

// Information modules use a quieter, smaller header than action controls.
const _moduleInset = 16.0;
const _headerIconSize = 14.0;

/// A single information surface. A clickable module owns one button/focus
/// node; put independent child actions in a nonclickable module instead.
class FrostModule extends StatelessWidget {
  /// Explicit content determines bones only; semantics use the loading label.
  factory FrostModule.skeleton({required String title, required bool icon, required String? value, required String? note}) =>
      _SkeletonModule(icon, title: title, value: value, note: note);
  const FrostModule({required this.title, this.icon, this.value, this.graphic, this.content, this.note, this.onPressed, super.key});
  final String title;
  final FrostIconData? icon;
  final String? value, note;
  final Widget? graphic, content;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final parts = <Widget>[
      Row(
        children: [
          if (icon != null) ...[FrostIcon(icon!, size: _headerIconSize, color: tokens.textTertiary), const SizedBox(width: FrostGap.related)],
          Expanded(
            child: FrostText(title, role: FrostTextRole.caption, tone: FrostTextTone.tertiary, numeric: true),
          ),
          if (onPressed != null) ...[
            const SizedBox(width: FrostGap.related),
            FrostIcon(FrostIconSet.of(context).chevronRight, size: _headerIconSize, color: tokens.textTertiary),
          ],
        ],
      ),
      if (value != null)
        LayoutBuilder(
          builder: (context, constraints) {
            final style = FrostTypography.of(context).style(FrostTextRole.title2, numeric: true).copyWith(color: tokens.textPrimary);
            final painter = TextPainter(
              text: TextSpan(text: value, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final wraps = painter.width > constraints.maxWidth;
            painter.dispose();
            return FrostLayoutCrossfade(
              layoutIdentity: wraps,
              settleDuration: Duration.zero,
              child: wraps ? FrostText(value!, role: FrostTextRole.title2, numeric: true) : FrostRollingText(value!, style: style),
            );
          },
        ),
      ?graphic,
      ?content,
      if (note != null) FrostText(note!, role: FrostTextRole.footnote, tone: FrostTextTone.secondary, numeric: true),
    ];
    // Keep transition clips outside the inner padding: edge-button feedback
    // and focus rings borrow that padding without being cut by AnimatedSize.
    Widget body = FrostMotionSize(
      duration: FrostMotion.duration(context, FrostMotion.layoutFade),
      alignment: AlignmentDirectional.topStart,
      child: FrostLayoutCrossfade(
        layoutIdentity: (title, value, note),
        child: FrostBleedBoundary(
          child: Padding(
            padding: const EdgeInsets.all(_moduleInset),
            child: FrostKeyline(
              leadingRoom: _moduleInset,
              trailingRoom: _moduleInset,
              edgeDistanceStart: _moduleInset,
              edgeDistanceEnd: _moduleInset,
              insideContainer: true,
              contentStart: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, part) in parts.indexed) ...[if (index > 0) const SizedBox(height: FrostGap.related), part],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (onPressed != null) {
      body = FrostClickSurfaceVisuals.scaled(
        child: FrostClickSurface(
          onTap: onPressed,
          customBorder: FrostRadius.shape(context, FrostRadius.lg),
          child: IgnorePointer(child: ExcludeFocus(child: body)),
        ),
      );
    }
    final surface = FrostSurface(role: FrostSurfaceRole.module, borderRadius: FrostRadius.borderRadius(FrostRadius.lg), child: body);
    return onPressed == null ? surface : Semantics(label: title, value: value, button: true, onTap: onPressed, excludeSemantics: true, child: surface);
  }
}

class _SkeletonModule extends FrostModule {
  const _SkeletonModule(this._icon, {required super.title, required super.value, required super.note});
  final bool _icon;
  @override
  Widget build(BuildContext context) =>
      FrostModule(title: title, icon: _icon ? FrostIconSet.of(context).empty : null, value: value, note: note).frostSkeleton(true);
}
