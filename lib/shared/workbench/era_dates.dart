import '../../core/time/local_date.dart';

/// English month names, January first.
const eraMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The calendar's column heads, Monday first.
const eraWeekdayInitials = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Mon": the weekday a date box shows before the date.
String eraWeekdayShort(LocalDate date) => _weekdayShort[date.weekday - 1];

/// "Mon 2026-10-05": what a date box shows.
String eraBoxDate(LocalDate date) => '${eraWeekdayShort(date)} $date';

/// "Monday 5 October 2026": how a date is announced.
String spokenDate(LocalDate date) =>
    '${_weekdayLong[date.weekday - 1]} ${date.day} '
    '${eraMonthNames[date.month - 1]} ${date.year}';

/// "October 2026": the month calendar's title.
String eraMonthTitle(LocalDate date) =>
    '${eraMonthNames[date.month - 1]} ${date.year}';

/// The 42 days a month calendar shows for [month]'s month: six
/// Monday-first weeks starting on or before the first.
List<LocalDate> monthGridDays(LocalDate month) {
  final first = month.firstOfMonth;
  final start = first.addDays(1 - first.weekday);
  return [for (var index = 0; index < 42; index++) start.addDays(index)];
}
