import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;
  late DayPlanService plans;
  late WorkSchedule saved;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    plans = fixture.plans;
    saved = await fixture.saveDepot();
  });
  tearDown(() => fixture.dispose());

  test('the plan lists the rotation from the stored schedule', () async {
    final days = await plans.plan(
      employment,
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 12),
    );
    expect(days.map((day) => day.runtimeType), [
      PlannedShift,
      PlannedShift,
      PlannedShift,
      OffDay,
      OffDay,
      OffDay,
      PlannedShift,
      PlannedShift,
    ]);
  });

  test('a confirmed date leaves the plan', () async {
    await fixture.markUsed(saved);
    final days = await plans.plan(
      employment,
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 6),
    );
    expect(days.map((day) => day.date), [const LocalDate(2026, 10, 6)]);
  });

  test('an exception on a confirmed date is refused', () async {
    await fixture.markUsed(saved);
    final outcome = await plans.cancelDay(
      employment,
      const LocalDate(2026, 10, 5),
      reason: CancelReason.other,
      note: null,
    );
    expect(
      (outcome as Invalid<DayException>).fields['date']!.single.code,
      FieldIssueCode.conflict,
    );
  });

  test('cancelling an Off day is refused on date', () async {
    final outcome = await plans.cancelDay(
      employment,
      const LocalDate(2026, 10, 8),
      reason: CancelReason.dayOff,
      note: null,
    );
    expect((outcome as Invalid<DayException>).fields.keys, ['date']);
  });

  test('an extra shift on an Off day is planned as extra', () async {
    await plans.addExtra(
      employment,
      const LocalDate(2026, 10, 8),
      start: const LocalTime(8, 0),
      end: const LocalTime(20, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: null,
      countsAsOvertime: false,
    );
    final day = (await plans.plan(
      employment,
      const LocalDate(2026, 10, 8),
      const LocalDate(2026, 10, 8),
    )).single;
    expect((day as PlannedShift).isExtra, isTrue);
  });

  test(
    'an extra shift whose break runs past its end is refused on breaks',
    () async {
      final outcome = await plans.addExtra(
        employment,
        const LocalDate(2026, 10, 8),
        start: const LocalTime(8, 0),
        end: const LocalTime(12, 0),
        endDayOffset: 0,
        breaks: const [
          FixedBreak(start: LocalTime(11, 50), dayOffset: 0, minutes: 30),
        ],
        shiftTypeId: null,
        countsAsOvertime: false,
      );
      expect((outcome as Invalid<DayException>).fields.keys, ['breaks']);
    },
  );

  test('a second exception on a date without its revision is Stale', () async {
    await plans.cancelDay(
      employment,
      const LocalDate(2026, 10, 5),
      reason: CancelReason.swapped,
      note: null,
    );
    final again = await plans.cancelDay(
      employment,
      const LocalDate(2026, 10, 5),
      reason: CancelReason.other,
      note: null,
    );
    expect(again, isA<Stale<DayException>>());
  });

  test('days to confirm are the past planned shifts and leave', () async {
    final pending = await plans.daysToConfirm(
      employment,
      today: const LocalDate(2026, 10, 10),
    );
    // 5, 6, 7 Day; 8–9 Off.
    expect(pending.map((day) => day.date), [
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 6),
      const LocalDate(2026, 10, 7),
    ]);
  });

  test('a day no pay agreement covers is not a day to confirm', () async {
    // The depot rotation from 24 August; the agreement pays from
    // 1 September. 24–26 August Day, 27–29 Off, 30–31 Night.
    await fixture.dispose();
    fixture = await ScheduleFixture.create();
    plans = fixture.plans;
    await fixture.saveDepot(from: const LocalDate(2026, 8, 24));
    final pending = await plans.daysToConfirm(
      employment,
      today: const LocalDate(2026, 9, 3),
    );
    // 1 September Night; 2 September Off.
    expect(pending.map((day) => day.date), [const LocalDate(2026, 9, 1)]);
    // Both lists come from one plan, so a day is in exactly one of them.
    final past = await plans.pastDays(
      employment,
      today: const LocalDate(2026, 9, 3),
    );
    expect(past.toConfirm.map((day) => day.date), [
      const LocalDate(2026, 9, 1),
    ]);
    expect(past.withoutAgreement.map((day) => day.date), [
      const LocalDate(2026, 8, 24),
      const LocalDate(2026, 8, 25),
      const LocalDate(2026, 8, 26),
      const LocalDate(2026, 8, 30),
      const LocalDate(2026, 8, 31),
    ]);
    // Confirm refuses them on the agreement, as before.
    expect(
      await plans.confirm(employment, const LocalDate(2026, 8, 24)),
      isA<Invalid<ConfirmedDay>>().having(
        (value) => value.fields.keys,
        'fields',
        ['agreement'],
      ),
    );
  });

  test(
    'a new version flags a Changed day that is now Off as needing review',
    () async {
      // 2026-11-10 is cycle day 1 (Day) under version 1.
      final changed = await plans.changeDay(
        employment,
        const LocalDate(2026, 11, 10),
        start: const LocalTime(7, 0),
        end: const LocalTime(20, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
      );
      expect(changed, isA<Committed<DayException>>());
      // A confirmed day makes version 1 used, so the edit starts version 2,
      // which is Off every day from 2026-11-01.
      await fixture.markUsed(saved);
      final next = await fixture.schedules.update(
        saved.id,
        expected: saved.revision,
        draft: depotDraft(onlyOff: true, from: const LocalDate(2026, 11, 1)),
        newVersionFrom: const LocalDate(2026, 11, 1),
      );
      expect(next, isA<Committed<WorkSchedule>>());
      final day = (await plans.plan(
        employment,
        const LocalDate(2026, 11, 10),
        const LocalDate(2026, 11, 10),
      )).single;
      expect(day, isA<NeedsReview>());
      expect((day as NeedsReview).underlying, isA<OffDay>());
    },
  );
}
