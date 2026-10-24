import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:frost_window/frost_window.dart' show FrostCaptionAction, FrostCaptionIcon, FrostCaptionMode, FrostCaptionStyle;

/// Native window actions and layout-time caption hit-region collection.
class FrostWindowCaptionScope extends StatefulWidget {
  const FrostWindowCaptionScope({required this.child, this.window, this.systemBackdropActive = false, this.systemBackdropAvailable = false, super.key});

  final FrostWindowActions? window;
  final Widget child;

  /// Whether the native host is currently drawing a system backdrop.
  /// A requested but unsupported backdrop must leave this false.
  final bool systemBackdropActive;

  /// Actual native backdrop capability, independent of the selected material.
  final bool systemBackdropAvailable;
  static bool systemBackdropAvailableOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CaptionScope>()?.owner.systemBackdropAvailable ?? false;

  static bool systemBackdropActiveOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_CaptionScope>()?.owner.systemBackdropActive ?? false;

  static FrostCaptionState? stateOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_CaptionScope>()?.state;

  static FrostWindowActions? windowOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_CaptionScope>()?.owner.window;

  @override
  State<FrostWindowCaptionScope> createState() => _CaptionScopeState();
}

class _CaptionScope extends InheritedWidget {
  const _CaptionScope({required this.owner, required this.collector, required this.state, required super.child});
  final FrostWindowCaptionScope owner;
  final _CaptionScopeState collector;
  final FrostCaptionState? state;

  @override
  bool updateShouldNotify(_CaptionScope oldWidget) =>
      owner.window != oldWidget.owner.window ||
      state != oldWidget.state ||
      owner.systemBackdropActive != oldWidget.owner.systemBackdropActive ||
      owner.systemBackdropAvailable != oldWidget.owner.systemBackdropAvailable;
}

/// Native hit-test coordinates are logical pixels relative to the Flutter view.
enum FrostHitKind { caption, maximize }

@immutable
class FrostHitRegion {
  const FrostHitRegion({required this.rect, required this.kind});
  final Rect rect;
  final FrostHitKind kind;

  @override
  bool operator ==(Object other) => other is FrostHitRegion && other.rect == rect && other.kind == kind;
  @override
  int get hashCode => Object.hash(rect, kind);
}

enum FrostCaptionSide { left, right }

@immutable
class FrostCaptionState {
  const FrostCaptionState({
    required this.maximized,
    required this.active,
    required this.maximizeHovered,
    required this.maximizePressed,
    required this.failed,
    this.mode = FrostCaptionMode.client,
    this.leftButtons = const [],
    this.rightButtons = const [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close],
    this.nativeControls = Rect.zero,
    this.style = FrostCaptionStyle.windows,
    this.icons = const {},
  });
  final bool maximized;
  final bool active;
  final bool maximizeHovered;
  final bool maximizePressed;
  final bool failed;
  final FrostCaptionMode mode;
  final FrostCaptionStyle style;

  /// Symbolic PNG masks from the host's icon theme, at the current display scale.
  /// Missing entries use the shared vector fallback; colors come from Frost.
  final Map<FrostCaptionIcon, Uint8List> icons;
  final List<FrostCaptionAction> leftButtons, rightButtons;

  /// Native button bounds in Flutter-view logical coordinates, not OS pixels.
  final Rect nativeControls;
}

abstract interface class FrostWindowActions implements Listenable {
  FrostCaptionState get captionState;
  Future<void> minimize();
  Future<void> toggleMaximized();
  Future<void> close();
  Future<void> retry();
  void updateHitRegions(List<FrostHitRegion> regions);
}

class _CaptionScopeState extends State<FrostWindowCaptionScope> {
  final _regions = <_CaptionRegionBox>{};
  List<FrostHitRegion> _last = const [];
  bool _queued = false;

  void _queueSync() {
    if (_queued || widget.window == null) return;
    _queued = true;
    // Layout/paint schedule this before post-frame callbacks run, so even the
    // first pump publishes final geometry without a corrective rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || widget.window == null) return;
      final regions = List.of(_regions).map((box) => box.region).nonNulls.toSet().toList()
        ..sort((a, b) {
          final av = [a.kind.index.toDouble(), a.rect.left, a.rect.top, a.rect.right, a.rect.bottom];
          final bv = [b.kind.index.toDouble(), b.rect.left, b.rect.top, b.rect.right, b.rect.bottom];
          for (var i = 0; i < av.length; i++) {
            final order = av[i].compareTo(bv[i]);
            if (order != 0) return order;
          }
          return 0;
        });
      // Observe later frames without requesting them, including changes behind
      // repaint boundaries where a hidden region never paints itself.
      _queueSync();
      if (listEquals(_last, regions)) return;
      _last = List.unmodifiable(regions);
      widget.window!.updateHitRegions(_last);
    });
  }

  @override
  void didUpdateWidget(FrostWindowCaptionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window != widget.window) {
      if (_last.isNotEmpty) oldWidget.window?.updateHitRegions(const []);
      _last = const [];
      _queueSync();
    }
  }

  @override
  void dispose() {
    if (_last.isNotEmpty) widget.window?.updateHitRegions(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget scope() => _CaptionScope(
      owner: widget,
      collector: this,
      state: widget.window?.captionState,
      child: widget.window == null ? widget.child : _CaptionLayout(onChanged: _queueSync, child: widget.child),
    );
    return widget.window == null ? scope() : ListenableBuilder(listenable: widget.window!, builder: (context, _) => scope());
  }
}

