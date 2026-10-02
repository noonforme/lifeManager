# Work Schedules, Part 1: Data, Domain and Pay — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Work rotating schedules, per-day exceptions, confirmable planned days, paid leave and overtime beyond the planned shift — as tested domain, data and services — and remove the live start/stop tracker.

**Architecture:** Schedules, shift types, cycle blocks, day exceptions and leave records are stored; planned shifts are derived on demand by a pure planner (`planDays`) and never stored. Confirming a day writes the existing finalized `WorkShift` (now with a schedule link) or a new `LeaveRecord`. Pay reuses the premium engine with a new `OvertimeRule`; leave is priced by a pure function over the 3 previous calendar months. The database moves from schema 1 to schema **3** (2 was used by pre-reset development builds and stays refused), with a backup taken before migrating.

**Tech Stack:** Flutter 3.47.5, Dart, Drift 2.35 (SQLite), Riverpod 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-02-work-schedules-design.md` (sections 2–4, 3.8, 7, 8). Screens (spec §5–§6) are **Part 2**, a separate plan written after this one lands.

## Global Constraints

- Work on a new branch `feat/work-schedules` cut from `feat/habits-slice`.
- Flutter binary: `F=~/.local/opt/flutter-3.47.5/bin` (not on PATH). Tests: `$F/flutter test <path>`; analysis: `$F/flutter analyze lib test tool`; format: `$F/dart format lib test tool`; schema: `$F/dart run tool/schema_check.dart`; code generation after table changes: `$F/dart run build_runner build --delete-conflicting-outputs`.
- Every task ends with analyze reporting "No issues found!", the format check passing and the full suite green.
- Planned shifts are derived, never stored. SQLite stays the single source of truth (PRODUCT.md).
- Every command returns the existing `MutationOutcome` variants (`Committed`, `Invalid`, `Stale`, `Missing`, `Unavailable`, `Uncertain`); field issues name the field (`blocks`, `inUseFrom`, `shiftTypes[1].breaks`, …). Nothing is retried silently (spec §7).
- Money is exact minor units; rounding uses `roundHalfUpRatio` from `lib/features/work/domain/pay.dart`.
- Wall-clock resolution for planned times follows the fold rules: a daylight-saving gap moves to the first valid instant; an overlap uses the first occurrence (`ZoneWallClock.toInstants(...).first`).
- Leave defaults: vacation 100 %, sick 62.06 % (`3103/5000`) for the first 2 calendar days of an illness, 0 % after; labelled "defaults, not legal advice" (spec §3.7, §4.3).
- Schema: current version becomes **3**; version 2 databases stay refused as earlier development builds; a released version-1 database is backed up, then migrated.
- Synthetic data only in tests and fixtures.
- Commit after every task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A real version-1 database with records migrates without loss:** employments, agreements, finalized shifts and payslips survive; a running shift becomes a draft with its start kept; the backup file holds the untouched version-1 data. Test in Task 5.
2. **Confirming the same day twice** (two taps, or two windows) must leave exactly one confirmed shift or leave record and report `Stale` for the second. Test in Task 9.
3. **A night shift on the night daylight saving ends** (Europe/Vilnius, last Sunday of October) must plan the right instants and pay the extra hour exactly once. Test in Task 3.
4. **A schedule edited after days were confirmed** must keep confirmed days untouched, start the new cycle from the chosen date, and flag exceptions that no longer fit as Needs review. Test in Tasks 3 and 7.
5. **Leave in a month with no confirmed work in the 3 months before** must fall back to the agreement rate and say so, never divide by zero. Test in Task 4.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/time/local_date.dart` | `addDays`, `daysSince`, `weekday`, `firstOfMonth`, `addMonths`. |
| `lib/features/work/domain/ids.dart` | `ScheduleId`, `LeaveRecordId`, `DayExceptionId`. |
| `lib/features/work/domain/pay_premiums.dart` | `OvertimeRule` and its use in `segmentPaidTime`. |
| `lib/features/work/domain/shift.dart` | `ScheduleLink` on `WorkShift`; states without running/on break; `FinalizationFacts.overtimeRule`. |
| `lib/features/work/domain/schedule.dart` (new) | `ShiftTypeId`, `FixedBreak`, `ShiftType`, `CycleBlock`, `WorkSchedule`, `validateSchedule`, `scheduleOverlaps`. |
| `lib/features/work/domain/day_exception.dart` (new) | `DayException` and its four kinds, `CancelReason`, `LeaveType`. |
| `lib/features/work/domain/planner.dart` (new) | `PlannedDay` kinds, `planDays`, `plannedPay`. |
| `lib/features/work/domain/leave.dart` (new) | `LeaveRecord`, `LeavePay`, `priceLeave`, `defaultIllnessStart`. |
| `lib/features/work/domain/agreement.dart` | Leave-pay terms on `PayAgreement`. |
| `lib/features/work/domain/reconciliation.dart` | Confirmed leave counted as expected evidence. |
| `lib/features/work/data/work_tables.dart` | New tables and columns. |
| `lib/core/database/{schema_versions,migration_strategy,database_service}.dart`, `tool/schema_check.dart`, `drift_schemas/schema_v3.json` | Schema 3, migration, backup. |
| `lib/features/work/data/daos/{schedule_dao,day_exception_dao,leave_dao}.dart` (new) | Table access. |
| `lib/features/work/data/work_converters.dart` | Row ↔ domain for the new tables and columns. |
| `lib/features/work/data/schedule_repository.dart` (new) | Drift implementation of the schedule, exception, confirm and leave repositories. |
| `lib/features/work/application/{schedule_service,day_plan_service,leave_service}.dart` (new) | Commands and services. |
| `lib/features/work/data/work_repository.dart`, `projections/*` | Plan query, leave in reconciliation. |
| `lib/app/production_work_providers.dart`, `lib/features/work/presentation/work_controller.dart` | Provider wiring. |
| `test/core/database/fixtures/schema_v1.sql` (new) | Exact version-1 DDL, captured before any table change. |

---

### Task 1: Dates and overtime rules

Spec §4.2. Pure domain; no storage yet.

**Files:**
- Modify: `lib/core/time/local_date.dart`
- Modify: `lib/features/work/domain/pay_premiums.dart`
- Test: `test/core/time/local_date_test.dart` (create if absent), `test/features/work/domain/pay_premiums_test.dart`

**Interfaces:**
- Produces:
  - `LocalDate.addDays(int days) → LocalDate`, `LocalDate.daysSince(LocalDate other) → int`, `int get weekday` (1 = Monday … 7 = Sunday), `LocalDate get firstOfMonth`, `LocalDate addMonths(int months)` (day clamped to 1 — only used on first-of-month dates).
  - `sealed class OvertimeRule`; `ThresholdOvertime(int seconds)`; `WindowOvertime({required DateTime start, required DateTime end})`; `AllOvertime()`; `NoOvertime()`.
  - `segmentPaidTime({…, OvertimeRule? overtime})` — `null` keeps today's behaviour (`ThresholdOvertime(agreement.overtimeThresholdMinutes * 60)`).

- [ ] **Step 1: Failing tests**

`test/core/time/local_date_test.dart` (append to it if it exists):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';

