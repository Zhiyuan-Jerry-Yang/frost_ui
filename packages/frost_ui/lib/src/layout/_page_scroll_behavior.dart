import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../primitives/_page_outline.dart';

/// Adapt only the inherited automatic Material scrollbar. Explicit suppression,
/// custom decorations and explicitly chosen orientations remain caller-owned.
Widget frostPageScrollbar(BuildContext context, Widget decoration) {
  if (FrostPageOutline.channelOf(context) == 0 || decoration is! Scrollbar || decoration.scrollbarOrientation != null) return decoration;
  return Scrollbar(
    key: decoration.key,
    controller: decoration.controller,
    thumbVisibility: decoration.thumbVisibility,
    trackVisibility: decoration.trackVisibility,
    thickness: decoration.thickness,
    radius: decoration.radius,
    notificationPredicate: decoration.notificationPredicate,
    interactive: decoration.interactive,
    scrollbarOrientation: ScrollbarOrientation.right,
    child: decoration.child,
  );
}

/// Scroll views keep their own normal decoration and controller. Only the
/// physical scrollbar edge changes; input, physics and caller overrides survive.
class FrostPageScrollBehavior extends ScrollBehavior {
  const FrostPageScrollBehavior(this.parent);
  final ScrollBehavior parent;
  @override
  TargetPlatform getPlatform(BuildContext context) => parent.getPlatform(context);
  @override
  Set<PointerDeviceKind> get dragDevices => parent.dragDevices;
  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers => parent.pointerAxisModifiers;
  @override
  MultitouchDragStrategy getMultitouchDragStrategy(BuildContext context) => parent.getMultitouchDragStrategy(context);
  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) => parent.velocityTrackerBuilder(context);
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => parent.getScrollPhysics(context);
  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(BuildContext context) => parent.getKeyboardDismissBehavior(context);
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => parent.buildOverscrollIndicator(context, child, details);
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => axisDirectionToAxis(details.direction) == Axis.vertical
      ? frostPageScrollbar(context, parent.buildScrollbar(context, child, details))
      : parent.buildScrollbar(context, child, details);
  @override
  bool shouldNotify(FrostPageScrollBehavior oldDelegate) => parent != oldDelegate.parent;
}
