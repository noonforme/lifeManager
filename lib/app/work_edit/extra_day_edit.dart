import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/ids.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import 'planned_day_edit.dart';
import 'work_outcomes.dart';

/// Words for an extra shift's problems.
abstract final class ExtraDayProblems {
  static const notOff =
      'The schedule plans work on this day; change that day instead.';
}

/// Adds an extra shift on an Off day through `DayPlanService.addExtra`
/// (Add extra shift, plan 4d-1 call 8): a new record until its first save,
/// which needs no question; after it, the same day's extra shift is edited
/// with its change's revision.
final class ExtraDayAdapter
    implements RecordEditAdapter<PlannedDayRecord, PlannedDayValues> {
  const ExtraDayAdapter({
    required this.plans,
    required this.employmentId,
    required this.date,
    required this.defaults,
  });

  final DayPlanService plans;
  final EmploymentId employmentId;
  final LocalDate date;

  /// What a new extra shift starts from: the first shift type of the
  /// schedule in use on [date].
  final PlannedDayValues defaults;

  @override
  PlannedDayValues draftOf(PlannedDayRecord? saved) =>
      saved?.values ?? defaults;

  @override
  Map<String, String> validate(PlannedDayValues draft) =>
      plannedDayProblems(draft);

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final key in fields.keys)
      key: switch (key) {
        'date' => ExtraDayProblems.notOff,
        'end' => PlannedDayProblems.end,
        'breaks' => PlannedDayProblems.breaks,
        'shiftTypeId' => PlannedDayProblems.shiftType,
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
    final outcome = await plans.addExtra(
      employmentId,
      date,
      start: draft.start,
      end: draft.end,
      endDayOffset: draft.endDayOffset,
      breaks: draft.breaks,
      shiftTypeId: draft.shiftTypeId,
      countsAsOvertime: draft.countsAsOvertime,
      expected: baseline?.exception?.revision,
    );
    return Submitted(
      await settle(outcome, (_) => readPlannedDay(plans, employmentId, date)),
    );
  }

  @override
  Future<ReadBack<PlannedDayRecord>> readBack(
    PlannedDayRecord? baseline,
    PlannedDayValues? submitted,
  ) async {
    final current = await readPlannedDay(plans, employmentId, date);
    if (current == null || !current.day.isExtra) return const ReadGone();
    return ReadFound(
      current,
      saved: submitted != null && current.values == submitted,
    );
  }
}
