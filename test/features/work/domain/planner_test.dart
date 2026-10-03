import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../../support/zone_clocks.dart';

void main() {
  const employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
  DateTime vilnius(int y, int m, int d, int h, [int min = 0]) =>
      // Summer time (UTC+3) until 25 October 2026, then UTC+2.
      DateTime.utc(y, m, d, h, min).subtract(
        Duration(
          hours: DateTime.utc(y, m, d).isBefore(DateTime.utc(2026, 10, 25))
              ? 3
              : 2,
        ),
      );

  List<PlannedDay> plan(
    LocalDate from,
    LocalDate to, {
    List<WorkSchedule>? schedules,
    List<DayException> exceptions = const [],
    Set<LocalDate> confirmed = const {},
  }) => planDays(
    from: from,
    to: to,
    schedules: schedules ?? [rotation()],
    exceptions: exceptions,
    confirmedDates: confirmed,
    zoneClocks: testZoneClocks,
  );

  test('the rotation plans Day and Night shifts on the wall clock', () {
    final days = plan(
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 16),
    );
    expect(days, hasLength(12));
    final first = days.first as PlannedShift;
    expect(first.type?.name, 'Day');
    expect(first.startUtc, vilnius(2026, 10, 5, 7));
    expect(first.endUtc, vilnius(2026, 10, 5, 19));
    expect(first.paidSeconds, (11 * 60 + 30) * 60);
    expect(days[3], isA<OffDay>());
    final night = days[6] as PlannedShift;
    expect(night.type?.name, 'Night');
    expect(night.endUtc, vilnius(2026, 10, 12, 7));
    expect(night.breaks.single.start, vilnius(2026, 10, 12, 0));
  });

  test('the night the clocks go back is planned once with its extra hour', () {
    // Start the cycle so day 7 (Night) is 2026-10-24; that night ends on
    // 2026-10-25, after the change at 04:00 → 03:00.
    final shifted = rotation();
    final cycleStart = const LocalDate(2026, 10, 24).addDays(-6);
    final adjusted = WorkSchedule(
      id: shifted.id,
      employmentId: shifted.employmentId,
      name: shifted.name,
      timezoneId: shifted.timezoneId,
      version: 1,
      cycleStart: cycleStart,
      inUseFrom: const LocalDate(2026, 10, 1),
      inUseUntil: null,
      shiftTypes: shifted.shiftTypes,
      blocks: shifted.blocks,
      createdAtUtc: shifted.createdAtUtc,
      revision: shifted.revision,
    );
    final night =
        plan(
              const LocalDate(2026, 10, 24),
              const LocalDate(2026, 10, 24),
              schedules: [adjusted],
            ).single
            as PlannedShift;
    expect(night.startUtc, DateTime.utc(2026, 10, 24, 16)); // 19:00 +03
    expect(night.endUtc, DateTime.utc(2026, 10, 25, 5)); // 07:00 +02
    expect(night.endUtc.difference(night.startUtc), const Duration(hours: 13));
    // 13 h minus the 30-minute break, counted once.
    expect(night.paidSeconds, (12 * 60 + 30) * 60);
  });

  test('a start inside the spring gap moves to the first valid instant', () {
    // 2026-03-29: 03:00 → 04:00 in Europe/Vilnius.
    final base = rotation();
    final early = WorkSchedule(
      id: base.id,
      employmentId: base.employmentId,
      name: base.name,
      timezoneId: base.timezoneId,
      version: 1,
      cycleStart: const LocalDate(2026, 3, 29),
      inUseFrom: const LocalDate(2026, 3, 1),
      inUseUntil: null,
      shiftTypes: const [
        ShiftType(
          id: ShiftTypeId('early'),
          name: 'Early',
          start: LocalTime(3, 30),
          end: LocalTime(15, 30),
          endDayOffset: 0,
        ),
      ],
      blocks: const [CycleBlock(count: 1, shiftTypeId: ShiftTypeId('early'))],
      createdAtUtc: base.createdAtUtc,
      revision: base.revision,
    );
    final shift =
        plan(
              const LocalDate(2026, 3, 29),
              const LocalDate(2026, 3, 29),
              schedules: [early],
            ).single
            as PlannedShift;
    expect(shift.startUtc, DateTime.utc(2026, 3, 29, 1)); // 04:00 +03
    expect(shift.endUtc, DateTime.utc(2026, 3, 29, 12, 30)); // 15:30 +03
  });

  test('a Changed day with another type takes that type\'s window', () {
    final now = DateTime.utc(2026, 10, 1);
    final day =
        plan(
              const LocalDate(2026, 10, 5),
              const LocalDate(2026, 10, 5),
              exceptions: [
                ChangedDay(
                  id: const DayExceptionId(
                    '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e06',
                  ),
                  employmentId: employment,
                  date: const LocalDate(2026, 10, 5),
                  start: const LocalTime(18, 0),
                  end: const LocalTime(7, 0),
                  endDayOffset: 1,
                  breaks: const [],
                  shiftTypeId: const ShiftTypeId('night'),
                  createdAtUtc: now,
                  updatedAtUtc: now,
                  revision: const Revision(0),
                ),
              ],
            ).single
            as PlannedShift;
    expect(day.type?.name, 'Night');
    expect(day.startUtc, vilnius(2026, 10, 5, 18));
    // Night's 19:00–07:00, so 18:00–19:00 becomes overtime once confirmed.
    expect(day.overtimeWindow!.start, vilnius(2026, 10, 5, 19));
    expect(day.overtimeWindow!.end, vilnius(2026, 10, 6, 7));
  });

  test('confirmed dates and dates without a schedule are left out', () {
    final days = plan(
      const LocalDate(2026, 10, 3),
      const LocalDate(2026, 10, 6),
      schedules: [rotation(from: const LocalDate(2026, 10, 5))],
      confirmed: {const LocalDate(2026, 10, 6)},
    );
    expect(days.map((day) => day.date), [const LocalDate(2026, 10, 5)]);
  });

  test('each exception kind changes only its own date', () {
    final now = DateTime.utc(2026, 10, 1);
    final days = plan(
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 8),
      exceptions: [
        ChangedDay(
          id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e01'),
          employmentId: employment,
          date: const LocalDate(2026, 10, 5),
          start: const LocalTime(7, 0),
          end: const LocalTime(20, 0),
          endDayOffset: 0,
          breaks: const [
            FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30),
          ],
          shiftTypeId: null,
          createdAtUtc: now,
          updatedAtUtc: now,
          revision: const Revision(0),
        ),
        CancelledDay(
          id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e02'),
          employmentId: employment,
          date: const LocalDate(2026, 10, 6),
          reason: CancelReason.swapped,
          note: null,
          createdAtUtc: now,
          updatedAtUtc: now,
          revision: const Revision(0),
        ),
        LeaveDay(
          id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e03'),
          employmentId: employment,
          date: const LocalDate(2026, 10, 7),
          leaveType: LeaveType.vacation,
          illnessStartedOn: null,
          createdAtUtc: now,
          updatedAtUtc: now,
          revision: const Revision(0),
        ),
        ExtraDay(
          id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e04'),
          employmentId: employment,
          date: const LocalDate(2026, 10, 8),
          start: const LocalTime(8, 0),
          end: const LocalTime(20, 0),
          endDayOffset: 0,
          breaks: const [],
          shiftTypeId: null,
          countsAsOvertime: true,
          createdAtUtc: now,
          updatedAtUtc: now,
          revision: const Revision(0),
        ),
      ],
    );
    final changed = days[0] as PlannedShift;
    expect(changed.changed, isTrue);
    expect(changed.endUtc, vilnius(2026, 10, 5, 20));
    // The window stays the original Day type's 07:00–19:00.
    expect(changed.overtimeWindow!.end, vilnius(2026, 10, 5, 19));
    final cancelled = days[1] as CancelledPlan;
    expect(cancelled.reason, CancelReason.swapped);
    final leave = days[2] as PlannedLeave;
    expect(leave.paidMinutes, 11 * 60 + 30);
    // 2026-10-08 is cycle day 4 (Off), so the extra shift stands.
    final extra = days[3] as PlannedShift;
    expect(extra.isExtra, isTrue);
    expect(extra.countsAsOvertime, isTrue);
    expect(extra.overtimeWindow, isNull);
  });

  test('an exception that no longer fits its date needs review', () {
    final now = DateTime.utc(2026, 10, 1);
    final days = plan(
      const LocalDate(2026, 10, 8),
      const LocalDate(2026, 10, 8),
      exceptions: [
        CancelledDay(
          id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e05'),
          employmentId: employment,
          // An Off day: there is nothing to cancel.
          date: const LocalDate(2026, 10, 8),
          reason: CancelReason.dayOff,
          note: null,
          createdAtUtc: now,
          updatedAtUtc: now,
          revision: const Revision(0),
        ),
      ],
    );
    final review = days.single as NeedsReview;
    expect(review.underlying, isA<OffDay>());
  });

  test('a later version takes over from its first date', () {
    final first = rotation(until: const LocalDate(2026, 10, 7));
    final second = WorkSchedule(
      id: first.id,
      employmentId: first.employmentId,
      name: first.name,
      timezoneId: first.timezoneId,
      version: 2,
      cycleStart: const LocalDate(2026, 10, 8),
      inUseFrom: const LocalDate(2026, 10, 8),
      inUseUntil: null,
      shiftTypes: first.shiftTypes,
      blocks: const [CycleBlock(count: 1, shiftTypeId: ShiftTypeId('night'))],
      createdAtUtc: first.createdAtUtc,
      revision: const Revision(0),
    );
    final days = plan(
      const LocalDate(2026, 10, 7),
      const LocalDate(2026, 10, 8),
      schedules: [first, second],
    );
    expect((days[0] as PlannedShift).scheduleVersion, 1);
    expect((days[1] as PlannedShift).scheduleVersion, 2);
    expect((days[1] as PlannedShift).type?.name, 'Night');
  });
}

