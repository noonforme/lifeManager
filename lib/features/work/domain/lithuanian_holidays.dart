import '../../../core/time/local_date.dart';

/// Which public-holiday calendar an agreement pays holiday premiums on.
/// Adding a country means adding a value and a function.
enum HolidayCalendar { none, lithuania }

/// Whether [date] is a public holiday in [calendar].
bool isPublicHoliday(HolidayCalendar calendar, LocalDate date) =>
    switch (calendar) {
      HolidayCalendar.none => false,
      HolidayCalendar.lithuania => isLithuanianPublicHoliday(date),
    };

/// Public holidays of the Labour Code of the Republic of Lithuania,
/// Article 123 (in force from 2020-01-01). A holiday covers the whole local
/// date in the shift's timezone.
bool isLithuanianPublicHoliday(LocalDate date) {
  const fixed = {
    (1, 1), // New Year's Day
    (2, 16), // Restoration of the State
    (3, 11), // Restoration of Independence
    (5, 1), // International Workers' Day
    (6, 24), // Rasos and Joninės
    (7, 6), // Statehood Day
    (8, 15), // Assumption (Žolinė)
    (11, 1), // All Saints' Day
    (11, 2), // All Souls' Day
    (12, 24), // Christmas Eve
    (12, 25), // Christmas Day
    (12, 26), // Christmas, second day
  };
  if (fixed.contains((date.month, date.day))) return true;

  final easter = westernEaster(date.year);
  if (date == easter || date == _addDays(easter, 1)) return true;

  // Mother's Day and Father's Day: the first Sundays of May and June.
  return date == _firstSunday(date.year, 5) ||
      date == _firstSunday(date.year, 6);
}

/// Western (Gregorian) Easter Sunday, by the anonymous Gregorian algorithm.
LocalDate westernEaster(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = (h + l - 7 * m + 114) % 31 + 1;
  return LocalDate(year, month, day);
}

LocalDate _firstSunday(int year, int month) {
  final weekday = DateTime.utc(year, month).weekday; // Monday 1 … Sunday 7
  return LocalDate(year, month, 1 + (DateTime.sunday - weekday) % 7);
}

LocalDate _addDays(LocalDate date, int days) {
  final value = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(value.year, value.month, value.day);
}
