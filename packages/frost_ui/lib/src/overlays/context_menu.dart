import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../foundation/scope.dart';
import 'adaptive_panel.dart';
import 'menu_anchor.dart';
import 'menu_entry.dart';
import 'sheet.dart';

/// Opens the shared menu at a point in global logical coordinates.
Future<void> showFrostContextMenu({required BuildContext context, required Offset globalPosition, required List<FrostMenuEntry> entries}) =>
    entries.isEmpty ? Future.value() : _ContextMenuSession(context, globalPosition, entries, FocusManager.instance.primaryFocus).closed;

abstract interface class _MenuSession {
  Future<void> get closed;
  void close();
}

class _ContextMenuSession implements _MenuSession {
  _ContextMenuSession(BuildContext context, Offset position, List<FrostMenuEntry> entries, FocusNode? origin) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = overlay.context.findRenderObject()! as RenderBox;
    final point = box.globalToLocal(position);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final content = Localizations.override(
      context: context,
      child: themes.wrap(
        FrostScope(
          config: FrostScope.configOf(context),
          reduceTransparency: FrostScope.maybeOf(context)?.reduceTransparency ?? false,
          child: MediaQuery(
            data: MediaQuery.of(context),
            child: Directionality(
              textDirection: Directionality.of(context),
              child: FrostMenuHost(
                entries: entries,
                autoOpen: true,
                returnFocus: origin,
                onClosed: close,
                builder: (context, focus, toggle) => Focus(focusNode: focus, child: const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = OverlayEntry(
      builder: (_) => Positioned(left: point.dx, top: point.dy, width: 0, height: 0, child: content),
    );
    overlay.insert(_entry);
  }
  late final OverlayEntry _entry;
  final _completion = Completer<void>();
  @override
  Future<void> get closed => _completion.future;
  @override
  void close() {
    if (_completion.isCompleted) return;
    _completion.complete();
    _entry.remove();
    _entry.dispose();
  }
}

// Touch uses a fitted sheet when floating actions do not fit. Mouse and
// keyboard context menus stay anchored even in a narrow desktop window.
class _TouchMenuSession implements _MenuSession {
  _TouchMenuSession(BuildContext context, List<FrostMenuEntry> entries) {
    closed = showFrostSheet<void>(
      context: context,
      detents: const [FrostSheetDetent.fitted],
      showsCloseButton: false,
      builder: (context) {
        _route = ModalRoute.of(context);
        if (_closing) {
          WidgetsBinding.instance.addPostFrameCallback((_) => close());
          return const SizedBox.shrink();
        }
        return FrostMenuScope(
          close: close,
          child: Builder(
            builder: (context) =>
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: frostMenuChildren(context, entries)),
          ),
        );
      },
    );
  }
  ModalRoute<void>? _route;
  bool _closing = false;
  @override
  late final Future<void> closed;
  @override
  void close() {
    _closing = true;
    final route = _route;
    if (route == null || !route.isActive) return;
    final navigator = route.navigator!;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }
}

/// Adds context-menu input without taking focus or changing the child's semantics.
/// The child owns its press feedback and shape; this region paints no surface.
class FrostContextMenuRegion extends StatefulWidget {
  const FrostContextMenuRegion({required this.entries, required this.child, this.enabled = true, super.key});
  final List<FrostMenuEntry> entries;
  final Widget child;
  final bool enabled;
  @override
  State<FrostContextMenuRegion> createState() => _FrostContextMenuRegionState();
}

class _FrostContextMenuRegionState extends State<FrostContextMenuRegion> {
  _MenuSession? _session;
  bool _touchPress = false;
  FocusNode? _origin;
  bool _activePress = false;
  Offset? _secondaryOrigin;
  bool get _enabled => widget.enabled && widget.entries.isNotEmpty;
  @override
  void didUpdateWidget(FrostContextMenuRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _activePress = false;
      _secondaryOrigin = null;
      _session?.close();
      _session = null;
    }
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    final hit = HitTestResult();
    GestureBinding.instance.hitTestInView(hit, event.position, event.viewId);
    final owner = hit.path
        .map((entry) => entry.target)
        .whereType<RenderMetaData>()
        .map((node) => node.metaData)
        .whereType<_FrostContextMenuRegionState>()
        .where((state) => state._enabled)
        .firstOrNull;
    _activePress = _enabled && identical(owner, this);
    _touchPress = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;
    _secondaryOrigin = _activePress && event.buttons & kSecondaryMouseButton != 0 ? event.position : null;
    if (!_activePress) return;
    _origin = FocusManager.instance.primaryFocus;
  }

  void _open(Offset position, {FocusNode? origin, bool touch = false}) {
    if (!_enabled || _session != null) return;
    final _MenuSession session = touch && frostPanelUsesSheet(context)
        ? _TouchMenuSession(context, widget.entries)
        : _ContextMenuSession(context, position, widget.entries, origin ?? _origin);
    _session = session;
    session.closed.then((_) {
      if (mounted && identical(_session, session)) _session = null;
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!_enabled || event is! KeyDownEvent) return KeyEventResult.ignored;
    final menuKey = event.logicalKey == LogicalKeyboardKey.contextMenu;
    final shiftF10 = event.logicalKey == LogicalKeyboardKey.f10 && HardwareKeyboard.instance.isShiftPressed;
    if (!menuKey && !shiftF10) return KeyEventResult.ignored;
    final focus = FocusManager.instance.primaryFocus;
    final render = focus?.context?.findRenderObject() ?? context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return KeyEventResult.ignored;
    _open(render.localToGlobal(Offset(0, render.size.height)), origin: focus);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => MetaData(
    metaData: this,
    behavior: HitTestBehavior.translucent,
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: _key,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _pointerDown,
        // Observe secondary taps before a selectable child claims its gesture.
        // Primary selection and the innermost-region ownership stay unchanged.
        onPointerMove: (event) {
          if (_secondaryOrigin case final origin? when (event.position - origin).distance > kTouchSlop) _secondaryOrigin = null;
        },
        onPointerUp: (event) {
          if (_secondaryOrigin != null) _open(event.position);
          _secondaryOrigin = null;
        },
        onPointerCancel: (_) {
          _secondaryOrigin = null;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus},
          onLongPressStart: !_enabled
              ? null
              : (details) {
                  if (_activePress) _open(details.globalPosition, touch: _touchPress);
                },
          child: widget.child,
        ),
      ),
    ),
  );
}

extension FrostContextMenuX on Widget {
  Widget frostContextMenu(List<FrostMenuEntry> entries, {bool enabled = true}) => FrostContextMenuRegion(entries: entries, enabled: enabled, child: this);
}

/// Library-owned toolbar overflow. Device input determines the presentation:
/// touch in narrow available space uses the same fitted menu as long press;
/// mouse and keyboard always retain an anchored menu.
class FrostAdaptiveMenuAnchor extends StatefulWidget {
  const FrostAdaptiveMenuAnchor({required this.entries, required this.builder, super.key});
  final List<FrostMenuEntry> entries;
  final FrostMenuTriggerBuilder builder;
  @override
  State<FrostAdaptiveMenuAnchor> createState() => _AdaptiveMenuAnchorState();
}

class _AdaptiveMenuAnchorState extends State<FrostAdaptiveMenuAnchor> {
  bool _touch = false;
  _MenuSession? _session;
  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, _) {
      _touch = false;
      return KeyEventResult.ignored;
    },
    child: Listener(
      onPointerDown: (event) => _touch = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus,
      child: FrostMenuAnchor(
        entries: widget.entries,
        builder: (context, focus, toggle) => widget.builder(context, focus, () {
          if (!_touch || !frostPanelUsesSheet(context)) {
            toggle();
            return;
          }
          if (_session != null) {
            _session!.close();
            return;
          }
          final session = _session = _TouchMenuSession(context, widget.entries);
          session.closed.whenComplete(() {
            if (identical(_session, session)) _session = null;
          });
        }),
      ),
    ),
  );
}
