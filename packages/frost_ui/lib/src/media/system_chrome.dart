import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';

// Continue the system-bar protection into edge-to-edge media.
const _systemFadeExtent = 24.0;

/// Declares edge-to-edge media on this route. FrostApp paints system-bar
/// protection above its Navigator, including Hero flights and route overlays.
/// Protection follows the route animation in both directions, including
/// predictive back. This does not consume safe-area padding or move content.
class FrostMediaSystemChrome extends StatefulWidget {
  const FrostMediaSystemChrome({required this.child, super.key});
  final Widget child;
  @override
  State<FrostMediaSystemChrome> createState() => _MediaSystemChromeState();
}

class _MediaSystemChromeState extends State<FrostMediaSystemChrome> {
  _SystemChromeScope? _scope;
  ModalRoute<Object?>? _route;
  Animation<double>? _animation;
  bool _enabled = true;
  double get progress => !_enabled || _route?.offstage == true ? 0 : (_animation?.value ?? 1).clamp(0.0, 1.0);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<_SystemChromeScope>();
    if (_scope != scope) {
      _scope?.entries.remove(this);
      _scope?.invalidate();
      _scope = scope;
      scope?.entries.add(this);
    }
    _enabled = TickerMode.valuesOf(context).enabled;
    _route = ModalRoute.of(context);
    final animation = _route?.animation;
    if (_animation != animation) {
      _animation?.removeListener(_changed);
      _animation = animation?..addListener(_changed);
    }
    _changed();
  }

  void _changed() => _scope?.invalidate();
  @override
  void dispose() {
    _animation?.removeListener(_changed);
    _scope?.entries.remove(this);
    _changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Installs system-bar protection above all routed content. FrostApp already
/// installs this host. Other WidgetsApp/MaterialApp builders can wrap their
/// Navigator with it. Keep it outside every Navigator/Overlay so transitions
/// cannot paint over the protection.
class FrostMediaSystemChromeHost extends StatefulWidget {
  const FrostMediaSystemChromeHost({required this.child, super.key});
  final Widget child;
  @override
  State<FrostMediaSystemChromeHost> createState() => _SystemChromeHostState();
}

class _SystemChromeHostState extends State<FrostMediaSystemChromeHost> {
  final _entries = <_MediaSystemChromeState>{};
  _RenderSystemChrome? _render;
  void _invalidate() {
    _render?.markNeedsPaint();
    // A route can unmount after this frame's paint. Request one final paint to
    // clear its annotation and gradient; never rebuild ancestors during build.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WidgetsBinding.instance.ensureVisualUpdate();
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SystemChromeScope(
    entries: _entries,
    invalidate: _invalidate,
    child: _SystemChromePaint(
      entries: _entries,
      scrim: FrostThemeTokens.of(context).onMediaScrim,
      top: math.max(MediaQuery.paddingOf(context).top, MediaQuery.viewPaddingOf(context).top),
      onRender: (render) => _render = render,
      child: widget.child,
    ),
  );
}

class _SystemChromeScope extends InheritedWidget {
  const _SystemChromeScope({required this.entries, required this.invalidate, required super.child});
  final Set<_MediaSystemChromeState> entries;
  final VoidCallback invalidate;
  @override
  bool updateShouldNotify(_SystemChromeScope oldWidget) => false;
}

class _SystemChromePaint extends SingleChildRenderObjectWidget {
  const _SystemChromePaint({required this.entries, required this.scrim, required this.top, required this.onRender, required super.child});
  final Set<_MediaSystemChromeState> entries;
  final Color scrim;
  final double top;
  final ValueChanged<_RenderSystemChrome> onRender;
  @override
  RenderObject createRenderObject(BuildContext context) {
    final render = _RenderSystemChrome(entries, scrim, top);
    onRender(render);
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderSystemChrome renderObject) {
    onRender(renderObject);
    renderObject
      ..scrim = scrim
      ..top = top
      ..markNeedsPaint();
  }
}

class _RenderSystemChrome extends RenderProxyBox {
  _RenderSystemChrome(this.entries, this.scrim, this.top);
  final Set<_MediaSystemChromeState> entries;
  Color scrim;
  double top;
  @override
  bool get alwaysNeedsCompositing => true;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final progress = entries.fold(0.0, (value, entry) => math.max(value, entry.progress));
    if (top <= 0 || progress <= 0) return;
    final rect = offset & Size(size.width, top + _systemFadeExtent);
    context.canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scrim.withValues(alpha: progress),
            scrim.withValues(alpha: scrim.a * progress),
            scrim.withValues(alpha: 0),
          ],
          stops: [0, top / rect.height, 1],
        ).createShader(rect),
    );
    // Added after the child: nested Navigator annotations cannot override the
    // light system icons protected by this topmost band.
    context.addLayer(
      AnnotatedRegionLayer<SystemUiOverlayStyle>(
        SystemUiOverlayStyle.light.copyWith(statusBarColor: scrim.withValues(alpha: 0), systemStatusBarContrastEnforced: false),
        size: Size(size.width, top),
        offset: offset,
      ),
    );
  }
}
