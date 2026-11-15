import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

const _employment = EmploymentId('e1');
const _day = ShiftTypeId('day');
const _night = ShiftTypeId('night');

/// 3 Day, 3 Night, 6 Off; Day 07:00–19:00 with 12:00–12:30, Night
/// 19:00–07:00 with 01:00–01:30.
ScheduleValues _depot() => const ScheduleValues(
  name: 'Depot rotation',
  timezoneId: 'Europe/Vilnius',
  cycleStart: LocalDate(2026, 9, 1),
  inUseFrom: LocalDate(2026, 9, 1),
  inUseUntil: null,
  types: [
    ShiftType(
      id: _day,
      name: 'Day',
      start: LocalTime(7, 0),
      end: LocalTime(19, 0),
      endDayOffset: 0,
      breaks: [FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30)],
    ),
    ShiftType(
      id: _night,
      name: 'Night',
      start: LocalTime(19, 0),
      end: LocalTime(7, 0),
      endDayOffset: 1,
      breaks: [FixedBreak(start: LocalTime(1, 0), dayOffset: 1, minutes: 30)],
    ),
  ],
  blocks: [
    CycleBlock(count: 3, shiftTypeId: _day),
    CycleBlock(count: 3, shiftTypeId: _night),
    CycleBlock(count: 6, shiftTypeId: null),
  ],
);

ScheduleValues _values(ScheduleEdit edit) {
  expect(edit.problem, isNull);
  return edit.values!;
}

