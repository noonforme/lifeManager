import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/schedule.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import 'work_outcomes.dart';

/// The pending times of an unconfirmed planned work day: what
/// `DayPlanService.changeDay` (or `addExtra` for an extra day) saves.
@immutable
final class PlannedDayValues {
  const PlannedDayValues({
    required this.start,
    required this.end,
    required this.endDayOffset,
    this.breaks = const [],
    this.shiftTypeId,
    this.countsAsOvertime = false,
  });

  final LocalTime start;
  final LocalTime end;

  /// 0 when the shift ends on its start date, 1 on the day after.
  final int endDayOffset;
  final List<FixedBreak> breaks;

  /// The schedule's shift type the day is changed to; null keeps the
  /// cycle's own.
  final ShiftTypeId? shiftTypeId;

  /// An extra day's Counts as overtime; false on any other day.
  final bool countsAsOvertime;

  PlannedDayValues copyWith({
    LocalTime? start,
    LocalTime? end,
    int? endDayOffset,
    List<FixedBreak>? breaks,
    ShiftTypeId? Function()? shiftTypeId,
    bool? countsAsOvertime,
  }) => PlannedDayValues(
    start: start ?? this.start,
    end: end ?? this.end,
    endDayOffset: endDayOffset ?? this.endDayOffset,
    breaks: breaks ?? this.breaks,
    shiftTypeId: shiftTypeId == null ? this.shiftTypeId : shiftTypeId(),
    countsAsOvertime: countsAsOvertime ?? this.countsAsOvertime,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedDayValues &&
      other.start == start &&
      other.end == end &&
      other.endDayOffset == endDayOffset &&
      listEquals(other.breaks, breaks) &&
      other.shiftTypeId == shiftTypeId &&
      other.countsAsOvertime == countsAsOvertime;

  @override
  int get hashCode => Object.hash(
    start,
    end,
    endDayOffset,
    Object.hashAll(breaks),
    shiftTypeId,
    countsAsOvertime,
  );
}

/// An unconfirmed planned work day as the plan holds it now. It has no
/// stored id: it is identified by its employment and date (spec 4.2).
@immutable
final class PlannedDayRecord {
  const PlannedDayRecord({
    required this.employmentId,
    required this.day,
    required this.exception,
  });

  final EmploymentId employmentId;
  final PlannedShift day;

  /// The changed or extra day that shapes it; null when it is the cycle's
  /// own shift.
  final DayException? exception;

  LocalDate get date => day.date;

  /// The times the day is planned with, as its editors show them.
  PlannedDayValues get values => switch (exception) {
    ChangedDay(:final start, :final end, :final endDayOffset, :final breaks) ||
    ExtraDay(
      :final start,
      :final end,
      :final endDayOffset,
      :final breaks,
    ) => PlannedDayValues(
      start: start,
      end: end,
      endDayOffset: endDayOffset,
      breaks: breaks,
      shiftTypeId: switch (exception) {
        ChangedDay(:final shiftTypeId) ||
        ExtraDay(:final shiftTypeId) => shiftTypeId,
        _ => null,
      },
      countsAsOvertime: switch (exception) {
        ExtraDay(:final countsAsOvertime) => countsAsOvertime,
        _ => false,
      },
    ),
    _ => PlannedDayValues(
      start: day.type!.start,
      end: day.type!.end,
      endDayOffset: day.type!.endDayOffset,
      breaks: day.type!.breaks,
    ),
  };

  /// The same day with the same exception revision and times.
  @override
  bool operator ==(Object other) =>
      other is PlannedDayRecord &&
      other.employmentId == employmentId &&
      other.date == date &&
      other.day.isExtra == day.isExtra &&
      other.exception?.id == exception?.id &&
      other.exception?.revision == exception?.revision &&
      other.values == values;

