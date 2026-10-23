import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/text.dart';
import '_field_options.dart';
import '_number_math.dart';
import 'form.dart';
import 'stepper.dart';
import 'text_field.dart';

// Invalid commits remain visible briefly before clamping or restoring the value.
const _invalidCommitDelay = Duration(milliseconds: 350);

/// Numeric editing uses a dot decimal separator. Editing text is preserved until
/// commit; step snapping starts at min, then precision rounds, then bounds clamp.
class FrostNumberField extends StatefulWidget {
  const FrostNumberField({
    required this.value,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.unit,
    this.label,
    this.help,
    this.error,
    required this.onChanged,
    this.size,
    this.decimals = 0,
    super.key,
  }) : assert(min > double.negativeInfinity && max < double.infinity && max >= min),
       assert(step > 0 && step < double.infinity),
       assert(value > double.negativeInfinity && value < double.infinity),
       assert(decimals >= 0 && decimals <= 20);
  final num value, min, max, step;
  final String? unit, label, help, error;
  final ValueChanged<num>? onChanged;
  final FrostControlSize? size;
  final int decimals;
  @override
  State<FrostNumberField> createState() => _NumberFieldState();
}

class _NumberStepIntent extends Intent {
  const _NumberStepIntent(this.direction);
  final int direction;
}

class _NumberFieldState extends State<FrostNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late String _lastText;
  Timer? _invalidTimer;
  Completer<bool>? _preparing;
  bool _invalid = false, _commitAfterComposing = false, _writing = false;
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context);
  bool get _composing => _controller.value.isComposingRangeValid && !_controller.value.composing.isCollapsed;

  @override
  void initState() {
    super.initState();
    _lastText = _format(widget.value);
    _controller = TextEditingController(text: _lastText)..addListener(_editingChanged);
    _focus = FocusNode()..addListener(_focusChanged);
  }

  String _format(num value) {
    final fixed = value.toStringAsFixed(widget.decimals);
    // Bounds take precedence over precision. Never print a different number
    // when a caller supplies a bound that is not aligned to decimal precision.
    return num.tryParse(fixed) == value ? fixed : value.toString();
  }

  num _normalized(num value) => frostNormalizeNumber(value, min: widget.min, max: widget.max, step: widget.step, decimals: widget.decimals);

  void _write(num value) {
    final text = _format(value);
    _lastText = text;
    _writing = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _writing = false;
  }

  void _editingChanged() {
    if (_writing) return;
    // Selection/composing updates alone must not cancel a committed correction.
    // New text does cancel it rather than overwriting the user's newer input.
    if (_lastText != _controller.text) {
      _lastText = _controller.text;
      _invalidTimer?.cancel();
      _invalidTimer = null;
      if (_invalid) setState(() => _invalid = false);
    }
    if (_preparing != null && !_composing) {
      final completion = _preparing!;
      _preparing = null;
      _commitImmediately();
      completion.complete(true);
    }
    if (_commitAfterComposing && !_composing) {
      _commitAfterComposing = false;
      _commit();
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _commit();
  }

  void _apply(num value) {
    _invalidTimer?.cancel();
    _invalidTimer = null;
    _write(value);
    if (_invalid) setState(() => _invalid = false);
    if (_enabled && value != widget.value) widget.onChanged!(value);
  }

  void _commit() {
    if (!_enabled) return;
    if (_composing) {
      _commitAfterComposing = true;
      return;
    }
    final parsed = num.tryParse(_controller.text.trim());
    _invalidTimer?.cancel();
    if (parsed == null || !parsed.isFinite || parsed < widget.min || parsed > widget.max) {
      setState(() => _invalid = true);
      _invalidTimer = Timer(_invalidCommitDelay, () {
        if (!mounted || !_enabled) return;
        _apply(parsed == null || !parsed.isFinite ? widget.value : _normalized(parsed));
      });
    } else {
      _apply(_normalized(parsed));
    }
  }

  void _commitImmediately() {
    _commitAfterComposing = false;
    final parsed = num.tryParse(_controller.text.trim());
    _apply(parsed == null || !parsed.isFinite ? widget.value : _normalized(parsed));
  }

  Future<bool> _prepareForSubmit() {
    if (!_enabled) return Future<bool>.value(true);
    _invalidTimer?.cancel();
    _invalidTimer = null;
    if (_composing) return (_preparing ??= Completer<bool>()).future;
    _commitImmediately();
    return Future<bool>.value(true);
  }

  void _cancelPreparation(bool accepted) {
    final completion = _preparing;
    _preparing = null;
    completion?.complete(accepted);
  }

  void _step(int direction) {
    if (!_enabled || _composing) return;
    final parsed = num.tryParse(_controller.text.trim());
    final base = parsed != null && parsed.isFinite ? parsed : widget.value;
    _apply(_normalized(frostStepNumber(base, widget.step, direction)));
  }

  @override
  void didUpdateWidget(FrostNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null) {
      _cancelPreparation(true);
      _invalidTimer?.cancel();
      _invalidTimer = null;
      _invalid = false;
      _commitAfterComposing = false;
      _write(widget.value);
    } else if (oldWidget.value != widget.value ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.step != widget.step ||
        oldWidget.decimals != widget.decimals) {
      _invalidTimer?.cancel();
      _invalidTimer = null;
      _invalid = false;
      _commitAfterComposing = false;
      if (!_focus.hasFocus) _write(widget.value);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      _cancelPreparation(true);
      _invalidTimer?.cancel();
      _invalidTimer = null;
      _invalid = false;
      _commitAfterComposing = false;
    }
  }

  @override
  void deactivate() {
    _cancelPreparation(false);
    _invalidTimer?.cancel();
    _invalidTimer = null;
    _invalid = false;
    _commitAfterComposing = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _cancelPreparation(false);
    _invalidTimer?.cancel();
    _controller.removeListener(_editingChanged);
    _controller.dispose();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostFieldOptions(
    invalid: _invalid,
    numeric: true,
    beforeSubmit: _prepareForSubmit,
    child: Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowUp): _NumberStepIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _NumberStepIntent(-1),
      },
      child: Actions(
        actions: {
          _NumberStepIntent: CallbackAction<_NumberStepIntent>(
            onInvoke: (intent) {
              _step(intent.direction);
              return null;
            },
          ),
        },
        child: FrostTextField(
          controller: _controller,
          focusNode: _focus,
          size: widget.size,
          label: widget.label,
          help: widget.help,
          error: widget.error,
          enabled: _enabled,
          keyboardType: TextInputType.numberWithOptions(signed: widget.min < 0, decimal: widget.decimals > 0 || widget.step % 1 != 0),
          textInputAction: FrostFormScope.maybeOf(context) == null ? TextInputAction.done : null,
          onEditingComplete: _commit,
          onTapOutside: (_) => _focus.unfocus(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.unit case final unit?) ...[
                DefaultTextStyle(
                  style: TextStyle(color: FrostThemeTokens.of(context).textSecondary),
                  child: FrostText(unit, role: FrostTextRole.subheadline, numeric: true),
                ),
                const SizedBox(width: FrostGap.related),
              ],
              FrostStepperControl(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                step: widget.step,
                onChanged: _enabled ? _apply : null,
                embedded: true,
                decimals: widget.decimals,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
