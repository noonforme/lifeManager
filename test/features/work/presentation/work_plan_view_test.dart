import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/presentation/work_plan_view.dart';

import '../../../support/schedule_fixture.dart';
import '../../../support/schedule_views.dart';

/// A Night 19:30–07:30 planned on [date]; [hours] is the zone's UTC offset.
PlannedShift _night(LocalDate date, {required int hours}) => PlannedShift(
  date,
  scheduleId: depotScheduleId,
  scheduleVersion: 1,
  timezoneId: 'Europe/Vilnius',
  type: depotSchedule().shiftTypes.firstWhere((type) => type.name == 'Night'),
  startUtc: DateTime.utc(
    date.year,
    date.month,
    date.day,
    19,
    30,
  ).subtract(Duration(hours: hours)),
  endUtc: DateTime.utc(
    date.year,
    date.month,
    date.day,
    7,
    30,
  ).add(const Duration(days: 1)).subtract(Duration(hours: hours)),
  breaks: const [],
  overtimeWindow: null,
  isExtra: false,
  countsAsOvertime: false,
  changed: false,
);

void main() {
  test('a night shift continues on the next day, after its own entries', () {
    final plan = [
      ...octoberPlan(),
      _night(const LocalDate(2026, 10, 7), hours: 3),
    ];
    final views = octoberViews(plan);
    final next = views[const LocalDate(2026, 10, 8)]!;
    final entry = next.entries.single;
    expect(entry.kind, DayEntryKind.continued);
    expect(entry.text, 'Night until 07:30');
    expect(entry.spoken, 'Night continues until 07:30');
    // Display only: nothing planned, recorded or confirmable on that day.
    expect(next.planned, isA<OffDay>());
    expect(next.shifts, isEmpty);
    expect(next.confirmed, isFalse);
    // The start day keeps its own entry and gains no continuation.
    expect(views[const LocalDate(2026, 10, 7)]!.entries.map((e) => e.kind), [
      DayEntryKind.planned,
    ]);
  });

  test('a continuation changes no month total', () {
    final base = monthTotals(
      octoberViews(octoberPlan()).values,
      price: (_) => null,
    );
    final plan = [...octoberPlan()]
      ..removeWhere((day) => day.date == const LocalDate(2026, 10, 7))
      ..add(_night(const LocalDate(2026, 10, 7), hours: 3));
    final totals = monthTotals(octoberViews(plan).values, price: (_) => null);
    expect(totals.shifts, base.shifts);
  });

  test('a night on 31 October continues on 1 November', () {
    final plan = [_night(const LocalDate(2026, 10, 31), hours: 2)];
    final views = dayViews(
      from: const LocalDate(2026, 11, 1),
      to: const LocalDate(2026, 11, 30),
      plan: plan,
      shifts: const [],
      leave: const [],
      schedules: [depotSchedule()],
      timezones: testTimezones,
    );
    expect(
      views[const LocalDate(2026, 11, 1)]!.entries.single.text,
      'Night until 07:30',
    );
    expect(views[const LocalDate(2026, 11, 2)]!.entries, isEmpty);
  });

  test('a confirmed night continues on the next day too', () {
    const date = LocalDate(2026, 10, 7);
    // 07:00 to 07:30 the next morning, Vilnius time.
    final night = confirmedDayRow(date, end: DateTime.utc(2026, 10, 8, 4, 30));
    final views = octoberViews(octoberPlan(), shifts: [night]);
    expect(
      views[const LocalDate(2026, 10, 8)]!.entries.single.text,
      'Day until 07:30',
    );
  });
  test('a planned day reads its type and wall-clock times', () {
    final views = octoberViews(octoberPlan());
    final entry = views[const LocalDate(2026, 10, 5)]!.entries.single;
    expect(entry.kind, DayEntryKind.planned);
    expect(entry.text, 'Day 07:00–19:00');
    expect(entry.confirmed, isFalse);
  });

  test('an Off day has no entry', () {
    expect(
      octoberViews(octoberPlan())[const LocalDate(2026, 10, 8)]!.entries,
      isEmpty,
    );
  });

  test('the night daylight saving ends reads 19:00–07:00, 12:30 paid', () {
    final views = octoberViews(octoberPlan());
    final night = views[const LocalDate(2026, 10, 24)]!;
    expect(night.entries.first.text, 'Night 19:00–07:00');
    // Its tail reads on the 25th, the morning the clocks went back.
    expect(
      views[const LocalDate(2026, 10, 25)]!.entries.last.text,
      'Night until 07:00',
    );
    expect((night.planned! as PlannedShift).paidSeconds, 12 * 3600 + 1800);
  });

  test('a cancelled day strikes its type and writes the reason', () {
    final views = octoberViews(
      octoberPlan(
        exceptions: [
          CancelledDay(
            id: const DayExceptionId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c91'),
            employmentId: fixtureEmployment,
            date: const LocalDate(2026, 10, 6),
            reason: CancelReason.swapped,
            note: null,
            createdAtUtc: DateTime.utc(2026, 10, 1),
            updatedAtUtc: DateTime.utc(2026, 10, 1),
            revision: const Revision(0),
          ),
        ],
      ),
    );
    final entry = views[const LocalDate(2026, 10, 6)]!.entries.single;
    expect(entry.kind, DayEntryKind.cancelled);
    expect(entry.struck, 'Day');
    expect(entry.text, 'Cancelled · Swapped');
  });

  test('a confirmed day reads like its plan, filled', () {
    const date = LocalDate(2026, 10, 7);
    final views = octoberViews(
      octoberPlan(confirmed: {date}),
      shifts: [confirmedDayRow(date)],
    );
    final day = views[date]!;
    expect(day.confirmed, isTrue);
    expect(day.planned, isNull);
    final entry = day.entries.single;
    expect(entry.kind, DayEntryKind.confirmed);
    expect(entry.text, 'Day 07:00–19:00');
    expect(entry.confirmed, isTrue);
  });

  test('a removed confirmed shift leaves its day planned again', () {
    const date = LocalDate(2026, 10, 7);
    final confirmed = confirmedDayRow(date);
    final removed = ShiftSheetRow(
      shift: confirmed.shift.removed(
        voidReason: 'Did not work it',
        nowUtc: DateTime.utc(2026, 10, 8),
      ),
      breakSeconds: confirmed.breakSeconds,
      paidSeconds: confirmed.paidSeconds,
      period: null,
    );
    // The void shift no longer confirms the date, so the plan holds it.
    final day = octoberViews(octoberPlan(), shifts: [removed])[date]!;
    expect(day.confirmed, isFalse);
    expect(day.planned, isA<PlannedShift>());
    final entry = day.entries.single;
    expect(entry.kind, DayEntryKind.planned);
    expect(entry.text, 'Day 07:00–19:00');
  });

  test('month totals count planned and confirmed shifts apart', () {
    const date = LocalDate(2026, 10, 7);
    final views = octoberViews(
      octoberPlan(confirmed: {date}),
      shifts: [confirmedDayRow(date)],
    );
    final totals = monthTotals(views.values, price: (_) => null);
    // October from the 5th: 15 shifts, one of them confirmed.
    expect(totals.shifts, 15);
    expect(totals.planned, const Money(minorUnits: 0));
  });

  test('Calendar is the default sheet while a schedule is in use today', () {
    expect(
      defaultSheetFor([depotSchedule()], const LocalDate(2026, 10, 7)),
      WorkSheet.calendar,
    );
    expect(
      defaultSheetFor([depotSchedule()], const LocalDate(2026, 10, 1)),
      WorkSheet.shifts,
    );
    expect(
      defaultSheetFor(const [], const LocalDate(2026, 10, 7)),
      WorkSheet.shifts,
    );
  });
}
