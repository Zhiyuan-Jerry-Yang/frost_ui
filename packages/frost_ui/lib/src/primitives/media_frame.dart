import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../media/media_image.dart';
import '_media_shape.dart';
import 'icon.dart';

/// A media boundary. Image loading belongs here only in provider mode.
class FrostMediaFrame extends StatelessWidget {
  /// Matches the media boundary's parent constraints when no ratio is given.
  /// Pass an explicit ratio, or null only with a finite parent height.
  /// Missing runtime geometry throws FlutterError in debug; no shape is guessed.
  factory FrostMediaFrame.skeleton({required double? aspectRatio, double radius = FrostRadius.lg}) => _SkeletonMediaFrame(aspectRatio, radius);
  const FrostMediaFrame({
    this.child,
    this.image,
    this.radius = FrostRadius.lg,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorBuilder,
    this.semanticLabel,
    super.key,
  }) : assert((child == null) != (image == null), 'Provide exactly one of child and image.'),
       assert(child == null || (placeholderBuilder == null && errorBuilder == null), 'Child mode owns its loading and error states.');

  /// Child mode preserves descendant semantics, including playback and retry
  /// controls, unless [semanticLabel] explicitly replaces the whole subtree's
  /// description. Image-provider mode supplies only the optional image label.
  final Widget? child;
  final ImageProvider? image;
  final double radius;
  final double? aspectRatio;
  final BoxFit fit;
  final Widget Function(BuildContext context, double? progress)? placeholderBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final String? semanticLabel;

  Widget _placeholder(BuildContext context, double? progress) =>
      placeholderBuilder?.call(context, progress) ?? ColoredBox(color: FrostThemeTokens.of(context).fillSubtle, child: const SizedBox.expand());

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final circle = FrostMediaCircle.of(context);
    final provider = image;
    Widget content =
        child ??
        Image(
          image: provider!,
          fit: fit,
          excludeFromSemantics: true,
          frameBuilder: (context, imageChild, frame, synchronous) {
            if (frame == null) return _placeholder(context, null);
            // A cached frame is already present; remounting a lazy row must not
            // replay loading feedback. Only genuinely asynchronous arrivals fade.
            final displayed = FrostMediaImage(child: imageChild);
            if (synchronous || MediaQuery.disableAnimationsOf(context)) return displayed;
            return TweenAnimationBuilder<double>(
              key: ObjectKey(provider),
              tween: Tween(begin: 0, end: 1),
              duration: FrostMotion.imageFade,
              builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
              child: displayed,
            );
          },
          loadingBuilder: (context, imageChild, progress) {
            if (progress == null) return imageChild;
            final total = progress.expectedTotalBytes;
            return _placeholder(context, total == null || total == 0 ? null : (progress.cumulativeBytesLoaded / total).clamp(0.0, 1.0));
          },
          errorBuilder: (context, error, stack) =>
              errorBuilder?.call(context, error) ??
              ColoredBox(
                color: tokens.fillSubtle,
                child: Center(
                  child: FrostIcon(FrostIconSet.of(context).imageError, size: FrostControlSize.regular.iconSize, color: tokens.textTertiary),
                ),
              ),
        );
    // One enclosing frame owns the media stroke, including a nested loading
    // placeholder. A card can already own it outside its hover transform.
    content = FrostMediaCircle(enabled: false, child: FrostMediaInnerStroke(enabled: false, child: content));
    if (FrostMediaInnerStroke.of(context)) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: (circle ? const CircleBorder() : FrostRadius.shape(context, radius) as OutlinedBorder).copyWith(
            side: BorderSide(color: tokens.mediaInnerStroke, width: 1 / MediaQuery.devicePixelRatioOf(context)),
          ),
        ),
        child: content,
      );
    }
    final corners = FrostRadius.borderRadius(radius);
    content = circle
        ? ClipOval(clipBehavior: Clip.antiAlias, child: content)
        : FrostScope.configOf(context).continuousCorners
        ? ClipRSuperellipse(borderRadius: corners, clipBehavior: Clip.antiAlias, child: content)
        : ClipRRect(borderRadius: corners, clipBehavior: Clip.antiAlias, child: content);
    if (aspectRatio != null) content = AspectRatio(aspectRatio: aspectRatio!, child: content);
    final label = semanticLabel;
    if (provider == null) {
      return label == null
          ? content
          : Semantics(
              image: true,
              label: label,
              child: ExcludeSemantics(child: content),
            );
    }
    return label == null
        ? ExcludeSemantics(child: content)
        : Semantics(
            image: true,
            label: label,
            child: ExcludeSemantics(child: content),
          );
  }
}

class _SkeletonMediaFrame extends FrostMediaFrame {
  const _SkeletonMediaFrame(double? aspectRatio, double radius) : super(aspectRatio: aspectRatio, radius: radius, child: const SizedBox.expand());
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(() {
        if (aspectRatio == null && !constraints.hasBoundedHeight) {
          throw FlutterError('FrostMediaFrame.skeleton requires aspectRatio when the parent height is unbounded.');
        }
        return true;
      }());
      return FrostMediaFrame(
        aspectRatio: aspectRatio,
        radius: radius,
        semanticLabel: FrostScope.labelsOf(context).loading,
        // Clip the shading layer at the real media boundary. A leaf annotation
        // outside this clip can record a picture that escapes its canvas clip.
        child: FrostSkeletonLeaf(
          child: ColoredBox(color: FrostThemeTokens.of(context).fill, child: const SizedBox.expand()),
        ).frostSkeleton(true),
      );
    },
  );
}
