import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '_status_bar_scroll_to_top.dart';

/// Routes iOS status-bar taps to the foreground page's vertical viewport.
///
/// Install above the Navigator, as `FrostApp` does, so pushed pages and modal
/// scroll areas participate without changing their controllers or page state.
/// Text editors, horizontal controls and covered/retained pages are excluded.
class FrostScrollToTopHost extends StatefulWidget {
  const FrostScrollToTopHost({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<FrostScrollToTopHost> createState() => _ScrollToTopHostState();
}

class _ScrollToTopHostState extends State<FrostScrollToTopHost> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void handleStatusBarTap() {
    if (FrostScrollToTopScope.contains(context) || !widget.enabled || Theme.of(context).platform != TargetPlatform.iOS) return;
    _ScrollTarget? target;
    void visit(Element element) {
      // EditableText's internal scroll position belongs to editing, not the
      // page. Leave its content, selection and keyboard focus intact.
      if (element.widget is EditableText) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        final position = scrollable.position;
        if (position.axis == Axis.vertical &&
            position.hasPixels &&
            position.hasContentDimensions &&
            position.maxScrollExtent > position.minScrollExtent &&
            position.physics.allowUserScrolling &&
            frostScrollToTopRouteIsActive(element)) {
          final visible = _visibleViewport(scrollable);
          if (visible != null) {
            final area = visible.width * visible.height;
            // Prefer the main content pane to a narrower navigation pane.
            if (target == null || area > target!.area) target = _ScrollTarget(position, element, area);
            // The page owns its nested content. Do not independently reset
            // smaller scroll areas inside it, even when the page is at top.
            return;
          }
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final selected = target;
    if (selected != null) frostScrollPositionToTop(selected.position, selected.context);
  }

  Rect? _visibleViewport(ScrollableState scrollable) {
    final box = scrollable.notificationContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return null;
    final view = View.of(scrollable.context);
    final ratio = view.devicePixelRatio;
    final screen = Rect.fromLTWH(0, 0, view.physicalSize.width / ratio, (view.physicalSize.height - view.viewInsets.bottom) / ratio);
    final visible = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size).intersect(screen);
    if (visible.isEmpty) return null;

    // Probe inside the viewport rather than under pinned page chrome. The
    // route check blocks modals; hit testing also detects sibling Navigators,
    // offstage branches and non-route barriers in the current Flutter View.
    for (final fraction in const [.5, .25, .75]) {
      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(result, Offset(visible.center.dx, visible.top + visible.height * fraction), view.viewId);
      if (result.path.any((entry) => _inside(entry.target, box))) return visible;
    }
    return null;
  }

  bool _inside(Object target, RenderObject viewport) {
    if (target is! RenderObject) return false;
    for (RenderObject? current = target; current != null; current = current.parent) {
      if (identical(current, viewport)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => FrostScrollToTopScope(child: widget.child);
}

class _ScrollTarget {
  const _ScrollTarget(this.position, this.context, this.area);
  final ScrollPosition position;
  final BuildContext context;
  final double area;
}
