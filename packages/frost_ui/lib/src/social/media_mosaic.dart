import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../media/media_hero.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_media_image_registry.dart';
import '../primitives/click_surface.dart';
import '../primitives/media_frame.dart';
import '../primitives/text.dart';

// Only the outside of the entire mosaic is rounded; interior corners are zero.
const _cellGap = 2.0;
const _minimumRatio = 4 / 5;
const _maximumRatio = 1.91;
const _multiRatio = 16 / 9;
const _maximumCells = 4;

bool _validSize(Size size) => size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0;

/// One to four visible media cells. The application owns the image providers
/// and navigation. App code can use FrostMediaHeroSource to produce [heroTag].
/// There is no automatic loading skeleton: declare its count and sizes using
/// the explicit constructor, or skeletonize a known application layout.
class FrostMediaMosaic extends StatelessWidget {
  FrostMediaMosaic({required this.images, this.sizes, this.onPressed, this.heroTag, this.semanticLabel, super.key})
    : _skeletonCount = null,
      assert(images.isNotEmpty),
      assert(sizes == null || sizes.length == images.length),
      assert(sizes == null || sizes.every((size) => size == null || _validSize(size)));
  FrostMediaMosaic.skeleton({required int count, required List<Size?> sizes, super.key})
    : _skeletonCount = count,
      images = const [],
      sizes = sizes,
      onPressed = null,
      heroTag = null,
      semanticLabel = null,
      assert(count > 0),
      assert(sizes.length == math.min(count, _maximumCells)),
      assert(() {
        if (count == 1 && (sizes.single == null || !_validSize(sizes.single!))) {
          throw FlutterError('FrostMediaMosaic.skeleton requires a finite positive Size for a single image; supply its aspect ratio.');
        }
        return true;
      }());
  final List<ImageProvider> images;
  final List<Size?>? sizes;
  final ValueChanged<int>? onPressed;
  final FrostMediaHeroTag Function(int index)? heroTag;
  final String Function(int index)? semanticLabel;
  final int? _skeletonCount;
  int get _count => _skeletonCount ?? images.length;
  double get _ratio {
    if (_count > 1) return _multiRatio;
    final size = sizes?.first;
    final ratio = _skeletonCount != null
        ? size!.width / size.height
        : size == null
        ? 1.0
        : size.width / size.height;
    return ratio.clamp(_minimumRatio, _maximumRatio);
  }

  BorderRadius _corners(BuildContext context, int index) {
    final radius = const Radius.circular(FrostRadius.md), zero = Radius.zero;
    final count = math.min(_count, _maximumCells);
    final topStart = index == 0, bottomStart = count < 4 ? index == 0 : index == 2;
    final topEnd = count == 1 ? index == 0 : index == 1;
    final bottomEnd = count == 1 ? index == 0 : index == count - 1;
    return BorderRadiusDirectional.only(
      topStart: topStart ? radius : zero,
      topEnd: topEnd ? radius : zero,
      bottomStart: bottomStart ? radius : zero,
      bottomEnd: bottomEnd ? radius : zero,
    ).resolve(Directionality.of(context));
  }

  Widget _cell(BuildContext context, int index) {
    final tokens = FrostThemeTokens.of(context);
    if (_skeletonCount != null) {
      return FrostMediaFrame(
        radius: 0,
        child: FrostSkeletonLeaf(
          child: ColoredBox(color: tokens.fill, child: const SizedBox.expand()),
        ),
      );
    }
    final more = _count > _maximumCells && index == _maximumCells - 1 ? FrostScope.labelsOf(context).moreMedia(_count - _maximumCells) : null;
    final label = semanticLabel?.call(index) ?? FrostScope.labelsOf(context).pageOf(index + 1, _count);
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        FrostMediaFrame(image: images[index], radius: 0, fit: BoxFit.cover, placeholderBuilder: (_, progress) => const SizedBox.shrink()),
        if (more != null)
          ColoredBox(
            color: tokens.onMediaScrim,
            child: Center(
              child: DefaultTextStyle(
                style: TextStyle(color: tokens.onMediaInk),
                child: FrostText(more, role: FrostTextRole.title2),
              ),
            ),
          ),
      ],
    );
    if (heroTag case final tag?) content = FrostMediaHero(tag: tag(index), radius: _corners(context, index), child: content);
    final action = onPressed == null ? null : () => onPressed!(index);
    return FrostMediaImageHost(
      builder: (context, images) => Semantics(
        image: true,
        button: action != null,
        label: label,
        value: more,
        onTap: action,
        excludeSemantics: true,
        child: FrostClickSurfaceVisuals.scaled(
          mediaImages: images,
          child: FrostClickSurface(
            onTap: action,
            borderRadius: _corners(context, index),
            feedback: FrostClickFeedback.media,
            child: FrostMediaImageRegistryScope(registry: images, child: content),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = math.min(_count, _maximumCells);
    final cells = [for (var index = 0; index < count; index++) _cell(context, index)];
    final content = switch (count) {
      1 => cells.single,
      2 => Row(
        children: [
          Expanded(child: cells[0]),
          const SizedBox(width: _cellGap),
          Expanded(child: cells[1]),
        ],
      ),
      3 => Row(
        children: [
          Expanded(child: cells[0]),
          const SizedBox(width: _cellGap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: cells[1]),
                const SizedBox(height: _cellGap),
                Expanded(child: cells[2]),
              ],
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: cells[0]),
                const SizedBox(width: _cellGap),
                Expanded(child: cells[1]),
              ],
            ),
          ),
          const SizedBox(height: _cellGap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: cells[2]),
                const SizedBox(width: _cellGap),
                Expanded(child: cells[3]),
              ],
            ),
          ),
        ],
      ),
    };
    final mosaic = AspectRatio(
      aspectRatio: _ratio,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: FrostRadius.shape(context, FrostRadius.md)),
        child: content,
      ),
    );
    return _skeletonCount == null ? mosaic : mosaic.frostSkeleton(true);
  }
}
