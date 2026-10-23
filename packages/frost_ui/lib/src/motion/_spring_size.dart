import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '_spring_simulation.dart';

/// Layout-driven standard spring; measuring never calls setState. Only the
/// render object listens to the ticker, so new targets retain current velocity.
class FrostSpringSize extends StatefulWidget {
  const FrostSpringSize({required this.child, super.key});
  final Widget child;
  @override
  State<FrostSpringSize> createState() => _SpringSizeState();
}

class _SpringSizeState extends State<FrostSpringSize> with SingleTickerProviderStateMixin {
  late final _motion = AnimationController.unbounded(vsync: this);
  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SpringSizeBox(motion: _motion, reduced: MediaQuery.disableAnimationsOf(context), child: widget.child);
}

class _SpringSizeBox extends SingleChildRenderObjectWidget {
  const _SpringSizeBox({required this.motion, required this.reduced, required super.child});
  final AnimationController motion;
  final bool reduced;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSpringSize(motion, reduced);
  @override
  void updateRenderObject(BuildContext context, covariant _RenderSpringSize renderObject) {
    renderObject.reduced = reduced;
    renderObject.markNeedsLayout();
  }
}

class _RenderSpringSize extends RenderProxyBox {
  _RenderSpringSize(this.motion, this.reduced) {
    motion.addListener(_tick);
  }
  final AnimationController motion;
  bool reduced;
  double? _target;
  bool _layingOut = false;
  void _tick() {
    if (!_layingOut) markNeedsLayout();
  }

  @override
  void performLayout() {
    _layingOut = true;
    try {
      child?.layout(constraints, parentUsesSize: true);
      final childSize = child?.size ?? Size.zero;
      if (_target != childSize.height || (reduced && motion.value != childSize.height)) {
        if (_target == null || reduced) {
          motion.stop();
          motion.value = childSize.height;
        } else {
          motion.animateWith(frostSpringSimulation(FrostMotion.standard, motion.value, childSize.height, motion.velocity));
        }
        _target = childSize.height;
      }
      size = constraints.constrain(Size(childSize.width, motion.value));
    } finally {
      _layingOut = false;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint);
  }

  @override
  void dispose() {
    motion.removeListener(_tick);
    super.dispose();
  }
}