void main() {
  test('days move across months, years and leap days', () {
    expect(const LocalDate(2026, 1, 31).addDays(1), const LocalDate(2026, 2, 1));
    expect(const LocalDate(2028, 2, 28).addDays(1), const LocalDate(2028, 2, 29));
    expect(const LocalDate(2026, 1, 1).addDays(-1), const LocalDate(2025, 12, 31));
  });

  test('days since counts whole days in either direction', () {
    expect(const LocalDate(2026, 10, 5).daysSince(const LocalDate(2026, 10, 1)), 4);
    expect(const LocalDate(2026, 9, 28).daysSince(const LocalDate(2026, 10, 1)), -3);
    // Across the October daylight-saving change: still whole days.
    expect(const LocalDate(2026, 10, 26).daysSince(const LocalDate(2026, 10, 24)), 2);
  });

  test('weekday is 1 for Monday and 7 for Sunday', () {
    expect(const LocalDate(2026, 10, 5).weekday, 1);
    expect(const LocalDate(2026, 10, 4).weekday, 7);
  });

  test('months step from the first of a month', () {
    expect(const LocalDate(2026, 10, 17).firstOfMonth, const LocalDate(2026, 10, 1));
    expect(const LocalDate(2026, 1, 1).addMonths(-3), const LocalDate(2025, 10, 1));
    expect(const LocalDate(2026, 11, 1).addMonths(2), const LocalDate(2027, 1, 1));
  });
}
```

Append to `test/features/work/domain/pay_premiums_test.dart` inside `main()` (it already has `_local`, `_agreement`, `_describe`, `_toLocal`, `_toInstants` on a fixed +2 h offset):

```dart
  group('overtime rules', () {
    List<PaySegment> segment(_Interval interval, OvertimeRule rule) =>
        segmentPaidTime(
          paidIntervals: [interval],
          agreement: _agreement(nightEnabled: false),
          toLocal: _toLocal,
          toInstants: _toInstants,
          overtime: rule,
        );

    test('a planned window makes only time outside it overtime', () {
      final segments = segment(
        _local('2026-09-15 06:30', '2026-09-15 19:45'),
        WindowOvertime(
          start: _utc('2026-09-15 07:00'),
          end: _utc('2026-09-15 19:00'),
        ),
      );
      expect(segments.map(_describe), [
        '06:30 0:30 --O',
        '07:00 12:00 ---',
        '19:00 0:45 --O',
      ]);
    });

    test('a 12-hour planned shift worked as planned has no overtime', () {
      final segments = segment(
        _local('2026-09-15 07:00', '2026-09-15 19:00'),
        WindowOvertime(
          start: _utc('2026-09-15 07:00'),
          end: _utc('2026-09-15 19:00'),
        ),
      );
      expect(segments.every((item) => !item.overtime), isTrue);
    });

    test('all and no overtime flag every second the same way', () {
      final interval = _local('2026-09-15 08:00', '2026-09-15 20:00');
      expect(
        segment(interval, const AllOvertime()).every((s) => s.overtime),
        isTrue,
      );
      expect(
        segment(interval, const NoOvertime()).every((s) => !s.overtime),
        isTrue,
      );
    });

    test('no rule keeps the agreement threshold', () {
      final segments = segmentPaidTime(
        paidIntervals: [_local('2026-09-15 08:00', '2026-09-15 18:00')],
        agreement: _agreement(nightEnabled: false),
        toLocal: _toLocal,
        toInstants: _toInstants,
      );
      expect(segments.map(_describe), ['08:00 8:00 ---', '16:00 2:00 --O']);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/core/time/local_date_test.dart test/features/work/domain/pay_premiums_test.dart`
Expected: compile errors (`addDays`, `OvertimeRule`, `overtime:` undefined).

- [ ] **Step 3: Implement**

In `lib/core/time/local_date.dart` add to `LocalDate`:

```dart
  /// The date [days] later, or earlier when negative.
  LocalDate addDays(int days) {
    final value = DateTime.utc(year, month, day + days);
    return LocalDate(value.year, value.month, value.day);
  }

  /// Whole days from [other] to this date; negative when this is earlier.
  int daysSince(LocalDate other) => DateTime.utc(year, month, day)
      .difference(DateTime.utc(other.year, other.month, other.day))
      .inDays;

  /// 1 for Monday through 7 for Sunday.
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// The first day of this date's month.
  LocalDate get firstOfMonth => LocalDate(year, month, 1);

  /// The first of the month [months] later, or earlier when negative.
  LocalDate addMonths(int months) {
    final value = DateTime.utc(year, month + months, 1);
    return LocalDate(value.year, value.month, 1);
  }
```

In `lib/features/work/domain/pay_premiums.dart` add after `PaySegment`:

```dart
/// Which paid time is overtime (schedules spec 4.2).
sealed class OvertimeRule {
  const OvertimeRule();
}

/// Paid time after [seconds] of paid time in the shift: the agreement's
/// threshold, for shifts without a schedule.
final class ThresholdOvertime extends OvertimeRule {
  const ThresholdOvertime(this.seconds);

  final int seconds;
}

/// Paid time before [start] or from [end] on: a confirmed scheduled shift's
/// planned window.
final class WindowOvertime extends OvertimeRule {
  const WindowOvertime({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

/// Every paid second: an extra shift marked as overtime.
final class AllOvertime extends OvertimeRule {
  const AllOvertime();
}

/// No paid second: an extra shift that is not overtime, and planned pay.
final class NoOvertime extends OvertimeRule {
  const NoOvertime();
}
```

Change `segmentPaidTime` to take `OvertimeRule? overtime` and use it:

```dart
List<PaySegment> segmentPaidTime({
  required List<({DateTime start, DateTime end})> paidIntervals,
  required PayAgreement agreement,
  required ToLocal toLocal,
  required ToInstants toInstants,
  OvertimeRule? overtime,
}) {
  // … the existing interval validation stays …
  final rule =
      overtime ?? ThresholdOvertime(agreement.overtimeThresholdMinutes * 60);
  final overtimeStart = switch (rule) {
    ThresholdOvertime(:final seconds) => _overtimeStart(intervals, seconds),
    _ => null,
  };
  final window = switch (rule) {
    WindowOvertime(:final start, :final end) => (
      start: _wholeSecond(start),
      end: _wholeSecond(end),
    ),
    _ => null,
  };
  bool isOvertime(DateTime from) => switch (rule) {
    ThresholdOvertime() => overtimeStart != null && !from.isBefore(overtimeStart),
    WindowOvertime() =>
      from.isBefore(window!.start) || !from.isBefore(window.end),
    AllOvertime() => true,
    NoOvertime() => false,
  };
```

In the per-interval loop add the window bounds to `cuts`:

```dart
    final cuts = <DateTime>{
      if (overtimeStart != null && inside(overtimeStart)) overtimeStart,
      if (window != null && inside(window.start)) window.start,
      if (window != null && inside(window.end)) window.end,
      ..._offsetChanges(start, end, toLocal),
    };
```

and set `overtime: isOvertime(from),` on each `PaySegment`. Update the function's doc comment: "…the overtime start or the planned window's edges…".

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/core/time test/features/work/domain`
Expected: PASS (the existing threshold tests are unchanged).

- [ ] **Step 5: Commit**

```bash
git add lib/core/time/local_date.dart lib/features/work/domain/pay_premiums.dart test/core/time test/features/work/domain/pay_premiums_test.dart
git commit -m "feat: add overtime rules and date arithmetic for schedules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Schedules, shift types and the cycle

Spec §3.1–§3.3.

**Files:**
- Modify: `lib/features/work/domain/ids.dart`
- Create: `lib/features/work/domain/schedule.dart`
- Test: `test/features/work/domain/schedule_test.dart`

**Interfaces:**
- Consumes: `LocalDate.daysSince`, `DomainIssue`, `Revision`.
- Produces (all in `schedule.dart` unless noted):
  - `ScheduleId`, `LeaveRecordId`, `DayExceptionId` (in `ids.dart`, `WorkRecordId` subclasses with `tryParse`, like `ShiftId`).
  - `ShiftTypeId(String value)` value class.
  - `FixedBreak({required LocalTime start, required int dayOffset, required int minutes})`, `int get startMinute` (minutes from the shift's start date midnight: `dayOffset * 1440 + start.hour * 60 + start.minute`).
  - `ShiftType({required ShiftTypeId id, required String name, required LocalTime start, required LocalTime end, required int endDayOffset, List<FixedBreak> breaks = const []})`, getters `startMinute`, `endMinute` (from the start date's midnight), `lengthMinutes`, `breakMinutes`, `paidMinutes`.
  - `CycleBlock({required int count, required ShiftTypeId? shiftTypeId})`.
  - `WorkSchedule({…})` with `cycleLength`, `isInUseOn(LocalDate)`, `cycleDayOf(LocalDate) → int` (1-based), `shiftTypeOn(LocalDate) → ShiftType?` (null = Off), `typeById(ShiftTypeId) → ShiftType?`, `usedByConfirmedDay` flag.
  - `List<DomainIssue> validateSchedule(WorkSchedule value)`.
  - `bool scheduleOverlaps(WorkSchedule candidate, Iterable<WorkSchedule> others)` — another schedule of the same employment (other id, or same id other version) in use on any common date.

- [ ] **Step 1: Failing tests**

Create `test/features/work/domain/schedule_test.dart`:

```dart
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
    String? on(int day) =>
        schedule.shiftTypeOn(const LocalDate(2026, 10, 5).addDays(day - 1))?.name;
    expect([for (var day = 1; day <= 12; day++) on(day)], [
      'Day', 'Day', 'Day', null, null, null,
      'Night', 'Night', 'Night', null, null, null,
    ]);
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
        nightBreak: const FixedBreak(start: LocalTime(6, 50), dayOffset: 1, minutes: 30),
      ),
    );
    expect(
      issues.map((issue) => issue.field),
      containsAll(<String>['blocks[0].count', 'shiftTypes[1].breaks']),
    );
  });

  test('a block may not name a missing shift type', () {
    final issues = validateSchedule(
      rotation(blocks: const [CycleBlock(count: 3, shiftTypeId: ShiftTypeId('x'))]),
    );
    expect(issues, contains(const DomainIssue('schedule.blockType', field: 'blocks[0].shiftTypeId')));
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
```

(The `FixedBreak(start: 06:50, dayOffset: 1, minutes: 30)` break ends at 07:20, after the Night shift's 07:00 end, so it is invalid.)

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/domain/schedule_test.dart`
Expected: compile errors (`schedule.dart` missing).

- [ ] **Step 3: Implement**

In `lib/features/work/domain/ids.dart` add `ScheduleId`, `LeaveRecordId` and `DayExceptionId`, each a copy of the `ShiftId` class with its own name (constructor, `value`, `tryParse` via `_parse`, `==`, `hashCode`).

Create `lib/features/work/domain/schedule.dart`:

```dart
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import 'facts.dart';
import 'ids.dart';

/// A shift type's id, unique within its schedule version.
final class ShiftTypeId {
  const ShiftTypeId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is ShiftTypeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A break at a fixed wall-clock time (schedules spec 3.2).
final class FixedBreak {
  const FixedBreak({
    required this.start,
    required this.dayOffset,
    required this.minutes,
  });

  final LocalTime start;

  /// 0 on the shift's start date, 1 on the day after.
  final int dayOffset;
  final int minutes;

  /// Minutes from midnight of the shift's start date.
  int get startMinute => dayOffset * 1440 + start.hour * 60 + start.minute;

  int get endMinute => startMinute + minutes;

  @override
  bool operator ==(Object other) =>
      other is FixedBreak &&
      other.start == start &&
      other.dayOffset == dayOffset &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(start, dayOffset, minutes);
}

/// A named kind of shift, such as Day 07:00–19:00.
final class ShiftType {
  const ShiftType({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.endDayOffset,
    this.breaks = const [],
  });

  final ShiftTypeId id;
  final String name;
  final LocalTime start;
  final LocalTime end;

  /// 1 when the shift ends the day after it starts.
  final int endDayOffset;
  final List<FixedBreak> breaks;

  int get startMinute => start.hour * 60 + start.minute;
  int get endMinute => endDayOffset * 1440 + end.hour * 60 + end.minute;
  int get lengthMinutes => endMinute - startMinute;
  int get breakMinutes => breaks.fold(0, (sum, item) => sum + item.minutes);
  int get paidMinutes => lengthMinutes - breakMinutes;
}

/// [count] days of one shift type, or of Off when [shiftTypeId] is null.
final class CycleBlock {
  const CycleBlock({required this.count, required this.shiftTypeId});

  final int count;
  final ShiftTypeId? shiftTypeId;
}

/// One version of a rotation (schedules spec 3.1).
final class WorkSchedule {
  WorkSchedule({
    required this.id,
    required this.employmentId,
    required this.name,
    required this.timezoneId,
    required this.version,
    required this.cycleStart,
    required this.inUseFrom,
    required this.inUseUntil,
    required this.shiftTypes,
    required this.blocks,
    required this.createdAtUtc,
    required this.revision,
    this.usedByConfirmedDay = false,
  }) {
    if (version <= 0) throw ArgumentError.value(version, 'version');
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
  }

  final ScheduleId id;
  final EmploymentId employmentId;
  final String name;
  final String timezoneId;
  final int version;

  /// The date that is cycle day 1.
  final LocalDate cycleStart;
  final LocalDate inUseFrom;

  /// Open when null.
  final LocalDate? inUseUntil;
  final List<ShiftType> shiftTypes;
  final List<CycleBlock> blocks;
  final DateTime createdAtUtc;
  final Revision revision;

  /// Whether a confirmed day was planned from this version; such a version
  /// is never edited in place.
  final bool usedByConfirmedDay;

  int get cycleLength => blocks.fold(0, (sum, block) => sum + block.count);

  bool isInUseOn(LocalDate date) =>
      inUseFrom.compareTo(date) <= 0 &&
      (inUseUntil == null || inUseUntil!.compareTo(date) >= 0);

  /// 1-based; dates before [cycleStart] follow the rotation backwards.
  int cycleDayOf(LocalDate date) =>
      date.daysSince(cycleStart) % cycleLength + 1;

  /// The shift type the cycle places on [date], or null for Off.
  ShiftType? shiftTypeOn(LocalDate date) {
    var day = cycleDayOf(date);
    for (final block in blocks) {
      if (day <= block.count) {
        final id = block.shiftTypeId;
        return id == null ? null : typeById(id);
      }
      day -= block.count;
    }
    return null;
  }

  ShiftType? typeById(ShiftTypeId id) =>
      shiftTypes.where((type) => type.id == id).firstOrNull;
}

/// Every problem with [value], each naming its field (spec 7).
List<DomainIssue> validateSchedule(WorkSchedule value) {
  final issues = <DomainIssue>[];
  final name = value.name.trim();
  if (name.isEmpty || name.length > 60) {
    issues.add(const DomainIssue('schedule.name', field: 'name'));
  }
  if (value.timezoneId.trim().isEmpty) {
    issues.add(const DomainIssue('schedule.timezone', field: 'timezoneId'));
  }
  final until = value.inUseUntil;
  if (until != null && until.compareTo(value.inUseFrom) < 0) {
    issues.add(const DomainIssue('schedule.until', field: 'inUseUntil'));
  }
  final names = <String>{};
  for (final (index, type) in value.shiftTypes.indexed) {
    final typeName = type.name.trim();
    if (typeName.isEmpty || typeName.length > 24 || !names.add(typeName)) {
      issues.add(
        DomainIssue('schedule.typeName', field: 'shiftTypes[$index].name'),
      );
    }
    if (type.endDayOffset < 0 ||
        type.endDayOffset > 1 ||
        type.lengthMinutes <= 0 ||
        type.lengthMinutes > 1440) {
      issues.add(
        DomainIssue('schedule.typeTimes', field: 'shiftTypes[$index].end'),
      );
    }
    final ordered = [...type.breaks]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    var previousEnd = type.startMinute;
    var breaksValid = true;
    for (final item in ordered) {
      if (item.minutes < 1 ||
          item.minutes > 240 ||
          item.dayOffset < 0 ||
          item.dayOffset > 1 ||
          item.startMinute < previousEnd ||
          item.endMinute > type.endMinute) {
        breaksValid = false;
      }
      previousEnd = item.endMinute;
    }
    if (!breaksValid || (type.breaks.isNotEmpty && type.paidMinutes <= 0)) {
      issues.add(
        DomainIssue('schedule.breaks', field: 'shiftTypes[$index].breaks'),
      );
    }
  }
  if (value.blocks.isEmpty) {
    issues.add(const DomainIssue('schedule.blocks', field: 'blocks'));
  }
  for (final (index, block) in value.blocks.indexed) {
    if (block.count < 1 || block.count > 99) {
      issues.add(
        DomainIssue('schedule.blockCount', field: 'blocks[$index].count'),
      );
    }
    final typeId = block.shiftTypeId;
    if (typeId != null && value.typeById(typeId) == null) {
      issues.add(
        DomainIssue('schedule.blockType', field: 'blocks[$index].shiftTypeId'),
      );
    }
  }
  final length = value.cycleLength;
  if (value.blocks.isNotEmpty && (length < 1 || length > 366)) {
    issues.add(const DomainIssue('schedule.cycleLength', field: 'blocks'));
  }
  return List.unmodifiable(issues);
}

/// Whether [candidate] shares a date with another schedule version of the
/// same employment (spec 3.1: at most one in use per date).
bool scheduleOverlaps(WorkSchedule candidate, Iterable<WorkSchedule> others) {
  for (final other in others) {
    if (other.employmentId != candidate.employmentId) continue;
    if (other.id == candidate.id && other.version == candidate.version) {
      continue;
    }
    final startsBeforeOtherEnds =
        other.inUseUntil == null ||
        candidate.inUseFrom.compareTo(other.inUseUntil!) <= 0;
    final endsAfterOtherStarts =
        candidate.inUseUntil == null ||
        candidate.inUseUntil!.compareTo(other.inUseFrom) >= 0;
    if (startsBeforeOtherEnds && endsAfterOtherStarts) return true;
  }
  return false;
}
```

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/features/work/domain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work/domain/ids.dart lib/features/work/domain/schedule.dart test/features/work/domain/schedule_test.dart
git commit -m "feat: model rotating schedules, shift types and cycles

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Day exceptions and the planner

Spec §3.4, §3.5. Pure functions; Review Focus 3 and 4.

**Files:**
- Create: `lib/features/work/domain/day_exception.dart`, `lib/features/work/domain/planner.dart`
- Test: `test/features/work/domain/planner_test.dart`

**Interfaces:**
- Consumes: `WorkSchedule`, `ShiftType`, `FixedBreak`, `ZoneClocks` (from `pay_premiums.dart`; production builds it with `zoneClocksOf(TimezoneService)` from `lib/core/time/wall_clock.dart`), `LocalDate.addDays`.
- Produces:
  - `enum CancelReason { swapped, dayOff, other }`, `enum LeaveType { vacation, sick }`.
  - `sealed class DayException` (`id`, `employmentId`, `date`, `createdAtUtc`, `updatedAtUtc`, `revision`) with `ChangedDay`, `CancelledDay`, `LeaveDay`, `ExtraDay` (fields below).
  - `sealed class PlannedDay { LocalDate date }` with `OffDay`, `PlannedShift`, `PlannedLeave`, `CancelledPlan`, `NeedsReview`.
  - `List<PlannedDay> planDays({required LocalDate from, required LocalDate to, required Iterable<WorkSchedule> schedules, required Iterable<DayException> exceptions, required Set<LocalDate> confirmedDates, required ZoneClocks zoneClocks})` — one entry per date that a schedule covers, in date order; dates without a schedule version in use and dates in `confirmedDates` are left out.

`PlannedShift` fields: `date`, `scheduleId`, `scheduleVersion`, `timezoneId`, `ShiftType? type` (null for a custom extra), `DateTime startUtc`, `DateTime endUtc`, `List<({DateTime start, DateTime end})> breaks`, `({DateTime start, DateTime end})? overtimeWindow` (null for extras), `bool isExtra`, `bool countsAsOvertime`, `bool changed`; getter `int paidSeconds`.
`PlannedLeave` fields: `date`, `scheduleId`, `scheduleVersion`, `LeaveType leaveType`, `LocalDate? illnessStartedOn`, `int paidMinutes`, `PlannedShift replaced`.
`CancelledPlan`: `date`, `CancelReason reason`, `String? note`, `PlannedShift replaced`.
`NeedsReview`: `date`, `DayException exception`, `PlannedDay underlying` (what the cycle holds without the exception).

- [ ] **Step 1: Failing tests**

Create `test/features/work/domain/planner_test.dart` (it reuses the `rotation()` builder; copy that function from `schedule_test.dart` into this file unchanged):

```dart
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
        Duration(hours: DateTime.utc(y, m, d).isBefore(DateTime.utc(2026, 10, 25)) ? 3 : 2),
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
    final days = plan(const LocalDate(2026, 10, 5), const LocalDate(2026, 10, 16));
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
    final night = plan(
      const LocalDate(2026, 10, 24),
      const LocalDate(2026, 10, 24),
      schedules: [adjusted],
    ).single as PlannedShift;
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
    final shift = plan(
      const LocalDate(2026, 3, 29),
      const LocalDate(2026, 3, 29),
      schedules: [early],
    ).single as PlannedShift;
    expect(shift.startUtc, DateTime.utc(2026, 3, 29, 1)); // 04:00 +03
    expect(shift.endUtc, DateTime.utc(2026, 3, 29, 12, 30)); // 15:30 +03
  });

  test('a Changed day with another type takes that type\'s window', () {
    final now = DateTime.utc(2026, 10, 1);
    final day = plan(
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 5),
      exceptions: [
        ChangedDay(
          id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4e06'),
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
    ).single as PlannedShift;
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
          breaks: const [FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30)],
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
    final first = rotation(until: const LocalDate(2026, 10, 9));
    final second = WorkSchedule(
      id: first.id,
      employmentId: first.employmentId,
      name: first.name,
      timezoneId: first.timezoneId,
      version: 2,
      cycleStart: const LocalDate(2026, 10, 10),
      inUseFrom: const LocalDate(2026, 10, 10),
      inUseUntil: null,
      shiftTypes: first.shiftTypes,
      blocks: const [CycleBlock(count: 1, shiftTypeId: ShiftTypeId('night'))],
      createdAtUtc: first.createdAtUtc,
      revision: const Revision(0),
    );
    final days = plan(
      const LocalDate(2026, 10, 9),
      const LocalDate(2026, 10, 10),
      schedules: [first, second],
    );
    expect((days[0] as PlannedShift).scheduleVersion, 1);
    expect((days[1] as PlannedShift).scheduleVersion, 2);
    expect((days[1] as PlannedShift).type?.name, 'Night');
  });
}

// rotation() — copy from schedule_test.dart.
```

(`vilnius()` above is a test helper for readable instants; the October 2026 change in Europe/Vilnius is on Sunday 25 October at 04:00 local → 03:00.)

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/domain/planner_test.dart`
Expected: compile errors (`day_exception.dart`, `planner.dart` missing).

- [ ] **Step 3: Implement**

Create `lib/features/work/domain/day_exception.dart`:

```dart
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import 'facts.dart';
import 'ids.dart';
import 'schedule.dart';

enum CancelReason { swapped, dayOff, other }

enum LeaveType { vacation, sick }

/// One owner change to one planned date (schedules spec 3.5).
sealed class DayException {
  const DayException({
    required this.id,
    required this.employmentId,
    required this.date,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  });

  final DayExceptionId id;
  final EmploymentId employmentId;
  final LocalDate date;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;
}

/// Other times, breaks or type on a planned day.
final class ChangedDay extends DayException {
  const ChangedDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.start,
    required this.end,
    required this.endDayOffset,
    required this.breaks,
    required this.shiftTypeId,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final LocalTime start;
  final LocalTime end;
  final int endDayOffset;
  final List<FixedBreak> breaks;

  /// The type worked instead, when the type changed.
  final ShiftTypeId? shiftTypeId;
}

/// A planned day not worked and not paid.
final class CancelledDay extends DayException {
  const CancelledDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.reason,
    required this.note,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final CancelReason reason;
  final String? note;
}

/// A planned day taken as paid leave.
final class LeaveDay extends DayException {
  const LeaveDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.leaveType,
    required this.illnessStartedOn,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final LeaveType leaveType;

  /// Sick leave only; null means the default (spec 4.3).
  final LocalDate? illnessStartedOn;
}

/// A shift on a day the cycle has Off.
final class ExtraDay extends DayException {
  const ExtraDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.start,
    required this.end,
    required this.endDayOffset,
    required this.breaks,
    required this.shiftTypeId,
    required this.countsAsOvertime,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final LocalTime start;
  final LocalTime end;
  final int endDayOffset;
  final List<FixedBreak> breaks;
  final ShiftTypeId? shiftTypeId;
  final bool countsAsOvertime;
}
```

Create `lib/features/work/domain/planner.dart`:

```dart
import '../../../core/time/local_date.dart';
import 'day_exception.dart';
import 'ids.dart';
import 'pay_premiums.dart';
import 'schedule.dart';

typedef Span = ({DateTime start, DateTime end});

/// What one date holds after schedules and exceptions (spec 3.4).
sealed class PlannedDay {
  const PlannedDay(this.date);

  final LocalDate date;
}

/// The cycle has Off and nothing was added.
final class OffDay extends PlannedDay {
  const OffDay(super.date, {required this.scheduleId, required this.scheduleVersion});

  final ScheduleId scheduleId;
  final int scheduleVersion;
}

final class PlannedShift extends PlannedDay {
  const PlannedShift(
    super.date, {
    required this.scheduleId,
    required this.scheduleVersion,
    required this.timezoneId,
    required this.type,
    required this.startUtc,
    required this.endUtc,
    required this.breaks,
    required this.overtimeWindow,
    required this.isExtra,
    required this.countsAsOvertime,
    required this.changed,
  });

  final ScheduleId scheduleId;
  final int scheduleVersion;
  final String timezoneId;

  /// Null for an extra shift with custom times.
  final ShiftType? type;
  final DateTime startUtc;
  final DateTime endUtc;
  final List<Span> breaks;

  /// Paid time outside this window is overtime once confirmed; null for
  /// extras, which are all or nothing.
  final Span? overtimeWindow;
  final bool isExtra;
  final bool countsAsOvertime;
  final bool changed;

  int get paidSeconds =>
      endUtc.difference(startUtc).inSeconds -
      breaks.fold(0, (sum, item) => sum + item.end.difference(item.start).inSeconds);
}

final class PlannedLeave extends PlannedDay {
  const PlannedLeave(
    super.date, {
    required this.scheduleId,
    required this.scheduleVersion,
    required this.leaveType,
    required this.illnessStartedOn,
    required this.paidMinutes,
    required this.replaced,
  });

  final ScheduleId scheduleId;
  final int scheduleVersion;
  final LeaveType leaveType;
  final LocalDate? illnessStartedOn;
  final int paidMinutes;
  final PlannedShift replaced;
}

final class CancelledPlan extends PlannedDay {
  const CancelledPlan(
    super.date, {
    required this.reason,
    required this.note,
    required this.replaced,
  });

  final CancelReason reason;
  final String? note;
  final PlannedShift replaced;
}

/// An exception that no longer fits what the cycle holds on its date. It
/// is ignored until edited or removed (spec 3.5).
final class NeedsReview extends PlannedDay {
  const NeedsReview(super.date, {required this.exception, required this.underlying});

  final DayException exception;
  final PlannedDay underlying;
}

/// Plans [from]..[to] inclusive. Dates with no version in use, and
/// [confirmedDates], are left out.
List<PlannedDay> planDays({
  required LocalDate from,
  required LocalDate to,
  required Iterable<WorkSchedule> schedules,
  required Iterable<DayException> exceptions,
  required Set<LocalDate> confirmedDates,
  required ZoneClocks zoneClocks,
}) {
  final versions = schedules.toList(growable: false);
  final byDate = {for (final item in exceptions) item.date: item};
  final days = <PlannedDay>[];
  for (var date = from; date.compareTo(to) <= 0; date = date.addDays(1)) {
    if (confirmedDates.contains(date)) continue;
    final schedule = versions.where((value) => value.isInUseOn(date)).firstOrNull;
    if (schedule == null) continue;
    final clock = zoneClocks(schedule.timezoneId);
    DateTime at(LocalDate day, int minuteOfDay) =>
        clock.toInstants(day, minuteOfDay).first;
    DateTime atMinute(int minuteFromStartDate) => at(
      date.addDays(minuteFromStartDate ~/ 1440),
      minuteFromStartDate % 1440,
    );

    PlannedShift shiftOf({
      required int startMinute,
      required int endMinute,
      required List<FixedBreak> breaks,
      required ShiftType? type,
      required ShiftType? windowType,
      required bool isExtra,
      required bool countsAsOvertime,
      required bool changed,
    }) => PlannedShift(
      date,
      scheduleId: schedule.id,
      scheduleVersion: schedule.version,
      timezoneId: schedule.timezoneId,
      type: type,
      startUtc: atMinute(startMinute),
      endUtc: atMinute(endMinute),
      breaks: [
        for (final item in breaks)
          (
            start: atMinute(item.startMinute),
            end: atMinute(item.startMinute).add(Duration(minutes: item.minutes)),
          ),
      ],
      overtimeWindow: windowType == null
          ? null
          : (
              start: atMinute(windowType.startMinute),
              end: atMinute(windowType.endMinute),
            ),
      isExtra: isExtra,
      countsAsOvertime: countsAsOvertime,
      changed: changed,
    );

    final cycleType = schedule.shiftTypeOn(date);
    final PlannedDay underlying = cycleType == null
        ? OffDay(date, scheduleId: schedule.id, scheduleVersion: schedule.version)
        : shiftOf(
            startMinute: cycleType.startMinute,
            endMinute: cycleType.endMinute,
            breaks: cycleType.breaks,
            type: cycleType,
            windowType: cycleType,
            isExtra: false,
            countsAsOvertime: false,
            changed: false,
          );

    final exception = byDate[date];
    final planned = underlying is PlannedShift ? underlying : null;
    days.add(switch (exception) {
      null => underlying,
      ChangedDay() when planned != null => () {
        final chosen = exception.shiftTypeId == null
            ? null
            : schedule.typeById(exception.shiftTypeId!);
        return shiftOf(
          startMinute: exception.start.hour * 60 + exception.start.minute,
          endMinute: exception.endDayOffset * 1440 +
              exception.end.hour * 60 +
              exception.end.minute,
          breaks: exception.breaks,
          type: chosen ?? cycleType,
          windowType: chosen ?? cycleType,
          isExtra: false,
          countsAsOvertime: false,
          changed: true,
        );
      }(),
      CancelledDay() when planned != null => CancelledPlan(
        date,
        reason: exception.reason,
        note: exception.note,
        replaced: planned,
      ),
      LeaveDay() when planned != null => PlannedLeave(
        date,
        scheduleId: schedule.id,
        scheduleVersion: schedule.version,
        leaveType: exception.leaveType,
        illnessStartedOn: exception.illnessStartedOn,
        paidMinutes: planned.paidSeconds ~/ 60,
        replaced: planned,
      ),
      ExtraDay() when planned == null => shiftOf(
        startMinute: exception.start.hour * 60 + exception.start.minute,
        endMinute: exception.endDayOffset * 1440 +
            exception.end.hour * 60 +
            exception.end.minute,
        breaks: exception.breaks,
        type: exception.shiftTypeId == null
            ? null
            : schedule.typeById(exception.shiftTypeId!),
        windowType: null,
        isExtra: true,
        countsAsOvertime: exception.countsAsOvertime,
        changed: false,
      ),
      _ => NeedsReview(date, exception: exception!, underlying: underlying),
    });
  }
  return List.unmodifiable(days);
}
```

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/features/work/domain`
Expected: PASS. If the daylight-saving test fails, check that `toInstants(...).first` is used for every instant (gap → first valid instant, overlap → first occurrence).

- [ ] **Step 5: Commit**

```bash
git add lib/features/work/domain/day_exception.dart lib/features/work/domain/planner.dart test/features/work/domain/planner_test.dart
git commit -m "feat: plan days from schedules and per-day exceptions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Planned pay, leave pay and agreement leave terms

Spec §3.7, §4.1, §4.3. Review Focus 5.

**Files:**
- Modify: `lib/features/work/domain/agreement.dart`
- Create: `lib/features/work/domain/leave.dart`
- Modify: `lib/features/work/domain/planner.dart` (add `plannedPay`)
- Test: `test/features/work/domain/leave_test.dart`, `test/features/work/domain/planner_test.dart`

**Interfaces:**
- Consumes: `PlannedShift`, `segmentPaidTime(…, overtime: const NoOvertime())`, `calculateExpectedPay`, `roundHalfUpRatio`, `resolveAgreement`.
- Produces:
  - `PayAgreement` gains `RationalMultiplier vacationPay` (default `1/1`), `RationalMultiplier sickPay` (default `3103/5000`), `int sickEmployerDays` (default `2`); `AgreementDefaults.vacationPay/sickPay/sickEmployerDays`. `withRangeEnd` copies them. Validation: `sickEmployerDays` 0..30.
  - `ExpectedPay? plannedPay(PlannedShift shift, {required Iterable<PayAgreement> agreements, required EmploymentId employmentId, required ZoneClocks zoneClocks})` — null when no single agreement is in effect on the date.
  - `enum LeaveState { confirmed, voided }`; `final class LeaveRecord` (fields in spec §3.6) with `bool get isEffective`.
  - `final class WorkedPay { LocalDate date; int paidSeconds; Money pay; }`.
  - `final class LeavePay { Money amount; int paidSeconds; RationalMultiplier? factor; bool employerPaid; bool usedFallback; ({int minorUnits, int paidSeconds})? average; }`.
  - `Map<LeaveRecordId, LeavePay> priceLeave({required List<LeaveRecord> leave, required List<WorkedPay> worked, required Iterable<PayAgreement> agreements})` — effective leave only, oldest first, each average including earlier priced leave.
  - `LocalDate defaultIllnessStart(LocalDate date, {required bool Function(LocalDate) isSick, required bool Function(LocalDate) isOff})`.

- [ ] **Step 1: Failing tests**

Create `test/features/work/domain/leave_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/features/work/domain/pay.dart';

void main() {
  test('vacation pays the 3-month average hourly earnings in full', () {
    final priced = priceLeave(
      leave: [leaveOn(const LocalDate(2026, 10, 7), LeaveType.vacation)],
      worked: [
        // July–September: 100 h earning EUR 2,500.00 → EUR 25.00 an hour.
        WorkedPay(date: const LocalDate(2026, 7, 10), paidSeconds: 60 * 3600, pay: const Money(minorUnits: 150000)),
        WorkedPay(date: const LocalDate(2026, 9, 30), paidSeconds: 40 * 3600, pay: const Money(minorUnits: 100000)),
        // October and June are outside the window.
        WorkedPay(date: const LocalDate(2026, 10, 1), paidSeconds: 10 * 3600, pay: const Money(minorUnits: 99900)),
        WorkedPay(date: const LocalDate(2026, 6, 30), paidSeconds: 10 * 3600, pay: const Money(minorUnits: 99900)),
      ],
      agreements: [agreement()],
    );
    final pay = priced.values.single;
    // 11:30 × EUR 25.00.
    expect(pay.amount.minorUnits, 28750);
    expect(pay.usedFallback, isFalse);
  });

  test('with no work in the window the agreement rate is used, and said', () {
    final pay = priceLeave(
      leave: [leaveOn(const LocalDate(2026, 10, 7), LeaveType.vacation)],
      worked: const [],
      agreements: [agreement()],
    ).values.single;
    expect(pay.usedFallback, isTrue);
    // 11:30 × EUR 18.40.
    expect(pay.amount.minorUnits, 21160);
  });

  test('sick leave pays 62.06 % for the first two days of an illness only', () {
    final worked = [
      WorkedPay(date: const LocalDate(2026, 9, 1), paidSeconds: 100 * 3600, pay: const Money(minorUnits: 250000)),
    ];
    final priced = priceLeave(
      leave: [
        leaveOn(const LocalDate(2026, 10, 5), LeaveType.sick, illness: const LocalDate(2026, 10, 4), id: 'a'),
        leaveOn(const LocalDate(2026, 10, 6), LeaveType.sick, illness: const LocalDate(2026, 10, 4), id: 'b'),
      ],
      worked: worked,
      agreements: [agreement()],
    );
    // Day 2 of the illness: 11:30 × 25.00 × 0.6206 = 178.4225 → 178.42.
    expect(priced[id('a')]!.amount.minorUnits, 17842);
    expect(priced[id('a')]!.employerPaid, isTrue);
    // Day 3: paid by the social insurer, not on the payslip.
    expect(priced[id('b')]!.amount.minorUnits, 0);
    expect(priced[id('b')]!.employerPaid, isFalse);
  });

  test('an illness starts at the first sick day, across Off days only', () {
    final sick = {const LocalDate(2026, 10, 1), const LocalDate(2026, 10, 2), const LocalDate(2026, 10, 7)};
    final off = {
      for (var d = 3; d <= 6; d++) LocalDate(2026, 10, d),
    };
    expect(
      defaultIllnessStart(
        const LocalDate(2026, 10, 7),
        isSick: sick.contains,
        isOff: off.contains,
      ),
      const LocalDate(2026, 10, 1),
    );
    // A worked day in between ends the run.
    expect(
      defaultIllnessStart(
        const LocalDate(2026, 10, 7),
        isSick: sick.contains,
        isOff: (date) => off.contains(date) && date != const LocalDate(2026, 10, 4),
      ),
      const LocalDate(2026, 10, 7),
    );
  });
}

LeaveRecordId id(String suffix) => LeaveRecordId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4f0$suffix');

LeaveRecord leaveOn(
  LocalDate date,
  LeaveType type, {
  LocalDate? illness,
  String id = '1',
}) => LeaveRecord(
  id: LeaveRecordId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4f0$id'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  date: date,
  leaveType: type,
  illnessStartedOn: illness,
  paidMinutes: 11 * 60 + 30,
  agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  scheduleId: const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d01'),
  scheduleVersion: 1,
  state: LeaveState.confirmed,
  voidReason: null,
  replacementId: null,
  replacedId: null,
  createdAtUtc: DateTime.utc(2026, 10),
  updatedAtUtc: DateTime.utc(2026, 10),
  revision: const Revision(0),
);

PayAgreement agreement() => PayAgreement(
  id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  version: 1,
  effectiveStart: const LocalDate(2026, 1, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 18400000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
```

Append to `planner_test.dart`:

```dart
  test('planned pay prices night time but never overtime', () {
    final night = plan(
      const LocalDate(2026, 10, 11),
      const LocalDate(2026, 10, 11),
    ).single as PlannedShift;
    final pay = plannedPay(
      night,
      agreements: [agreementForPlan()],
      employmentId: employment,
      zoneClocks: testZoneClocks,
    )!;
    expect(pay.overtimePaidSeconds, 0);
    // 22:00–06:00 minus the 00:00 break: 7:30 of night time.
    expect(pay.nightPaidSeconds, (7 * 60 + 30) * 60);
  });
```

with `agreementForPlan()` returning the same agreement as `leave_test.dart`'s `agreement()` (copy it).

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/domain/leave_test.dart test/features/work/domain/planner_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

`agreement.dart`: add to `AgreementDefaults`

```dart
  /// Vacation pays the full average (spec 4.3).
  static const vacationPay = RationalMultiplier(numerator: 1, denominator: 1);

  /// The employer pays 62.06 % of the average for the first sick days.
  static const sickPay = RationalMultiplier(numerator: 3103, denominator: 5000);
  static const sickEmployerDays = 2;
```

and to `PayAgreement`: constructor params `this.vacationPay = AgreementDefaults.vacationPay`, `this.sickPay = AgreementDefaults.sickPay`, `this.sickEmployerDays = AgreementDefaults.sickEmployerDays`; fields with doc comments; validation `if (sickEmployerDays < 0 || sickEmployerDays > 30) throw ArgumentError.value(sickEmployerDays, 'sickEmployerDays');`; pass all three through `withRangeEnd`. Add the same three (with defaults) to `AgreementTerms` in `lib/features/work/application/work_commands.dart` and pass them where `AgreementTerms` builds a `PayAgreement` (`agreement_service.dart`; grep `overtimeMultiplier: terms.overtimeMultiplier` to find each spot).

Create `lib/features/work/domain/leave.dart`:

```dart
import '../../../core/time/local_date.dart';
import 'agreement.dart';
import 'day_exception.dart';
import 'facts.dart';
import 'ids.dart';
import 'pay.dart';

enum LeaveState { confirmed, voided }

/// A confirmed leave day (schedules spec 3.6).
final class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.employmentId,
    required this.date,
    required this.leaveType,
    required this.illnessStartedOn,
    required this.paidMinutes,
    required this.agreementId,
    required this.scheduleId,
    required this.scheduleVersion,
    required this.state,
    required this.voidReason,
    required this.replacementId,
    required this.replacedId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  }) {
    if (paidMinutes <= 0) throw ArgumentError.value(paidMinutes, 'paidMinutes');
    if (leaveType != LeaveType.sick && illnessStartedOn != null) {
      throw ArgumentError.value(illnessStartedOn, 'illnessStartedOn');
    }
    if (state == LeaveState.voided &&
        (voidReason?.trim().isEmpty != false || replacementId == null)) {
      throw ArgumentError('Voided leave requires a reason and replacement.');
    }
  }

  final LeaveRecordId id;
  final EmploymentId employmentId;
  final LocalDate date;
  final LeaveType leaveType;
  final LocalDate? illnessStartedOn;
  final int paidMinutes;
  final AgreementId agreementId;
  final ScheduleId scheduleId;
  final int scheduleVersion;
  final LeaveState state;
  final String? voidReason;
  final LeaveRecordId? replacementId;
  final LeaveRecordId? replacedId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  bool get isEffective => state == LeaveState.confirmed;
}

/// A confirmed worked day's paid time and expected pay, for averages.
final class WorkedPay {
  const WorkedPay({
    required this.date,
    required this.paidSeconds,
    required this.pay,
  });

  final LocalDate date;
  final int paidSeconds;
  final Money pay;
}

/// How one leave day is priced, with what Working shows.
final class LeavePay {
  const LeavePay({
    required this.amount,
    required this.paidSeconds,
    required this.factor,
    required this.employerPaid,
    required this.usedFallback,
    required this.average,
  });

  final Money amount;
  final int paidSeconds;

  /// The agreement's percent, as a fraction; null when the employer does
  /// not pay this day.
  final RationalMultiplier? factor;
  final bool employerPaid;

  /// No confirmed paid time in the 3 months before: the agreement rate.
  final bool usedFallback;

  /// The window's totals behind the average, when not a fallback.
  final ({int minorUnits, int paidSeconds})? average;
}

/// Prices every effective leave record, oldest first, so a leave day's
/// average includes earlier priced leave (spec 4.3).
Map<LeaveRecordId, LeavePay> priceLeave({
  required List<LeaveRecord> leave,
  required List<WorkedPay> worked,
  required Iterable<PayAgreement> agreements,
}) {
  final byId = {for (final value in agreements) value.id: value};
  final ordered = [
    for (final item in leave)
      if (item.isEffective) item,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final priced = <LeaveRecordId, LeavePay>{};
  final pricedLeave = <WorkedPay>[];
  for (final item in ordered) {
    final agreement = byId[item.agreementId];
    if (agreement == null) continue;
    final windowStart = item.date.firstOfMonth.addMonths(-3);
    final windowEnd = item.date.firstOfMonth.addDays(-1);
    var minor = 0;
    var seconds = 0;
    for (final day in [...worked, ...pricedLeave]) {
      if (day.date.compareTo(windowStart) >= 0 &&
          day.date.compareTo(windowEnd) <= 0 &&
          day.paidSeconds > 0) {
        minor += day.pay.minorUnits;
        seconds += day.paidSeconds;
      }
    }
    final paidSeconds = item.paidMinutes * 60;
    final factor = switch (item.leaveType) {
      LeaveType.vacation => agreement.vacationPay,
      LeaveType.sick
          when item.date.daysSince(item.illnessStartedOn ?? item.date) <
              agreement.sickEmployerDays =>
        agreement.sickPay,
      LeaveType.sick => null,
    };
    final fallback = seconds == 0;
    final amount = factor == null
        ? 0
        : fallback
        // micro-EUR per hour → cents: ÷ 3600 s ÷ 10 000.
        ? roundHalfUpRatio(
            BigInt.from(paidSeconds) *
                BigInt.from(agreement.hourlyRateMicroEur) *
                BigInt.from(factor.numerator),
            BigInt.from(3600 * 10000) * BigInt.from(factor.denominator),
          )
        : roundHalfUpRatio(
            BigInt.from(paidSeconds) *
                BigInt.from(minor) *
                BigInt.from(factor.numerator),
            BigInt.from(seconds) * BigInt.from(factor.denominator),
          );
    final pay = LeavePay(
      amount: Money(minorUnits: amount),
      paidSeconds: paidSeconds,
      factor: factor,
      employerPaid: factor != null,
      usedFallback: fallback,
      average: fallback ? null : (minorUnits: minor, paidSeconds: seconds),
    );
    priced[item.id] = pay;
    if (factor != null) {
      pricedLeave.add(
        WorkedPay(date: item.date, paidSeconds: paidSeconds, pay: pay.amount),
      );
    }
  }
  return priced;
}

/// The default start of the illness [date] belongs to: the earliest sick
/// day of a run ending at [date] in which only Off days separate the sick
/// days (spec 4.3). Looks back at most a year.
LocalDate defaultIllnessStart(
  LocalDate date, {
  required bool Function(LocalDate) isSick,
  required bool Function(LocalDate) isOff,
}) {
  var start = date;
  for (var back = 1; back <= 366; back++) {
    final day = date.addDays(-back);
    if (isSick(day)) {
      start = day;
    } else if (!isOff(day)) {
      break;
    }
  }
  return start;
}
```

(`roundHalfUpRatio` lives in `pay.dart`; if it is private there, make it public and keep its existing callers.)

`planner.dart`: add

```dart
/// A planned shift's pay: night and holiday premiums, never overtime
/// (spec 4.1). Null when no single agreement is in effect on its date.
ExpectedPay? plannedPay(
  PlannedShift shift, {
  required Iterable<PayAgreement> agreements,
  required EmploymentId employmentId,
  required ZoneClocks zoneClocks,
}) {
  final resolution = resolveAgreement(
    employmentId: employmentId,
    localStartDate: shift.date,
    agreements: agreements,
  );
  if (resolution is! ResolvedAgreement) return null;
  final agreement = resolution.agreement;
  final clock = zoneClocks(shift.timezoneId);
  final paid = <Span>[];
  var from = shift.startUtc;
  for (final item in shift.breaks) {
    if (item.start.isAfter(from)) paid.add((start: from, end: item.start));
    from = item.end;
  }
  if (shift.endUtc.isAfter(from)) paid.add((start: from, end: shift.endUtc));
  return calculateExpectedPay(
    segments: segmentPaidTime(
      paidIntervals: paid,
      agreement: agreement,
      toLocal: clock.toLocal,
      toInstants: clock.toInstants,
      overtime: const NoOvertime(),
    ),
    hourlyRateMicroEur: agreement.hourlyRateMicroEur,
    agreement: agreement,
    currency: const CurrencyCode.eur(),
  );
}
```

with imports `agreement.dart`, `pay.dart`.

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/features/work`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work test/features/work
git commit -m "feat: price planned shifts and leave from the 3-month average

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Schema 3, backup and migration

Spec §3.1–§3.8 (storage), §8 Data. Review Focus 1.

**Files:**
- Create: `test/core/database/fixtures/schema_v1.sql` (captured **before** any table edit)
- Modify: `lib/features/work/data/work_tables.dart`, `lib/core/database/app_database.dart` (regenerate `app_database.g.dart`)
- Modify: `lib/core/database/schema_versions.dart`, `migration_strategy.dart`, `database_service.dart`
- Modify: `tool/schema_check.dart`; create `drift_schemas/schema_v3.json`
- Modify: `lib/features/work/data/work_converters.dart`
- Test: `test/core/database/migration_test.dart`, `test/core/database/schedule_migration_test.dart` (new)

**Interfaces:**
- Produces: Drift tables `WorkSchedules`, `WorkScheduleShiftTypes`, `WorkScheduleBlocks`, `WorkDayExceptions`, `WorkLeaveRecords`; new `WorkShifts` and `PayAgreements` columns (below); `currentSchemaVersion == 3`; the backup file `<database>.v1-backup-<yyyyMMddTHHmmssZ>.sqlite`.

- [ ] **Step 1: Capture the version-1 DDL fixture (before touching tables)**

Create a throwaway test `test/core/database/capture_v1_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('capture v1 DDL', () async {
    final raw = sqlite.sqlite3.openInMemory();
    final database = AppDatabase(NativeDatabase.opened(raw));
    await database.customSelect('SELECT 1').getSingle();
    final ddl = raw
        .select(
          "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL "
          "AND name NOT LIKE 'sqlite_%' ORDER BY type DESC, name",
        )
        .map((row) => '${row['sql']};')
        .join('\n');
    File('test/core/database/fixtures/schema_v1.sql')
      ..createSync(recursive: true)
      ..writeAsStringSync('$ddl\n');
    await database.close();
  });
}
```

Run: `$F/flutter test test/core/database/capture_v1_test.dart`, check `test/core/database/fixtures/schema_v1.sql` contains `CREATE TABLE "work_shifts"` and `CREATE UNIQUE INDEX one_active_shift`, then delete `capture_v1_test.dart`. Commit the fixture on its own:

```bash
git add test/core/database/fixtures/schema_v1.sql
git commit -m "test: capture the released schema 1 DDL as a fixture

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Failing migration tests**

Create `test/core/database/schedule_migration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../support/owned_test_root.dart';

/// A released schema-1 database with synthetic records, as an owner
/// would have it before upgrading.
File releasedV1(OwnedTestRoot root) {
  final file = File.fromUri(root.uri.resolve('lifeos-native-v1.sqlite'));
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute('PRAGMA application_id = $lifeOsApplicationId');
  raw.execute(File('test/core/database/fixtures/schema_v1.sql').readAsStringSync());
  raw.execute('INSERT INTO core_metadata (id) VALUES (1)');
  raw.execute(
    "INSERT INTO employments VALUES ('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', 'Synthetic depot', NULL, "
    "'active', 0, 0, 0)",
  );
  raw.execute(
    "INSERT INTO pay_agreements (id, employment_id, version, effective_start, "
    "effective_end, hourly_rate_micro_eur, basis, overtime_threshold_minutes, "
    "overtime_multiplier_numerator, overtime_multiplier_denominator, "
    "night_enabled, night_start_minute, night_end_minute, "
    "night_multiplier_numerator, night_multiplier_denominator, "
    "holiday_calendar, holiday_multiplier_numerator, "
    "holiday_multiplier_denominator, premium_stacking, label, note, "
    "created_at_utc_micros, revision) VALUES ('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', 1, '2026-09-01', "
    "NULL, 18400000, 'gross', 480, 3, 2, 1, 1320, 360, 3, 2, 'lithuania', "
    "2, 1, 'highest', NULL, NULL, 0, 0)",
  );
  raw.execute(
    "INSERT INTO work_shifts (id, employment_id, agreement_id, state, "
    "start_utc_micros, end_utc_micros, timezone_id, local_start_date, note, "
    "void_reason, replacement_shift_id, replaced_shift_id, "
    "created_at_utc_micros, updated_at_utc_micros, revision) VALUES "
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21', 'finalized', 1788753600000000, 1788782400000000, "
    "'Europe/Vilnius', "
    "'2026-09-07', NULL, NULL, NULL, NULL, 0, 0, 2), "
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', NULL, "
    "'onBreak', 1788840000000000, NULL, 'Europe/Vilnius', "
    "'2026-09-08', NULL, NULL, NULL, NULL, 0, 0, 3)",
  );
  raw.execute(
    "INSERT INTO shift_breaks VALUES "
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32', "
    "1788854400000000, 1788856200000000, 0, 0, 1), "
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c52', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32', "
    "1788865200000000, NULL, 0, 0, 0)",
  );
  raw.userVersion = 1;
  raw.close();
  return file;
}

void main() {
  test('a released schema-1 database is backed up, then migrated to 3', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = releasedV1(root);

    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(service.close);

    final raw = service.database;
    final shifts = await raw
        .customSelect('SELECT id, state, end_utc_micros FROM work_shifts ORDER BY id')
        .get();
    expect(shifts.map((row) => row.data['state']), ['finalized', 'draft']);
    expect(shifts.last.data['end_utc_micros'], isNull);
    final breaks = await raw
        .customSelect('SELECT id FROM shift_breaks ORDER BY id')
        .get();
    // The unfinished break is dropped; the finished one is kept.
    expect(breaks.map((row) => row.data['id']), ['018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51']);
    final agreement = await raw
        .customSelect(
          'SELECT sick_pay_numerator, sick_pay_denominator, sick_employer_days '
          'FROM pay_agreements',
        )
        .getSingle();
    expect(agreement.data, {
      'sick_pay_numerator': 3103,
      'sick_pay_denominator': 5000,
      'sick_employer_days': 2,
    });
    for (final table in [
      'work_schedules',
      'work_schedule_shift_types',
      'work_schedule_blocks',
      'work_day_exceptions',
      'work_leave_records',
    ]) {
      final found = await raw
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(table)],
          )
          .get();
      expect(found, hasLength(1), reason: table);
    }

    final backups = root.directory
        .listSync()
        .whereType<File>()
        .where((value) => value.path.contains('.v1-backup-'))
        .toList();
    expect(backups, hasLength(1));
    final backup = sqlite.sqlite3.open(backups.single.path, mode: sqlite.OpenMode.readOnly);
    addTearDown(backup.close);
    expect(backup.userVersion, 1);
    expect(
      backup
          .select("SELECT state FROM work_shifts WHERE id = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32'")
          .single['state'],
      'onBreak',
    );
    expect(file.existsSync(), isTrue);

    // The migrated records load through the app's own repository.
    final register = await DriftWorkRepository(service.database)
        .watchRegister(
          const WorkScope(
            employmentId: EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
            temporal: DateRangeScope(
              start: LocalDate(2026, 9, 1),
              end: LocalDate(2026, 9, 30),
            ),
          ),
        )
        .first;
    expect(register.shiftRows, hasLength(2));
  });

  test('a fresh database starts at 3 with no active-shift index', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(service.close);
    final version = await service.database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 3);
    final index = await service.database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'one_active_shift'",
        )
        .get();
    expect(index, isEmpty);
  });
}
```

Copy `_locationFor` from `test/core/database/migration_test.dart` (same body) and add the imports `package:drift/drift.dart` (`show Variable`), `package:lifeos/core/time/local_date.dart`, `package:lifeos/features/work/data/work_repository.dart`, `package:lifeos/features/work/data/projections/work_register_projection.dart` and `package:lifeos/features/work/domain/ids.dart`. If `OwnedTestRoot` has no `directory` getter, use `Directory.fromUri(root.uri)`.

In `test/core/database/migration_test.dart`:
- The first test iterates `releasedMigrationFingerprints.keys` instead of `1..currentSchemaVersion`, and expects `currentSchemaVersion == 3` and keys `{1, 3}`.
- "a fresh database is created at version one…" becomes "…at version three…": `expect(raw.userVersion, 3)`, and expects the `one_active_shift` index to be **absent**.
- The loop `for (final version in [1, 2])` "is refused, not migrated" becomes `[2]` only, plus keep the two "earlier development build" shape tests (they stay refused: a version-1 file without the released tables is not the released schema).

- [ ] **Step 3: Run to verify failure**

Run: `$F/flutter test test/core/database`
Expected: FAIL (version 1, no new tables, no backup).

- [ ] **Step 4: Tables**

Append to `lib/features/work/data/work_tables.dart`:

```dart
class WorkSchedules extends Table {
  TextColumn get id => text()();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get timezoneId => text()();
  TextColumn get cycleStart => text()();
  TextColumn get inUseFrom => text()();
  TextColumn get inUseUntil => text().nullable()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id, version};

  @override
  List<String> get customConstraints => [
    'CHECK (in_use_until IS NULL OR in_use_until >= in_use_from)',
  ];
}