/// Marks only the native caption or maximize area; it adds no pointer handler.
/// Regions on a covered route are inactive even when a translucent page leaves
/// them painted. This also checks enclosing routes across nested Navigators.
class FrostCaptionRegion extends StatelessWidget {
  const FrostCaptionRegion({required this.kind, required this.child, super.key});
  final FrostHitKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_CaptionScope>();
    if (scope?.owner.window == null) return child;
    final routes = <ModalRoute<Object?>>[];
    // Keep route identities, whose isCurrent state is read at every sync. A
    // nested page can remain current while its enclosing shell is covered by
    // a root viewer, so checking only the nearest route is insufficient.
    for (var route = ModalRoute.of<Object?>(context); route != null;) {
      if (routes.contains(route)) break;
      routes.add(route);
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of<Object?>(navigator.context);
    }
    return _CaptionRegion(collector: scope!.collector, kind: kind, routes: routes, child: child);
  }
}

class _CaptionRegion extends SingleChildRenderObjectWidget {
  const _CaptionRegion({required this.collector, required this.kind, required this.routes, required super.child});
  final _CaptionScopeState collector;
  final FrostHitKind kind;
  final List<ModalRoute<Object?>> routes;

  @override
  RenderObject createRenderObject(BuildContext context) => _CaptionRegionBox(collector, kind, routes, context, View.of(context));
  @override
  void updateRenderObject(BuildContext context, _CaptionRegionBox renderObject) {
    renderObject.update(collector, kind, routes, View.of(context));
  }
}

class _CaptionRegionBox extends RenderProxyBox {
  _CaptionRegionBox(this.collector, this.kind, this.routes, this.context, this.view);
  final BuildContext context;
  FlutterView view;
  _CaptionScopeState collector;
  FrostHitKind kind;
  List<ModalRoute<Object?>> routes;

  void update(_CaptionScopeState nextCollector, FrostHitKind nextKind, List<ModalRoute<Object?>> nextRoutes, FlutterView nextView) {
    if (collector != nextCollector && attached) {
      collector._regions.remove(this);
      collector._queueSync();
      nextCollector._regions.add(this);
    }
    collector = nextCollector;
    kind = nextKind;
    routes = nextRoutes;
    view = nextView;
    collector._queueSync();
  }

  FrostHitRegion? get region {
    if (!attached || !hasSize || size.isEmpty || routes.any((route) => !route.isCurrent)) return null;
    final pipeline = owner;
    if (pipeline == null || !context.mounted) return null;
    // Reparenting can temporarily leave an attached node outside its owner's
    // root. Only coordinates rooted in this live Flutter view are native hits.
    RenderObject root = this;
    while (root.parent != null) {
      final ancestor = root.parent!;
      if (ancestor.owner != pipeline) return null;
      root = ancestor;
    }
    if (root is! RenderView || root.flutterView != view || pipeline.rootNode != root || !RendererBinding.instance.renderViews.contains(root)) return null;
    var visible = true;
    context.visitAncestorElements((element) {
      if (element.widget case Visibility(visible: false)) {
        visible = false;
        return false;
      }
      return true;
    });
    if (!visible) return null;
    RenderObject descendant = this;
    for (RenderObject? ancestor = parent; ancestor != null; ancestor = ancestor.parent) {
      if (!ancestor.paintsChild(descendant)) return null;
      descendant = ancestor;
    }
    final rect = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
    if (rect.isEmpty || !rect.isFinite) return null;
    return FrostHitRegion(rect: rect, kind: kind);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    collector._regions.add(this);
    collector._queueSync();
  }

  @override
  void detach() {
    collector._regions.remove(this);
    collector._queueSync();
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    collector._queueSync();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    collector._queueSync();
  }
}

// Observe the whole scope as well: hiding a retained Offstage descendant can
// skip that region's own layout and paint while its old geometry still exists.
class _CaptionLayout extends SingleChildRenderObjectWidget {
  const _CaptionLayout({required this.onChanged, required super.child});
  final VoidCallback onChanged;
  @override
  RenderObject createRenderObject(BuildContext context) => _CaptionLayoutBox(onChanged);
  @override
  void updateRenderObject(BuildContext context, _CaptionLayoutBox renderObject) => renderObject.onChanged = onChanged;
}

class _CaptionLayoutBox extends RenderProxyBox {
  _CaptionLayoutBox(this.onChanged);
  VoidCallback onChanged;
  @override
  void performLayout() {
    super.performLayout();
    onChanged();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onChanged();
  }
}