void main() {
  test('a night type ends the next day', () {
    final day = _values(
      withTypeField(
        _depot(),
        _day,
        ScheduleField.typeEnd,
        const LocalTime(6, 0),
      ),
    );
    final type = day.types.first;
    expect(type.endDayOffset, 1);
    expect(type.breaks.single.dayOffset, 0, reason: 'the break keeps 12:00');
    final night = _values(
      withTypeField(
        _depot(),
        _night,
        ScheduleField.typeStart,
        const LocalTime(20, 0),
      ),
    );
    expect(night.types.last.endDayOffset, 1);
    expect(night.types.last.breaks.single.dayOffset, 1);
  });

  test('moving a block renumbers the cycle', () {
    final moved = _values(withBlockMoved(_depot(), 2, 1));
    expect([for (final b in moved.blocks) b.count], [3, 6, 3]);
    expect([for (final b in moved.blocks) b.shiftTypeId], [_day, null, _night]);
  });

  test('a type the cycle uses stays', () {
    expect(withoutType(_depot(), _day).problem, ScheduleProblems.typeInCycle);
    final unused = _values(withNewType(_depot()));
    expect(unused.types.last.name, 'Type 3');
    expect(unused.types.last.start, const LocalTime(8, 0));
    expect(unused.types.last.end, const LocalTime(16, 0));
    final gone = _values(withoutType(unused, unused.types.last.id));
    expect(gone.types, hasLength(2));
  });

  test('a duplicate type name says so', () {
    final values = _values(
      withTypeField(_depot(), _night, ScheduleField.typeName, 'Day'),
    );
    final issues = scheduleIssues(values, employmentId: _employment);
    expect(
      issues[typeKey(_night, ScheduleField.typeName)],
      ScheduleProblems.typeNameTaken,
    );
    // The first type renamed to the second's name is flagged too, so the
    // edited row says it.
    final first = _values(
      withTypeField(_depot(), _day, ScheduleField.typeName, 'Night'),
    );
    expect(
      scheduleIssues(first, employmentId: _employment)[typeKey(
        _day,
        ScheduleField.typeName,
      )],
      ScheduleProblems.typeNameTaken,
    );
  });

  test('a break outside the shift says so', () {
    final outside = _values(
      withBreakField(
        _depot(),
        _day,
        0,
        ScheduleField.breakStart,
        const LocalTime(18, 45),
      ),
    );
    final moved = _values(
      withBreakField(
        outside,
        _day,
        0,
        ScheduleField.breakEnd,
        const LocalTime(19, 15),
      ),
    );
    expect(moved.types.first.breaks.single.minutes, 30);
    expect(
      scheduleIssues(moved, employmentId: _employment)[typeKey(_day, 'breaks')],
      ScheduleProblems.breaks,
    );
  });

  test('a break moved past its end is refused until the end follows', () {
    final late = _values(
      withBreakField(
        _depot(),
        _night,
        0,
        ScheduleField.breakStart,
        const LocalTime(2, 0),
      ),
    );
    expect(
      scheduleIssues(late, employmentId: _employment)[typeKey(
        _night,
        'breaks',
      )],
      ScheduleProblems.breaks,
    );
    final fixed = _values(
      withBreakField(
        late,
        _night,
        0,
        ScheduleField.breakEnd,
        const LocalTime(2, 30),
      ),
    );
    expect(
      scheduleIssues(fixed, employmentId: _employment),
      isNot(contains(typeKey(_night, 'breaks'))),
    );
    expect(
      fixed.types.last.breaks.single,
      const FixedBreak(start: LocalTime(2, 0), dayOffset: 1, minutes: 30),
    );
  });

  test('a new break sits at the middle of the shift', () {
    final values = _values(withNewBreak(_depot(), _night));
    expect(
      values.types.last.breaks.last,
      const FixedBreak(start: LocalTime(1, 0), dayOffset: 1, minutes: 30),
    );
    final fewer = _values(withoutBreak(values, _night, 0));
    expect(fewer.types.last.breaks, hasLength(1));
  });

  test('block days outside 1 to 99 are refused', () {
    for (final text in ['0', '100', 'x', '']) {
      expect(
        withBlockField(_depot(), 0, ScheduleField.blockDays, text).problem,
        ScheduleProblems.blockDays,
        reason: text,
      );
    }
    final four = _values(
      withBlockField(_depot(), 0, ScheduleField.blockDays, ' 4 '),
    );
    expect(four.blocks.first.count, 4);
    final off = _values(
      withBlockField(_depot(), 0, ScheduleField.blockType, null),
    );
    expect(off.blocks.first.shiftTypeId, isNull);
    expect(
      withBlockField(
        _depot(),
        0,
        ScheduleField.blockType,
        const ShiftTypeId('x'),
      ).problem,
      ScheduleProblems.blockType,
    );
  });

  test('an empty cycle says so', () {
    var values = _depot();
    for (var i = 0; i < 3; i++) {
      values = _values(withoutBlock(values, 0));
    }
    expect(
      scheduleIssues(values, employmentId: _employment)[ScheduleField.cycle],
      ScheduleProblems.cycle,
    );
    final one = _values(withNewBlock(values));
    expect(one.blocks.single.count, 1);
    expect(one.blocks.single.shiftTypeId, isNull);
  });

  test('schedule fields take their values', () {
    final named = _values(withScheduleField(_depot(), ScheduleField.name, ''));
    expect(
      scheduleIssues(named, employmentId: _employment)[ScheduleField.name],
      ScheduleProblems.name,
    );
    final until = _values(
      withScheduleField(
        _depot(),
        ScheduleField.inUseUntil,
        const LocalDate(2026, 8, 1),
      ),
    );
    expect(
      scheduleIssues(
        until,
        employmentId: _employment,
      )[ScheduleField.inUseUntil],
      ScheduleProblems.until,
    );
    final from = _values(
      withScheduleField(
        _depot(),
        ScheduleField.versionFrom,
        const LocalDate(2026, 10, 19),
      ),
    );
    expect(from.versionFrom, const LocalDate(2026, 10, 19));
    expect(
      withScheduleField(_depot(), ScheduleField.cycleStart, 'x').problem,
      ScheduleProblems.notEditable,
    );
  });

  test('values compare deeply', () {
    expect(_depot(), _depot());
    final schedule = _depot().asSchedule(
      employmentId: _employment,
      id: const ScheduleId('s'),
      version: 1,
    );
    expect(ScheduleValues.of(schedule), _depot());
    final changed = _values(
      withBreakField(
        _depot(),
        _day,
        0,
        ScheduleField.breakEnd,
        const LocalTime(12, 45),
      ),
    );
    expect(changed, isNot(_depot()));
    expect(_depot().toDraft(_employment).blocks, hasLength(3));
  });
}
