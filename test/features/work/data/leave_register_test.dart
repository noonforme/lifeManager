import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  test(
    'the register lists confirmed leave and counts past unconfirmed days',
    () async {
      final fixture = await ScheduleFixture.create();
      addTearDown(fixture.dispose);
      await fixture.saveDepot();
      await fixture.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 6),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      await fixture.plans.confirm(
        fixtureEmployment,
        const LocalDate(2026, 10, 6),
      );
      // Today is 2026-10-09 in Vilnius.
      fixture.clock.value = DateTime.utc(2026, 10, 9, 12);
      final work = DriftWorkRepository(fixture.database, clock: fixture.clock);
      final period = PayPeriod.create(
        id: const PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41'),
        employmentId: fixtureEmployment,
        start: const LocalDate(2026, 10, 1),
        end: const LocalDate(2026, 10, 31),
        label: null,
        nowUtc: fixture.clock.value,
      );
      await work.createPeriod(period);

      final register = await work
          .watchRegister(
            WorkScope(
              employmentId: fixtureEmployment,
              temporal: PayPeriodScope(period.id),
            ),
          )
          .first;

      expect(
        register.leaveSheet.single.record.date,
        const LocalDate(2026, 10, 6),
      );
      // No work in July–September: the agreement rate, 11:30 × EUR 18.40.
      expect(register.leaveSheet.single.pay!.amount.minorUnits, 21160);
      expect(register.leaveSheet.single.pay!.usedFallback, isTrue);
      // 5 and 7 October are past Day shifts not yet confirmed; 8 is Off.
      expect(register.plannedNotConfirmed, 2);
    },
  );
}
