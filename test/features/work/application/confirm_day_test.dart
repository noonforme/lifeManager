import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;
  late DayPlanService plans;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    plans = fixture.plans;
    await fixture.saveDepot();
  });
  tearDown(() => fixture.dispose());

  test('confirming a planned Day writes one finalized, linked shift', () async {
    final outcome = await plans.confirm(
      employment,
      const LocalDate(2026, 10, 5),
    );
    final shift =
        ((outcome as Committed<ConfirmedDay>).value as ConfirmedShift).shift;
    expect(shift.state, ShiftState.finalized);
    expect(shift.schedule?.plannedDate, const LocalDate(2026, 10, 5));
    expect(shift.schedule?.scheduleVersion, 1);
    final rest = await plans.plan(
      employment,
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 5),
    );
    expect(rest, isEmpty);
  });

  test('removing a confirmed shift returns its day to confirm', () async {
    const date = LocalDate(2026, 10, 5);
    const today = LocalDate(2026, 10, 12);
    final shift =
        ((await plans.confirm(
                  employment,
                  date,
                ) as Committed<ConfirmedDay>).value
                as ConfirmedShift)
            .shift;
    expect(
      (await plans.daysToConfirm(employment, today: today)).map((d) => d.date),
      isNot(contains(date)),
    );

    final removed = await fixture.shifts.commitVoid(
      shift.id,
      expected: shift.revision,
      voidReason: 'Did not work it',
      nowUtc: fixture.clock.value,
    );

    expect(removed, isA<Committed<WorkShift>>());
    expect(
      (await plans.daysToConfirm(employment, today: today)).map((d) => d.date),
      contains(date),
    );
    final again = await plans.plan(employment, date, date);
    expect(again.single, isA<PlannedShift>());
    // The day can be confirmed afresh; the void shift stays in history.
    expect(
      await plans.confirm(employment, date),
      isA<Committed<ConfirmedDay>>(),
    );
    final rows = await fixture.database
        .customSelect(
          'SELECT state FROM work_shifts '
          "WHERE planned_date = '2026-10-05' ORDER BY state",
        )
        .get();
    expect(rows.map((row) => row.read<String>('state')), [
      'finalized',
      'voided',
    ]);
  });

  test('confirming the same day twice reports Stale and writes once', () async {
    final results = await Future.wait([
      plans.confirm(employment, const LocalDate(2026, 10, 5)),
      plans.confirm(employment, const LocalDate(2026, 10, 5)),
    ]);
    expect(results.whereType<Committed<ConfirmedDay>>(), hasLength(1));
    expect(results.whereType<Stale<ConfirmedDay>>(), hasLength(1));
    final rows = await fixture.database
        .customSelect(
          "SELECT COUNT(*) AS n FROM work_shifts WHERE planned_date = '2026-10-05'",
        )
        .getSingle();
    expect(rows.data['n'], 1);
  });

  test('confirming a leave day writes a leave record for 11:30', () async {
    await plans.markLeave(
      employment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final outcome = await plans.confirm(
      employment,
      const LocalDate(2026, 10, 6),
    );
    final leave =
        ((outcome as Committed<ConfirmedDay>).value as ConfirmedLeave).leave;
    expect(leave.paidMinutes, 11 * 60 + 30);
    expect(leave.leaveType, LeaveType.vacation);
  });

  test('a sick day defaults its illness start across Off days', () async {
    // 2026-10-07 Day (sick), 8–10 Off, 11 Night (sick).
    await plans.markLeave(
      employment,
      const LocalDate(2026, 10, 7),
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
    );
    await plans.markLeave(
      employment,
      const LocalDate(2026, 10, 11),
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
    );
    await plans.confirm(employment, const LocalDate(2026, 10, 7));
    final outcome = await plans.confirm(
      employment,
      const LocalDate(2026, 10, 11),
    );
    final leave =
        ((outcome as Committed<ConfirmedDay>).value as ConfirmedLeave).leave;
    expect(leave.illnessStartedOn, const LocalDate(2026, 10, 7));
  });

  test('an Off day cannot be confirmed', () async {
    final outcome = await plans.confirm(
      employment,
      const LocalDate(2026, 10, 8),
    );
    expect((outcome as Invalid<ConfirmedDay>).fields.keys, ['date']);
  });

  test('confirmed vacation is corrected to sick by void and replace', () async {
    await plans.markLeave(
      employment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final first =
        ((await plans.confirm(
                  employment,
                  const LocalDate(2026, 10, 6),
                ) as Committed<ConfirmedDay>).value
                as ConfirmedLeave)
            .leave;

    final blank = await plans.correctLeave(
      first.id,
      expected: first.revision,
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
      reason: ' ',
    );
    expect((blank as Invalid<LeaveRecord>).fields.keys, ['reason']);

    final outcome = await plans.correctLeave(
      first.id,
      expected: first.revision,
      leaveType: LeaveType.sick,
      illnessStartedOn: const LocalDate(2026, 10, 6),
      reason: 'Was ill, not on holiday',
    );
    final replacement = (outcome as Committed<LeaveRecord>).value;
    expect(replacement.leaveType, LeaveType.sick);
    expect(replacement.replacedId, first.id);
    final all = await fixture.repository.leaveFor(employment);
    expect(all.where((item) => item.isEffective).single.id, replacement.id);
    expect(
      all.firstWhere((item) => item.id == first.id).state,
      LeaveState.voided,
    );
  });
}
