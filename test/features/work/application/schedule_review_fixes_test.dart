import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/employment_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../../support/schedule_fixture.dart';

/// Regressions for the final branch review of schedules part 1.
void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;

  setUp(() async => fixture = await ScheduleFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'a Changed day whose shift type changed under it needs review',
    () async {
      final saved = await fixture.saveDepot();
      // 2026-11-10 is a Day under version 1.
      final change = await fixture.plans.changeDay(
        employment,
        const LocalDate(2026, 11, 10),
        start: const LocalTime(8, 0),
        end: const LocalTime(19, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
      );
      expect(
        ((change as Committed<DayException>).value as ChangedDay).plannedTypeId,
        const ShiftTypeId('day'),
      );
      await fixture.markUsed(saved);
      // Version 2: Night every day from 1 November.
      final next = await fixture.schedules.update(
        saved.id,
        expected: saved.revision,
        draft: depotDraft(
          from: const LocalDate(2026, 11, 1),
          blocks: const [
            CycleBlock(count: 1, shiftTypeId: ShiftTypeId('night')),
          ],
        ),
        newVersionFrom: const LocalDate(2026, 11, 1),
      );
      expect(next, isA<Committed<WorkSchedule>>(), reason: '$next');

      final day = (await fixture.plans.plan(
        employment,
        const LocalDate(2026, 11, 10),
        const LocalDate(2026, 11, 10),
      )).single;
      expect(day, isA<NeedsReview>());
      expect(
        await fixture.plans.confirm(employment, const LocalDate(2026, 11, 10)),
        isA<Invalid<ConfirmedDay>>(),
      );
    },
  );

  test(
    'an employment with only a schedule is kept, not half-deleted',
    () async {
      await fixture.saveDepot();
      final work = DriftWorkRepository(fixture.database, clock: fixture.clock);
      final current = (await work.employmentById(employment))!;
      final outcome =
          await EmploymentService(
            work,
            idFactory: UuidV7WorkIdFactory(),
            clock: fixture.clock,
          ).deleteEmployment(
            DeleteEmploymentCommand(
              employmentId: employment,
              expectedRevision: current.revision,
            ),
          );
      expect(outcome, isA<Invalid<Employment>>());
    },
  );

  test('an agreement used only by confirmed leave is in use', () async {
    await fixture.saveDepot();
    await fixture.plans.markLeave(
      employment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await fixture.plans.confirm(employment, const LocalDate(2026, 10, 6));
    final agreements = await DriftWorkRepository(fixture.database)
        .agreementsFor(employment);
    expect(agreements.single.usedByFinalizedShift, isTrue);
  });

  test('editing an unused agreement keeps its new leave pay', () async {
    final work = DriftWorkRepository(fixture.database, clock: fixture.clock);
    final current = (await work.agreementsFor(employment)).single;
    final outcome =
        await AgreementService(
          work,
          idFactory: UuidV7WorkIdFactory(),
          clock: fixture.clock,
        ).updateAgreement(
          UpdateAgreementCommand(
            agreementId: current.id,
            employmentId: employment,
            expectedRevision: current.revision,
            terms: AgreementTerms(
              effectiveStart: current.effectiveStart,
              effectiveEnd: null,
              hourlyRateMicroEur: current.hourlyRateMicroEur,
              basis: current.basis,
              label: null,
              note: null,
              sickPay: const RationalMultiplier(numerator: 7, denominator: 10),
              sickEmployerDays: 3,
            ),
          ),
        );
    expect(outcome, isA<Committed<PayAgreement>>());
    final stored = (await work.agreementsFor(employment)).single;
    expect(
      stored.sickPay,
      const RationalMultiplier(numerator: 7, denominator: 10),
    );
    expect(stored.sickEmployerDays, 3);
  });

  test('a future day cannot be confirmed', () async {
    await fixture.saveDepot();
    fixture.clock.value = DateTime.utc(2026, 10, 6, 12); // 6 Oct in Vilnius
    final outcome = await fixture.plans.confirm(
      employment,
      const LocalDate(2026, 10, 7),
    );
    expect((outcome as Invalid<ConfirmedDay>).fields.keys, ['date']);
    // Today itself can be confirmed.
    expect(
      await fixture.plans.confirm(employment, const LocalDate(2026, 10, 6)),
      isA<Committed<ConfirmedDay>>(),
    );
  });
}
