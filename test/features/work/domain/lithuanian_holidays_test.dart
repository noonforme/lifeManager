import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/lithuanian_holidays.dart';

void main() {
  test('every 2026 public holiday from the Labour Code is recognised', () {
    const holidays2026 = [
      '2026-01-01', // New Year's Day
      '2026-02-16', // Restoration of the State
      '2026-03-11', // Restoration of Independence
      '2026-04-05', // Easter Sunday
      '2026-04-06', // Easter Monday
      '2026-05-01', // International Workers' Day
      '2026-05-03', // Mother's Day, first Sunday of May
      '2026-06-07', // Father's Day, first Sunday of June
      '2026-06-24', // Rasos and Joninės
      '2026-07-06', // Statehood Day
      '2026-08-15', // Assumption
      '2026-11-01', // All Saints' Day
      '2026-11-02', // All Souls' Day
      '2026-12-24', // Christmas Eve
      '2026-12-25', // Christmas Day
      '2026-12-26', // Christmas, second day
    ];
    for (final date in holidays2026) {
      expect(
        isLithuanianPublicHoliday(LocalDate.parse(date)),
        isTrue,
        reason: date,
      );
    }
  });

  test('ordinary days are not holidays', () {
    for (final date in [
      '2026-01-02',
      '2026-04-07',
      '2026-05-10',
      '2026-06-14',
      '2026-11-03',
      '2026-12-27',
    ]) {
      expect(
        isLithuanianPublicHoliday(LocalDate.parse(date)),
        isFalse,
        reason: date,
      );
    }
  });

  test('Western Easter matches the published dates for 2024 to 2030', () {
    const easter = {
      2024: '2024-03-31',
      2025: '2025-04-20',
      2026: '2026-04-05',
      2027: '2027-03-28',
      2028: '2028-04-16',
      2029: '2029-04-01',
      2030: '2030-04-21',
    };
    for (final MapEntry(key: year, value: date) in easter.entries) {
      expect(westernEaster(year), LocalDate.parse(date), reason: '$year');
      expect(isLithuanianPublicHoliday(LocalDate.parse(date)), isTrue);
    }
  });

  test('Mother\'s and Father\'s Day follow the first Sundays', () {
    // 2027: 1 May is a Saturday, so Mother's Day is 2 May.
    expect(isLithuanianPublicHoliday(LocalDate.parse('2027-05-02')), isTrue);
    expect(isLithuanianPublicHoliday(LocalDate.parse('2027-05-09')), isFalse);
    // 2027: 6 June is the first Sunday of June.
    expect(isLithuanianPublicHoliday(LocalDate.parse('2027-06-06')), isTrue);
  });

  test('the calendar choice decides', () {
    final christmas = LocalDate.parse('2026-12-25');
    expect(isPublicHoliday(HolidayCalendar.lithuania, christmas), isTrue);
    expect(isPublicHoliday(HolidayCalendar.none, christmas), isFalse);
  });
}
