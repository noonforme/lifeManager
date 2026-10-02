import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';

void main() {
  final clock = ZoneWallClock(IanaTimezoneService(), 'Europe/Vilnius');

  test('reads the local date and minute of the day', () {
    final local = clock.toLocal(DateTime.utc(2026, 9, 29, 21, 30, 59));
    expect(local.date, LocalDate.parse('2026-09-30'));
    expect(local.minuteOfDay, 30);
  });

  test('an ordinary local time has one instant', () {
    expect(clock.toInstants(LocalDate.parse('2026-09-30'), 22 * 60), [
      DateTime.utc(2026, 9, 30, 19),
    ]);
  });

  test('a time in the autumn overlap has both instants', () {
    expect(clock.toInstants(LocalDate.parse('2026-10-25'), 3 * 60 + 30), [
      DateTime.utc(2026, 10, 25, 0, 30),
      DateTime.utc(2026, 10, 25, 1, 30),
    ]);
  });

  test('a time in the spring gap resolves to the first valid instant', () {
    expect(clock.toInstants(LocalDate.parse('2026-03-29'), 3 * 60 + 30), [
      DateTime.utc(2026, 3, 29, 1),
    ]);
  });
}
