import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../feedback/progress.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_labeled_track.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../motion/rolling_text.dart';
import '../motion/spring.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_local_scroll_view.dart';
import '_control_surfaces.dart';
import '_input_surface.dart';
import '_slider_media_scope.dart';

// Thumb geometry matches Switch, reserving the pressed radius at both ends.
const _thumbDiameter = 20.0, _pressedDiameter = 24.0, _trackHeight = 4.0;
// Continuous keyboard increments are fractions of the complete range.
const _arrowFraction = .01, _pageFraction = .1, _disabledOpacity = .38;
// Punctuation is kept separate from application-localized value labels.
const _percentSign = '%';
// Shared minimum for the same track in normal controls and media bars.
const frostSliderMinimumTrackWidth = frostMinimumTrackWidth + _pressedDiameter;

/// A controlled slider. Drag updates follow the pointer; track clicks and
/// external values settle on the snappy spring. Values are clamped to bounds.
class FrostSlider extends StatefulWidget {
  const FrostSlider({
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    required this.semanticLabel,
    this.valueLabel,
    super.key,
  }) : assert(min > double.negativeInfinity && max < double.infinity && max > min),
       assert(value > double.negativeInfinity && value < double.infinity),
       assert(divisions == null || divisions > 0);
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged, onChangeEnd;
  final String semanticLabel;
  final String Function(double value)? valueLabel;
  @override
  State<FrostSlider> createState() => _SliderState();
}

