import 'dart:collection';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Cancellable UI work shared across page owners, never a business-work queue.
/// At most one callback releases a paint gate for the following frame.
class FrostFrameWork {
  FrostFrameWork._(this._callback);
  VoidCallback? _callback;
  void cancel() => _callback = null;
}

class FrostFrameWorkQueue {
  static final _pending = Queue<FrostFrameWork>();
  static bool _scheduled = false;

  static FrostFrameWork enqueue(VoidCallback callback) {
    final work = FrostFrameWork._(callback);
    _pending.add(work);
    _schedule();
    return work;
  }

  static void _schedule() {
    if (_scheduled || _pending.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      while (_pending.isNotEmpty) {
        final work = _pending.removeFirst();
        final callback = work._callback;
        work.cancel();
        if (callback == null) continue;
        callback();
        break;
      }
      _schedule();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}

// Entry scheduling never changes the sliver list or its measured extents.
// Offscreen blocks remain lazy; mounted blocks keep their final layout even
// while painting is deferred. No opacity or retained-layer manipulation is used.
enum FrostFrameWorkPhase { immediate, waiting, queued, stopped }

class FrostFrameWorkPaint extends StatefulWidget {
  const FrostFrameWorkPaint({required this.phase, required this.child, super.key});
  final FrostFrameWorkPhase phase;
  final Widget child;
  @override
  State<FrostFrameWorkPaint> createState() => _FrameWorkPaintState();
}

class _FrameWorkPaintState extends State<FrostFrameWorkPaint> {
  late bool _shown = widget.phase == FrostFrameWorkPhase.immediate;
  FrostFrameWork? _pending;
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FrostFrameWorkPaint oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.phase != FrostFrameWorkPhase.queued) {
      _pending?.cancel();
      _pending = null;
    }
    if (widget.phase == FrostFrameWorkPhase.immediate) _shown = true;
    if (_shown || _pending != null || widget.phase != FrostFrameWorkPhase.queued) return;
    _pending = FrostFrameWorkQueue.enqueue(() {
      _pending = null;
      if (mounted && widget.phase == FrostFrameWorkPhase.queued) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PaintGate(visible: _shown, child: widget.child);
}

class _PaintGate extends SingleChildRenderObjectWidget {
  const _PaintGate({required this.visible, required super.child});
  final bool visible;
  @override
  RenderObject createRenderObject(BuildContext context) => FrostFrameWorkRender(visible);
  @override
  void updateRenderObject(BuildContext context, FrostFrameWorkRender renderObject) => renderObject.visible = visible;
}

class FrostFrameWorkRender extends RenderProxyBox {
  FrostFrameWorkRender(this._visible);
  bool _visible;
  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_visible) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => _visible && super.hitTest(result, position: position);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visible) super.visitChildrenForSemantics(visitor);
  }
}
