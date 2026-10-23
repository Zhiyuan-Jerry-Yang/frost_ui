import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '_media_image_registry.dart';

/// Internal keyboard-list highlight; ordinary click surfaces are unaffected.
class FrostClickHighlight extends InheritedWidget {
  const FrostClickHighlight({required this.highlighted, required super.child, super.key});
  final bool highlighted;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostClickHighlight>()?.highlighted ?? false;
  @override
  bool updateShouldNotify(FrostClickHighlight oldWidget) => highlighted != oldWidget.highlighted;
}

/// Internal delegation for controls that paint their visual surface themselves.
/// Input, focus and nested-hover arbitration still belong to the click surface.
class FrostClickSurfaceVisuals extends InheritedWidget {
  const FrostClickSurfaceVisuals({required super.child, super.key})
    : delegated = true,
      clipsContent = true,
      scalesOnPress = false,
      fillsBounds = false,
      mediaImages = null;

  const FrostClickSurfaceVisuals.standard({required super.child, super.key})
    : delegated = false,
      clipsContent = true,
      scalesOnPress = false,
      fillsBounds = false,
      mediaImages = null;

  /// Media owners already clip the picture; outside rings must remain visible.
  const FrostClickSurfaceVisuals.unclipped({required super.child, this.scalesOnPress = false, this.mediaImages, super.key})
    : delegated = false,
      clipsContent = false,
      fillsBounds = false;

  /// Only large content cards opt into press scaling.
  const FrostClickSurfaceVisuals.scaled({required super.child, this.mediaImages, super.key})
    : delegated = false,
      clipsContent = true,
      scalesOnPress = true,
      fillsBounds = false;

  /// A contiguous group's outer surface owns clipping; row fills stay rectangular.
  const FrostClickSurfaceVisuals.grouped({required super.child, super.key})
    : delegated = false,
      clipsContent = false,
      scalesOnPress = false,
      fillsBounds = true,
      mediaImages = null;
  final FrostMediaImageRegistry? mediaImages;
  static FrostMediaImageRegistry? mediaImagesOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostClickSurfaceVisuals>()?.mediaImages;
  final bool fillsBounds;
  static bool fillsBoundsOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostClickSurfaceVisuals>()?.fillsBounds ?? false;
  final bool delegated;
  final bool clipsContent;
  final bool scalesOnPress;

  static bool delegatedOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostClickSurfaceVisuals>()?.delegated ?? false;

  static bool clipsContentOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostClickSurfaceVisuals>()?.clipsContent ?? true;

  static bool scalesOnPressOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostClickSurfaceVisuals>()?.scalesOnPress ?? false;

  @override
  bool updateShouldNotify(FrostClickSurfaceVisuals oldWidget) =>
      mediaImages != oldWidget.mediaImages ||
      fillsBounds != oldWidget.fillsBounds ||
      delegated != oldWidget.delegated ||
      clipsContent != oldWidget.clipsContent ||
      scalesOnPress != oldWidget.scalesOnPress;
}

/// Internal composites may let an activation key reach their own shortcuts.
class FrostClickKeyboardScope extends InheritedWidget {
  const FrostClickKeyboardScope({required this.passThrough, required super.child, super.key});
  final Set<LogicalKeyboardKey> passThrough;
  static bool passes(BuildContext context, LogicalKeyboardKey key) =>
      context.dependOnInheritedWidgetOfExactType<FrostClickKeyboardScope>()?.passThrough.contains(key) ?? false;
  @override
  bool updateShouldNotify(FrostClickKeyboardScope oldWidget) => passThrough != oldWidget.passThrough;
}
