final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12),
      assert(day >= 1 && day <= 31);

  factory LocalDate.parse(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid local date');
    }
    return parsed;
  }

  static LocalDate? tryParse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      return null;
    }
    return LocalDate(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  /// The date [days] later, or earlier when negative.
  LocalDate addDays(int days) {
    final value = DateTime.utc(year, month, day + days);
    return LocalDate(value.year, value.month, value.day);
  }

  /// Whole days from [other] to this date; negative when this is earlier.
  int daysSince(LocalDate other) => DateTime.utc(
    year,
    month,
    day,
  ).difference(DateTime.utc(other.year, other.month, other.day)).inDays;

  /// 1 for Monday through 7 for Sunday.
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// The first day of this date's month.
  LocalDate get firstOfMonth => LocalDate(year, month, 1);

  /// The first of the month [months] later, or earlier when negative.
  LocalDate addMonths(int months) {
    final value = DateTime.utc(year, month + months, 1);
    return LocalDate(value.year, value.month, 1);
  }

  /// The number of days in this date's month.
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// The last day of this date's month.
  LocalDate get lastOfMonth => LocalDate(year, month, daysInMonth);

  /// The same day [months] later, or earlier when negative, clamped to the
  /// target month's last day: 31 January plus one month is 28 or 29
  /// February.
  LocalDate addMonthsClamped(int months) {
    final target = addMonths(months);
    final last = target.daysInMonth;
    return LocalDate(target.year, target.month, day < last ? day : last);
  }

  @override
  int compareTo(LocalDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) return yearComparison;
    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) return monthComparison;
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