  @override
  int get hashCode => Object.hash(
    employmentId,
    date,
    exception?.id,
    exception?.revision,
    values,
  );
}

/// Reads [employmentId]'s planned work day on [date] from the plan, or
/// null when the date holds no unconfirmed planned shift (it was
/// confirmed, cancelled, made leave, or its schedule moved).
Future<PlannedDayRecord?> readPlannedDay(
  DayPlanService plans,
  EmploymentId employmentId,
  LocalDate date,
) async {
  final inputs = await plans.repository.planInputs(employmentId);
  final day = planDays(
    from: date,
    to: date,
    schedules: inputs.schedules,
    exceptions: inputs.exceptions,
    confirmedDates: inputs.confirmedDates,
    zoneClocks: plans.zoneClocks,
  ).firstOrNull;
  if (day is! PlannedShift) return null;
  final exception = inputs.exceptions
      .where((value) => value.date == date)
      .firstOrNull;
  return PlannedDayRecord(
    employmentId: employmentId,
    day: day,
    exception: exception is ChangedDay || exception is ExtraDay
        ? exception
        : null,
  );
}

/// Words for a planned day's problems, by field key.
abstract final class PlannedDayProblems {
  static const end =
      'The shift must last more than a minute and at most 24 hours.';
  static const breaks =
      'Keep each break inside the shift, 1 to 240 minutes, without '
      'overlaps.';
  static const confirmed = 'This day is already confirmed.';
  static const notPlanned = 'The schedule no longer plans work on this day.';
  static const shiftType = 'Pick a shift type of this schedule.';
}

/// The problems of [values] by field key, empty when they make a shift
/// (schedules spec 3.2): it lasts more than a minute and at most 24 hours,
/// and its breaks are 1..240 minutes, inside it, without overlaps.
Map<String, String> plannedDayProblems(PlannedDayValues values) {
  final check = checkShiftTimes(
    ShiftType(
      id: const ShiftTypeId('day'),
      name: 'Day',
      start: values.start,
      end: values.end,
      endDayOffset: values.endDayOffset,
      breaks: values.breaks,
    ),
  );
  return {
    if (!check.times) 'end': PlannedDayProblems.end,
    if (!check.breaks) 'breaks': PlannedDayProblems.breaks,
  };
}

/// Saves an unconfirmed planned work day as a day exception through
/// `DayPlanService` (spec 4.2 save matrix, first row): the day stays
/// unconfirmed, and confirming it remains a separate action. Saving asks
/// nothing.
final class PlannedDayAdapter
    implements RecordEditAdapter<PlannedDayRecord, PlannedDayValues> {
  const PlannedDayAdapter(this.plans);

  final DayPlanService plans;

  /// A planned day always exists; its session starts from it.
  @override
  PlannedDayValues draftOf(PlannedDayRecord? saved) {
    if (saved == null) {
      throw ArgumentError.notNull('saved');
    }
    return saved.values;
  }

  @override
  Map<String, String> validate(PlannedDayValues draft) =>
      plannedDayProblems(draft);

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final MapEntry(:key, :value) in fields.entries)
      key: switch ((key, value.firstOrNull?.code)) {
        ('end', _) => PlannedDayProblems.end,
        ('breaks', _) => PlannedDayProblems.breaks,
        ('date', FieldIssueCode.conflict) => PlannedDayProblems.confirmed,
        ('date', _) => PlannedDayProblems.notPlanned,
        ('shiftTypeId', _) => PlannedDayProblems.shiftType,
        _ => WorkProblems.unknownField,
      },
  };

  @override
  Future<ConfirmRequest?> guard(
    PlannedDayRecord? baseline,
    PlannedDayValues draft,
  ) async => null;

  @override
  Future<SubmitResult<PlannedDayRecord>> submit(
    PlannedDayRecord? baseline,
    PlannedDayValues draft, {
    Object? consent,
  }) async {
    final saved = baseline!;
    // The service guards only the exception's revision: a day whose plan
    // changed under the session (another schedule version or cycle) would
    // be saved over the new plan, so that is Stale before any write. A day
    // no longer planned is left to the command, which says why.
    final current = await readPlannedDay(plans, saved.employmentId, saved.date);
    if (current != null && current != saved) {
      return const Submitted(Stale());
    }
    final day = saved.day;
    final outcome = day.isExtra
        ? await plans.addExtra(
            saved.employmentId,
            saved.date,
            start: draft.start,
            end: draft.end,
            endDayOffset: draft.endDayOffset,
            breaks: draft.breaks,
            shiftTypeId: draft.shiftTypeId,
            countsAsOvertime: draft.countsAsOvertime,
            expected: saved.exception?.revision,
          )
        : await plans.changeDay(
            saved.employmentId,
            saved.date,
            start: draft.start,
            end: draft.end,
            endDayOffset: draft.endDayOffset,
            breaks: draft.breaks,
            shiftTypeId: draft.shiftTypeId,
            expected: saved.exception?.revision,
          );
    return Submitted(
      await settle(
        outcome,
        (_) => readPlannedDay(plans, saved.employmentId, saved.date),
      ),
    );
  }

  @override
  Future<ReadBack<PlannedDayRecord>> readBack(
    PlannedDayRecord? baseline,
    PlannedDayValues? submitted,
  ) async {
    final saved = baseline!;
    final current = await readPlannedDay(plans, saved.employmentId, saved.date);
    if (current == null) return const ReadGone();
    return ReadFound(
      current,
      saved: submitted != null && current.values == submitted,
    );
  }
}