WorkSchedule rotation({
  ScheduleId id = const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d01'),
  LocalDate from = const LocalDate(2026, 10, 5),
  LocalDate? until,
  List<CycleBlock>? blocks,
  FixedBreak nightBreak = const FixedBreak(
    start: LocalTime(0, 0),
    dayOffset: 1,
    minutes: 30,
  ),
}) => WorkSchedule(
  id: id,
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  name: 'Depot rotation',
  timezoneId: 'Europe/Vilnius',
  version: 1,
  cycleStart: const LocalDate(2026, 10, 5),
  inUseFrom: from,
  inUseUntil: until,
  shiftTypes: [
    const ShiftType(
      id: ShiftTypeId('day'),
      name: 'Day',
      start: LocalTime(7, 0),
      end: LocalTime(19, 0),
      endDayOffset: 0,
      breaks: [FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30)],
    ),
    ShiftType(
      id: const ShiftTypeId('night'),
      name: 'Night',
      start: const LocalTime(19, 0),
      end: const LocalTime(7, 0),
      endDayOffset: 1,
      breaks: [nightBreak],
    ),
  ],
  blocks:
      blocks ??
      const [
        CycleBlock(count: 3, shiftTypeId: ShiftTypeId('day')),
        CycleBlock(count: 3, shiftTypeId: null),
        CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
        CycleBlock(count: 3, shiftTypeId: null),
      ],
  createdAtUtc: DateTime.utc(2026, 10),
  revision: const Revision(0),
);
