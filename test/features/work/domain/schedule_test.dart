import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

void main() {
  test('3 day, 3 off, 3 night, 3 off has a 12-day cycle', () {
    final schedule = rotation();
    expect(schedule.cycleLength, 12);
    expect(schedule.cycleDayOf(const LocalDate(2026, 10, 5)), 1);
    expect(schedule.cycleDayOf(const LocalDate(2026, 10, 16)), 12);
    expect(schedule.cycleDayOf(const LocalDate(2026, 10, 17)), 1);
  });

  test('dates before the cycle start follow the rotation backwards', () {
    final schedule = rotation();
    // 2026-10-04 is the day before day 1, so it is day 12 (Off).
    expect(schedule.cycleDayOf(const LocalDate(2026, 10, 4)), 12);
    expect(schedule.cycleDayOf(const LocalDate(2026, 9, 23)), 1);
    expect(schedule.shiftTypeOn(const LocalDate(2026, 9, 23))?.name, 'Day');
  });

  test('blocks map cycle days to Day, Off and Night', () {
    final schedule = rotation();
    String? on(int day) => schedule
        .shiftTypeOn(const LocalDate(2026, 10, 5).addDays(day - 1))
        ?.name;
    expect(
      [for (var day = 1; day <= 12; day++) on(day)],
      [
        'Day',
        'Day',
        'Day',
        null,
        null,
        null,
        'Night',
        'Night',
        'Night',
        null,
        null,
        null,
      ],
    );
  });

  test('a cycle longer than a month repeats on its own length', () {
    final schedule = rotation(
      blocks: const [
        CycleBlock(count: 20, shiftTypeId: ShiftTypeId('day')),
        CycleBlock(count: 20, shiftTypeId: null),
      ],
    );
    final start = const LocalDate(2026, 10, 5);
    expect(schedule.cycleLength, 40);
    expect(schedule.cycleDayOf(start.addDays(45)), 6);
    expect(schedule.shiftTypeOn(start.addDays(45))?.name, 'Day');
    expect(schedule.shiftTypeOn(start.addDays(65)), isNull);
    expect(schedule.cycleDayOf(start.addDays(-1)), 40);
  });

  test('a 12-hour shift with a 30-minute break pays 11:30', () {
    final night = rotation().shiftTypes.last;
    expect(night.lengthMinutes, 12 * 60);
    expect(night.paidMinutes, 11 * 60 + 30);
  });

  test('validation names the offending field', () {
    final issues = validateSchedule(
      rotation(
        blocks: const [CycleBlock(count: 0, shiftTypeId: ShiftTypeId('day'))],
        nightBreak: const FixedBreak(
          start: LocalTime(6, 50),
          dayOffset: 1,
          minutes: 30,
        ),
      ),
    );
    expect(
      issues.map((issue) => issue.field),
      containsAll(<String>['blocks[0].count', 'shiftTypes[1].breaks']),
    );
  });

  test('a block may not name a missing shift type', () {
    final issues = validateSchedule(
      rotation(
        blocks: const [CycleBlock(count: 3, shiftTypeId: ShiftTypeId('x'))],
      ),
    );
    expect(
      issues,
      contains(
        const DomainIssue('schedule.blockType', field: 'blocks[0].shiftTypeId'),
      ),
    );
  });

  test('two schedules of one employment may not share a date', () {
    final first = rotation(until: const LocalDate(2026, 12, 31));
    final second = rotation(
      id: const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d02'),
      from: const LocalDate(2026, 12, 31),
    );
    expect(scheduleOverlaps(second, [first]), isTrue);
    final later = rotation(
      id: const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d02'),
      from: const LocalDate(2027, 1, 1),
    );
    expect(scheduleOverlaps(later, [first]), isFalse);
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