class WorkScheduleShiftTypes extends Table {
  TextColumn get scheduleId => text()();
  IntColumn get scheduleVersion => integer()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  IntColumn get startMinute => integer().check(
    const CustomExpression<bool>('start_minute BETWEEN 0 AND 1439'),
  )();
  IntColumn get endMinute => integer().check(
    const CustomExpression<bool>('end_minute BETWEEN 0 AND 1439'),
  )();
  IntColumn get endDayOffset => integer().check(
    const CustomExpression<bool>('end_day_offset IN (0, 1)'),
  )();

  /// "dayOffset:minuteOfDay:minutes" per break, joined by ";".
  TextColumn get breaks => text()();

  @override
  Set<Column<Object>> get primaryKey => {scheduleId, scheduleVersion, id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (schedule_id, schedule_version) '
        'REFERENCES work_schedules (id, version) ON DELETE CASCADE',
  ];
}

class WorkScheduleBlocks extends Table {
  TextColumn get scheduleId => text()();
  IntColumn get scheduleVersion => integer()();
  IntColumn get position => integer()();
  IntColumn get count => integer().check(
    const CustomExpression<bool>('count BETWEEN 1 AND 99'),
  )();

  /// Null for Off.
  TextColumn get shiftTypeId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {scheduleId, scheduleVersion, position};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (schedule_id, schedule_version) '
        'REFERENCES work_schedules (id, version) ON DELETE CASCADE',
  ];
}

