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

void main() {
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
    expect(night.entries.single.text, 'Night 19:00–07:00');
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
