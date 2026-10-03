import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/era_dates.dart';

void main() {
  const monday = LocalDate(2026, 10, 5);

  test('the box shows the weekday then the ISO date', () {
    expect(eraBoxDate(monday), 'Mon 2026-10-05');
    expect(eraBoxDate(const LocalDate(2026, 10, 11)), 'Sun 2026-10-11');
  });

  test('a date is announced in words', () {
    expect(spokenDate(monday), 'Monday 5 October 2026');
  });

  test('the calendar title names the month and year', () {
    expect(eraMonthTitle(monday), 'October 2026');
  });

  test('the grid is six Monday-first weeks', () {
    final days = monthGridDays(monday);
    expect(days, hasLength(42));
    expect(days.first, const LocalDate(2026, 9, 28));
    expect(days.first.weekday, 1);
    expect(days.last, const LocalDate(2026, 11, 8));
  });

  test('a month starting on Monday starts the grid on its first', () {
    expect(
      monthGridDays(const LocalDate(2026, 6, 20)).first,
      const LocalDate(2026, 6, 1),
    );
  });
}
