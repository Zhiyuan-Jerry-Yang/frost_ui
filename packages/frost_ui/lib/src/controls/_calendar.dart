import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/text.dart';
import '_input_surface.dart';
import 'buttons.dart';

// Calendar geometry: all distances are logical pixels.
const frostCalendarCircleInset = 4.0;
const frostCalendarMonthGap = 24.0;
const frostCalendarHeaderGap = 8.0;
const frostCalendarWeekdayGap = 4.0;
const frostCalendarNumberSpace = 4.0;
// The shared Popover has 16 pixels of inset on each side.
const frostCalendarPopoverInset = 32.0;

DateTime frostDateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime frostFirstDate(DateTime? date) => date == null ? DateTime(1) : frostDateOnly(date);
DateTime frostLastDate(DateTime? date) => date == null ? DateTime(9999, 12, 31) : frostDateOnly(date);
DateTime frostClampDate(DateTime date, DateTime first, DateTime last) => date.isBefore(first)
    ? first
    : date.isAfter(last)
    ? last
    : date;
DateTime frostDateMonth(DateTime date) => DateTime(date.year, date.month);
DateTime frostShiftMonth(DateTime date, int months) {
  final month = DateTime(date.year, date.month + months);
  return DateTime(month.year, month.month, math.min(date.day, DateUtils.getDaysInMonth(month.year, month.month)));
}

/// A clock boundary for deterministic tests; never exported by frost_ui.dart.
class FrostDateClock extends InheritedWidget {
  const FrostDateClock({required this.today, required super.child, super.key});
  final DateTime today;
  static DateTime todayOf(BuildContext context) => frostDateOnly(context.dependOnInheritedWidgetOfExactType<FrostDateClock>()?.today ?? DateTime.now());
  @override
  bool updateShouldNotify(FrostDateClock oldWidget) => today != oldWidget.today;
}

double frostCalendarCell(BuildContext context) => frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.callout).height;

/// The single calendar implementation shared by date and range fields.
class FrostCalendar extends StatefulWidget {
  const FrostCalendar({
    required this.firstDate,
    required this.lastDate,
    required this.today,
    required this.onSelected,
    this.start,
    this.end,
    this.range = false,
    this.dualMonth = false,
    super.key,
  });
  final DateTime firstDate, lastDate, today;
  final DateTime? start, end;
  final ValueChanged<DateTime> onSelected;
  final bool range, dualMonth;
  @override
  State<FrostCalendar> createState() => _CalendarState();
}

