import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  test('days to confirm update live when a day is confirmed', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    await fixture.saveDepot();
    final lengths = <int>[];
    final subscription = fixture.plans
        .watchDaysToConfirm(
          fixtureEmployment,
          today: const LocalDate(2026, 12, 1),
        )
        .listen((days) => lengths.add(days.length));
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // 5 October to 30 November: four 12-day cycles and 9 days more.
    expect(lengths.last, 30);
    await fixture.plans.confirm(
      fixtureEmployment,
      const LocalDate(2026, 10, 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(lengths.last, 29);
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
