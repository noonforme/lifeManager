import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../support/schedule_fixture.dart';

void main() {
  test('a rotation is confirmed, takes leave and reconciles', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final clock = FixedClock(DateTime.utc(2026, 9, 1, 6));
    final ids = UuidV7WorkIdFactory();
    final work = buildWorkProviders(
      database: database,
      clock: clock,
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Vilnius',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
      scheduleIds: ids,
    );

    // 1. Employment and agreement, EUR 18.40 an hour gross.
    final employment = (await work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic depot', legalLabel: null),
    ) as Committed<Employment>).value.id;
    await work.agreement.createAgreement(
      CreateAgreementCommand(
        employmentId: employment,
        version: 1,
        terms: const AgreementTerms(
          effectiveStart: LocalDate(2026, 9, 1),
          effectiveEnd: null,
          hourlyRateMicroEur: 18400000,
          basis: GrossBasis(),
          label: null,
          note: null,
        ),
      ),
    );

    // 2. 3 Day / 3 Off / 3 Night / 3 Off from 2026-09-01:
    //    Day 1–3, Off 4–6, Night 7–9, Off 10–12 September.
    final draft = depotDraft(from: const LocalDate(2026, 9, 1));
    expect(
      await work.schedules.create(
        ScheduleDraft(
          employmentId: employment,
          name: draft.name,
          timezoneId: draft.timezoneId,
          cycleStart: draft.cycleStart,
          inUseFrom: draft.inUseFrom,
          inUseUntil: null,
          shiftTypes: draft.shiftTypes,
          blocks: draft.blocks,
        ),
      ),
      isA<Committed<WorkSchedule>>(),
    );

    // 3. Vacation on a Day, sick on a Night.
    await work.plans.markLeave(
      employment,
      const LocalDate(2026, 9, 2),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await work.plans.markLeave(
      employment,
      const LocalDate(2026, 9, 8),
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
    );

    // 4. On 13 September, confirm everything up to 12 September.
    clock.value = DateTime.utc(2026, 9, 13, 6);
    final pending = await work.plans.daysToConfirm(
      employment,
      today: const LocalDate(2026, 9, 13),
    );
    expect(pending.map((day) => day.date.day), [1, 2, 3, 7, 8, 9]);
    for (final day in pending) {
      expect(
        await work.plans.confirm(employment, day.date),
        isA<Committed<ConfirmedDay>>(),
      );
    }
    expect(
      await work.plans.daysToConfirm(
        employment,
        today: const LocalDate(2026, 9, 13),
      ),
      isEmpty,
    );

    // 5. September pay period and its payslip.
    final period = (await work.periods.createPeriod(
      CreatePayPeriodCommand(
        employmentId: employment,
        start: const LocalDate(2026, 9, 1),
        end: const LocalDate(2026, 9, 30),
        label: null,
      ),
    ) as Committed<PayPeriod>).value;
    await work.payslips.recordPayslip(
      RecordPayslipCommand(
        periodId: period.id,
        issuedDate: const LocalDate(2026, 10, 5),
        paidDate: null,
        amountMinorUnits: 132732,
        basis: const GrossBasis(),
        grossMinorUnits: 132732,
        netMinorUnits: null,
        deductionMinorUnits: null,
        reference: null,
        note: null,
      ),
    );

    // 6. Expected pay:
    //    Day, 1 and 3 Sep: 11:30 × 18.40                    = 211.60 each
    //    Night, 7 and 9 Sep: 4:00 × 18.40 + 7:30 × 18.40 × 1.5
    //                        (22:00–06:00 less the break)   = 280.60 each
    //    Vacation, 2 Sep: no work June–August, agreement rate
    //                     11:30 × 18.40                     = 211.60
    //    Sick, 8 Sep: illness day 1 (7 Sep was worked), rate fallback
    //                 211.60 × 0.6206 = 131.31896           = 131.32
    //    Total                                              = 1,327.32
    // Today is 13 September: every earlier planned day is confirmed.
    clock.value = DateTime.utc(2026, 9, 13, 6);
    final register = await work.workRepository
        .watchRegister(
          WorkScope(
            employmentId: employment,
            temporal: PayPeriodScope(period.id),
          ),
        )
        .first;
    final group = register.reconciliation!.groups.single;
    expect(group.expected, const Money(minorUnits: 132732));
    expect(group.paid, const Money(minorUnits: 132732));
    expect(register.leaveSheet, hasLength(2));
    expect(register.plannedNotConfirmed, 0);
  });
}
