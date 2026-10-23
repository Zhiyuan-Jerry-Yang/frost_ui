import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../motion/_spring_simulation.dart';
import '../motion/spring.dart';
import '_control_surfaces.dart';

// The thumb has a fixed two-pixel inset in both density columns.
const _thumbInset = 2.0;
const _pointerTrackWidth = 40.0, _pointerTrackHeight = 24.0, _pointerThumb = 20.0;
const _touchTrackWidth = 48.0, _touchTrackHeight = 28.0, _touchThumb = 24.0;
// A press stretches toward the next side without changing the thumb's height.
const _pressedExtension = 6.0;
// Faster releases choose their direction; slower releases choose the nearest side.
const _velocityThreshold = 200.0;
const _focusOutset = 3.0;
const _disabledOpacity = .38;

class FrostSwitch extends StatefulWidget {
  const FrostSwitch({required this.value, required this.onChanged, required this.semanticLabel, super.key});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<FrostSwitch> createState() => _FrostSwitchState();
}

class _FrostSwitchState extends State<FrostSwitch> with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);
  final FocusNode _focus = FocusNode();
  bool _pressed = false, _dragging = false, _invalidPress = false, _focusVisible = false;
  double _origin = 0, _startPosition = 0, _dragValue = 0, _stretchDirection = 1;
  VelocityTracker? _velocity;
  bool get _enabled => widget.onChanged != null;
  bool get _touch => FrostControlSize.compact.height(context) == FrostControlSize.compact.visualHeight(touch: true);
  double get _travel => !_touch ? _pointerTrackWidth - _pointerThumb - _thumbInset * 2 : _touchTrackWidth - _touchThumb - _thumbInset * 2;
  double get _direction => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  @override
  void didUpdateWidget(FrostSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _invalidPress = true;
      _pressed = false;
      _dragging = false;
    }
    if (oldWidget.value != widget.value || oldWidget.onChanged != null && !_enabled) _settle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _position.value = widget.value ? 1 : 0;
  }

  void _settle({double? velocity}) {
    final target = widget.value ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
    } else {
      _position.animateWith(frostSpringSimulation(FrostMotion.snappy, _position.value, target, velocity ?? _position.velocity));
    }
  }

  void _toggle() {
    if (_enabled && !_invalidPress) widget.onChanged!(!widget.value);
  }

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _endDrag(double pixelVelocity, {bool cancelled = false}) {
    if (!_dragging) return;
    _dragging = false;
    _press(false);
    final logicalVelocity = pixelVelocity * _direction;
    final target = logicalVelocity.abs() >= _velocityThreshold ? logicalVelocity > 0 : _dragValue >= .5;
    if (!cancelled && !_invalidPress && _enabled && target != widget.value) widget.onChanged!(target);
    // The caller owns value, including a rejected change. Preserve release speed
    // in units of thumb travel/second across the caller's subsequent rebuild.
    _settle(velocity: cancelled ? null : logicalVelocity / _travel);
  }

  @override
  void dispose() {
    _position.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final touch = _touch;
    final width = touch ? _touchTrackWidth : _pointerTrackWidth;
    final height = touch ? _touchTrackHeight : _pointerTrackHeight;
    final diameter = touch ? _touchThumb : _pointerThumb;
    Widget control = FocusableActionDetector(
      enabled: _enabled,
      focusNode: _focus,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
      shortcuts: const {SingleActivator(LogicalKeyboardKey.space): ActivateIntent(), SingleActivator(LogicalKeyboardKey.enter): ActivateIntent()},
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (_enabled) widget.onChanged!(!widget.value);
            return null;
          },
        ),
      },
      child: Listener(
        onPointerDown: (event) {
          _invalidPress = !_enabled;
          _origin = event.localPosition.dx;
          // A fast spring can overshoot internally while the track clips it.
          // A new drag starts from the visible thumb, without a dead zone.
          _startPosition = _position.value.clamp(0.0, 1.0);
          _stretchDirection = widget.value ? -1 : 1;
          _velocity = VelocityTracker.withKind(event.kind)..addPosition(event.timeStamp, event.position);
          if (_enabled) {
            _focus.requestFocus();
            _press(true);
          }
        },
        onPointerMove: (event) => _velocity?.addPosition(event.timeStamp, event.position),
        onPointerUp: (_) => _press(false),
        onPointerCancel: (_) {
          _invalidPress = true;
          _press(false);
          _endDrag(0, cancelled: true);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: _toggle,
          onTapCancel: () {
            if (!_dragging) _press(false);
          },
          onHorizontalDragStart: (_) {
            if (!_enabled || _invalidPress) return;
            _dragging = true;
            _dragValue = _position.value.clamp(0.0, 1.0);
            _position.stop();
            _press(true);
          },
          onHorizontalDragUpdate: (details) {
            if (!_dragging || !_enabled || _invalidPress) return;
            _dragValue = (_startPosition + (details.localPosition.dx - _origin) * _direction / _travel).clamp(0.0, 1.0);
            if (details.delta.dx != 0) _stretchDirection = details.delta.dx.sign * _direction;
            _position.value = _dragValue;
          },
          // DragGestureRecognizer applies an additional fling-distance floor.
          // Our specified speed threshold also covers a short, fast release.
          onHorizontalDragEnd: (details) => _endDrag(_velocity?.getVelocity().pixelsPerSecond.dx ?? details.primaryVelocity ?? 0),
          onHorizontalDragCancel: () => _endDrag(0, cancelled: true),
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : _disabledOpacity,
            duration: FrostMotion.duration(context, FrostMotion.hover),
            child: SizedBox(
              width: width,
              height: math.max(height, FrostDensity.of(context).targetHeight),
              child: Center(
                child: CustomPaint(
                  foregroundPainter: _enabled && _focusVisible ? _SwitchFocusPainter(tokens.focus, height) : null,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: FrostSpringBuilder(
                      value: _pressed && _enabled ? _pressedExtension : 0,
                      spring: FrostMotion.snappy,
                      builder: (context, extension, _) => AnimatedBuilder(
                        animation: _position,
                        builder: (context, _) {
                          final progress = _position.value.clamp(0.0, 1.0);
                          final physical = _direction == 1 ? progress : 1 - progress;
                          final thumbWidth = diameter + extension;
                          final extendsLeft = _stretchDirection * _direction < 0;
                          final x = (_thumbInset + _travel * physical - (extendsLeft ? extension : 0)).clamp(_thumbInset, width - _thumbInset - thumbWidth);
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.lerp(tokens.fillStrong, tokens.actionFill, progress),
                              borderRadius: BorderRadius.circular(height / 2),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: x,
                                  top: _thumbInset,
                                  child: SizedBox(
                                    width: thumbWidth,
                                    height: diameter,
                                    child: FrostControlThumb(height: diameter),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.semanticLabel == null
        ? ExcludeSemantics(child: control)
        : Semantics(
            label: widget.semanticLabel,
            toggled: widget.value,
            enabled: _enabled,
            onTap: _enabled ? () => widget.onChanged!(!widget.value) : null,
            excludeSemantics: true,
            child: control,
          );
  }
}

class _SwitchFocusPainter extends CustomPainter {
  const _SwitchFocusPainter(this.color, this.height);
  final Color color;
  final double height;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius((Offset.zero & size).inflate(_focusOutset), Radius.circular(height / 2 + _focusOutset)),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = FrostMetrics.focusBorderWidth,
  );
  @override
  bool shouldRepaint(_SwitchFocusPainter oldDelegate) => color != oldDelegate.color || height != oldDelegate.height;
}
