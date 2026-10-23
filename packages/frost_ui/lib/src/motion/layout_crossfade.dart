import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../foundation/metrics.dart';
import '_layout_identity.dart';
import '_material_reveal.dart';

/// Reflows a single live subtree, then fades its outgoing pixels away.
///
/// Only a discrete layout identity captures a frame. Resizing within the same
/// layout never starts an animation. The snapshot has no state, focus, Heroes or
/// resource subscriptions; all input continues to the newly laid out child.
class FrostLayoutCrossfade extends StatefulWidget {
  const FrostLayoutCrossfade({
    required this.layoutIdentity,
    required this.child,
    this.duration = FrostMotion.layoutFade,
    this.settleDuration = const Duration(milliseconds: 100),
    super.key,
  });
  final Object layoutIdentity;
  final Widget child;
  final Duration duration;
  final Duration settleDuration;
  @override
  State<FrostLayoutCrossfade> createState() => _FrostLayoutCrossfadeState();
}

class _FrostLayoutCrossfadeState extends State<FrostLayoutCrossfade> with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  final _OutgoingSnapshot _snapshot = _OutgoingSnapshot();
  late final AnimationController _fade = AnimationController(vsync: this, value: 1, duration: widget.duration, animationBehavior: AnimationBehavior.preserve)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _release();
    });
  Timer? _settle;
  Size? _size;
  bool _active = false, _reduced = false;

  @override
  void initState() {
    super.initState();
    if (widget.layoutIdentity case final FrostLayoutIdentity identity) identity.addListener(_layoutChanged);
  }

  void _layoutChanged() {
    final identity = widget.layoutIdentity as FrostLayoutIdentity;
    if (identity.identityChanged) {
      _capture();
    } else if (_active) {
      _fade.stop();
      _scheduleFade();
    }
  }

  @override
  void didUpdateWidget(FrostLayoutCrossfade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fade.duration = widget.duration;
    if (oldWidget.layoutIdentity is FrostLayoutIdentity && oldWidget.layoutIdentity != widget.layoutIdentity) {
      (oldWidget.layoutIdentity as FrostLayoutIdentity).removeListener(_layoutChanged);
    }
    if (widget.layoutIdentity is FrostLayoutIdentity) {
      if (oldWidget.layoutIdentity != widget.layoutIdentity) (widget.layoutIdentity as FrostLayoutIdentity).addListener(_layoutChanged);
      return;
    }
    if (oldWidget.layoutIdentity != widget.layoutIdentity) _capture();
  }

  void _capture() {
    _settle?.cancel();
    _fade.stop();
    if (_reduced || View.of(context).physicalSize.isEmpty) {
      _release();
      _fade.value = 1;
      return;
    }
    final boundary = _boundary.currentContext?.findRenderObject();
    final image = boundary is _SnapshotRenderBoundary && boundary.hasSize && !boundary.size.isEmpty ? boundary.captureLastFrame() : null;
    // No outgoing pixels exist after an empty viewport or before first paint.
    // Fading the live replacement would only expose an empty background.
    if (image == null) {
      _release();
      _fade.value = 1;
      return;
    }
    _snapshot.replace(image);
    _active = true;
    _fade.value = 0;
    _scheduleFade();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _settle?.cancel();
      _fade.stop();
      _release();
      _fade.value = 1;
    }
  }

  void _scheduleFade() {
    _settle?.cancel();
    _settle = Timer(widget.settleDuration, () {
      if (mounted && _active) _fade.forward();
    });
  }

  void _release() {
    _active = false;
    _snapshot.replace(null);
  }

  @override
  void dispose() {
    if (widget.layoutIdentity case final FrostLayoutIdentity identity) identity.removeListener(_layoutChanged);
    _settle?.cancel();
    _fade.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _OutgoingFramePainter(_snapshot, _fade, Directionality.of(context)),
    child: FrostMaterialRevealTransition(
      layoutDriven: true,
      contentOnly: true,
      // Input and focus already belong to the live replacement at opacity zero.
      alwaysIncludeSemantics: true,
      opacity: _fade,
      child: _SnapshotBoundary(
        key: _boundary,
        onSize: (size) {
          if (_size != size && _active) {
            _fade.stop();
            _scheduleFade();
          }
          _size = size;
        },
        child: widget.child,
      ),
    ),
  );
}

class _OutgoingSnapshot extends ChangeNotifier {
  ui.Image? image;
  void replace(ui.Image? value) {
    image?.dispose();
    image = value;
    notifyListeners();
  }

  @override
  void dispose() {
    image?.dispose();
    image = null;
    super.dispose();
  }
}

class _OutgoingFramePainter extends CustomPainter {
  _OutgoingFramePainter(this.snapshot, this.fade, this.direction) : super(repaint: Listenable.merge([snapshot, fade]));
  final _OutgoingSnapshot snapshot;
  final Animation<double> fade;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    if (snapshot.image case final image?) {
      // Retain the old row's relative positions and pixel proportions. Cropping
      // at the new viewport edge avoids squeezing labels during a resize.
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: image,
        fit: BoxFit.none,
        alignment: direction == TextDirection.ltr ? Alignment.topLeft : Alignment.topRight,
        opacity: 1 - fade.value,
      );
    }
  }

  @override
  bool shouldRepaint(_OutgoingFramePainter oldDelegate) => snapshot != oldDelegate.snapshot || fade != oldDelegate.fade || direction != oldDelegate.direction;
}

class _SnapshotBoundary extends RepaintBoundary {
  const _SnapshotBoundary({required super.child, required this.onSize, super.key});
  final ValueChanged<Size> onSize;
  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) => _SnapshotRenderBoundary(onSize);
  @override
  void updateRenderObject(BuildContext context, _SnapshotRenderBoundary renderObject) => renderObject.onSize = onSize;
}

class _SnapshotRenderBoundary extends RenderRepaintBoundary {
  _SnapshotRenderBoundary(this.onSize);
  ValueChanged<Size> onSize;
  @override
  void performLayout() {
    super.performLayout();
    // Postpone paint-only fading without blocking intrinsic measurement or
    // rebuilding widgets during a parent's layout.
    onSize(size);
  }

  ui.Image? captureLastFrame() => switch (layer) {
    final OffsetLayer painted => painted.toImageSync(Offset.zero & size),
    _ => null,
  };
}

/// [AnimatedSize] that resizes at once with reduced motion.
class FrostMotionSize extends StatefulWidget {
  const FrostMotionSize({required this.duration, required this.child, this.alignment = Alignment.center, this.curve = Curves.linear, super.key});

  final Duration duration;
  final Widget child;
  final AlignmentGeometry alignment;
  final Curve curve;

  @override
  State<FrostMotionSize> createState() => _MotionSizeState();
}

class _MotionSizeState extends State<FrostMotionSize> {
  // Reparent the same subtree when motion preferences change. Zero-duration
  // RenderAnimatedSize can dirty itself during layout, so reduced motion still
  // bypasses that render object while retaining unkeyed descendant states.
  final _content = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _content, child: widget.child);
    return MediaQuery.disableAnimationsOf(context)
        ? child
        : AnimatedSize(duration: widget.duration, alignment: widget.alignment, curve: widget.curve, child: child);
  }
}