class WorkDayExceptions extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get date => text()();
  TextColumn get kind => text().check(
    const CustomExpression<bool>(
      "kind IN ('changed', 'cancelled', 'leave', 'extra')",
    ),
  )();
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();
  IntColumn get endDayOffset => integer().nullable()();
  TextColumn get breaks => text().nullable()();
  TextColumn get shiftTypeId => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get leaveType => text().nullable()();
  TextColumn get illnessStartedOn => text().nullable()();
  BoolColumn get countsAsOvertime =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (employment_id, date)'];
}

class WorkLeaveRecords extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get date => text()();
  TextColumn get leaveType => text().check(
    const CustomExpression<bool>("leave_type IN ('vacation', 'sick')"),
  )();
  TextColumn get illnessStartedOn => text().nullable()();
  IntColumn get paidMinutes =>
      integer().check(const CustomExpression<bool>('paid_minutes > 0'))();
  TextColumn get agreementId =>
      text().references(PayAgreements, #id, onDelete: KeyAction.restrict)();
  TextColumn get scheduleId => text()();
  IntColumn get scheduleVersion => integer()();
  TextColumn get state => text().check(
    const CustomExpression<bool>("state IN ('confirmed', 'voided')"),
  )();
  TextColumn get voidReason => text().nullable()();
  TextColumn get replacementLeaveId => text().nullable().references(
    WorkLeaveRecords,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get replacedLeaveId => text().nullable().references(
    WorkLeaveRecords,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Add to `WorkShifts` (all nullable or defaulted, so `ALTER TABLE ADD COLUMN` works):

```dart
  /// The schedule a confirmed day was planned from (spec 3.6).
  TextColumn get scheduleId => text().nullable()();
  IntColumn get scheduleVersion => integer().nullable()();
  TextColumn get plannedDate => text().nullable()();
  IntColumn get plannedStartUtcMicros => integer().nullable()();
  IntColumn get plannedEndUtcMicros => integer().nullable()();
  BoolColumn get isExtra => boolean().withDefault(const Constant(false))();
  BoolColumn get extraCountsAsOvertime =>
      boolean().withDefault(const Constant(false))();
```

Add to `PayAgreements`:

```dart
  IntColumn get vacationPayNumerator =>
      integer().withDefault(const Constant(1))();
  IntColumn get vacationPayDenominator =>
      integer().withDefault(const Constant(1))();
  IntColumn get sickPayNumerator =>
      integer().withDefault(const Constant(3103))();
  IntColumn get sickPayDenominator =>
      integer().withDefault(const Constant(5000))();
  IntColumn get sickEmployerDays =>
      integer().withDefault(const Constant(2))();
```

Register the five tables in `@DriftDatabase(tables: [...])` in `app_database.dart` (after `Payslips`). Run `$F/dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Schema version, migration and backup**

`schema_versions.dart`:

```dart
/// The schema history was reset before the first release (2026-10-01):
/// version 1 is the first released schema. Version 2 was only ever written
/// by development builds before the reset and is never reused; schedules
/// (2026-10-02) are version 3.
const currentSchemaVersion = 3;

const releasedMigrationFingerprints = <int, String>{
  1: '573e0c481060d530f055a826876ea5fab6bb73d95d9a87acb2b996993bd169a0',
  3: '<sha256 of drift_schemas/schema_v3.json, filled in Step 6>',
};
```

`migration_strategy.dart`:

```dart
MigrationStrategy lifeOsMigrationStrategy(AppDatabase database) {
  Future<void> scheduleIndexes() async {
    await database.customStatement(
      'CREATE UNIQUE INDEX one_confirmed_shift_per_planned_day '
      'ON work_shifts (employment_id, planned_date) '
      "WHERE planned_date IS NOT NULL AND state = 'finalized'",
    );
    await database.customStatement(
      'CREATE UNIQUE INDEX one_confirmed_leave_per_day '
      'ON work_leave_records (employment_id, date) '
      "WHERE state = 'confirmed'",
    );
  }

  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await scheduleIndexes();
      await database.customStatement(
        'CREATE INDEX record_events_by_record '
        'ON record_events (record_kind, record_id, id)',
      );
      await database
          .into(database.coreMetadata)
          .insert(const CoreMetadataCompanion(id: Value(1)));
    },
    // The released schema 1 moves to 3 (schedules). Anything else is from
    // a development build and was refused before Drift opened it.
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 3) {
        throw DatabaseFromEarlierBuild(from: from, to: to);
      }
      for (final table in [
        database.workSchedules,
        database.workScheduleShiftTypes,
        database.workScheduleBlocks,
        database.workDayExceptions,
        database.workLeaveRecords,
      ]) {
        await migrator.createTable(table);
      }
      final shifts = database.workShifts;
      for (final column in [
        shifts.scheduleId,
        shifts.scheduleVersion,
        shifts.plannedDate,
        shifts.plannedStartUtcMicros,
        shifts.plannedEndUtcMicros,
        shifts.isExtra,
        shifts.extraCountsAsOvertime,
      ]) {
        await migrator.addColumn(shifts, column);
      }
      final agreements = database.payAgreements;
      for (final column in [
        agreements.vacationPayNumerator,
        agreements.vacationPayDenominator,
        agreements.sickPayNumerator,
        agreements.sickPayDenominator,
        agreements.sickEmployerDays,
      ]) {
        await migrator.addColumn(agreements, column);
      }
      // The live tracker is gone (spec 3.8): a shift still running becomes
      // a draft to finish by hand; an unfinished break is dropped.
      await database.customStatement(
        'DELETE FROM shift_breaks WHERE end_utc_micros IS NULL',
      );
      await database.customStatement(
        "UPDATE work_shifts SET state = 'draft' "
        "WHERE state IN ('running', 'onBreak')",
      );
      await database.customStatement('DROP INDEX IF EXISTS one_active_shift');
      await scheduleIndexes();
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

`database_service.dart`:
- Replace `_isFromEarlierBuild` with:

```dart
  /// Version 1 is the released schema and is migrated; version 2 was only
  /// written by development builds before the reset and is refused, as is
  /// a version-1 file missing anything the released schema had.
  static bool _isFromEarlierBuild(sqlite.Database raw) {
    final version = raw.userVersion;
    if (version == 0 || version == currentSchemaVersion) return false;
    if (version != 1) return true;
    final tables = raw
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'])
        .toSet();
    if (!tables.containsAll(const [
      'record_events',
      'desks',
      'desk_tiles',
      'saved_views',
      'preferences',
    ])) {
      return true;
    }
    final columns = raw
        .select('PRAGMA table_info(pay_agreements)')
        .map((row) => row['name'])
        .toSet();
    return !columns.contains('premium_stacking');
  }
```

- In `open`, after `_validateExistingIdentity(file);`, back up a released schema-1 file before Drift migrates it:

```dart
    if (!wasEmpty) {
      // Throws DatabaseFromEarlierBuild for anything that is not migrated.
      _validateExistingIdentity(file);
      await _backUpBeforeUpgrade(file);
    }
```

and add:

```dart
  /// Copies a database written by an older released schema next to itself
  /// before it is migrated, so an upgrade can always be undone by hand.
  static Future<void> _backUpBeforeUpgrade(File file) async {
    final source = sqlite.sqlite3.open(
      file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final version = source.userVersion;
      if (version == 0 || version >= currentSchemaVersion) return;
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[-:]'), '')
          .split('.')
          .first;
      final target = sqlite.sqlite3.open(
        '${file.path}.v$version-backup-${stamp}Z.sqlite',
      );
      try {
        await source.backup(target).drain<void>();
      } finally {
        target.close();
      }
    } finally {
      source.close();
    }
  }
```

(`createSnapshot` in the same file already uses the backup API this way; match it if its call differs.)

- [ ] **Step 6: Schema snapshot and checker**

`tool/schema_check.dart`: import `package:lifeos/core/database/schema_versions.dart`; dump to `${temp.path}/schema.json` and compare with `drift_schemas/schema_v$currentSchemaVersion.json` (message "Committed schema v$currentSchemaVersion snapshot is missing/stale").

Write the snapshot and its fingerprint:

```bash
$F/dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/schema_v3.json
sha256sum drift_schemas/schema_v3.json
```

Put the hash into `releasedMigrationFingerprints[3]`. Keep `drift_schemas/schema_v1.json` unchanged.

- [ ] **Step 7: Converters for the new columns**

`work_converters.dart`:
- `shiftToCompanion` writes the link columns from `value.schedule` (Task 6 adds `ScheduleLink` to `WorkShift`; in this task write them as `const Value(null)` / `Value(false)` so the file compiles, and Task 6 fills them).
- `agreementToCompanion` / `agreementFromRow` write and read the five leave columns into `vacationPay`, `sickPay`, `sickEmployerDays`.
- Add break codec helpers used by Task 7:

```dart
/// "dayOffset:minuteOfDay:minutes;…" ↔ breaks.
String encodeBreaks(List<FixedBreak> breaks) => breaks
    .map((item) => '${item.dayOffset}:${item.start.hour * 60 + item.start.minute}:${item.minutes}')
    .join(';');

List<FixedBreak> decodeBreaks(String text) => [
  for (final part in text.split(';'))
    if (part.isNotEmpty)
      () {
        final [offset, minute, minutes] = part.split(':').map(int.parse).toList();
        return FixedBreak(
          start: LocalTime(minute ~/ 60, minute % 60),
          dayOffset: offset,
          minutes: minutes,
        );
      }(),
];
```

with a round-trip test in `test/features/work/data/work_converters_test.dart` (create if absent):

```dart
  test('breaks round-trip through their text form', () {
    const breaks = [
      FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30),
      FixedBreak(start: LocalTime(0, 15), dayOffset: 1, minutes: 20),
    ];
    expect(encodeBreaks(breaks), '0:720:30;1:15:20');
    expect(decodeBreaks(encodeBreaks(breaks)), breaks);
    expect(decodeBreaks(''), isEmpty);
  });
```

- [ ] **Step 8: Run tests**

```bash
$F/flutter test test/core/database test/features/work/data
$F/dart run tool/schema_check.dart
$F/flutter test
```

Expected: PASS; schema check exits 0.

- [ ] **Step 9: Commit**

```bash
git add lib/core/database lib/features/work/data drift_schemas tool test
git commit -m "feat: migrate the database to schema 3 for schedules, with a backup

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Remove the live tracker; link shifts to schedules

Spec §3.6, §3.8, §4.2.

**Files (each found by `grep -rln "ShiftState.running\|ShiftState.onBreak\|onBreak\|RowState.running\|workActiveShiftProvider\|watchActiveShift\|RunningShift\|startShift\|startBreak\|endBreak\|endShift" lib test`):**
- Modify: `lib/features/work/domain/shift.dart`
- Modify: `lib/features/work/application/shift_lifecycle_service.dart` (keep finalize and correct; delete start, break and end), `work_query_service.dart`
- Modify: `lib/features/work/data/{shift_repository,work_repository,work_converters}.dart`, `daos/shift_dao.dart`
- Modify: `lib/features/work/presentation/{shift_forms,work_inspector,work_screen,work_sheets,work_controller,work_desk_tiles}.dart`, `lib/shared/workbench/data_register.dart`, `lib/shared/shell/status_line.dart`, `lib/app/{shell_host,app_router,production_work_providers}.dart`, `lib/features/journal/journal_projection.dart`
- Delete: `test/features/work/application/shift_lifecycle_service_test.dart` cases for start/break/end, `test/features/work/presentation/live_shift_workflow_test.dart`
- Test: `test/features/work/domain/shift_test.dart`, `test/features/work/domain/overtime_link_test.dart` (new)

**Interfaces:**
- Produces:
  - `enum ShiftState { draft, finalized, voided }`.
  - `final class ScheduleLink({required ScheduleId scheduleId, required int scheduleVersion, required LocalDate plannedDate, required DateTime plannedStartUtc, required DateTime plannedEndUtc, bool isExtra = false, bool extraCountsAsOvertime = false})`; `WorkShift({…, ScheduleLink? schedule})`; every copy method (`finalizedWith`, `voidedForCorrection`, `revisedFacts`, `replacementDraft`) carries `schedule`.
  - `FinalizationFacts.overtimeRule → OvertimeRule`, used by `expectedPay`.
  - `StatusSnapshot` without `runningShift`; `RowState` without `running`.

- [ ] **Step 1: Failing test**

Create `test/features/work/domain/overtime_link_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_premiums.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../../support/zone_clocks.dart';

void main() {
  WorkShift shift({ScheduleLink? link, required DateTime end}) => WorkShift(
    id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
    employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
    agreementId: null,
    state: ShiftState.draft,
    startUtc: DateTime.utc(2026, 9, 15, 4), // 07:00 Vilnius
    endUtc: end,
    timezoneId: 'Europe/Vilnius',
    localStartDate: const LocalDate(2026, 9, 15),
    note: null,
    voidReason: null,
    replacementShiftId: null,
    replacedShiftId: null,
    createdAtUtc: DateTime.utc(2026, 9, 15),
    updatedAtUtc: DateTime.utc(2026, 9, 15),
    revision: const Revision(0),
    schedule: link,
  );

  ExpectedPay pay(WorkShift value) {
    final facts = validateFinalization(
      shift: value,
      breaks: const [],
      agreements: [agreement()],
    ).facts!;
    final clock = testZoneClocks(value.timezoneId);
    return facts.expectedPay(toLocal: clock.toLocal, toInstants: clock.toInstants);
  }

  final link = ScheduleLink(
    scheduleId: const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d01'),
    scheduleVersion: 1,
    plannedDate: const LocalDate(2026, 9, 15),
    plannedStartUtc: DateTime.utc(2026, 9, 15, 4),
    plannedEndUtc: DateTime.utc(2026, 9, 15, 16), // 19:00
  );

  test('a scheduled 12-hour shift worked as planned has no overtime', () {
    expect(pay(shift(link: link, end: DateTime.utc(2026, 9, 15, 16))).overtimePaidSeconds, 0);
  });

  test('a scheduled shift run 45 minutes late has 45 minutes of overtime', () {
    expect(
      pay(shift(link: link, end: DateTime.utc(2026, 9, 15, 16, 45))).overtimePaidSeconds,
      45 * 60,
    );
  });

  test('an unscheduled 12-hour shift keeps the 8-hour threshold', () {
    expect(pay(shift(end: DateTime.utc(2026, 9, 15, 16))).overtimePaidSeconds, 4 * 3600);
  });

  ScheduleLink extra({required bool overtime}) => ScheduleLink(
    scheduleId: link.scheduleId,
    scheduleVersion: 1,
    plannedDate: link.plannedDate,
    plannedStartUtc: link.plannedStartUtc,
    plannedEndUtc: link.plannedEndUtc,
    isExtra: true,
    extraCountsAsOvertime: overtime,
  );

  test('an extra shift marked as overtime is overtime throughout', () {
    expect(
      pay(shift(link: extra(overtime: true), end: DateTime.utc(2026, 9, 15, 10))).overtimePaidSeconds,
      6 * 3600,
    );
  });

  test('an extra shift not marked as overtime has none, even past 8 hours', () {
    expect(
      pay(shift(link: extra(overtime: false), end: DateTime.utc(2026, 9, 15, 16))).overtimePaidSeconds,
      0,
    );
  });

  test('the link survives finalizing and correction', () {
    final finalized = shift(link: link, end: DateTime.utc(2026, 9, 15, 16))
        .finalizedWith(agreement());
    expect(finalized.schedule, link);
    expect(
      finalized
          .replacementDraft(
            replacementId: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32'),
            nowUtc: DateTime.utc(2026, 9, 16),
          )
          .schedule,
      link,
    );
  });
}

PayAgreement agreement() => PayAgreement(
  id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  version: 1,
  effectiveStart: const LocalDate(2026, 1, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 18400000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
```

Give `ScheduleLink` value equality (`==`/`hashCode` over all fields) so `expect(…, link)` works.

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/domain/overtime_link_test.dart`
Expected: compile error (`ScheduleLink`, `schedule:` undefined).

- [ ] **Step 3: Domain**

In `shift.dart`:
- `enum ShiftState { draft, finalized, voided }`; delete the `running || onBreak` constructor case.
- Add `ScheduleLink` (fields as in **Interfaces**, constructor checks both instants are UTC and `plannedEndUtc` is after `plannedStartUtc`, value equality).
- Add `this.schedule` (optional named) and `final ScheduleLink? schedule;` to `WorkShift`; pass `schedule: schedule` in `finalizedWith`, `voidedForCorrection`, `revisedFacts` and `replacementDraft`.
- In `FinalizationFacts` add:

```dart
  /// Which paid time is overtime (schedules spec 4.2): outside the planned
  /// window for a scheduled shift, all or none for an extra, and the
  /// agreement threshold for a shift without a schedule.
  OvertimeRule get overtimeRule => switch (shift.schedule) {
    null => ThresholdOvertime(agreement.overtimeThresholdMinutes * 60),
    ScheduleLink(isExtra: true, extraCountsAsOvertime: true) =>
      const AllOvertime(),
    ScheduleLink(isExtra: true) => const NoOvertime(),
    ScheduleLink(:final plannedStartUtc, :final plannedEndUtc) =>
      WindowOvertime(start: plannedStartUtc, end: plannedEndUtc),
  };
```

and pass `overtime: overtimeRule` to `segmentPaidTime` in `expectedPay`.

- [ ] **Step 4: Data**

- `shift_dao.dart`: delete `active()`/`watchActive()` and anything filtering on running/on-break states.
- `work_converters.dart`: `_shiftState` maps `draft`, `finalized`, `voided` only (anything else is a decode failure). `shiftToCompanion` writes `scheduleId`, `scheduleVersion`, `plannedDate`, `plannedStartUtcMicros`, `plannedEndUtcMicros`, `isExtra`, `extraCountsAsOvertime` from `value.schedule`; `shiftFromRow` reads them back into a `ScheduleLink` when `scheduleId` is not null.
- `shift_repository.dart`: delete `start`, `commitStart`, `activeShift`, `watchActiveShift`, `startBreak`, `commitStartBreak`, `endBreak`, `commitEndBreak`, `endShift`, `commitEndShift`, `_StaleBreakEnd`; keep `finalizeShift`, manual create, draft revision and correction.
- `work_repository.dart`: delete `watchActiveShift` (and the interface method in `work_query_service.dart`).

- [ ] **Step 5: Application and presentation**

- `shift_lifecycle_service.dart`: delete the start, break and end methods, their typedefs and command classes; keep `finalizeShift` and `correctShift`.
- `work_controller.dart`: delete `startShiftProvider`, `startBreakProvider`, `endBreakProvider`, `endShiftProvider`, `workActiveShiftProvider` and any controller method that calls them.
- `production_work_providers.dart`: delete their overrides.
- `shift_forms.dart`: delete `RunningShiftInspector`, `OnBreakShiftInspector`, `_LifecyclePane`; `ShiftCreateInspector` keeps only **Add manual shift** (`KeyButton(kind: KeyKind.primary)`).
- `work_inspector.dart`: delete the `running`/`onBreak` arms and the `onStartBreak`, `onEndBreak`, `onEndShift`, `durationLabel` parameters; `WorkInspector.fromProjection` goes away if only lifecycle code used it.
- `work_screen.dart`, `app_router.dart`: delete `onStartShift`, `onStartBreak`, `onEndBreak`, `onEndShift` plumbing and `_startShift`/`_startFailure`.
- `work_sheets.dart`, `data_register.dart`: delete `RowState.running` and its styling; a draft row still reads "Draft".
- `work_desk_tiles.dart`: the month checklist line "No drafts or running shifts" becomes "No drafts".
- `status_line.dart`: delete `RunningShiftStatus` and `StatusSnapshot.runningShift`; the first (expanding) slot stays empty for Part 2's "days to confirm".
- `shell_host.dart`: delete the active-shift watch, the `running` live value and the `'Start shift'` quick-add entry.
- `journal_projection.dart`: delete the `running`/`onBreak` transitions and the `breakStarted`, `breakEnded`, `shiftEnded` kinds if nothing else produces them.

- [ ] **Step 6: Tests**

- Delete `test/features/work/presentation/live_shift_workflow_test.dart` and the start/break/end cases in `shift_lifecycle_service_test.dart`, `shift_repository_test.dart`, `work_controller_test.dart`, `router_test.dart`, `work_core_flow_test.dart` and `status_line_test.dart`.
- In `shift_test.dart`, replace any running/on-break construction with `draft`.
- Then:

```bash
grep -rn "running\|onBreak\|RunningShift\|startShift\|startBreak\|endBreak\|endShift\|activeShift" lib test | grep -v "// " 
```

Expected: no hits except the migration's SQL in `migration_strategy.dart` and `schedule_migration_test.dart`.

- [ ] **Step 7: Run tests**

Run: `$F/flutter analyze lib test tool && $F/flutter test`
Expected: no issues; all green. Update goldens if the status bar or a tile changed (`$F/flutter test --update-goldens test/goldens`) and look at them.

- [ ] **Step 8: Commit**

```bash
git add -A lib test
git commit -m "refactor: remove the live shift tracker; link shifts to their schedule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Schedule storage and service

Spec §3.1, §6.4 (save rules), §7. Review Focus 4.

**Files:**
- Create: `lib/features/work/data/daos/schedule_dao.dart`
- Create: `lib/features/work/application/schedule_service.dart`
- Create: `lib/features/work/data/schedule_repository.dart` (Drift implementation; Tasks 8–9 add to it)
- Modify: `lib/features/work/application/work_commands.dart` (`ScheduleIdFactory`), `uuid_v7_work_id_factory.dart`, `lib/features/work/data/work_history.dart`
- Test: `test/features/work/application/schedule_service_test.dart`, `test/support/schedule_fixture.dart` (new, shared by Tasks 7–11)

**Interfaces:**
- Consumes: `WorkSchedule`, `validateSchedule`, `scheduleOverlaps`, `encodeBreaks`/`decodeBreaks`.
- Produces:
  - `abstract interface class ScheduleIdFactory { ScheduleId scheduleId(); ShiftTypeId shiftTypeId(); DayExceptionId dayExceptionId(); LeaveRecordId leaveRecordId(); }` (implemented by `UuidV7WorkIdFactory`).
  - `final class ScheduleDraft { EmploymentId employmentId; String name; String timezoneId; LocalDate cycleStart; LocalDate inUseFrom; LocalDate? inUseUntil; List<ShiftType> shiftTypes; List<CycleBlock> blocks; }`.
  - `abstract interface class ScheduleRepository { Future<List<WorkSchedule>> schedulesFor(EmploymentId id); Stream<List<WorkSchedule>> watchSchedules(EmploymentId id); Future<MutationOutcome<WorkSchedule>> insertVersion(WorkSchedule value, {WorkSchedule? closing}); Future<MutationOutcome<WorkSchedule>> replaceVersion(WorkSchedule value, {required Revision expected}); Future<MutationOutcome<WorkSchedule>> deleteSchedule(ScheduleId id, {required Revision expected}); }`
  - `final class ScheduleService({required ScheduleRepository repository, required ScheduleIdFactory ids, required AppClock clock})` with:
    - `Future<MutationOutcome<WorkSchedule>> create(ScheduleDraft draft)`
    - `Future<MutationOutcome<WorkSchedule>> update(ScheduleId id, {required Revision expected, required ScheduleDraft draft, LocalDate? newVersionFrom})`
    - `Future<MutationOutcome<WorkSchedule>> delete(ScheduleId id, {required Revision expected})`
  - `WorkRecordKinds.schedule = 'schedule'`, `WorkRecordKinds.leave = 'leave'`; `scheduleFacts(WorkSchedule)` for history.

Rules:
- Validation issues → `Invalid` keyed by each `DomainIssue.field`.
- Overlap with another schedule of the employment → `Invalid({'inUseFrom': [FieldIssue(FieldIssueCode.conflict)]})`.
- `update` of the latest version not used by a confirmed day → replaced in place (revision + 1, history `changed`).
- `update` of a version used by a confirmed day without `newVersionFrom` → `Invalid({'newVersionFrom': [FieldIssue(FieldIssueCode.required)]})`; with it → the current version's `inUseUntil` becomes `newVersionFrom − 1` (must be ≥ its `inUseFrom`, else `Invalid` on `newVersionFrom`), and version + 1 starts on `newVersionFrom` with the draft's cycle (history `created`).
- `delete` while any confirmed day uses the schedule → `Invalid({'schedule': [FieldIssue(FieldIssueCode.conflict)]})`.
- `usedByConfirmedDay` is read in the repository: `EXISTS (SELECT 1 FROM work_shifts WHERE schedule_id = ? AND schedule_version = ? AND state <> 'voided') OR EXISTS (SELECT 1 FROM work_leave_records WHERE schedule_id = ? AND schedule_version = ? AND state = 'confirmed')`.

- [ ] **Step 1: Failing tests**

First the shared fixture Tasks 7–11 use. Create `test/support/schedule_fixture.dart`:

```dart
import 'package:drift/native.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/data/schedule_repository.dart';
import 'package:lifeos/features/work/data/shift_repository.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';

const fixtureEmployment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const fixtureAgreement = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

/// A clock tests move by hand.
final class FixedClock implements AppClock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

/// An in-memory database with one synthetic employment paid EUR 18.40
/// gross from 2026-09-01, and the schedule services under test.
final class ScheduleFixture {
  ScheduleFixture._({
    required this.database,
    required this.clock,
    required this.ids,
    required this.shifts,
    required this.repository,
    required this.schedules,
  });

  final AppDatabase database;
  final FixedClock clock;
  final UuidV7WorkIdFactory ids;
  final DriftShiftRepository shifts;
  final DriftScheduleRepository repository;
  final ScheduleService schedules;

  static Future<ScheduleFixture> create() async {
    final database = AppDatabase(NativeDatabase.memory());
    final clock = FixedClock(DateTime.utc(2026, 10, 1));
    final ids = UuidV7WorkIdFactory();
    final work = DriftWorkRepository(database, clock: clock);
    await work.insertEmployment(
      Employment.create(
        id: fixtureEmployment,
        name: 'Synthetic depot',
        legalLabel: null,
        nowUtc: clock.value,
      ),
    );
    await work.insertAgreement(
      PayAgreement(
        id: fixtureAgreement,
        employmentId: fixtureEmployment,
        version: 1,
        effectiveStart: const LocalDate(2026, 9, 1),
        effectiveEnd: null,
        hourlyRateMicroEur: 18400000,
        basis: const GrossBasis(),
        overtimeThresholdMinutes: 480,
        overtimeMultiplier: const RationalMultiplier(
          numerator: 3,
          denominator: 2,
        ),
        label: null,
        note: null,
        createdAtUtc: clock.value,
        revision: const Revision(0),
        usedByFinalizedShift: false,
      ),
    );
    final repository = DriftScheduleRepository(database, clock: clock);
    return ScheduleFixture._(
      database: database,
      clock: clock,
      ids: ids,
      shifts: DriftShiftRepository(
        database,
        createBreakId: ids.shiftBreakId,
        clock: clock,
      ),
      repository: repository,
      schedules: ScheduleService(
        repository: repository,
        ids: ids,
        clock: clock,
      ),
    );
  }

  Future<void> dispose() => database.close();

  /// Saves the 3 Day / 3 Off / 3 Night / 3 Off rotation from [from].
  Future<WorkSchedule> saveDepot({
    LocalDate from = const LocalDate(2026, 10, 5),
  }) async {
    final outcome = await schedules.create(depotDraft(from: from));
    return (outcome as Committed<WorkSchedule>).value;
  }

  /// Confirms a Day shift on [date] from [version] directly, so the
  /// version counts as used (Task 9 adds the real confirm command).
  Future<void> markUsed(
    WorkSchedule version, {
    LocalDate date = const LocalDate(2026, 10, 5),
  }) async {
    // 07:00–19:00 in Europe/Vilnius, summer time (UTC+3).
    final start = DateTime.utc(date.year, date.month, date.day, 4);
    final end = DateTime.utc(date.year, date.month, date.day, 16);
    await shifts.createAndFinalizeManual(
      WorkShift(
        id: ids.shiftId(),
        employmentId: fixtureEmployment,
        agreementId: null,
        state: ShiftState.draft,
        startUtc: start,
        endUtc: end,
        timezoneId: 'Europe/Vilnius',
        localStartDate: date,
        note: null,
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: clock.value,
        updatedAtUtc: clock.value,
        revision: const Revision(0),
        schedule: ScheduleLink(
          scheduleId: version.id,
          scheduleVersion: version.version,
          plannedDate: date,
          plannedStartUtc: start,
          plannedEndUtc: end,
        ),
      ),
      const [],
    );
  }
}

/// The owner's rotation: Day 07:00–19:00 and Night 19:00–07:00, each with
/// a 30-minute break, as 3 Day, 3 Off, 3 Night, 3 Off.
ScheduleDraft depotDraft({
  String name = 'Depot rotation',
  int firstCount = 3,
  bool onlyOff = false,
  LocalDate from = const LocalDate(2026, 10, 5),
}) => ScheduleDraft(
  employmentId: fixtureEmployment,
  name: name,
  timezoneId: 'Europe/Vilnius',
  cycleStart: from,
  inUseFrom: from,
  inUseUntil: null,
  shiftTypes: const [
    ShiftType(
      id: ShiftTypeId('day'),
      name: 'Day',
      start: LocalTime(7, 0),
      end: LocalTime(19, 0),
      endDayOffset: 0,
      breaks: [FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30)],
    ),
    ShiftType(
      id: ShiftTypeId('night'),
      name: 'Night',
      start: LocalTime(19, 0),
      end: LocalTime(7, 0),
      endDayOffset: 1,
      breaks: [FixedBreak(start: LocalTime(0, 0), dayOffset: 1, minutes: 30)],
    ),
  ],
  blocks: onlyOff
      ? const [CycleBlock(count: 1, shiftTypeId: null)]
      : [
          CycleBlock(count: firstCount, shiftTypeId: const ShiftTypeId('day')),
          const CycleBlock(count: 3, shiftTypeId: null),
          const CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
          const CycleBlock(count: 3, shiftTypeId: null),
        ],
);
```

`DriftScheduleRepository(AppDatabase, {AppClock? clock})` and `ScheduleDraft` (a plain value class with a const constructor taking the fields named in **Interfaces**) are what this task creates. `DriftWorkRepository` and `DriftShiftRepository` already take `clock:`.

Then create `test/features/work/application/schedule_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/data/schedule_repository.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;
  late ScheduleService service;
  late DriftScheduleRepository repository;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    service = fixture.schedules;
    repository = fixture.repository;
  });
  tearDown(() => fixture.dispose());

  Future<void> markUsed(WorkSchedule value) => fixture.markUsed(value);

  test('a valid rotation is saved as version 1', () async {
    final outcome = await service.create(depotDraft());
    final saved = (outcome as Committed<WorkSchedule>).value;
    expect(saved.version, 1);
    expect((await repository.schedulesFor(employment)).single.cycleLength, 12);
  });

  test('a block count of 0 is invalid on blocks[0].count', () async {
    final outcome = await service.create(depotDraft(firstCount: 0));
    expect((outcome as Invalid<WorkSchedule>).fields.keys, contains('blocks[0].count'));
  });

  test('a second schedule on the same dates is invalid on inUseFrom', () async {
    await service.create(depotDraft());
    final outcome = await service.create(depotDraft(name: 'Other'));
    expect((outcome as Invalid<WorkSchedule>).fields.keys, ['inUseFrom']);
  });

  test('an unused version is edited in place', () async {
    final saved = (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    final outcome = await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(name: 'Depot, new name'),
    );
    final updated = (outcome as Committed<WorkSchedule>).value;
    expect(updated.version, 1);
    expect(updated.name, 'Depot, new name');
  });

  test('a used version needs a date and starts version 2 from it', () async {
    final saved = (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    await markUsed(saved); // inserts a finalized shift linked to version 1
    final missing = await service.update(saved.id, expected: saved.revision, draft: depotDraft(firstCount: 2));
    expect((missing as Invalid<WorkSchedule>).fields.keys, ['newVersionFrom']);

    final outcome = await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(firstCount: 2),
      newVersionFrom: const LocalDate(2026, 11, 1),
    );
    final next = (outcome as Committed<WorkSchedule>).value;
    expect(next.version, 2);
    expect(next.inUseFrom, const LocalDate(2026, 11, 1));
    final versions = await repository.schedulesFor(employment);
    expect(versions.firstWhere((v) => v.version == 1).inUseUntil, const LocalDate(2026, 10, 31));
  });

  test('a used schedule cannot be deleted', () async {
    final saved = (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    await markUsed(saved);
    final outcome = await service.delete(saved.id, expected: saved.revision);
    expect((outcome as Invalid<WorkSchedule>).fields.keys, ['schedule']);
  });

  test('an edit against an old revision is Stale', () async {
    final saved = (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    await service.update(saved.id, expected: saved.revision, draft: depotDraft(name: 'A'));
    final outcome = await service.update(saved.id, expected: saved.revision, draft: depotDraft(name: 'B'));
    expect(outcome, isA<Stale<WorkSchedule>>());
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/application/schedule_service_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

`schedule_dao.dart` — `DatabaseAccessor<AppDatabase>` with:
- `Future<List<WorkSchedule>> forEmployment(EmploymentId id)` — reads `work_schedules` rows, their `work_schedule_shift_types` (ordered by `position`) and `work_schedule_blocks` (ordered by `position`), builds `WorkSchedule`s via converters, and sets `usedByConfirmedDay` with the `EXISTS` query from **Rules**.
- `Future<void> insertVersion(WorkSchedule value)` — inserts the schedule row, then type rows (`position` = list index, `breaks` = `encodeBreaks`) and block rows.
- `Future<int> replaceVersion(WorkSchedule value, {required Revision expected})` — `UPDATE work_schedules … WHERE id = ? AND version = ? AND revision = ?`, then deletes and re-inserts its types and blocks; returns rows updated (0 = stale).
- `Future<int> closeVersion(ScheduleId id, int version, LocalDate until, {required Revision expected})`.
- `Future<int> deleteSchedule(ScheduleId id)` — deletes all versions (types and blocks cascade).

`schedule_repository.dart` — `DriftScheduleRepository implements ScheduleRepository` wrapping the DAO in `_database.transaction`, mapping 0-row writes to `Stale`, recording history through `WorkHistoryWriter` (`WorkRecordKinds.schedule`, record id `'${id.value}@$version'`), and `watchSchedules` on `tableUpdates` of the three schedule tables plus `work_shifts` and `work_leave_records`.

`schedule_service.dart` — validates with `validateSchedule` and `scheduleOverlaps` against `schedulesFor(employmentId)` before calling the repository; builds `WorkSchedule` from `ScheduleDraft` with `ids.scheduleId()` (create) or the existing id (update), `clock.nowUtc()` for `createdAtUtc`, `Revision(0)` for new versions; implements the version rules above. Map `DomainIssue` lists to `Invalid({issue.field!: [FieldIssue(FieldIssueCode.invalid)]})`, grouping issues by field.

`work_commands.dart`: add `ScheduleIdFactory`; `uuid_v7_work_id_factory.dart`: implement it (`ScheduleId(_uuid.v7())`, `ShiftTypeId(_uuid.v7())`, …).

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/features/work`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work test/features/work test/support/schedule_fixture.dart
git commit -m "feat: store schedules with versions and a schedule service

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Day exceptions and the plan query

Spec §3.5, §3.4, §7.

**Files:**
- Create: `lib/features/work/data/daos/day_exception_dao.dart`
- Create: `lib/features/work/application/day_plan_service.dart`
- Modify: `lib/features/work/data/schedule_repository.dart`, `lib/features/work/data/work_converters.dart`, `test/support/schedule_fixture.dart`
- Test: `test/features/work/application/day_plan_service_test.dart`

**Interfaces:**
- Consumes: `planDays`, `DayException` kinds, `ScheduleRepository`.
- Produces:
  - `abstract interface class DayPlanRepository { Future<PlanInputs> planInputs(EmploymentId id); Stream<PlanInputs> watchPlanInputs(EmploymentId id); Future<MutationOutcome<DayException>> putException(DayException value, {Revision? expected}); Future<MutationOutcome<DayException>> removeException(DayExceptionId id, {required Revision expected}); }`
  - `final class PlanInputs { List<WorkSchedule> schedules; List<DayException> exceptions; Set<LocalDate> confirmedDates; List<PayAgreement> agreements; }` — `confirmedDates` are the `planned_date` of non-voided shifts with a schedule link plus the dates of confirmed leave.
  - `final class DayPlanService({required DayPlanRepository repository, required ScheduleIdFactory ids, required AppClock clock, required ZoneClocks zoneClocks})` with:
    - `Future<List<PlannedDay>> plan(EmploymentId id, LocalDate from, LocalDate to)`
    - `Stream<List<PlannedDay>> watchPlan(EmploymentId id, LocalDate from, LocalDate to)`
    - `Future<List<PlannedDay>> daysToConfirm(EmploymentId id, {required LocalDate today})` — every `PlannedShift` and `PlannedLeave` from the earliest `inUseFrom` to `today − 1`.
    - Exception commands, one date each. Passing `expected` edits the date's existing exception (any kind may replace any kind); without it a date that already has one is `Stale`:
      - `changeDay(EmploymentId id, LocalDate date, {required LocalTime start, required LocalTime end, required int endDayOffset, required List<FixedBreak> breaks, required ShiftTypeId? shiftTypeId, Revision? expected})`
      - `cancelDay(EmploymentId id, LocalDate date, {required CancelReason reason, required String? note, Revision? expected})`
      - `markLeave(EmploymentId id, LocalDate date, {required LeaveType leaveType, required LocalDate? illnessStartedOn, Revision? expected})`
      - `addExtra(EmploymentId id, LocalDate date, {required LocalTime start, required LocalTime end, required int endDayOffset, required List<FixedBreak> breaks, required ShiftTypeId? shiftTypeId, required bool countsAsOvertime, Revision? expected})`
      - `removeException(DayExceptionId id, {required Revision expected})`
      - All return `Future<MutationOutcome<DayException>>`.
    - Refusals: `Invalid({'date': [FieldIssue(FieldIssueCode.invalid)]})` when the date's plan without the exception does not fit (Changed, Cancelled and Leave need a `PlannedShift`, Extra needs an `OffDay`, any date needs a schedule in use); `Invalid({'date': [FieldIssue(FieldIssueCode.conflict)]})` when the date is already confirmed, for edits and removals too (spec 3.5: editable until confirmed). Changed and Extra times are checked like a shift type (`validateSchedule`'s rules: length 1 min..24 h, breaks inside and not overlapping) with issues on `start`, `end` or `breaks`.

- [ ] **Step 1: Failing tests**

Give the fixture its plan service. In `test/support/schedule_fixture.dart` add a `final DayPlanService plans;` field, set in `create()` with:

```dart
      plans: DayPlanService(
        repository: repository,
        ids: ids,
        clock: clock,
        zoneClocks: zoneClocksOf(IanaTimezoneService()),
      ),
```

(imports `package:lifeos/core/time/timezone_service.dart`, `package:lifeos/core/time/wall_clock.dart`, `package:lifeos/features/work/application/day_plan_service.dart`).

Create `test/features/work/application/day_plan_service_test.dart`:

```dart
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
    final days = await plans.plan(employment, const LocalDate(2026, 10, 5), const LocalDate(2026, 10, 12));
    expect(days.map((day) => day.runtimeType), [
      PlannedShift, PlannedShift, PlannedShift,
      OffDay, OffDay, OffDay,
      PlannedShift, PlannedShift,
    ]);
  });

  test('a confirmed date leaves the plan', () async {
    await fixture.markUsed(saved);
    final days = await plans.plan(employment, const LocalDate(2026, 10, 5), const LocalDate(2026, 10, 6));
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
    expect((outcome as Invalid<DayException>).fields['date']!.single.code, FieldIssueCode.conflict);
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
    final day = (await plans.plan(employment, const LocalDate(2026, 10, 8), const LocalDate(2026, 10, 8))).single;
    expect((day as PlannedShift).isExtra, isTrue);
  });

  test('days to confirm are the past planned shifts and leave', () async {
    final pending = await plans.daysToConfirm(employment, today: const LocalDate(2026, 10, 10));
    // 5, 6, 7 Day; 8–9 Off.
    expect(pending.map((day) => day.date), [
      const LocalDate(2026, 10, 5),
      const LocalDate(2026, 10, 6),
      const LocalDate(2026, 10, 7),
    ]);
  });

  test('a new version flags a Changed day that is now Off as needing review', () async {
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
    final day = (await plans.plan(employment, const LocalDate(2026, 11, 10), const LocalDate(2026, 11, 10))).single;
    expect(day, isA<NeedsReview>());
    expect((day as NeedsReview).underlying, isA<OffDay>());
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/application/day_plan_service_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

- `day_exception_dao.dart`: `forEmployment`, `byDate`, `upsert(DayException, {Revision? expected})` (insert when absent; `UPDATE … WHERE id = ? AND revision = ?` when present; 0 rows → stale), `delete(id, expected)`.
- `work_converters.dart`: `dayExceptionToCompanion` / `dayExceptionFromRow` over `kind` (`changed`, `cancelled`, `leave`, `extra`), times as minutes, `breaks` via `encodeBreaks`, enums by `.name`.
- `schedule_repository.dart`: implement `DayPlanRepository` (`planInputs` reads schedules, exceptions, agreements and confirmed dates in one transaction; `watchPlanInputs` re-reads on `tableUpdates` of the schedule tables, `work_day_exceptions`, `work_shifts`, `work_leave_records`, `pay_agreements`).
- `day_plan_service.dart`: `plan` = `planDays(from, to, inputs…, zoneClocks)`; exception commands compute the date's plan first to decide `Invalid` per the rules; ids from `ids.dayExceptionId()`; times from `clock.nowUtc()`.

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/features/work`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work test/features/work test/support/schedule_fixture.dart
git commit -m "feat: store day exceptions and plan days from stored schedules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Confirming days

Spec §3.6, §6.3 (behaviour), §7. Review Focus 2.

**Files:**
- Create: `lib/features/work/data/daos/leave_dao.dart`
- Modify: `lib/features/work/data/schedule_repository.dart`, `lib/features/work/data/work_converters.dart`, `lib/features/work/data/work_history.dart`
- Modify: `lib/features/work/application/day_plan_service.dart` (add `confirm`, `correctLeave`), `lib/features/work/data/shift_repository.dart`, `test/support/schedule_fixture.dart`
- Test: `test/features/work/application/confirm_day_test.dart`

**Interfaces:**
- Consumes: `PlannedShift`, `PlannedLeave`, `DriftShiftRepository.createAndFinalizeManual`, `ScheduleLink`, `LeaveRecord`, `defaultIllnessStart`.
- Produces:
  - `sealed class ConfirmedDay` with `ConfirmedShift(WorkShift shift)` and `ConfirmedLeave(LeaveRecord leave)`.
  - `DayPlanService.confirm(EmploymentId id, LocalDate date) → Future<MutationOutcome<ConfirmedDay>>`:
    - `PlannedShift` → a draft `WorkShift` (`ids.shiftId()`), its breaks (`ids.shiftBreakId()`), and `ScheduleLink(scheduleId, scheduleVersion, plannedDate: date, plannedStartUtc/plannedEndUtc from overtimeWindow — or the shift's own start/end for extras —, isExtra, extraCountsAsOvertime: countsAsOvertime)`, finalized through `createAndFinalizeManual` → `ConfirmedShift`.
    - `PlannedLeave` → `LeaveRecord` with `paidMinutes`, the agreement in effect on the date, and `illnessStartedOn` = the exception's value or `defaultIllnessStart(date, isSick: sick leave dates, isOff: Off days of the plan)` for sick leave → `ConfirmedLeave` (history `created` under `WorkRecordKinds.leave`).
    - A date already in `confirmedDates` → `Stale`.
    - `OffDay`, `CancelledPlan`, `NeedsReview`, or no plan → `Invalid({'date': [FieldIssue(FieldIssueCode.invalid)]})`.
    - No agreement in effect → `Invalid({'agreement': [FieldIssue(FieldIssueCode.unavailable)]})`.
  - `LeaveRepository` (in the same Drift class): `insertLeave`, `leaveFor(EmploymentId)`, `watchLeave(EmploymentId)`, `correctLeave(LeaveRecordId id, {required Revision expected, required LeaveType leaveType, required LocalDate? illnessStartedOn, required String reason, required LeaveRecordId replacementId})` (void and replace, like payslips).
  - `DayPlanService.correctLeave(LeaveRecordId id, {required Revision expected, required LeaveType leaveType, required LocalDate? illnessStartedOn, required String reason}) → Future<MutationOutcome<LeaveRecord>>` — ids the replacement with `ids.leaveRecordId()`; a blank reason is `Invalid({'reason': [FieldIssue(FieldIssueCode.required)]})`; the replacement keeps date, paid minutes, agreement and schedule.
  - `DayPlanService` gains a `required ManualShiftRepository shifts` constructor parameter.
  - `DriftShiftRepository.createAndFinalizeManual` refuses a draft with a `schedule` link when a non-voided shift of the same employment already has that `planned_date`, returning `Stale` (checked inside its transaction, before the insert).

- [ ] **Step 1: Failing tests**

In `test/support/schedule_fixture.dart` pass `shifts: shifts` to the `DayPlanService` (build `DriftShiftRepository` into a local before the constructor call).

Create `test/features/work/application/confirm_day_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/leave.dart';
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
    final outcome = await plans.confirm(employment, const LocalDate(2026, 10, 5));
    final shift = ((outcome as Committed<ConfirmedDay>).value as ConfirmedShift).shift;
    expect(shift.state, ShiftState.finalized);
    expect(shift.schedule?.plannedDate, const LocalDate(2026, 10, 5));
    expect(shift.schedule?.scheduleVersion, 1);
    final rest = await plans.plan(employment, const LocalDate(2026, 10, 5), const LocalDate(2026, 10, 5));
    expect(rest, isEmpty);
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
    await plans.markLeave(employment, const LocalDate(2026, 10, 6), leaveType: LeaveType.vacation, illnessStartedOn: null);
    final outcome = await plans.confirm(employment, const LocalDate(2026, 10, 6));
    final leave = ((outcome as Committed<ConfirmedDay>).value as ConfirmedLeave).leave;
    expect(leave.paidMinutes, 11 * 60 + 30);
    expect(leave.leaveType, LeaveType.vacation);
  });

  test('a sick day defaults its illness start across Off days', () async {
    // 2026-10-07 Day (sick), 8–10 Off, 11 Night (sick).
    await plans.markLeave(employment, const LocalDate(2026, 10, 7), leaveType: LeaveType.sick, illnessStartedOn: null);
    await plans.markLeave(employment, const LocalDate(2026, 10, 11), leaveType: LeaveType.sick, illnessStartedOn: null);
    await plans.confirm(employment, const LocalDate(2026, 10, 7));
    final outcome = await plans.confirm(employment, const LocalDate(2026, 10, 11));
    final leave = ((outcome as Committed<ConfirmedDay>).value as ConfirmedLeave).leave;
    expect(leave.illnessStartedOn, const LocalDate(2026, 10, 7));
  });

  test('an Off day cannot be confirmed', () async {
    final outcome = await plans.confirm(employment, const LocalDate(2026, 10, 8));
    expect((outcome as Invalid<ConfirmedDay>).fields.keys, ['date']);
  });

  test('confirmed vacation is corrected to sick by void and replace', () async {
    await plans.markLeave(employment, const LocalDate(2026, 10, 6), leaveType: LeaveType.vacation, illnessStartedOn: null);
    final first = ((await plans.confirm(employment, const LocalDate(2026, 10, 6)) as Committed<ConfirmedDay>).value as ConfirmedLeave).leave;

    final blank = await plans.correctLeave(first.id, expected: first.revision, leaveType: LeaveType.sick, illnessStartedOn: null, reason: ' ');
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
    expect(all.firstWhere((item) => item.id == first.id).state, LeaveState.voided);
  });
}
```

(Two confirms of one date are serialised by Drift; the second either sees the date in `confirmedDates` or is refused inside `createAndFinalizeManual` / the leave insert's transaction. The `one_confirmed_shift_per_planned_day` and `one_confirmed_leave_per_day` indexes are the last guard: catch their `SqliteException` (unique constraint) and return `Stale` too.)

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work/application/confirm_day_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

- `leave_dao.dart` and converters (`leaveToCompanion`, `leaveFromRow`), `leaveFacts(LeaveRecord)` in `work_history.dart` ('Date', 'Type', 'Illness started on', 'Paid time').
- `DayPlanService.confirm`: read `planInputs`, plan the single date, branch as in **Interfaces**. Worked days: build the draft and breaks from the `PlannedShift`, call `shifts.createAndFinalizeManual(draft, breaks)` and wrap its `Committed` in `ConfirmedShift`; pass other outcomes through with the new type. Leave: `insertLeave` re-checks in its transaction that no confirmed leave or non-voided linked shift holds the date (else `Stale`).
- `shift_repository.dart` `createAndFinalizeManual`: before inserting, when `draft.schedule != null`, `SELECT 1 FROM work_shifts WHERE employment_id = ? AND planned_date = ? AND state <> 'voided'`; a row → `Stale`.
- `correctLeave` in the repository: in one transaction, `UPDATE work_leave_records SET state = 'voided', void_reason = ?, replacement_leave_id = ?, revision = revision + 1 WHERE id = ? AND revision = ? AND state = 'confirmed'` (0 rows → `Stale`), insert the replacement with `replaced_leave_id`, history `corrected` on both. Insert the replacement first if the foreign key on `replacement_leave_id` requires it (same order as `correctPayslip` in `work_repository.dart`).

- [ ] **Step 4: Run tests**

Run: `$F/flutter test test/features/work`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work test/features/work test/support/schedule_fixture.dart
git commit -m "feat: confirm planned days as linked shifts or leave records

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Leave in reconciliation, registers and agreements

Spec §3.7, §4.3, §4.4.

**Files:**
- Modify: `lib/features/work/domain/reconciliation.dart`
- Modify: `lib/features/work/data/work_repository.dart`, `projections/work_register_projection.dart`, `projections/reconciliation_projection.dart`
- Modify: `lib/features/work/application/agreement_service.dart`, `lib/features/work/presentation/employment_agreement_forms.dart` (Leave pay group box)
- Test: `test/features/work/domain/reconciliation_test.dart`, `test/features/work/data/leave_register_test.dart` (new), `test/features/work/presentation/employment_agreement_forms_test.dart`

**Interfaces:**
- Consumes: `priceLeave`, `LeaveRecord`, `WorkedPay`.
- Produces:
  - `reconcilePeriod({…, Iterable<PricedLeave> leave = const []})` with `final class PricedLeave { LeaveRecordId id; LocalDate date; RateBasis basis; LeavePay pay; }`; employer-paid leave in the period counts as expected evidence (its `paidSeconds` as regular time).
  - `WorkRegisterProjection` gains `List<LeaveSheetRow> leaveSheet` (`LeaveRecord record; LeavePay? pay`) and `int plannedNotConfirmed` (past planned days in the selected period).
  - `AgreementForm` shows a **Leave pay** group box: "Vacation %" (default 100), "Sick, first days %" (default 62.06) and "Sick days the employer pays" (default 2), with the existing defaults note.

- [ ] **Step 1: Failing tests**

In `reconciliation_test.dart`:

```dart
  test('confirmed leave counts as expected pay in its period', () {
    final groups = reconcilePeriod(
      employmentId: employment,
      period: september,
      shifts: const [],
      breaks: const [],
      agreements: [agreement],
      payslips: const [],
      zoneClocks: testZoneClocks,
      leave: [
        PricedLeave(
          id: const LeaveRecordId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4f01'),
          date: const LocalDate(2026, 9, 10),
          basis: const GrossBasis(),
          pay: const LeavePay(
            amount: Money(minorUnits: 28750),
            paidSeconds: 41400,
            factor: AgreementDefaults.vacationPay,
            employerPaid: true,
            usedFallback: false,
            average: (minorUnits: 250000, paidSeconds: 360000),
          ),
        ),
      ],
    );
    expect(groups.single.expected, const Money(minorUnits: 28750));
  });
```

(`reconciliation_test.dart` already builds an employment, a September `PayPeriod` and an agreement for its other tests; use those values under whatever names the file gives them, and add imports for `leave.dart` and `ids.dart`.)

Create `test/features/work/data/leave_register_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  test('the register lists confirmed leave and counts past unconfirmed days', () async {
    final fixture = await ScheduleFixture.create();
    addTearDown(fixture.dispose);
    await fixture.saveDepot();
    await fixture.plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await fixture.plans.confirm(fixtureEmployment, const LocalDate(2026, 10, 6));
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

    expect(register.leaveSheet.single.record.date, const LocalDate(2026, 10, 6));
    // No work in July–September: the agreement rate, 11:30 × EUR 18.40.
    expect(register.leaveSheet.single.pay!.amount.minorUnits, 21160);
    expect(register.leaveSheet.single.pay!.usedFallback, isTrue);
    // 5 and 7 October are past Day shifts not yet confirmed; 8 is Off.
    expect(register.plannedNotConfirmed, 2);
  });
}
```

In `test/features/work/presentation/employment_agreement_forms_test.dart`, inside the agreement group, using the file's `pumpAgreementForm`, `enter`, `submitAgreement` and `_r` helpers:

```dart
    testWidgets('leave pay has its own group box and exact fractions', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      expect(find.text('Leave pay'), findsOneWidget);
      await enter(tester, 'agreement-sick-percent', '70');
      await submitAgreement(tester);

      final terms = submitted!.terms;
      expect(terms.vacationPay, _r(1, 1));
      expect(terms.sickPay, _r(7, 10));
      expect(terms.sickEmployerDays, 2);
    });

    testWidgets('leave pay defaults are 100 %, 62.06 % and 2 days', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await submitAgreement(tester);

      expect(submitted!.terms.sickPay, _r(3103, 5000));
    });
```

The three fields are `EraField`s keyed `agreement-vacation-percent`, `agreement-sick-percent` and `agreement-sick-days`, labelled "Vacation %", "Sick, first days %" and "Sick days the employer pays", in a `GroupBox(legend: 'Leave pay')` placed and shown like the form's other premium group boxes. A percent that is empty, not a number, or not above 0 is refused with the form's existing number message; days accept whole numbers 0..30.

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/features/work`
Expected: FAIL on the three new tests.

- [ ] **Step 3: Implement**

- `reconciliation.dart`: add `PricedLeave`; in `reconcilePeriod`, for each `leave` item with `pay.employerPaid` and `period.contains(item.date)`, add `_Evidence.expected(basis: item.basis, money: item.pay.amount, regularPaidSeconds: item.pay.paidSeconds, overtimePaidSeconds: 0, shiftId: null)` (make `shiftId` nullable in `_Evidence` if needed).
- `work_repository.dart` `_loadRegister`: read leave records (`LeaveDao`), schedules (`ScheduleDao`) and day exceptions (`DayExceptionDao`); build `WorkedPay` from each finalized shift's date, paid seconds and expected pay; call `priceLeave`; pass `PricedLeave` (basis from the leave's agreement) to `reconcilePeriod` and `projectReconciliation`; fill `leaveSheet`. `plannedNotConfirmed` counts the `PlannedShift` and `PlannedLeave` entries of `planDays` over the period whose date is before today, where today is `_timezones.localDateAt(_clock.nowUtc(), schedule.timezoneId)` for the schedule that planned the day (`DriftWorkRepository` already holds `timezones` and `clock`). With no employment in scope it is 0.
- `watchRegister` also re-reads on updates to `work_leave_records`, `work_day_exceptions` and the three schedule tables.
- Agreement percent fields parse "62.06" as `RationalMultiplier(numerator: 6206, denominator: 10000)` reduced by gcd; `agreement_service.dart` passes them through `AgreementTerms`.

- [ ] **Step 4: Run tests**

Run: `$F/flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/work test/features/work
git commit -m "feat: reconcile confirmed leave and set leave pay on agreements

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Wiring, end-to-end flow and docs

Spec §8 Integration (headless half; the screens are Part 2).

**Files:**
- Modify: `lib/app/production_work_providers.dart`, `lib/features/work/presentation/work_controller.dart`
- Create: `test/integration/schedule_flow_test.dart`
- Modify: `README.md`, `PRODUCT.md`, `DESIGN.md` (no UI change; note the removed tracker), `CLAUDE.md` only if `app.sh` changes (it should not)

**Interfaces:**
- Produces Riverpod providers (overridden in `production_work_providers.dart`, defaulting to `throw UnimplementedError` like the existing ones): `scheduleServiceProvider`, `dayPlanServiceProvider`, `workPlanProvider` (`StreamProvider.autoDispose.family<List<PlannedDay>, ({EmploymentId employment, LocalDate from, LocalDate to})>`), `daysToConfirmProvider` (`FutureProvider.autoDispose.family<List<PlannedDay>, EmploymentId>` using `todayProvider`).

- [ ] **Step 1: Failing end-to-end test**

Create `test/integration/schedule_flow_test.dart`. It drives the production composition (`buildWorkProviders` on an in-memory database) through its services, without UI; Part 2 adds the screen-level flow.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/planner.dart';
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
    await work.plans.markLeave(employment, const LocalDate(2026, 9, 2), leaveType: LeaveType.vacation, illnessStartedOn: null);
    await work.plans.markLeave(employment, const LocalDate(2026, 9, 8), leaveType: LeaveType.sick, illnessStartedOn: null);

    // 4. Confirm everything up to 12 September.
    final pending = await work.plans.daysToConfirm(employment, today: const LocalDate(2026, 9, 13));
    expect(pending.map((day) => day.date.day), [1, 2, 3, 7, 8, 9]);
    for (final day in pending) {
      expect(await work.plans.confirm(employment, day.date), isA<Committed<ConfirmedDay>>());
    }
    expect(await work.plans.daysToConfirm(employment, today: const LocalDate(2026, 9, 13)), isEmpty);

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
          WorkScope(employmentId: employment, temporal: PayPeriodScope(period.id)),
        )
        .first;
    final group = register.reconciliation!.groups.single;
    expect(group.expected, const Money(minorUnits: 132732));
    expect(group.paid, const Money(minorUnits: 132732));
    expect(register.leaveSheet, hasLength(2));
    expect(register.plannedNotConfirmed, 0);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `$F/flutter test test/integration/schedule_flow_test.dart`
Expected: FAIL (providers not wired / services missing in the composition).

- [ ] **Step 3: Implement**

- `production_work_providers.dart`: `buildWorkProviders` gains `ScheduleIdFactory? scheduleIds` (default `UuidV7WorkIdFactory()`, so existing callers compile unchanged); construct `DriftScheduleRepository(database, clock: clock)`, `ScheduleService`, and `DayPlanService(repository:, shifts: shiftRepository, ids:, clock:, zoneClocks: zoneClocksOf(timezones))`; expose them as `ProductionWorkProviders.schedules` and `.plans`; add their provider overrides.
- `work_controller.dart`: declare the providers listed in **Interfaces**.
- Docs: README's Work bullet becomes "employments and agreements with premiums and leave pay; rotating schedules with planned days you confirm; manual shifts; pay periods, payslips and reconciliation; correction". PRODUCT.md's capabilities line replaces "live and manual shifts" with "rotating schedules, confirmed days, leave and manual shifts".

- [ ] **Step 4: Full verification**

```bash
$F/flutter analyze lib test tool
$F/dart format --output=none --set-exit-if-changed lib test tool
$F/dart run tool/schema_check.dart
$F/flutter test
printf '2\n4\n' | ./app.sh
```

Expected: clean, green. Then start the app once against a **copy** of a schema-1 database (`./app.sh` option 1 with the default database location backed up first, or a disposable test root) and confirm it opens, a `.v1-backup-…sqlite` appears, and Work shows the old records.

- [ ] **Step 5: Commit**

```bash
git add -A lib test README.md PRODUCT.md DESIGN.md
git commit -m "feat: wire schedules into the app; document the change

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
