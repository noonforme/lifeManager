import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';

void main() {
  late IanaTimezoneService zones;

  setUpAll(() {
    zones = IanaTimezoneService();
  });

  test('fold requires an explicit occurrence', () {
    const date = LocalDate(2026, 10, 25);
    const time = LocalTime(2, 30);

    expect(
      () => zones.resolveLocal(date, time, 'Europe/Berlin'),
      throwsA(isA<AmbiguousLocalTime>()),
    );

    final earlier = zones.resolveLocal(
      date,
      time,
      'Europe/Berlin',
      fold: FoldChoice.earlier,
    );
    final later = zones.resolveLocal(
      date,
      time,
      'Europe/Berlin',
      fold: FoldChoice.later,
    );

    expect(earlier.utc, DateTime.utc(2026, 10, 25, 0, 30));
    expect(later.utc, DateTime.utc(2026, 10, 25, 1, 30));
  });

  test('gap is invalid even when a fold choice is supplied', () {
    expect(
      () => zones.resolveLocal(
        const LocalDate(2026, 3, 29),
        const LocalTime(2, 30),
        'Europe/Berlin',
        fold: FoldChoice.earlier,
      ),
      throwsA(isA<NonexistentLocalTime>()),
    );
  });

  test('UTC conversion determines the correct local date', () {
    expect(
      zones.localDateAt(DateTime.utc(2026, 9, 29, 22, 30), 'Europe/Berlin'),
      const LocalDate(2026, 9, 30),
    );
  });

  test('elapsed UTC duration remains correct across a DST fold', () {
    final start = zones.resolveLocal(
      const LocalDate(2026, 10, 25),
      const LocalTime(1, 30),
      'Europe/Berlin',
      fold: FoldChoice.earlier,
    );
    final end = zones.resolveLocal(
      const LocalDate(2026, 10, 25),
      const LocalTime(3, 30),
      'Europe/Berlin',
      fold: FoldChoice.later,
    );

    expect(end.utc.difference(start.utc), const Duration(hours: 3));
  });

  test('unknown timezone is rejected', () {
    expect(
      () => zones.localDateAt(DateTime.utc(2026), 'Mars/Olympus'),
      throwsA(isA<UnknownTimezone>()),
    );
  });
}
