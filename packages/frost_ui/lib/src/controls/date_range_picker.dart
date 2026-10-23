import 'package:flutter/material.dart';

import '../foundation/_layout_scope.dart';
import '../foundation/control_scope.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../overlays/_popover_options.dart';
import '../overlays/popover.dart';
import '../overlays/sheet.dart';
import '../primitives/icon.dart';
import '_button_control.dart';
import '_button_types.dart';
import '_calendar.dart';
import '_field_trigger.dart';
import 'form.dart';

// An en dash joins two independently localized medium dates.
const frostDateRangeSeparator = ' – ';

/// An app-owned date range with a local draft until Apply. Cancel never calls
/// onChanged; applying an empty draft explicitly returns null.
class FrostDateRangePicker extends StatefulWidget {
  FrostDateRangePicker({
    required this.value,
    required this.onChanged,
    required this.label,
    this.firstDate,
    this.lastDate,
    this.placeholder,
    this.help,
    this.error,
    this.size,
    super.key,
  }) : assert(!frostFirstDate(firstDate).isAfter(frostLastDate(lastDate)));
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?>? onChanged;
  final String label;
  final DateTime? firstDate, lastDate;
  final String? placeholder, help, error;
  final FrostControlSize? size;
  @override
  State<FrostDateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<FrostDateRangePicker> {
  FocusNode? _focus;
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context);
  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context), value = widget.value;
    final today = FrostDateClock.todayOf(context), dual = FrostSizeClass.of(context) != FrostSizeClass.compact;
    final width = frostCalendarCell(context) * (dual ? 14 : 7) + (dual ? frostCalendarMonthGap : 0) + frostCalendarPopoverInset;
    return FrostFormFieldRegistration(
      focusOf: () => _focus,
      enabled: _enabled,
      error: widget.error,
      child: FrostPopoverDetents(
        detents: const [FrostSheetDetent.fitted],
        child: FrostPopover(
          title: widget.label,
          maxWidth: width,
          builder: (context, focus, toggle) {
            _focus = focus;
            return FrostFieldTrigger(
              label: widget.label,
              value: value == null
                  ? widget.placeholder ?? ''
                  : '${localizations.formatMediumDate(value.start)}$frostDateRangeSeparator${localizations.formatMediumDate(value.end)}',
              onPressed: _enabled ? toggle : null,
              focus: focus,
              size: widget.size,
              help: widget.help,
              error: widget.error,
              trailing: FrostIcon(FrostIconSet.of(context).calendar, size: (widget.size ?? FrostControlScope.sizeOf(context)).iconSize),
            );
          },
          contentBuilder: (context, close) => _RangePanel(
            value: widget.value,
            firstDate: frostFirstDate(widget.firstDate),
            lastDate: frostLastDate(widget.lastDate),
            today: today,
            dual: dual,
            close: close,
            onApply: (range) {
              if (mounted && _enabled) widget.onChanged!(range);
              close();
            },
          ),
        ),
      ),
    );
  }
}

class _RangePanel extends StatefulWidget {
  const _RangePanel({
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.today,
    required this.dual,
    required this.close,
    required this.onApply,
  });
  final DateTimeRange? value;
  final DateTime firstDate, lastDate, today;
  final bool dual;
  final VoidCallback close;
  final ValueChanged<DateTimeRange?> onApply;
  @override
  State<_RangePanel> createState() => _RangePanelState();
}

class _RangePanelState extends State<_RangePanel> {
  DateTime? _start, _end;
  @override
  void initState() {
    super.initState();
    _start = widget.value == null ? null : frostDateOnly(widget.value!.start);
    _end = widget.value == null ? null : frostDateOnly(widget.value!.end);
  }

  bool get _canApply =>
      (_start == null && _end == null) || (_start != null && _end != null && !_start!.isBefore(widget.firstDate) && !_end!.isAfter(widget.lastDate));
  void _select(DateTime date) => setState(() {
    if (_start == null || _end != null || date.isBefore(_start!)) {
      _start = date;
      _end = null;
    } else {
      _end = date;
    }
  });
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context), gap = FrostGap.of(context).related;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrostCalendar(
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          today: widget.today,
          start: _start,
          end: _end,
          range: true,
          dualMonth: widget.dual,
          onSelected: _select,
        ),
        SizedBox(height: gap),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.end,
          children: [
            FrostButtonControl(
              label: labels.clear,
              variant: FrostButtonVariant.plain,
              wrapsLabel: true,
              onPressed: () => setState(() {
                _start = null;
                _end = null;
              }),
            ),
            FrostButtonControl(label: labels.cancel, role: FrostButtonRole.cancel, wrapsLabel: true, onPressed: widget.close),
            FrostButtonControl(
              label: labels.apply,
              variant: FrostButtonVariant.prominent,
              wrapsLabel: true,
              onPressed: _canApply ? () => widget.onApply(_start == null ? null : DateTimeRange(start: _start!, end: _end!)) : null,
            ),
          ],
        ),
      ],
    );
  }
}
