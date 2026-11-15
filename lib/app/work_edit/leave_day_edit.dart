import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/planner.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import 'work_outcomes.dart';

/// The pending leave of an unconfirmed planned leave day: what
/// `DayPlanService.markLeave` saves (Change leave, plan 4d-1 call 7).
@immutable
final class LeaveDayValues {
  const LeaveDayValues({required this.leaveType, this.illnessStartedOn});

  final LeaveType leaveType;

  /// Sick leave only; null counts from the first sick day.
  final LocalDate? illnessStartedOn;

  @override
  bool operator ==(Object other) =>
      other is LeaveDayValues &&
      other.leaveType == leaveType &&
      other.illnessStartedOn == illnessStartedOn;

  @override
  int get hashCode => Object.hash(leaveType, illnessStartedOn);
}

/// An unconfirmed planned leave day as the plan holds it now, with the
/// change that makes it leave.
@immutable
final class LeaveDayRecord {
  const LeaveDayRecord({
    required this.employmentId,
    required this.day,
    required this.exception,
  });

  final EmploymentId employmentId;
  final PlannedLeave day;
  final LeaveDay exception;

  LocalDate get date => day.date;

  LeaveDayValues get values => LeaveDayValues(
    leaveType: exception.leaveType,
    illnessStartedOn: exception.illnessStartedOn,
  );

  @override
  bool operator ==(Object other) =>
      other is LeaveDayRecord &&
      other.employmentId == employmentId &&
      other.date == date &&
      other.exception.id == exception.id &&
      other.exception.revision == exception.revision &&
      other.values == values;

  @override
  int get hashCode =>
      Object.hash(employmentId, date, exception.id, exception.revision, values);
}

/// Reads [employmentId]'s planned leave day on [date], or null when the
/// date holds none (it was confirmed, restored or changed).
Future<LeaveDayRecord?> readLeaveDay(
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
  final exception = inputs.exceptions
      .where((value) => value.date == date)
      .firstOrNull;
  if (day is! PlannedLeave || exception is! LeaveDay) return null;
  return LeaveDayRecord(
    employmentId: employmentId,
    day: day,
    exception: exception,
  );
}

/// Words for a leave day's problems.
abstract final class LeaveDayProblems {
  static const illness = 'The illness must start on or before this day.';
  static const notLeave = 'This day is no longer planned leave.';
}

/// Saves an unconfirmed leave day's leave through `DayPlanService.markLeave`
/// with its change's revision (spec 4.2 save matrix, first row): the day
/// stays unconfirmed, and saving asks nothing.
final class LeaveDayAdapter
    implements RecordEditAdapter<LeaveDayRecord, LeaveDayValues> {
  const LeaveDayAdapter(this.plans, {required this.date});

  final DayPlanService plans;

  /// The day the leave is on: an illness cannot start after it.
  final LocalDate date;

  @override
  LeaveDayValues draftOf(LeaveDayRecord? saved) {
    if (saved == null) throw ArgumentError.notNull('saved');
    return saved.values;
  }

  /// An illness start belongs to sick leave and lies on or before [date].
  @override
  Map<String, String> validate(LeaveDayValues draft) => {
    if (draft.illnessStartedOn case final start?
        when draft.leaveType != LeaveType.sick || start.compareTo(date) > 0)
      'illnessStartedOn': LeaveDayProblems.illness,
  };

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final key in fields.keys)
      key: switch (key) {
        'illnessStartedOn' => LeaveDayProblems.illness,
        'date' => LeaveDayProblems.notLeave,
        _ => WorkProblems.unknownField,
      },
  };

  @override
  Future<ConfirmRequest?> guard(
    LeaveDayRecord? baseline,
    LeaveDayValues draft,
  ) async => null;

  @override
  Future<SubmitResult<LeaveDayRecord>> submit(
    LeaveDayRecord? baseline,
    LeaveDayValues draft, {
    Object? consent,
  }) async {
    final saved = baseline!;
    final current = await readLeaveDay(plans, saved.employmentId, saved.date);
    if (current != null && current != saved) {
      return const Submitted(Stale());
    }
    final outcome = await plans.markLeave(
      saved.employmentId,
      saved.date,
      leaveType: draft.leaveType,
      illnessStartedOn: draft.illnessStartedOn,
      expected: saved.exception.revision,
    );
    return Submitted(
      await settle(
        outcome,
        (_) => readLeaveDay(plans, saved.employmentId, saved.date),
      ),
    );
  }

  @override
  Future<ReadBack<LeaveDayRecord>> readBack(
    LeaveDayRecord? baseline,
    LeaveDayValues? submitted,
  ) async {
    final saved = baseline!;
    final current = await readLeaveDay(plans, saved.employmentId, saved.date);
    if (current == null) return const ReadGone();
    return ReadFound(
      current,
      saved: submitted != null && current.values == submitted,
    );
  }
}
