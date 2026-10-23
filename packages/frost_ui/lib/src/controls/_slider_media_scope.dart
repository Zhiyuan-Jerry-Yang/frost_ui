import 'package:flutter/widgets.dart';

// Media track portions use the same foreground at three distinct opacities.
const frostVideoPlayedOpacity = 1.0;
const frostVideoBufferedOpacity = .4;
const frostVideoTrackOpacity = .2;

/// Private adaptation of the shared slider. Time always advances left to
/// right, independently of the surrounding writing direction.
class FrostSliderMediaScope extends InheritedWidget {
  const FrostSliderMediaScope({
    required this.ink,
    required this.buffered,
    required this.step,
    required this.onInteractionChanged,
    required super.child,
    super.key,
  });
  final Color ink;
  final double buffered, step;
  final ValueChanged<bool> onInteractionChanged;
  static FrostSliderMediaScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostSliderMediaScope>();
  @override
  bool updateShouldNotify(FrostSliderMediaScope oldWidget) =>
      ink != oldWidget.ink || buffered != oldWidget.buffered || step != oldWidget.step || onInteractionChanged != oldWidget.onInteractionChanged;
}