class _SliderState extends State<FrostSlider> with SingleTickerProviderStateMixin {
  late final _position = AnimationController.unbounded(vsync: this, value: _unit(widget.value));
  final _focus = FocusNode(), _identity = FrostLayoutIdentity();
  bool _dragging = false, _pointerActive = false;
  double _pointerX = 0, _slotWidth = 0, _requested = 0;
  FrostSliderMediaScope? get _media => FrostSliderMediaScope.of(context);
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context);
  double _unit(double value) => (value.clamp(widget.min, widget.max) - widget.min) / (widget.max - widget.min);
  double _snap(double value) {
    final fraction = _unit(value);
    return widget.min + (widget.max - widget.min) * (widget.divisions == null ? fraction : (fraction * widget.divisions!).round() / widget.divisions!);
  }

  double _at(double x) {
    final inset = math.min(_pressedDiameter / 2, _slotWidth / 2), travel = math.max(0.0, _slotWidth - inset * 2);
    final fraction = travel == 0 ? 0.0 : ((x - inset) / travel).clamp(0.0, 1.0);
    return _snap(widget.min + (widget.max - widget.min) * (Directionality.of(context) == TextDirection.rtl ? 1 - fraction : fraction));
  }

  String _label(double value) => widget.valueLabel?.call(value) ?? '${(_unit(value) * 100).round()}$_percentSign';
  double _next(int direction, {bool page = false}) => _snap(
    widget.value + direction * (_media?.step ?? (widget.max - widget.min) * (page ? _pageFraction : 1 / (widget.divisions ?? (1 / _arrowFraction).round()))),
  );
  void _adjust(double value) {
    if (!_enabled) return;
    value = _snap(value);
    if (value == widget.value.clamp(widget.min, widget.max)) return;
    widget.onChanged!(value);
    widget.onChangeEnd?.call(value);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    if (_media != null && (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight)) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final value = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _next(rtl ? 1 : -1),
      LogicalKeyboardKey.arrowRight => _next(rtl ? -1 : 1),
      LogicalKeyboardKey.arrowUp => _next(1),
      LogicalKeyboardKey.arrowDown => _next(-1),
      LogicalKeyboardKey.pageUp => _next(1, page: true),
      LogicalKeyboardKey.pageDown => _next(-1, page: true),
      LogicalKeyboardKey.home => widget.min,
      LogicalKeyboardKey.end => widget.max,
      _ => null,
    };
    if (value == null) return KeyEventResult.ignored;
    _adjust(value);
    return KeyEventResult.handled;
  }

  void _settle() => FrostMotion.springTo(context, _position, _unit(widget.value), FrostMotion.snappy);
  void _dragTo(double x) {
    if (!_enabled || !_pointerActive) return;
    _requested = _at(x);
    _position.value = _unit(_requested);
    widget.onChanged!(_requested);
  }

  void _end({bool cancelled = false}) {
    if (!_pointerActive) return;
    _pointerActive = false;
    setState(() => _dragging = false);
    if (!cancelled && _enabled) widget.onChangeEnd?.call(_requested);
    _media?.onInteractionChanged(false);
    _settle();
  }

  void _tap() {
    if (!_enabled || !_pointerActive) return;
    _pointerActive = false;
    final value = _at(_pointerX);
    widget.onChanged!(value);
    widget.onChangeEnd?.call(value);
    _media?.onInteractionChanged(false);
  }

  @override
  void didUpdateWidget(FrostSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _dragging = false;
      _pointerActive = false;
    }
    if (!_dragging) _settle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      _dragging = false;
      _pointerActive = false;
      _settle();
    }
    if (MediaQuery.disableAnimationsOf(context)) _position.value = _unit(widget.value);
  }

  @override
  void deactivate() {
    _pointerActive = false;
    _dragging = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _position.dispose();
    _focus.dispose();
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context), direction = Directionality.of(context);
    final value = widget.value.clamp(widget.min, widget.max), target = FrostDensity.of(context).targetHeight;
    final media = _media;
    final label = media == null ? widget.valueLabel?.call(value) : null;
    return Semantics(
      slider: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: _label(value),
      increasedValue: _enabled && value < widget.max ? _label(_next(1)) : null,
      decreasedValue: _enabled && value > widget.min ? _label(_next(-1)) : null,
      onIncrease: _enabled && value < widget.max ? () => _adjust(_next(1)) : null,
      onDecrease: _enabled && value > widget.min ? () => _adjust(_next(-1)) : null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: _enabled ? 1 : _disabledOpacity,
        duration: FrostMotion.duration(context, FrostMotion.hover),
        child: FrostMotionSize(
          duration: FrostMotion.duration(context, FrostMotion.layoutFade),
          alignment: AlignmentDirectional.topStart,
          child: FrostLayoutCrossfade(
            layoutIdentity: _identity,
            settleDuration: Duration.zero,
            child: FrostLabeledTrackLayout(
              identity: _identity,
              direction: direction,
              hasLeading: false,
              hasTrailing: label != null,
              trackHeight: target,
              minimumTrackWidth: frostSliderMinimumTrackWidth,
              children: [
                Focus(
                  canRequestFocus: false,
                  onKeyEvent: _key,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _slotWidth = constraints.maxWidth;
                      return Listener(
                        onPointerDown: _enabled
                            ? (event) {
                                _pointerActive = true;
                                _pointerX = event.localPosition.dx;
                                _requested = value;
                              }
                            : null,
                        onPointerCancel: (_) {
                          if (!_dragging) _pointerActive = false;
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _enabled
                              ? (event) {
                                  if (!_pointerActive) return;
                                  _focus.requestFocus();
                                  setState(() => _dragging = true);
                                  _media?.onInteractionChanged(true);
                                  _dragTo(event.localPosition.dx);
                                }
                              : null,
                          onHorizontalDragUpdate: _enabled ? (event) => _dragTo(event.localPosition.dx) : null,
                          onHorizontalDragEnd: _enabled ? (_) => _end() : null,
                          onHorizontalDragCancel: () {
                            if (_dragging) _end(cancelled: true);
                          },
                          child: FrostClickKeyboardScope(
                            passThrough: media == null ? const {} : {LogicalKeyboardKey.space},
                            child: FrostInputSurface(
                              onTap: _enabled ? _tap : null,
                              focusNode: _focus,
                              builder: (context, states) => TweenAnimationBuilder<(Color, Color)>(
                                tween: FrostProgressPaletteTween(
                                  end: media == null
                                      ? (tokens.fillStrong, tokens.actionFill)
                                      : (media.ink.withValues(alpha: frostVideoTrackOpacity), media.ink.withValues(alpha: frostVideoPlayedOpacity)),
                                ),
                                duration: FrostMotion.duration(context, FrostMotion.hover),
                                curve: FrostMotion.hoverCurve,
                                builder: (context, colors, _) => AnimatedBuilder(
                                  animation: _position,
                                  builder: (context, _) {
                                    final fraction = _position.value.clamp(0.0, 1.0), inset = math.min(_pressedDiameter / 2, constraints.maxWidth / 2);
                                    final travel = math.max(0.0, constraints.maxWidth - inset * 2);
                                    return SizedBox(
                                      height: target,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned(
                                            left: inset,
                                            right: inset,
                                            height: _trackHeight,
                                            child: CustomPaint(
                                              painter: FrostProgressPainter(
                                                fraction,
                                                colors.$1,
                                                colors.$2,
                                                null,
                                                direction,
                                                buffered: media?.buffered,
                                                bufferedInk: media == null ? null : colors.$2.withValues(alpha: frostVideoBufferedOpacity),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: inset + travel * (direction == TextDirection.ltr ? fraction : 1 - fraction) - _pressedDiameter / 2,
                                            width: _pressedDiameter,
                                            height: _pressedDiameter,
                                            child: Center(
                                              child: FrostSpringBuilder(
                                                value: _enabled && (_dragging || states.contains(WidgetState.pressed)) ? _pressedDiameter : _thumbDiameter,
                                                spring: FrostMotion.snappy,
                                                builder: (context, diameter, _) => SizedBox.square(
                                                  dimension: diameter,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      FrostControlThumb(height: diameter, showsEdge: true),
                                                      FrostClickFeedbackVisual(
                                                        states: {...states, if (_dragging) WidgetState.pressed},
                                                        shape: const CircleBorder(),
                                                        scalesOnPress: false,
                                                        clipsContent: false,
                                                        child: const SizedBox.expand(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
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
                      );
                    },
                  ),
                ),
                const SizedBox.shrink(),
                label == null
                    ? const SizedBox.shrink()
                    : FrostLocalScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: direction == TextDirection.rtl,
                        child: FrostRollingText(
                          label,
                          style: FrostTypography.of(context).style(FrostTextRole.callout, numeric: true).copyWith(color: tokens.textPrimary),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
