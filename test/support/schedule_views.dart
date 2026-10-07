import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/planner.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_plan_view.dart';

import 'schedule_fixture.dart';
import 'zone_clocks.dart';

const depotScheduleId = ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
final testTimezones = IanaTimezoneService();

/// The 3 Day / 3 Off / 3 Night / 3 Off rotation from 5 October 2026, as a
/// stored version 1.
WorkSchedule depotSchedule() {
  final draft = depotDraft();
  return WorkSchedule(
    id: depotScheduleId,
    employmentId: fixtureEmployment,
    name: draft.name,
    timezoneId: draft.timezoneId,
    version: 1,
    cycleStart: draft.cycleStart,
    inUseFrom: draft.inUseFrom,
    inUseUntil: null,
    shiftTypes: draft.shiftTypes,
    blocks: draft.blocks,
    createdAtUtc: DateTime.utc(2026, 10, 1),
    revision: const Revision(0),
  );
}

/// October 2026 planned from [depotSchedule].
List<PlannedDay> octoberPlan({
  List<DayException> exceptions = const [],
  Set<LocalDate> confirmed = const {},
}) => planDays(
  from: const LocalDate(2026, 10, 1),
  to: const LocalDate(2026, 10, 31),
  schedules: [depotSchedule()],
  exceptions: exceptions,
  confirmedDates: confirmed,
  zoneClocks: testZoneClocks,
);

/// October 2026's calendar days.
Map<LocalDate, DayView> octoberViews(
  List<PlannedDay> plan, {
  List<ShiftSheetRow> shifts = const [],
}) => dayViews(
  from: const LocalDate(2026, 10, 1),
  to: const LocalDate(2026, 10, 31),
  plan: plan,
  shifts: shifts,
  leave: const [],
  schedules: [depotSchedule()],
  timezones: testTimezones,
);

/// A finalized Day shift on [date], confirmed from [depotSchedule].
ShiftSheetRow confirmedDayRow(LocalDate date, {DateTime? end}) {
  // 07:00–19:00 Europe/Vilnius in summer time (UTC+3).
  final start = DateTime.utc(date.year, date.month, date.day, 4);
  end ??= DateTime.utc(date.year, date.month, date.day, 16);
  return ShiftSheetRow(
    shift: WorkShift(
      id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c81'),
      employmentId: fixtureEmployment,
      agreementId: fixtureAgreement,
      state: ShiftState.finalized,
      startUtc: start,
      endUtc: end,
      timezoneId: 'Europe/Vilnius',
      localStartDate: date,
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 10, 1),
      updatedAtUtc: DateTime.utc(2026, 10, 1),
      revision: const Revision(1),
      schedule: ScheduleLink(
        scheduleId: depotScheduleId,
        scheduleVersion: 1,
        plannedDate: date,
        plannedStartUtc: start,
        plannedEndUtc: end,
      ),
    ),
    breakSeconds: 1800,
    paidSeconds: 41400,
    period: null,
  );
}
