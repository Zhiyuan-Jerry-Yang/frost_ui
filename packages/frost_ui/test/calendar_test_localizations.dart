import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Controlled fixtures, not a substitute for App GlobalMaterialLocalizations.
/// Non-English samples deliberately live only in test/.
class CalendarTestLocalizations extends DefaultMaterialLocalizations {
  const CalendarTestLocalizations(this.locale);
  final Locale locale;
  bool get chinese => locale.languageCode == 'zh';
  @override
  int get firstDayOfWeekIndex => 1;
  @override
  List<String> get narrowWeekdays => chinese ? const ['日', '一', '二', '三', '四', '五', '六'] : super.narrowWeekdays;
  @override
  String formatMonthYear(DateTime date) => chinese ? '${date.year}年${date.month}月' : 'GB ${super.formatMonthYear(date)}';
  @override
  String formatMediumDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  @override
  String formatFullDate(DateTime date) => '${chinese ? '日期' : 'GB date'} ${date.day}/${date.month}/${date.year}';
  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      chinese && !alwaysUse24HourFormat ? TimeOfDayFormat.a_space_h_colon_mm : TimeOfDayFormat.HH_colon_mm;
  @override
  String formatHour(TimeOfDay value, {bool alwaysUse24HourFormat = false}) {
    if (timeOfDayFormat(alwaysUse24HourFormat: alwaysUse24HourFormat) == TimeOfDayFormat.HH_colon_mm) return value.hour.toString().padLeft(2, '0');
    return (value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod).toString();
  }

  @override
  String formatTimeOfDay(TimeOfDay value, {bool alwaysUse24HourFormat = false}) {
    final time = '${formatHour(value, alwaysUse24HourFormat: alwaysUse24HourFormat)}:${formatMinute(value)}';
    return timeOfDayFormat(alwaysUse24HourFormat: alwaysUse24HourFormat) == TimeOfDayFormat.a_space_h_colon_mm
        ? '${value.period == DayPeriod.am ? anteMeridiemAbbreviation : postMeridiemAbbreviation} $time'
        : time;
  }

  @override
  String get anteMeridiemAbbreviation => chinese ? '上午' : super.anteMeridiemAbbreviation;
  @override
  String get postMeridiemAbbreviation => chinese ? '下午' : super.postMeridiemAbbreviation;
}

class CalendarTestDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const CalendarTestDelegate();
  @override
  bool isSupported(Locale locale) => const ['zh', 'en'].contains(locale.languageCode);
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(CalendarTestLocalizations(locale));
  @override
  bool shouldReload(CalendarTestDelegate old) => false;
}
