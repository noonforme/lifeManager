import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  test('days to confirm update live when a day is confirmed', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    await fixture.saveDepot();

    // Get the first value from the stream
    final firstValue = await fixture.plans
        .watchDaysToConfirm(
          fixtureEmployment,
          today: const LocalDate(2026, 12, 1),
        )
        .first;
    // 5 October to 30 November: four 12-day cycles and 9 days more.
    expect(firstValue.length, 30);

    await fixture.plans.confirm(
      fixtureEmployment,
      const LocalDate(2026, 10, 5),
    );

    // Get the second value after confirming
    final secondValue = await fixture.plans
        .watchDaysToConfirm(
          fixtureEmployment,
          today: const LocalDate(2026, 12, 1),
        )
        .first;
    expect(secondValue.length, 29);
  });

  test('schedules are watched per employment', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    final first = fixture.schedules.watch(fixtureEmployment).first;
    expect(await first, isEmpty);
    await fixture.saveDepot();
    expect(
      (await fixture.schedules.watch(fixtureEmployment).first).single.name,
      'Depot rotation',
    );
  });
}
