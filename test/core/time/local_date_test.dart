import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';

void main() {
  test('strict date rejects malformed and impossible input', () {
    expect(LocalDate.tryParse('2026-09-29'), const LocalDate(2026, 9, 29));
    expect(LocalDate.tryParse('29/09/2026'), isNull);
    expect(LocalDate.tryParse('2026-9-29'), isNull);
    expect(LocalDate.tryParse('2026-09-31'), isNull);
    expect(
      () => LocalDate.parse('2026-02-29'),
      throwsA(isA<FormatException>()),
    );
  });

  test('dates compare and render without timezone conversion', () {
    const earlier = LocalDate(2026, 9, 29);
    const later = LocalDate(2026, 9, 30);

    expect(earlier.compareTo(later), lessThan(0));
    expect(earlier.toString(), '2026-09-29');
  });

  test('system clock returns a UTC instant', () {
    expect(SystemAppClock().nowUtc().isUtc, isTrue);
  });
  test('days move across months, years and leap days', () {
    expect(
      const LocalDate(2026, 1, 31).addDays(1),
      const LocalDate(2026, 2, 1),
    );
    expect(
      const LocalDate(2028, 2, 28).addDays(1),
      const LocalDate(2028, 2, 29),
    );
    expect(
      const LocalDate(2026, 1, 1).addDays(-1),
      const LocalDate(2025, 12, 31),
    );
  });

  test('days since counts whole days in either direction', () {
    expect(
      const LocalDate(2026, 10, 5).daysSince(const LocalDate(2026, 10, 1)),
      4,
    );
    expect(
      const LocalDate(2026, 9, 28).daysSince(const LocalDate(2026, 10, 1)),
      -3,
    );
    // Across the October daylight-saving change: still whole days.
    expect(
      const LocalDate(2026, 10, 26).daysSince(const LocalDate(2026, 10, 24)),
      2,
    );
  });

  test('weekday is 1 for Monday and 7 for Sunday', () {
    expect(const LocalDate(2026, 10, 5).weekday, 1);
    expect(const LocalDate(2026, 10, 4).weekday, 7);
  });

  test('months step from the first of a month', () {
    expect(
      const LocalDate(2026, 10, 17).firstOfMonth,
      const LocalDate(2026, 10, 1),
    );
    expect(
      const LocalDate(2026, 1, 1).addMonths(-3),
      const LocalDate(2025, 10, 1),
    );
    expect(
      const LocalDate(2026, 11, 1).addMonths(2),
      const LocalDate(2027, 1, 1),
    );
  });

  test('months clamp to the last day of a shorter month', () {
    expect(
      const LocalDate(2027, 1, 31).addMonthsClamped(1),
      const LocalDate(2027, 2, 28),
    );
    expect(
      const LocalDate(2028, 1, 31).addMonthsClamped(1),
      const LocalDate(2028, 2, 29),
    );
    expect(
      const LocalDate(2026, 10, 5).addMonthsClamped(-12),
      const LocalDate(2025, 10, 5),
    );
    expect(
      const LocalDate(2026, 12, 15).addMonthsClamped(1),
      const LocalDate(2027, 1, 15),
    );
  });

  test('a month knows its length and last day', () {
    expect(const LocalDate(2028, 2, 10).daysInMonth, 29);
    expect(
      const LocalDate(2027, 2, 10).lastOfMonth,
      const LocalDate(2027, 2, 28),
    );
    expect(
      const LocalDate(2026, 10, 5).lastOfMonth,
      const LocalDate(2026, 10, 31),
    );
  });
}
