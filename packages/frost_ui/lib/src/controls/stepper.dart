import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/divider.dart';
import '../primitives/icon.dart';
import '_control_surfaces.dart';
import '_input_surface.dart';
import '_number_math.dart';

// A held step starts immediately, then repeats after the deliberate hold delay.
const _holdDelay = Duration(milliseconds: 400), _repeatInterval = Duration(milliseconds: 80);
// Match the segmented control's composed disabled opacity without dimming twice.
const _disabledOpacity = .38;

/// A compact pair of decrement/increment controls with adjustable semantics.
class FrostStepper extends StatelessWidget {
  const FrostStepper({required this.value, this.min = 0, this.max = 100, this.step = 1, required this.onChanged, required this.semanticLabel, super.key})
    : assert(min > double.negativeInfinity && max < double.infinity && max >= min),
      assert(step > 0 && step < double.infinity),
      assert(value > double.negativeInfinity && value < double.infinity);
  final num value, min, max, step;
  final ValueChanged<num>? onChanged;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => FrostStepperControl(value: value, min: min, max: max, step: step, onChanged: onChanged, semanticLabel: semanticLabel);
}

/// The number field uses the same controls, with the field owning dimming and
/// value semantics. This presentation is intentionally not a public option.
class FrostStepperControl extends StatefulWidget {
  const FrostStepperControl({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.semanticLabel,
    this.embedded = false,
    this.decimals,
    super.key,
  });
  final num value, min, max, step;
  final ValueChanged<num>? onChanged;
  final String? semanticLabel;
  final bool embedded;
  final int? decimals;
  @override
  State<FrostStepperControl> createState() => _StepperState();
}

class _StepperState extends State<FrostStepperControl> {
  Timer? _repeat;
  int? _held, _suppressTap;
  int _inputSequence = 0;
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context);
  bool _canStep(int direction) => _enabled && (direction < 0 ? widget.value > widget.min : widget.value < widget.max);

  num _next(int direction) {
    final stepped = frostStepNumber(widget.value, widget.step, direction);
    return widget.decimals == null
        ? stepped.clamp(widget.min, widget.max)
        : frostNormalizeNumber(stepped, min: widget.min, max: widget.max, step: widget.step, decimals: widget.decimals!);
  }

  void _step(int direction) {
    if (!_canStep(direction)) return;
    final next = _next(direction);
    if (next != widget.value) widget.onChanged!(next);
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
    _held = null;
  }

  void _pressed(int direction, bool pressed) {
    if (!pressed) {
      _stop();
      final sequence = _inputSequence;
      // Only bookkeeping is deferred until the recognizers finish this input
      // dispatch. No press/change notification is emitted from this microtask.
      scheduleMicrotask(() {
        if (mounted && sequence == _inputSequence) _suppressTap = null;
      });
      return;
    }
    if (!_canStep(direction)) return;
    _stop();
    _inputSequence++;
    _held = direction;
    _suppressTap = direction;
    _step(direction);
    _repeat = Timer(_holdDelay, () {
      if (!mounted || _held != direction || !_canStep(direction)) return;
      _step(direction);
      _repeat = Timer.periodic(_repeatInterval, (_) {
        if (!mounted || _held != direction || !_canStep(direction)) {
          _stop();
        } else {
          _step(direction);
        }
      });
    });
  }

  void _activate(int direction) {
    if (_suppressTap == direction) {
      _suppressTap = null;
      return;
    }
    _step(direction);
  }

  @override
  void didUpdateWidget(FrostStepperControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_held case final held? when !_canStep(held)) {
      _stop();
      _suppressTap = null;
      _inputSequence++;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) _stop();
  }

  @override
  void deactivate() {
    _stop();
    _suppressTap = null;
    _inputSequence++;
    super.deactivate();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context), icons = FrostIconSet.of(context);
    final visualHeight = FrostControlSize.compact.height(context), target = FrostDensity.of(context).targetHeight;
    final hitHeight = math.max(target, visualHeight), separator = 1 / MediaQuery.devicePixelRatioOf(context);
    final radius = Radius.circular(FrostRadius.forHeight(visualHeight));
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _enabled || widget.embedded ? 1 : _disabledOpacity),
      duration: FrostMotion.duration(context, FrostMotion.hover),
      builder: (context, overallOpacity, _) {
        Widget segment(int direction) {
          final enabled = _canStep(direction), label = direction < 0 ? labels.decrement : labels.increment;
          final start = direction < 0;
          final corners = BorderRadiusDirectional.only(
            topStart: start ? radius : Radius.zero,
            bottomStart: start ? radius : Radius.zero,
            topEnd: start ? Radius.zero : radius,
            bottomEnd: start ? Radius.zero : radius,
          ).resolve(Directionality.of(context));
          final shape = switch (FrostRadius.shape(context, radius.x)) {
            RoundedSuperellipseBorder() => RoundedSuperellipseBorder(borderRadius: corners),
            _ => RoundedRectangleBorder(borderRadius: corners),
          };
          return Semantics(
            label: label,
            button: true,
            enabled: enabled,
            onTap: enabled ? () => _step(direction) : null,
            excludeSemantics: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: enabled || !_enabled && widget.embedded ? 1 : _disabledOpacity),
              duration: FrostMotion.duration(context, FrostMotion.hover),
              builder: (context, sideOpacity, child) => Opacity(opacity: math.min(1, sideOpacity / overallOpacity), child: child),
              child: FrostInputSurface(
                onTap: enabled ? () => _activate(direction) : null,
                onPressedChange: (pressed) => _pressed(direction, pressed),
                builder: (context, states) => SizedBox(
                  width: target,
                  height: hitHeight,
                  child: Center(
                    child: SizedBox(
                      width: target,
                      height: visualHeight,
                      child: FrostClickFeedbackVisual(
                        states: states,
                        shape: shape,
                        child: Center(
                          child: FrostIcon(
                            direction < 0 ? icons.remove : icons.add,
                            size: FrostControlSize.compact.iconSize,
                            color: FrostThemeTokens.of(context).textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final control = Opacity(
          opacity: overallOpacity,
          child: SizedBox(
            width: target * 2 + separator,
            height: hitHeight,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: visualHeight,
                  width: target * 2 + separator,
                  child: FrostControlTrack(height: visualHeight, child: const SizedBox.expand()),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    segment(-1),
                    FrostDivider(axis: Axis.vertical, length: visualHeight),
                    segment(1),
                  ],
                ),
              ],
            ),
          ),
        );
        return widget.semanticLabel == null
            ? control
            : Semantics(
                container: true,
                explicitChildNodes: true,
                label: widget.semanticLabel,
                value: widget.value.toString(),
                increasedValue: _canStep(1) ? _next(1).toString() : null,
                decreasedValue: _canStep(-1) ? _next(-1).toString() : null,
                enabled: _enabled,
                onIncrease: _canStep(1) ? () => _step(1) : null,
                onDecrease: _canStep(-1) ? () => _step(-1) : null,
                child: control,
              );
      },
    );
  }
}
