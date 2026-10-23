import 'package:flutter/widgets.dart';

import '../foundation/_layout_scope.dart';

export '../foundation/_layout_scope.dart' show FrostSizeClass, FrostSizeLayout, isHorizontalSize;

typedef FrostAutoScaffoldBuilder = Widget Function(BuildContext context, FrostSizeLayout layout, Orientation orientation, bool useHorizontalLayout);

class FrostAutoScaffold extends StatelessWidget {
  const FrostAutoScaffold({
    required this.builder,
    this.mobileBreakpoint = frostMobileBreakpoint,
    this.tabletBreakpoint = frostTabletBreakpoint,
    this.desktopBreakpoint = frostDesktopBreakpoint,
    super.key,
  });

  final FrostAutoScaffoldBuilder builder;
  final double mobileBreakpoint;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  static bool usesHorizontalLayoutOf(BuildContext context) => FrostAdaptiveLayoutData.horizontalOf(context);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = size.width >= size.height ? Orientation.landscape : Orientation.portrait;

    final layout = FrostSizeLayout.fromSize(size, mobileBreakpoint: mobileBreakpoint, tabletBreakpoint: tabletBreakpoint, desktopBreakpoint: desktopBreakpoint);

    final horizontal = usesHorizontalLayoutOf(context);
    return FrostAdaptiveLayoutData(horizontal: horizontal, sizeClass: layout.sizeClass, child: builder(context, layout, orientation, horizontal));
  }
}

/// Install above the router so nested viewports and keyboards cannot change mode.
class FrostLayoutScope extends StatelessWidget {
  const FrostLayoutScope({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => FrostAdaptiveLayoutData(
    horizontal: isHorizontalSize(MediaQuery.sizeOf(context)),
    sizeClass: frostDefaultSizeClass(MediaQuery.sizeOf(context)),
    child: child,
  );
}
