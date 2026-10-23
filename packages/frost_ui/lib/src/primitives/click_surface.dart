import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../foundation/_focus_modality.dart';
import '../foundation/feedback.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '_click_feedback.dart';
import '_click_surface_visuals.dart';

enum FrostClickFeedback { surface, quiet, media }

/// Shared pointer feedback. Presses deepen the fill without moving content.
/// Library content cards explicitly opt into scaling; media stays unshaded.
/// Only keyboard focus
/// receives an outline. Layout never determines the available input methods.
class FrostClickSurface extends StatefulWidget {
  const FrostClickSurface({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.feedback = FrostClickFeedback.surface,
    this.borderRadius,
    this.customBorder,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
    this.onHover,
    this.onFocusChange,
    this.onPressedChange,
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final FrostClickFeedback feedback;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor? mouseCursor;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;

  /// Input-event notifications only. Disabling silently cancels the current
  /// press; consumers must also derive their visual state from availability.
  final ValueChanged<bool>? onPressedChange;

  /// Whether the nearest enclosing click surface is under the pointer (not
  /// over a nested control), for content that reacts to hovering its card,
  /// such as a picture zooming inside its frame.
  static bool hoveredOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_HoverScope>()?.hovered ?? false;

  @override
  State<FrostClickSurface> createState() => _AppClickSurfaceState();
}

class _HoverScope extends InheritedWidget {
  const _HoverScope({required this.hovered, required super.child});

  final bool hovered;

  @override
  bool updateShouldNotify(_HoverScope oldWidget) => hovered != oldWidget.hovered;
}

class _AppClickSurfaceState extends State<FrostClickSurface> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _invalidPress = false;
  bool _disabledDuringPress = false;
  LogicalKeyboardKey? _activationKey;
  final FocusNode _ownedFocus = FocusNode();

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      // A covered route owns no active pointer/activation gesture. Cancel
      // silently, as on deactivate; callbacks here could mutate an ancestor
      // while the framework is rebuilding the route's ticker scope.
      _hovered = false;
      _pressed = false;
      _invalidPress = true;
      _disabledDuringPress = true;
      _activationKey = null;
    }
  }

  @override
  void didUpdateWidget(FrostClickSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      // A lifecycle cancellation is intentionally silent. Keep the gesture
      // invalid even if availability returns before this pointer is released.
      _invalidPress = true;
      _disabledDuringPress = true;
      _pressed = false;
      _activationKey = null;
    }
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
    widget.onPressedChange?.call(value);
  }

  bool _touchPress = false;
  void _pointerDown(PointerDownEvent event) {
    _touchPress = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;
    _invalidPress = !_enabled;
    _disabledDuringPress = !_enabled;
    if (_enabled) {
      // Pointer activation keeps the current editing focus. Keyboard traversal
      // owns focus acquisition, as with Flutter buttons.
      _setPressed(true);
    }
  }

  void _cancelPress() {
    _invalidPress = true;
    _setPressed(false);
  }

  void _activate() {
    if (_enabled && !_invalidPress) widget.onTap?.call();
  }

  KeyEventResult _keyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (FrostClickKeyboardScope.passes(context, key)) return KeyEventResult.ignored;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (event is KeyDownEvent && _enabled) {
      _invalidPress = false;
      _activationKey = key;
      _setPressed(true);
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent && _activationKey == key) {
      _activationKey = null;
      _setPressed(false);
      _activate();
      return KeyEventResult.handled;
    }
    // Windows can batch unrelated key events with a synthesized release. An
    // unmatched release must not swallow Escape on its way to a modal parent.
    return event is KeyRepeatEvent && _activationKey == key ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _updateHover(PointerEvent event) {
    if (!FrostInputModality.instance.acceptsHover(event)) return;
    final result = HitTestResult();
    GestureBinding.instance.hitTestInView(result, event.position, event.viewId);
    var nestedControl = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && identical(target.metaData, this)) break;
      // Material buttons and nested click surfaces resolve their cursor on the
      // render object. Stop parent feedback even over a disabled child control.
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer) {
        nestedControl = true;
      }
    }
    _setHovered(!nestedControl);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover?.call(value);
  }

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  void _modalityChanged() {
    if (!mounted) return;
    if (FrostInputModality.instance.touch) _setHovered(false);
    setState(() {});
  }

  void _highlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void deactivate() {
    // Disposing the last tap recognizer can call onTapCancel while children
    // unmount. Clear input state before that lifecycle cancellation, silently.
    _invalidPress = true;
    _disabledDuringPress = true;
    _pressed = false;
    _activationKey = null;
    super.deactivate();
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    _ownedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (_hovered) WidgetState.hovered,
      if (_pressed) WidgetState.pressed,
      if (_focused) WidgetState.focused,
    };
    final shape =
        widget.customBorder ??
        (FrostScope.configOf(context).continuousCorners
            ? RoundedSuperellipseBorder(borderRadius: widget.borderRadius ?? FrostRadius.borderRadius(FrostRadius.md))
            : RoundedRectangleBorder(borderRadius: widget.borderRadius ?? FrostRadius.borderRadius(FrostRadius.md)));
    final delegated = FrostClickSurfaceVisuals.delegatedOf(context);
    Widget content = MetaData(
      metaData: this,
      behavior: HitTestBehavior.translucent,
      child: FrostClickSurfaceVisuals.standard(
        child: _HoverScope(hovered: enabled && _hovered, child: widget.child),
      ),
    );
    if (!delegated) {
      content = FrostClickFeedbackVisual(
        states: states,
        feedback: widget.feedback,
        shape: shape,
        clipsContent: FrostClickSurfaceVisuals.clipsContentOf(context),
        fillsBounds: FrostClickSurfaceVisuals.fillsBoundsOf(context),
        scalesOnPress: FrostClickSurfaceVisuals.scalesOnPressOf(context),
        mediaImages: FrostClickSurfaceVisuals.mediaImagesOf(context),
        highlighted: FrostClickHighlight.of(context),
        child: content,
      );
    }
    return MouseRegion(
      cursor: widget.mouseCursor ?? frostClickCursor.resolve(states),
      onEnter: _updateHover,
      onHover: _updateHover,
      onExit: (_) => _setHovered(false),
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (_enabled) widget.onTap?.call();
              return null;
            },
          ),
        },
        child: Focus(
          canRequestFocus: enabled,
          onKeyEvent: _keyEvent,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode ?? _ownedFocus,
          onFocusChange: (value) {
            setState(() => _focused = value);
            widget.onFocusChange?.call(value);
          },
          child: Listener(
            onPointerDown: _pointerDown,
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _cancelPress(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? _activate : null,
              onTapCancel: _cancelPress,
              onLongPress: enabled && widget.onLongPress != null
                  ? () {
                      if (_touchPress && !_disabledDuringPress) widget.onLongPress?.call();
                    }
                  : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
