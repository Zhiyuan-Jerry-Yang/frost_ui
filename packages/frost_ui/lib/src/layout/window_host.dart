import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frost_window/frost_window.dart';

import '../foundation/scope.dart';
import '../navigation/back.dart';
import '../navigation/window_caption.dart';
import 'window_caption_scope.dart';

/// Native window behaviour without a drawn frame. Install above the Navigator
/// so caption controls can stay outside route and dialog barriers.
class FrostWindowHost extends StatefulWidget {
  const FrostWindowHost({
    required this.controller,
    required this.title,
    required this.child,
    this.resizeBorderWidth = 4.0,
    this.backdrop = FrostWindowBackdrop.none,
    super.key,
  }) : assert(resizeBorderWidth > 0 && resizeBorderWidth < double.infinity);
  final FrostWindowController controller;
  final String title;
  final Widget child;

  /// No system backdrop by default. The app's ambient image or solid base
  /// remains in charge. Mica requires Windows 11 build 22621 or newer and
  /// falls back normally when the OS or the app disables transparency.
  final FrostWindowBackdrop backdrop;

  /// Logical-pixel resize strip: the visible top edge on Windows, all edges
  /// on Linux. AppKit supplies its own macOS resize edges.
  final double resizeBorderWidth;
  @override
  State<FrostWindowHost> createState() => _FrostWindowHostState();
}