class _CalendarState extends State<FrostCalendar> {
  late DateTime _month, _focused;
  DateTime? _hovered;
  final _nodes = <DateTime, FocusNode>{};
  bool _changedMonth = false;
  @override
  void initState() {
    super.initState();
    _focused = frostClampDate(widget.start ?? widget.today, widget.firstDate, widget.lastDate);
    _month = frostDateMonth(_focused);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestFocus(_focused);
    });
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _requestFocus(DateTime day) {
    final node = _nodes[day];
    if (node?.context != null) FocusTraversalPolicy.defaultTraversalRequestFocusCallback(node!);
  }

  FocusNode _node(DateTime day) => _nodes.putIfAbsent(day, () => FocusNode());
  bool _enabled(DateTime day) => !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);
  int _serial(DateTime date) => date.year * 12 + date.month;
  void _showMonth(DateTime month) {
    month = frostDateMonth(frostClampDate(month, frostDateMonth(widget.firstDate), frostDateMonth(widget.lastDate)));
    if (month == _month) return;
    setState(() {
      _month = month;
      _hovered = null;
      _changedMonth = true;
    });
  }

  void _focus(DateTime day, int count) {
    day = frostClampDate(day, widget.firstDate, widget.lastDate);
    _focused = day;
    final changesMonth = _serial(day) < _serial(_month) || _serial(day) >= _serial(_month) + count;
    if (changesMonth) _showMonth(frostDateMonth(day));
    // A retained node may still point at the deactivated previous month.
    // Wait for its new attachment before asking Scrollable to reveal it.
    if (!changesMonth && _nodes[day]?.context != null) {
      _requestFocus(day);
      return;
    }
    final target = day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestFocus(target);
    });
  }

  KeyEventResult _key(KeyEvent event, DateTime day, int count) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final weekOffset = (day.weekday % 7 - firstWeekday + 7) % 7;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => DateTime(day.year, day.month, day.day + (rtl ? 1 : -1)),
      LogicalKeyboardKey.arrowRight => DateTime(day.year, day.month, day.day + (rtl ? -1 : 1)),
      LogicalKeyboardKey.arrowUp => DateTime(day.year, day.month, day.day - 7),
      LogicalKeyboardKey.arrowDown => DateTime(day.year, day.month, day.day + 7),
      LogicalKeyboardKey.pageUp => frostShiftMonth(day, -1),
      LogicalKeyboardKey.pageDown => frostShiftMonth(day, 1),
      LogicalKeyboardKey.home => DateTime(day.year, day.month, day.day - weekOffset),
      LogicalKeyboardKey.end => DateTime(day.year, day.month, day.day + 6 - weekOffset),
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _focus(target, count);
    return KeyEventResult.handled;
  }

  double _minimumCell(BuildContext context) {
    final localizations = MaterialLocalizations.of(context), style = FrostTypography.of(context).style(FrostTextRole.callout, numeric: true);
    var width = 0.0;
    for (var day = 1; day <= 31; day++) {
      final painter = TextPainter(
        text: TextSpan(text: localizations.formatDecimal(day), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width = math.max(width, painter.width);
      painter.dispose();
    }
    return width + frostCalendarNumberSpace;
  }

  // The responsive builder cannot answer intrinsic queries. Publish calendar
  // dimensions from the same month/row geometry without speculative builds.
  double _intrinsicHeight(BuildContext context, double available) {
    final desired = frostCalendarCell(context);
    final two = widget.dualMonth && available >= desired * 14 + frostCalendarMonthGap;
    final count = two ? 2 : 1;
    final cell = two || !available.isFinite ? desired : math.max(_minimumCell(context), math.min(desired, available / 7));
    final localizations = MaterialLocalizations.of(context);
    final months = List.generate(count, (index) => DateTime(_month.year, _month.month + index));
    double textHeight(String text, FrostTextRole role, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: FrostTypography.of(context).style(role)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(0, width));
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final button = math.max(FrostDensity.of(context).targetHeight, FrostControlSize.compact.height(context));
    final header = months.indexed
        .map((entry) {
          final occupied = count == 1 ? button * 2 : button;
          return textHeight(localizations.formatMonthYear(entry.$2), FrostTextRole.headline, cell * 7 - occupied);
        })
        .fold(button, math.max);
    final weekdays = localizations.narrowWeekdays.map((day) => textHeight(day, FrostTextRole.caption, cell)).reduce(math.max);
    final rows = months
        .map((month) => (((month.weekday % 7 - localizations.firstDayOfWeekIndex + 7) % 7 + DateUtils.getDaysInMonth(month.year, month.month)) / 7).ceil())
        .reduce(math.max);
    return header + frostCalendarHeaderGap + weekdays + frostCalendarWeekdayGap + rows * cell;
  }

  @override
  Widget build(BuildContext context) => _CalendarIntrinsic(
    width: frostCalendarCell(context) * (widget.dualMonth ? 14 : 7) + (widget.dualMonth ? frostCalendarMonthGap : 0),
    height: (width) => _intrinsicHeight(context, width),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final desired = frostCalendarCell(context), minimum = _minimumCell(context);
        final available = constraints.maxWidth;
        final two = widget.dualMonth && available >= desired * 14 + frostCalendarMonthGap;
        final count = two ? 2 : 1;
        final cell = two || !available.isFinite ? desired : math.max(minimum, math.min(desired, available / 7));
        final width = cell * 7;
        final months = List.generate(count, (index) => DateTime(_month.year, _month.month + index));
        final localizations = MaterialLocalizations.of(context), labels = FrostScope.labelsOf(context), icons = FrostIconSet.of(context);
        final rowCount = months
            .map((month) => (((month.weekday % 7 - localizations.firstDayOfWeekIndex + 7) % 7 + DateUtils.getDaysInMonth(month.year, month.month)) / 7).ceil())
            .reduce(math.max);
        final contentWidth = width * count + (two ? frostCalendarMonthGap : 0);
        Widget content = SizedBox(
          width: contentWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var index = 0; index < count; index++) ...[
                    if (index > 0) const SizedBox(width: frostCalendarMonthGap),
                    SizedBox(
                      width: width,
                      child: Row(
                        children: [
                          if (index == 0)
                            FrostButton.icon(
                              icon: icons.chevronLeft,
                              label: labels.previous,
                              size: FrostControlSize.compact,
                              onPressed: _month.isAfter(frostDateMonth(widget.firstDate)) ? () => _showMonth(DateTime(_month.year, _month.month - 1)) : null,
                            ),
                          Expanded(
                            child: FrostText(localizations.formatMonthYear(months[index]), role: FrostTextRole.headline, textAlign: TextAlign.center),
                          ),
                          if (index == count - 1)
                            FrostButton.icon(
                              icon: icons.chevronRight,
                              label: labels.next,
                              size: FrostControlSize.compact,
                              onPressed: DateTime(_month.year, _month.month + count).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month + 1))
                                  ? () => _showMonth(DateTime(_month.year, _month.month + 1))
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: frostCalendarHeaderGap),
              FrostLayoutCrossfade(
                layoutIdentity: _serial(_month),
                duration: FrostMotion.standardDuration,
                settleDuration: Duration.zero,
                child: FrostSpringBuilder(
                  value: _serial(_month).toDouble(),
                  spring: FrostMotion.standard,
                  builder: (context, position, child) {
                    final reduced = MediaQuery.disableAnimationsOf(context);
                    return Transform.translate(
                      key: const ValueKey('calendar-month-slide'),
                      offset: Offset(reduced ? 0 : (_serial(_month) - position) * width * (Directionality.of(context) == TextDirection.rtl ? -1 : 1), 0),
                      child: child,
                    );
                  },
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_serial(_month)),
                    tween: Tween(begin: _changedMonth && MediaQuery.disableAnimationsOf(context) ? 0 : 1, end: 1),
                    duration: FrostMotion.reducedFade,
                    builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0; index < count; index++) ...[
                          if (index > 0) const SizedBox(width: frostCalendarMonthGap),
                          _grid(months[index], cell, rowCount, count),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        if (contentWidth > available) content = SingleChildScrollView(scrollDirection: Axis.horizontal, child: content);
        return content;
      },
    ),
  );
  Widget _grid(DateTime month, double cell, int rows, int count) {
    final localizations = MaterialLocalizations.of(context);
    final offset = (month.weekday % 7 - localizations.firstDayOfWeekIndex + 7) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    DateTime? end = widget.end;
    if (widget.range && widget.start != null && end == null && _hovered != null) end = _hovered;
    var start = widget.start;
    if (start != null && end != null && end.isBefore(start)) {
      final swap = start;
      start = end;
      end = swap;
    }
    return SizedBox(
      width: cell * 7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                SizedBox(
                  width: cell,
                  child: FrostText(
                    localizations.narrowWeekdays[(localizations.firstDayOfWeekIndex + column) % 7],
                    role: FrostTextRole.caption,
                    tone: FrostTextTone.tertiary,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          const SizedBox(height: frostCalendarWeekdayGap),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  if (row * 7 + column - offset + 1 case final day when day >= 1 && day <= days)
                    _day(DateTime(month.year, month.month, day), cell, count, start, end)
                  else
                    SizedBox(width: cell, height: cell),
              ],
            ),
        ],
      ),
    );
  }

  Widget _day(DateTime day, double cell, int count, DateTime? start, DateTime? end) {
    final localizations = MaterialLocalizations.of(context), tokens = FrostThemeTokens.of(context), enabled = _enabled(day);
    final selected = enabled && (day == widget.start || day == widget.end);
    final inRange = enabled && widget.range && start != null && end != null && !day.isBefore(start) && !day.isAfter(end);
    final bandStart = day == start, bandEnd = day == end;
    return SizedBox(
      key: ValueKey(day),
      width: cell,
      height: cell,
      child: MouseRegion(
        onEnter: enabled && widget.range ? (_) => setState(() => _hovered = day) : null,
        onExit: enabled && widget.range ? (_) => setState(() => _hovered = null) : null,
        child: Semantics(
          container: true,
          button: true,
          onTap: enabled ? () => widget.onSelected(day) : null,
          enabled: enabled,
          selected: selected || inRange,
          label: localizations.formatFullDate(day),
          hint: day == widget.today ? localizations.currentDateLabel : null,
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.range)
                  PositionedDirectional(
                    start: bandStart ? cell / 2 : 0,
                    end: bandEnd ? cell / 2 : 0,
                    top: frostCalendarCircleInset / 2,
                    bottom: frostCalendarCircleInset / 2,
                    child: AnimatedContainer(
                      key: ValueKey(('range-band', day)),
                      duration: FrostMotion.duration(context, FrostMotion.hover),
                      color: inRange ? tokens.selectionFill : tokens.selectionFill.withValues(alpha: 0),
                    ),
                  ),
                Focus(
                  canRequestFocus: false,
                  onKeyEvent: (_, event) => _key(event, day, count),
                  child: FrostInputSurface(
                    focusNode: _node(day),
                    onTap: enabled ? () => widget.onSelected(day) : null,
                    builder: (context, states) => Center(
                      child: FrostClickFeedbackVisual(
                        states: states,
                        shape: const CircleBorder(),
                        scalesOnPress: false,
                        child: AnimatedContainer(
                          key: ValueKey(('date-circle', day)),
                          duration: FrostMotion.duration(context, FrostMotion.hover),
                          width: cell - frostCalendarCircleInset,
                          height: cell - frostCalendarCircleInset,
                          decoration: ShapeDecoration(
                            shape: const CircleBorder(),
                            color: selected ? tokens.actionFill : tokens.actionFill.withValues(alpha: 0),
                          ),
                          alignment: Alignment.center,
                          child: FrostSkeletonText(
                            child: Text(
                              localizations.formatDecimal(day.day),
                              style: FrostTypography.of(context)
                                  .style(FrostTextRole.callout, numeric: true)
                                  .copyWith(
                                    color: !enabled
                                        ? tokens.textQuaternary
                                        : selected
                                        ? tokens.onAction
                                        : day == widget.today
                                        ? tokens.accentInk
                                        : tokens.textPrimary,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
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

// Only geometry is exposed; the calendar still builds once at real constraints.
class _CalendarIntrinsic extends SingleChildRenderObjectWidget {
  const _CalendarIntrinsic({required this.width, required this.height, required super.child});
  final double width;
  final double Function(double) height;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCalendarIntrinsic(width, height);
  @override
  void updateRenderObject(BuildContext context, _RenderCalendarIntrinsic renderObject) {
    renderObject.width = width;
    renderObject.height = height;
    renderObject.markNeedsLayout();
  }
}

class _RenderCalendarIntrinsic extends RenderProxyBox {
  _RenderCalendarIntrinsic(this.width, this.height);
  double width;
  double Function(double) height;
  @override
  double computeMaxIntrinsicWidth(double height) => width;
  @override
  double computeMinIntrinsicWidth(double height) => width;
  @override
  double computeMaxIntrinsicHeight(double width) => height(width.isFinite ? width : this.width);
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
}
