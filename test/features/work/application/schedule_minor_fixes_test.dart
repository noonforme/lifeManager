import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../../support/schedule_fixture.dart';

/// Regressions for the minor findings of the schedules part 1 review.
void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;

  setUp(() async => fixture = await ScheduleFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'a shift cannot be confirmed on a date that already has leave',
    () async {
      final saved = await fixture.saveDepot();
      await fixture.plans.markLeave(
        employment,
        const LocalDate(2026, 10, 6),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      await fixture.plans.confirm(employment, const LocalDate(2026, 10, 6));
      final outcome = await fixture.markUsed(
        saved,
        date: const LocalDate(2026, 10, 6),
      );
      expect(outcome, isA<Stale<WorkShift>>());
    },
  );

  test('a new version after an ended one does not extend it', () async {
    final saved = (await fixture.schedules.create(
      depotDraft(until: const LocalDate(2026, 10, 31)),
    ) as Committed<WorkSchedule>).value;
    await fixture.markUsed(saved);
    final outcome = await fixture.schedules.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(from: const LocalDate(2026, 12, 1)),
      newVersionFrom: const LocalDate(2026, 12, 1),
    );
    expect(outcome, isA<Committed<WorkSchedule>>());
    final versions = await fixture.repository.schedulesFor(employment);
    expect(
      versions.firstWhere((value) => value.version == 1).inUseUntil,
      const LocalDate(2026, 10, 31),
    );
    expect(
      versions.firstWhere((value) => value.version == 2).inUseFrom,
      const LocalDate(2026, 12, 1),
    );
  });

  test('a new version may not start on or before a confirmed day', () async {
    final saved = await fixture.saveDepot();
    await fixture.markUsed(saved, date: const LocalDate(2026, 10, 7));
    final early = await fixture.schedules.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(from: const LocalDate(2026, 10, 7)),
      newVersionFrom: const LocalDate(2026, 10, 7),
    );
    expect(
      (early as Invalid<WorkSchedule>).fields['newVersionFrom']!.single.code,
      FieldIssueCode.conflict,
    );
    final next = await fixture.schedules.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(from: const LocalDate(2026, 10, 8)),
      newVersionFrom: const LocalDate(2026, 10, 8),
    );
    expect(next, isA<Committed<WorkSchedule>>());
  });

  test('a day change must name a shift type of its schedule', () async {
    await fixture.saveDepot();
    final changed = await fixture.plans.changeDay(
      employment,
      const LocalDate(2026, 10, 5),
      start: const LocalTime(7, 0),
      end: const LocalTime(19, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: const ShiftTypeId('missing'),
    );
    expect((changed as Invalid<DayException>).fields.keys, ['shiftTypeId']);
    final extra = await fixture.plans.addExtra(
      employment,
      const LocalDate(2026, 10, 8),
      start: const LocalTime(8, 0),
      end: const LocalTime(20, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: const ShiftTypeId('missing'),
      countsAsOvertime: false,
    );
    expect((extra as Invalid<DayException>).fields.keys, ['shiftTypeId']);
  });

  test('correcting leave to sick follows the illness run by default', () async {
    await fixture.saveDepot();
    // 7 October Day (sick), 8–10 Off, 11 Night (vacation, later sick).
    await fixture.plans.markLeave(
      employment,
      const LocalDate(2026, 10, 7),
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
    );
    await fixture.plans.markLeave(
      employment,
      const LocalDate(2026, 10, 11),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await fixture.plans.confirm(employment, const LocalDate(2026, 10, 7));
    final vacation =
        ((await fixture.plans.confirm(
                  employment,
                  const LocalDate(2026, 10, 11),
                ) as Committed<ConfirmedDay>).value
                as ConfirmedLeave)
            .leave;
    final outcome = await fixture.plans.correctLeave(
      vacation.id,
      expected: vacation.revision,
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
      reason: 'Was ill',
    );
    expect(
      (outcome as Committed<LeaveRecord>).value.illnessStartedOn,
      const LocalDate(2026, 10, 7),
    );
  });

  test(
    'a shift lost in a daylight-saving gap is refused, not thrown',
    () async {
      // 28 March 2027: 03:00 → 04:00 in Vilnius; 03:00–03:30 does not exist.
      await fixture.schedules.create(
        const ScheduleDraft(
          employmentId: fixtureEmployment,
          name: 'Gap',
          timezoneId: 'Europe/Vilnius',
          cycleStart: LocalDate(2027, 3, 28),
          inUseFrom: LocalDate(2027, 3, 28),
          inUseUntil: LocalDate(2027, 3, 28),
          shiftTypes: [
            ShiftType(
              id: ShiftTypeId('gap'),
              name: 'Gap',
              start: LocalTime(3, 0),
              end: LocalTime(3, 30),
              endDayOffset: 0,
            ),
          ],
          blocks: [CycleBlock(count: 1, shiftTypeId: ShiftTypeId('gap'))],
        ),
      );
      fixture.clock.value = DateTime.utc(2027, 4, 1);
      final outcome = await fixture.plans.confirm(
        employment,
        const LocalDate(2027, 3, 28),
      );
      expect((outcome as Invalid<ConfirmedDay>).fields.keys, ['date']);
    },
  );
}