class _FrostWindowHostState extends State<FrostWindowHost> with WidgetsBindingObserver {
  final _contentFocus = FocusScopeNode(debugLabel: 'Window content');
  FocusNode? _lastContentFocus;
  final _navigatorFocusEdges = <FocusScopeNode, TraversalEdgeBehavior>{};
  late _WindowActions _actions;
  List<FrostHitRegion> _regions = const [];
  List<FrostHitRegion>? _lastRegions;
  ({String title, bool dark})? _lastToolbar;
  double? _lastResizeBorder;
  ({FrostWindowBackdrop backdrop, bool reduceTransparency})? _lastBackdrop;
  bool _reduceTransparency = false;
  bool _syncQueued = false;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _bind();
    FocusManager.instance.addListener(_rememberContentFocus);
    WidgetsBinding.instance.addObserver(this);
    if (frostUsesCustomTitleBar) unawaited(_initializeNative());
  }

  void _bind() {
    _actions = _WindowActions(widget.controller, _initializeNative, (regions) {
      _regions = List.unmodifiable(regions);
      _syncNative();
    });
    widget.controller.addListener(_queueSync);
    widget.controller.addBackListener(_navigateBack);
  }

  void _unbind(FrostWindowController controller) {
    controller.removeListener(_queueSync);
    controller.removeBackListener(_navigateBack);
    _actions.dispose();
    if (frostUsesCustomTitleBar && controller.ready) unawaited(_perform(() => controller.setRegions(const [])));
  }

  @override
  void didUpdateWidget(FrostWindowHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unbind(oldWidget.controller);
      _regions = const [];
      _lastRegions = null;
      _lastToolbar = null;
      _lastResizeBorder = null;
      _lastBackdrop = null;
      _bind();
      if (frostUsesCustomTitleBar) unawaited(_initializeNative());
    }
    _queueSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dark = Theme.of(context).brightness == Brightness.dark;
    _reduceTransparency = FrostScope.solidSurfaces(context);
    _queueSync();
  }

  Future<void> _initializeNative() async {
    final controller = widget.controller;
    if (!frostUsesCustomTitleBar) return;
    try {
      await controller.initialize();
    } on FrostWindowFailure {
      return;
    }
    if (!mounted || controller != widget.controller) return;
    _lastRegions = null;
    _lastToolbar = null;
    _lastResizeBorder = null;
    _lastBackdrop = null;
    _queueSync();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeMetrics() => _queueSync();

  void _queueSync() {
    if (_syncQueued || !mounted || !frostUsesCustomTitleBar) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (mounted) _syncNative();
    });
  }

  void _syncNative() {
    if (!mounted || !frostUsesCustomTitleBar || !widget.controller.ready) return;
    final controller = widget.controller;
    final toolbar = (title: widget.title, dark: _dark);
    if (_lastResizeBorder != widget.resizeBorderWidth) {
      _lastResizeBorder = widget.resizeBorderWidth;
      unawaited(_perform(() => controller.setResizeBorder(widget.resizeBorderWidth)));
    }
    if (toolbar != _lastToolbar) {
      _lastToolbar = toolbar;
      unawaited(_perform(() => controller.setToolbar(title: toolbar.title, dark: toolbar.dark)));
    }
    final backdrop = (backdrop: widget.backdrop, reduceTransparency: _reduceTransparency);
    if (backdrop != _lastBackdrop) {
      _lastBackdrop = backdrop;
      unawaited(_perform(() => controller.setBackdrop(backdrop.backdrop, reduceTransparency: backdrop.reduceTransparency)));
    }
    if (!listEquals(_regions, _lastRegions)) {
      _lastRegions = List.of(_regions);
      final regions = _regions
          .map(
            (region) => <Object>[
              region.rect.left,
              region.rect.top,
              region.rect.right,
              region.rect.bottom,
              switch (region.kind) {
                FrostHitKind.caption => 'caption',
                FrostHitKind.maximize => 'maximize',
              },
            ],
          )
          .toList();
      unawaited(_perform(() => controller.setRegions(regions)));
    }
  }

  bool _isContentFocus(FocusNode? node) =>
      node != null &&
      node is! FocusScopeNode &&
      node.ancestors.contains(_contentFocus) &&
      node.context?.findAncestorWidgetOfExactType<FrostCaptionButtons>() == null;

  void _rememberContentFocus() {
    final current = FocusManager.instance.primaryFocus;
    if (_isContentFocus(current)) {
      _lastContentFocus = current;
      final targetContext = current?.context;
      final scope = targetContext == null ? null : Navigator.maybeOf(targetContext)?.focusNode.enclosingScope;
      // WidgetsApp's Navigator scope otherwise loops before reaching caption
      // controls installed by its builder. Route/dialog scopes keep their own
      // edge policy, including a modal's intentional closed loop.
      if (scope != null && scope.ancestors.contains(_contentFocus) && scope.traversalEdgeBehavior == TraversalEdgeBehavior.closedLoop) {
        _navigatorFocusEdges.putIfAbsent(scope, () => scope.traversalEdgeBehavior);
        scope.traversalEdgeBehavior = TraversalEdgeBehavior.parentScope;
      }
    }
  }

  void _navigateBack() {
    if (!mounted || !widget.controller.state.active || widget.controller.state.minimized) return;
    FocusNode? target = FocusManager.instance.primaryFocus;
    if (!_isContentFocus(target)) {
      target = _contentFocus.focusedChild;
      while (target is FocusScopeNode && target.focusedChild != null) {
        target = target.focusedChild;
      }
      final previous = _lastContentFocus;
      final previousContext = previous?.context;
      if (previousContext != null && previousContext.mounted && ModalRoute.of(previousContext)?.isCurrent == true && !_isContentFocus(target)) {
        target = previous;
      }
    }
    requestFrostBack(context: target?.context);
  }

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } on FrostWindowFailure {
      // Controller failure state exposes retry through FrostCaptionButtons.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_rememberContentFocus);
    _unbind(widget.controller);
    for (final entry in _navigatorFocusEdges.entries) {
      if (entry.key.traversalEdgeBehavior == TraversalEdgeBehavior.parentScope) entry.key.traversalEdgeBehavior = entry.value;
    }
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!frostUsesCustomTitleBar) return widget.child;
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true, includeRepeats: false): VoidCallbackIntent(_navigateBack),
        const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): VoidCallbackIntent(_navigateBack),
      },
      child: Overlay.wrap(
        child: FocusScope(
          node: _contentFocus,
          child: ListenableBuilder(
            listenable: widget.controller,
            child: widget.child,
            builder: (context, child) => FrostScope(
              config: FrostScope.maybeOf(context)?.config,
              reduceTransparency: _reduceTransparency || widget.controller.state.reduceTransparency,
              child: FrostWindowCaptionScope(
                window: _actions,
                systemBackdropAvailable: widget.controller.state.backdropAvailable,
                systemBackdropActive: widget.controller.state.backdropActive && !_reduceTransparency && !widget.controller.state.reduceTransparency,
                child: child!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowActions extends ChangeNotifier implements FrostWindowActions {
  _WindowActions(this.controller, this.initialize, this.onRegions) {
    controller.addListener(notifyListeners);
  }
  final FrostWindowController controller;
  final Future<void> Function() initialize;
  final ValueChanged<List<FrostHitRegion>> onRegions;
  bool _disposed = false;

  @override
  FrostCaptionState get captionState {
    final state = controller.state;
    return FrostCaptionState(
      mode: state.captionMode,
      style: state.captionStyle,
      icons: state.captionIcons,
      leftButtons: state.leftButtons,
      rightButtons: state.rightButtons,
      nativeControls: state.nativeControls,
      maximized: state.maximized,
      active: state.active,
      maximizeHovered: state.hoveredButton == 'maximize',
      maximizePressed: state.pressedButton == 'maximize',
      failed: controller.failed,
    );
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (!frostUsesCustomTitleBar) return;
    try {
      await operation();
    } on FrostWindowFailure {
      // The same observable controller state drives the retry affordance.
    }
  }

  @override
  Future<void> minimize() => _perform(controller.minimize);
  @override
  Future<void> toggleMaximized() => _perform(controller.toggleMaximized);
  @override
  Future<void> close() => _perform(controller.close);
  @override
  Future<void> retry() => initialize();
  @override
  void updateHitRegions(List<FrostHitRegion> regions) {
    if (!_disposed) onRegions(regions);
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(notifyListeners);
    super.dispose();
  }
}
