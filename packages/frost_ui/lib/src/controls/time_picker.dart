import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_field_frame.dart';
import '_field_layout.dart';
import 'form.dart';

// An empty time segment is deliberately independent of localized date strings.
const frostTimeSegmentPlaceholder = '--';
const _timeSegmentDigits = 2;
// TextField defaults to a two-pixel cursor; measurement and painting share it.
const _timeCursorWidth = 2.0;
// Flutter RenderEditable adds its private _kCaretGap to cursorWidth when
// computing editable width. Mirror that gap only, not a combined allowance.
const _frameworkCaretGap = 1.0;

enum _TimePart { hour, minute, period }

/// Edits independent time segments with the host's locale and hour format.
/// Minutes wrap without carrying into the hour; direct input is not step-snapped.
class FrostTimePicker extends StatefulWidget {
  const FrostTimePicker({required this.value, required this.onChanged, required this.label, this.help, this.error, this.minuteStep = 1, this.size, super.key})
    : assert(minuteStep >= 1 && minuteStep <= 59);
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?>? onChanged;
  final String label;
  final String? help, error;
  final int minuteStep;
  final FrostControlSize? size;
  @override
  State<FrostTimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<FrostTimePicker> {
  final _nodes = <_TimePart, FocusNode>{};
  final _controllers = <_TimePart, TextEditingController>{};
  final _scrolls = <_TimePart, ScrollController>{};
  final _processed = <_TimePart, String>{};
  int? _hour, _minute, _period;
  bool _writing = false, _pendingEcho = false;
  TimeOfDay? _lastEmitted;
  TimeOfDayFormat? _format;
  _TimePart _current = _TimePart.hour;
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context);
  bool get _is24 => switch (_format!) {
    TimeOfDayFormat.h_colon_mm_space_a || TimeOfDayFormat.a_space_h_colon_mm => false,
    _ => true,
  };
  List<_TimePart> get _order => switch (_format!) {
    TimeOfDayFormat.a_space_h_colon_mm => [_TimePart.period, _TimePart.hour, _TimePart.minute],
    TimeOfDayFormat.h_colon_mm_space_a => [_TimePart.hour, _TimePart.minute, _TimePart.period],
    _ => [_TimePart.hour, _TimePart.minute],
  };
  TimeOfDay? get _value =>
      _hour == null || _minute == null || (!_is24 && _period == null) ? null : TimeOfDay(hour: _is24 ? _hour! : _hour! % 12 + _period! * 12, minute: _minute!);
  int _minimum(_TimePart part) => part == _TimePart.hour && !_is24 ? 1 : 0;
  int _maximum(_TimePart part) => switch (part) {
    _TimePart.minute => 59,
    _TimePart.period => 1,
    _TimePart.hour => _is24 ? 23 : 12,
  };
  int? _number(_TimePart part) => switch (part) {
    _TimePart.hour => _hour,
    _TimePart.minute => _minute,
    _TimePart.period => _period,
  };
  @override
  void initState() {
    super.initState();
    for (final part in _TimePart.values) {
      _nodes[part] = FocusNode(onKeyEvent: (_, event) => _key(part, event))..addListener(() => _focused(part));
      if (part != _TimePart.period) {
        _controllers[part] = TextEditingController()..addListener(() => _input(part));
        // An editor must never restore the enclosing page's PageStorage offset.
        _scrolls[part] = ScrollController(keepScrollOffset: false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final format = MaterialLocalizations.of(context).timeOfDayFormat(alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    if (_format != format) {
      _format = format;
      _readValue();
      _current = _order.first;
    }
  }

  @override
  void didUpdateWidget(FrostTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final echo = _pendingEcho && widget.value == _lastEmitted;
    _pendingEcho = false;
    if (!echo && widget.value != oldWidget.value) _readValue();
  }

  void _readValue() {
    final value = widget.value;
    _hour = value == null
        ? null
        : _is24
        ? value.hour
        : (value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod);
    _minute = value?.minute;
    _period = value?.period.index;
    _write(_TimePart.hour);
    _write(_TimePart.minute);
  }

  String _formatted(_TimePart part) {
    final number = _number(part);
    if (number == null) return '';
    final localizations = MaterialLocalizations.of(context);
    if (part == _TimePart.minute) return localizations.formatMinute(TimeOfDay(hour: 0, minute: number));
    final physicalHour = _is24 ? number : number % 12 + (_period ?? 0) * 12;
    return localizations.formatHour(TimeOfDay(hour: physicalHour, minute: 0), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  }

  void _write(_TimePart part) {
    _writing = true;
    final text = _formatted(part);
    _processed[part] = text;
    _controllers[part]!.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    _writing = false;
  }

  void _focused(_TimePart part) {
    if (!mounted) return;
    if (_nodes[part]!.hasFocus) {
      _current = part;
      final controller = _controllers[part];
      if (controller != null) controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    }
    if (!_nodes[part]!.hasFocus && part != _TimePart.period && _number(part) != null) _write(part);
    setState(() {});
  }

  void _assign(_TimePart part, int? value) {
    switch (part) {
      case _TimePart.hour:
        _hour = value;
      case _TimePart.minute:
        _minute = value;
      case _TimePart.period:
        _period = value;
    }
  }

  void _emit({bool cleared = false}) {
    if (_value == null && !cleared) return;
    _lastEmitted = _value;
    _pendingEcho = true;
    widget.onChanged?.call(_lastEmitted);
  }

  void _input(_TimePart part) {
    if (_writing || !_enabled) return;
    final editing = _controllers[part]!.value;
    if (editing.isComposingRangeValid && !editing.composing.isCollapsed) return;
    final text = editing.text;
    if (_processed[part] == text) return;
    _processed[part] = text;
    final number = int.tryParse(text);
    final valid = number != null && number >= _minimum(part) && number <= _maximum(part);
    setState(() => _assign(part, valid ? number : null));
    _emit(cleared: text.isEmpty);
    if (valid && (text.length >= _timeSegmentDigits || number * 10 > _maximum(part))) _move(part, 1);
  }

  void _move(_TimePart part, int direction) {
    final order = _order, index = order.indexOf(part) + direction;
    if (index >= 0 && index < order.length) _nodes[order[index]]!.requestFocus();
  }

  int _nextNumber(_TimePart part, int direction) {
    final minimum = _minimum(part), maximum = _maximum(part), old = _number(part);
    final step = part == _TimePart.minute ? widget.minuteStep : 1;
    return old == null ? (direction > 0 ? minimum : maximum) : minimum + (old - minimum + direction * step) % (maximum - minimum + 1);
  }

  String _semanticAfter(int direction) {
    if (_value == null) return '';
    final next = _nextNumber(_current, direction);
    final hour = _current == _TimePart.hour ? next : _hour!;
    final minute = _current == _TimePart.minute ? next : _minute!;
    final period = _current == _TimePart.period ? next : _period ?? 0;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: _is24 ? hour : hour % 12 + period * 12, minute: minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  void _step(_TimePart part, int direction) {
    if (!_enabled) return;
    setState(() => _assign(part, _nextNumber(part, direction)));
    if (part != _TimePart.period) _write(part);
    _emit();
  }

  KeyEventResult _key(_TimePart part, KeyEvent event) {
    if (!_enabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final key = event.logicalKey, rtl = Directionality.of(context) == TextDirection.rtl;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      _step(part, key == LogicalKeyboardKey.arrowUp ? 1 : -1);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _move(part, (key == LogicalKeyboardKey.arrowRight) != rtl ? 1 : -1);
    } else if (key == LogicalKeyboardKey.backspace) {
      setState(() => _assign(part, null));
      if (part != _TimePart.period) _write(part);
      _emit(cleared: true);
    } else if (part == _TimePart.period && (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter)) {
      _step(part, 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    for (final scroll in _scrolls.values) {
      scroll.dispose();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _separator(MaterialLocalizations localizations) {
    const sample = TimeOfDay(hour: 11, minute: 37);
    final always24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final formatted = localizations.formatTimeOfDay(sample, alwaysUse24HourFormat: always24);
    final hour = localizations.formatHour(sample, alwaysUse24HourFormat: always24), minute = localizations.formatMinute(sample);
    final start = formatted.indexOf(hour), end = formatted.indexOf(minute, math.max(0, start + hour.length));
    return start >= 0 && end >= start + hour.length ? formatted.substring(start + hour.length, end).trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? FrostControlScope.sizeOf(context), geometry = frostControlGeometry(context, size);
    final localizations = MaterialLocalizations.of(context), value = _value;
    final focused = _nodes.values.any((node) => node.hasFocus);
    final order = _order, gap = FrostGap.of(context).inline;
    return FrostFormFieldRegistration(
      focusOf: () => _nodes[order.first],
      enabled: _enabled,
      error: widget.error,
      child: Semantics(
        container: true,
        textField: true,
        enabled: _enabled,
        focused: focused,
        label: widget.label,
        hint: widget.error ?? widget.help,
        value: value == null ? '' : localizations.formatTimeOfDay(value, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context)),
        increasedValue: _semanticAfter(1),
        decreasedValue: _semanticAfter(-1),
        onIncrease: _enabled ? () => _step(_current, 1) : null,
        onDecrease: _enabled ? () => _step(_current, -1) : null,
        child: ExcludeSemantics(
          child: FrostFieldLayout(
            label: widget.label,
            help: widget.help,
            error: widget.error,
            enabled: _enabled,
            child: FrostFieldFrame(
              size: size,
              enabled: _enabled,
              focused: focused,
              invalid: widget.error != null,
              multiline: true,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final part in order) ...[
                      if (part == _TimePart.minute)
                        FrostSkeletonText(child: Text(_separator(localizations), style: FrostTypography.of(context).style(FrostTextRole.body))),
                      _segment(part, gap),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(_TimePart part, double inset) {
    final localizations = MaterialLocalizations.of(context), tokens = FrostThemeTokens.of(context), focus = _nodes[part]!.hasFocus;
    final style = FrostTypography.of(context).style(FrostTextRole.body, numeric: true).copyWith(color: focus ? tokens.selectionInk : tokens.textPrimary);
    final samples = part == _TimePart.period
        ? [localizations.anteMeridiemAbbreviation, localizations.postMeridiemAbbreviation, frostTimeSegmentPlaceholder]
        : [localizations.formatDecimal(88), frostTimeSegmentPlaceholder];
    var width = 0.0;
    var height = 0.0;
    for (final sample in samples) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
      painter.dispose();
    }
    return AnimatedContainer(
      key: ValueKey(part.name),
      duration: FrostMotion.duration(context, FrostMotion.hover),
      width: width + inset * 2 + (part == _TimePart.period ? 0 : _timeCursorWidth + _frameworkCaretGap),
      padding: EdgeInsets.symmetric(horizontal: inset),
      decoration: ShapeDecoration(
        shape: FrostRadius.shape(context, FrostRadius.xs),
        color: focus ? tokens.selectionFill : tokens.selectionFill.withValues(alpha: 0),
      ),
      child: TweenAnimationBuilder<TextStyle?>(
        tween: TextStyleTween(end: style),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        builder: (context, animatedStyle, _) => _segmentInput(part, height, animatedStyle!),
      ),
    );
  }

  Widget _segmentInput(_TimePart part, double height, TextStyle style) {
    final localizations = MaterialLocalizations.of(context), tokens = FrostThemeTokens.of(context);
    final text = _period == null
        ? frostTimeSegmentPlaceholder
        : _period == 0
        ? localizations.anteMeridiemAbbreviation
        : localizations.postMeridiemAbbreviation;
    return part == _TimePart.period
        ? Focus(
            focusNode: _nodes[part],
            canRequestFocus: _enabled,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _enabled
                  ? () {
                      _nodes[part]!.requestFocus();
                      _step(part, 1);
                    }
                  : null,
              child: FrostSkeletonText(child: Text(text, style: style)),
            ),
          )
        : SizedBox(
            height: height,
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: _controllers[part],
                scrollController: _scrolls[part],
                focusNode: _nodes[part],
                enabled: _enabled,
                keyboardType: TextInputType.number,
                textInputAction: _isLast(part) ? TextInputAction.done : TextInputAction.next,
                onEditingComplete: () => _move(part, 1),
                style: style,
                // A one-digit hour hugs its separator without inventing a zero.
                // Logical end mirrors the alignment for RTL writing direction.
                textAlign: part == _TimePart.hour ? TextAlign.end : TextAlign.start,
                cursorColor: tokens.selectionInk,
                cursorWidth: _timeCursorWidth,
                // The shared frame owns every border. A collapsed decoration
                // alone still inherits OutlineInputBorder.gapPadding from theme.
                decoration: InputDecoration(
                  isCollapsed: true,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: frostTimeSegmentPlaceholder,
                  hintStyle: style.copyWith(color: tokens.textTertiary),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    if (newValue.composing.isValid && !newValue.composing.isCollapsed) return newValue;
                    final number = int.tryParse(newValue.text);
                    return newValue.text.isEmpty || newValue.text.length <= _timeSegmentDigits && number != null && number <= _maximum(part)
                        ? newValue
                        : oldValue;
                  }),
                ],
              ),
            ),
          );
  }

  bool _isLast(_TimePart part) => _order.last == part;
}
