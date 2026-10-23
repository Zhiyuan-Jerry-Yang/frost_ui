import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// The page's panel and the physical-right scrollbar channel share one viewport.
/// The surface consumes only paint ownership; columns retain the channel budget.
class FrostPageOutline extends InheritedWidget {
  const FrostPageOutline({super.key, required this.radius, this.scrollbarChannel = 0, this.channelClaimed = false, required super.child});
  final BorderRadius radius;
  final double scrollbarChannel;
  final bool channelClaimed;
  static FrostPageOutline? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPageOutline>();
  static BorderRadius of(BuildContext context) => maybeOf(context)?.radius ?? BorderRadius.zero;
  static double channelOf(BuildContext context) => maybeOf(context)?.scrollbarChannel ?? 0;
  static double contentWidth(BuildContext context, double width) => math.max(0, width - channelOf(context));

  /// Columns already reserved the channel; descendants must not add it again.
  static Widget content(BuildContext context, Widget child) => FrostPageOutline(radius: of(context), channelClaimed: true, child: child);
  Widget consumeSurface(Widget child) => FrostPageOutline(radius: radius, scrollbarChannel: scrollbarChannel, channelClaimed: true, child: child);
  @override
  bool updateShouldNotify(FrostPageOutline oldWidget) =>
      radius != oldWidget.radius || scrollbarChannel != oldWidget.scrollbarChannel || channelClaimed != oldWidget.channelClaimed;
}

/// Images keep the panel's curved corners; the adjoining scrollbar channel is
/// part of the same clip so a normal Scrollbar can paint at the viewport edge.
class FrostPageViewportClip extends CustomClipper<Path> {
  const FrostPageViewportClip({required this.radius, required this.continuous, required this.channel});
  final BorderRadius radius;
  final bool continuous;
  final double channel;
  @override
  Path getClip(Size size) {
    final width = math.max(0.0, size.width - channel);
    final panel = Rect.fromLTWH(0, 0, width, size.height);
    final shape = continuous ? RoundedSuperellipseBorder(borderRadius: radius) : RoundedRectangleBorder(borderRadius: radius);
    return Path.combine(PathOperation.union, shape.getOuterPath(panel), Path()..addRect(Rect.fromLTRB(width, 0, size.width, size.height)));
  }

  @override
  bool shouldReclip(FrostPageViewportClip oldClipper) => radius != oldClipper.radius || continuous != oldClipper.continuous || channel != oldClipper.channel;
}
