import 'package:flutter/material.dart';

import '../primitives/_page_outline.dart';

/// One window-edge scrollbar for a coordinated header and the selected tab.
/// Inner tab viewports do not own scrollbars. The adapter owns only its own
/// position; it never attaches to a position owned by NestedScrollView.
class FrostNestedPageScrollbar extends StatefulWidget {
  const FrostNestedPageScrollbar({required this.outerController, required this.innerPosition, required this.child, super.key});

  final ScrollController outerController;
  final ScrollPosition? Function() innerPosition;
  final Widget child;

  @override
  State<FrostNestedPageScrollbar> createState() => _FrostNestedPageScrollbarState();
}

class _FrostNestedPageScrollbarState extends State<FrostNestedPageScrollbar> {
  final _controller = ScrollController();
  final _metricsKey = GlobalKey();
  _NestedPagePosition? _position;
  ScrollPosition? _inner;
  bool _queued = false;

  @override
  void initState() {
    super.initState();
    widget.outerController.addListener(_scheduleSync);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(FrostNestedPageScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outerController != widget.outerController) {
      oldWidget.outerController.removeListener(_scheduleSync);
      widget.outerController.addListener(_scheduleSync);
      _disposePosition();
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_queued || !mounted) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !widget.outerController.hasClients) return;
      final outer = widget.outerController.position;
      final inner = widget.innerPosition();
      if (!identical(inner, _inner)) {
        _inner?.removeListener(_scheduleSync);
        _inner = inner;
        _inner?.addListener(_scheduleSync);
      }
      if (!outer.hasContentDimensions || !outer.hasViewportDimension) return;
      final position = _position ??= _NestedPagePosition(
        context: outer.context,
        outer: () => widget.outerController.position,
        inner: () => widget.innerPosition(),
      );
      if (!_controller.hasClients) _controller.attach(position);
      position.sync();
      final context = _metricsKey.currentContext;
      if (context != null) {
        ScrollMetricsNotification(metrics: _NestedPageMetrics(position), context: context).dispatch(context);
      }
    });
  }

  void _disposePosition() {
    final position = _position;
    if (position == null) return;
    _controller.detach(position);
    position.dispose();
    _position = null;
  }

  @override
  void dispose() {
    widget.outerController.removeListener(_scheduleSync);
    _inner?.removeListener(_scheduleSync);
    _disposePosition();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    scrollbarOrientation: FrostPageOutline.channelOf(context) > 0 ? ScrollbarOrientation.right : null,
    thumbVisibility: true,
    notificationPredicate: (notification) => notification.metrics is _NestedPageMetrics,
    child: NotificationListener<ScrollMetricsNotification>(
      key: _metricsKey,
      onNotification: (_) {
        _scheduleSync();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) _scheduleSync();
          return false;
        },
        child: widget.child,
      ),
    ),
  );
}

class _NestedPageMetrics extends FixedScrollMetrics {
  _NestedPageMetrics(ScrollPosition position)
    : super(
        minScrollExtent: position.minScrollExtent,
        maxScrollExtent: position.maxScrollExtent,
        pixels: position.pixels,
        viewportDimension: position.viewportDimension,
        axisDirection: position.axisDirection,
        devicePixelRatio: position.devicePixelRatio,
      );
}

class _NestedPagePosition extends ScrollPositionWithSingleContext {
  _NestedPagePosition({required super.context, required this.outer, required this.inner})
    : super(physics: const ClampingScrollPhysics(), initialPixels: 0, keepScrollOffset: false);

  final ScrollPosition Function() outer;
  final ScrollPosition? Function() inner;

  void sync() {
    final header = outer();
    final body = inner();
    final headerExtent = header.maxScrollExtent - header.minScrollExtent;
    final bodyExtent = body?.hasContentDimensions == true ? body!.maxScrollExtent - body.minScrollExtent : 0.0;
    final bodyOffset = body?.hasContentDimensions == true ? (body!.pixels - body.minScrollExtent).clamp(0.0, bodyExtent) : 0.0;
    correctPixels(header.pixels - header.minScrollExtent + bodyOffset);
    applyViewportDimension(header.viewportDimension);
    applyContentDimensions(0, headerExtent + bodyExtent);
    notifyListeners();
  }

  void _move(double value) {
    final header = outer();
    final body = inner();
    final headerExtent = header.maxScrollExtent - header.minScrollExtent;
    final target = value.clamp(minScrollExtent, maxScrollExtent);
    if (target <= headerExtent || body?.hasContentDimensions != true) {
      header.jumpTo(header.minScrollExtent + target);
    } else {
      // NestedScrollView's inner jump maps to the coordinated outer+inner
      // offset and collapses the header. Do not move both owners separately.
      body!.jumpTo(body.minScrollExtent + target - headerExtent);
    }
    sync();
  }

  @override
  void jumpTo(double value) => _move(value);

  @override
  Future<void> animateTo(double to, {required Duration duration, required Curve curve}) {
    final header = outer();
    final body = inner();
    final headerExtent = header.maxScrollExtent - header.minScrollExtent;
    final target = to.clamp(minScrollExtent, maxScrollExtent);
    return target <= headerExtent || body?.hasContentDimensions != true
        ? header.animateTo(header.minScrollExtent + target, duration: duration, curve: curve)
        : body!.animateTo(body.minScrollExtent + target - headerExtent, duration: duration, curve: curve);
  }

  @override
  void applyUserOffset(double delta) => _move(pixels - delta);

  @override
  double setPixels(double newPixels) {
    final target = newPixels.clamp(minScrollExtent, maxScrollExtent);
    _move(target);
    return newPixels - target;
  }

  @override
  void pointerScroll(double delta) => _move(pixels + delta);
}
