import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../core/time/timezone_service.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/pay_premiums.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/schedule.dart' show ShiftTypeId;
import '../../features/work/domain/shift.dart';
import 'planned_day_edit.dart';
import 'shift_edit.dart';

/// The derived values a pending shift shows while it is edited (spec 4.2):
/// recomputed from the draft on every edit, never stored, and read-only.
@immutable
final class WorkPreview {
  const WorkPreview({
    required this.breakSeconds,
    required this.paidSeconds,
    required this.pay,
    this.planDifferenceSeconds,
  });

  final int breakSeconds;
  final int paidSeconds;

  /// Estimated pay with its premiums; null when no single pay agreement
  /// covers the date.
  final ExpectedPay? pay;

  /// Paid time against the cycle's own plan for the day, negative when
  /// shorter; null for an extra day or a recorded shift.
  final int? planDifferenceSeconds;
}

/// What saving [values] would make of [record]'s day: the plan with the
/// pending change applied, priced as planned (night and holiday premiums,
/// never overtime, schedules spec 4.1). [inputs] are the employment's
/// plan inputs, read once for the record. Null while the values do not
/// make a planned shift.
WorkPreview? previewPlannedDay(
  PlannedDayRecord record,
  PlannedDayValues values, {
  required PlanInputs inputs,
  required ZoneClocks zoneClocks,
}) => _previewDay(
  employmentId: record.employmentId,
  date: record.date,
  isExtra: record.day.isExtra,
  plannedTypeId: switch (record.exception) {
    ChangedDay(:final plannedTypeId) => plannedTypeId,
    _ => record.day.type?.id,
  },
  values: values,
  inputs: inputs,
  zoneClocks: zoneClocks,
);

/// What saving [values] as a new extra shift of [employmentId] on [date]
/// would make (Add extra shift, plan 4d-1): priced as planned.
WorkPreview? previewNewExtra(
  EmploymentId employmentId,
  LocalDate date,
  PlannedDayValues values, {
  required PlanInputs inputs,
  required ZoneClocks zoneClocks,
}) => _previewDay(
  employmentId: employmentId,
  date: date,
  isExtra: true,
  plannedTypeId: null,
  values: values,
  inputs: inputs,
  zoneClocks: zoneClocks,
);

WorkPreview? _previewDay({
  required EmploymentId employmentId,
  required LocalDate date,
  required bool isExtra,
  required ShiftTypeId? plannedTypeId,
  required PlannedDayValues values,
  required PlanInputs inputs,
  required ZoneClocks zoneClocks,
}) {
  if (plannedDayProblems(values).isNotEmpty) return null;
  final at = DateTime.utc(2000);
  final DayException pending = isExtra
      ? ExtraDay(
          id: const DayExceptionId('preview'),
          employmentId: employmentId,
          date: date,
          start: values.start,
          end: values.end,
          endDayOffset: values.endDayOffset,
          breaks: values.breaks,
          shiftTypeId: values.shiftTypeId,
          countsAsOvertime: values.countsAsOvertime,
          createdAtUtc: at,
          updatedAtUtc: at,
          revision: const Revision(0),
        )
      : ChangedDay(
          id: const DayExceptionId('preview'),
          employmentId: employmentId,
          date: date,
          start: values.start,
          end: values.end,
          endDayOffset: values.endDayOffset,
          breaks: values.breaks,
          shiftTypeId: values.shiftTypeId,
          plannedTypeId: plannedTypeId,
          createdAtUtc: at,
          updatedAtUtc: at,
          revision: const Revision(0),
        );
  final others = [
    for (final value in inputs.exceptions)
      if (value.date != date) value,
  ];
  PlannedDay? planned(List<DayException> exceptions) => planDays(
    from: date,
    to: date,
    schedules: inputs.schedules,
    exceptions: exceptions,
    confirmedDates: const {},
    zoneClocks: zoneClocks,
  ).firstOrNull;

  final day = planned([...others, pending]);
  if (day is! PlannedShift) return null;
  final cycle = isExtra ? null : planned(others);
  final elapsed = day.endUtc.difference(day.startUtc).inSeconds;
  return WorkPreview(
    breakSeconds: elapsed - day.paidSeconds,
    paidSeconds: day.paidSeconds,
    pay: plannedPay(
      day,
      agreements: inputs.agreements,
      employmentId: employmentId,
      zoneClocks: zoneClocks,
    ),
    planDifferenceSeconds: cycle is PlannedShift
        ? day.paidSeconds - cycle.paidSeconds
        : null,
  );
}

/// What finalizing [values] would pay: a new manual shift of
/// [employmentId], or a draft carrying [schedule] (a correction's
/// replacement keeps its planned window for overtime). Priced as
/// finalization prices it, overtime included. Null while the values do not
/// make a shift with paid time, or name a wall-clock time that does not
/// exist or is ambiguous in its zone.
WorkPreview? previewShift(
  ShiftValues values, {
  required EmploymentId employmentId,
  required Iterable<PayAgreement> agreements,
  required TimezoneService timezones,
  required ZoneClocks zoneClocks,
  ScheduleLink? schedule,
}) {
  final zone = values.timezoneId.trim();
  final DateTime start;
  final DateTime end;
  final List<ShiftBreak> breaks;
  final at = DateTime.utc(2000);
  const id = ShiftId('preview');
  try {
    DateTime utc(LocalDate date, LocalTime time, FoldChoice? fold) =>
        timezones.resolveLocal(date, time, zone, fold: fold).utc;
    start = utc(values.startDate, values.start, values.startFold);
    end = utc(values.endDate, values.end, values.endFold);
    breaks = [
      for (final (index, item) in values.breaks.indexed)
        ShiftBreak(
          id: ShiftBreakId('preview-$index'),
          shiftId: id,
          startUtc: utc(item.startDate, item.start, item.startFold),
          endUtc: utc(item.endDate, item.end, item.endFold),
          createdAtUtc: at,
          updatedAtUtc: at,
          revision: const Revision(0),
        ),
    ];
  } on Exception {
    return null;
  } on ArgumentError {
    return null;
  }
  if (!end.isAfter(start)) return null;
  final WorkShift shift;
  try {
    shift = WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: null,
      state: ShiftState.draft,
      startUtc: start,
      endUtc: end,
      timezoneId: zone,
      localStartDate: values.startDate,
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: at,
      updatedAtUtc: at,
      revision: const Revision(0),
      schedule: schedule,
    );
  } on ArgumentError {
    return null;
  }
  final elapsed = end.difference(start).inSeconds;
  final breakSeconds = breaks.fold(
    0,
    (sum, item) => sum + item.endUtc!.difference(item.startUtc).inSeconds,
  );
  if (elapsed - breakSeconds <= 0) return null;
  final facts = validateFinalization(
    shift: shift,
    breaks: breaks,
    agreements: agreements,
  ).facts;
  final clock = zoneClocks(zone);
  return WorkPreview(
    breakSeconds: breakSeconds,
    paidSeconds: elapsed - breakSeconds,
    pay: facts?.expectedPay(
      toLocal: clock.toLocal,
      toInstants: clock.toInstants,
    ),
  );
}
