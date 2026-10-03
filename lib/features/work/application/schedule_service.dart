import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/local_date.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import 'work_commands.dart';

/// What the owner edits for a schedule (schedules spec 6.4).
final class ScheduleDraft {
  const ScheduleDraft({
    required this.employmentId,
    required this.name,
    required this.timezoneId,
    required this.cycleStart,
    required this.inUseFrom,
    required this.inUseUntil,
    required this.shiftTypes,
    required this.blocks,
  });

  final EmploymentId employmentId;
  final String name;
  final String timezoneId;
  final LocalDate cycleStart;
  final LocalDate inUseFrom;
  final LocalDate? inUseUntil;
  final List<ShiftType> shiftTypes;
  final List<CycleBlock> blocks;
}

abstract interface class ScheduleRepository {
  /// Every version of every schedule of the employment.
  Future<List<WorkSchedule>> schedulesFor(EmploymentId id);

  Stream<List<WorkSchedule>> watchSchedules(EmploymentId id);

  /// The last date confirmed from one version, as a shift or as leave.
  Future<LocalDate?> lastConfirmedDate(ScheduleId id, int version);

  /// Inserts [value]; with [closing], first ends that version on its
  /// `inUseUntil`, provided it is still at [closingExpected].
  Future<MutationOutcome<WorkSchedule>> insertVersion(
    WorkSchedule value, {
    WorkSchedule? closing,
    Revision? closingExpected,
  });

  /// Rewrites a version no confirmed day uses yet.
  Future<MutationOutcome<WorkSchedule>> replaceVersion(
    WorkSchedule value, {
    required Revision expected,
  });

  /// Deletes every version, while no confirmed day uses the schedule.
  Future<MutationOutcome<WorkSchedule>> deleteSchedule(
    ScheduleId id, {
    required Revision expected,
  });
}

/// Creates, edits and deletes schedules (schedules spec 3.1, 6.4).
final class ScheduleService {
  const ScheduleService({
    required this.repository,
    required this.ids,
    required this.clock,
  });

  final ScheduleRepository repository;
  final ScheduleIdFactory ids;
  final AppClock clock;

  Future<MutationOutcome<WorkSchedule>> create(ScheduleDraft draft) =>
      _guard(() async {
        final WorkSchedule value;
        try {
          value = _build(
            draft,
            id: ids.scheduleId(),
            version: 1,
            inUseFrom: draft.inUseFrom,
            createdAtUtc: clock.nowUtc(),
            revision: const Revision(0),
          );
        } on ArgumentError {
          return _invalid('schedule');
        }
        final refused = await _check(value);
        return refused ?? repository.insertVersion(value);
      });

  /// Edits the latest version in place while no confirmed day uses it;
  /// otherwise ends it the day before [newVersionFrom] and starts the next
  /// version from that date.
  Future<MutationOutcome<WorkSchedule>> update(
    ScheduleId id, {
    required Revision expected,
    required ScheduleDraft draft,
    LocalDate? newVersionFrom,
  }) => _guard(() async {
    final current = _latest(
      await repository.schedulesFor(draft.employmentId),
      id,
    );
    if (current == null) return const Missing<WorkSchedule>();
    if (current.revision != expected) return const Stale<WorkSchedule>();
    if (!current.usedByConfirmedDay) {
      final WorkSchedule value;
      try {
        value = _build(
          draft,
          id: id,
          version: current.version,
          inUseFrom: draft.inUseFrom,
          createdAtUtc: current.createdAtUtc,
          revision: current.revision.next(),
        );
      } on ArgumentError {
        return _invalid('schedule');
      }
      final refused = await _check(value);
      return refused ??
          repository.replaceVersion(value, expected: current.revision);
    }
    if (newVersionFrom == null) {
      return const Invalid<WorkSchedule>({
        'newVersionFrom': [FieldIssue(FieldIssueCode.required)],
      });
    }
    if (newVersionFrom.compareTo(current.inUseFrom) <= 0) {
      return const Invalid<WorkSchedule>({
        'newVersionFrom': [FieldIssue(FieldIssueCode.invalid)],
      });
    }
    // Confirmed days keep the version they were planned from, so the new
    // version starts after the last of them.
    final lastConfirmed = await repository.lastConfirmedDate(
      id,
      current.version,
    );
    if (lastConfirmed != null && newVersionFrom.compareTo(lastConfirmed) <= 0) {
      return const Invalid<WorkSchedule>({
        'newVersionFrom': [FieldIssue(FieldIssueCode.conflict)],
      });
    }
    // Ending the current version never moves an earlier end later.
    final dayBefore = newVersionFrom.addDays(-1);
    final currentEnd = current.inUseUntil;
    final until = currentEnd != null && currentEnd.compareTo(dayBefore) < 0
        ? currentEnd
        : dayBefore;
    final closing = WorkSchedule(
      id: current.id,
      employmentId: current.employmentId,
      name: current.name,
      timezoneId: current.timezoneId,
      version: current.version,
      cycleStart: current.cycleStart,
      inUseFrom: current.inUseFrom,
      inUseUntil: until,
      shiftTypes: current.shiftTypes,
      blocks: current.blocks,
      createdAtUtc: current.createdAtUtc,
      revision: current.revision.next(),
      usedByConfirmedDay: true,
    );
    final WorkSchedule next;
    try {
      next = _build(
        draft,
        id: id,
        version: current.version + 1,
        inUseFrom: newVersionFrom,
        createdAtUtc: clock.nowUtc(),
        revision: const Revision(0),
      );
    } on ArgumentError {
      return _invalid('schedule');
    }
    final refused = await _check(next, replacing: current, closing: closing);
    return refused ??
        repository.insertVersion(
          next,
          closing: closing,
          closingExpected: current.revision,
        );
  });

  Future<MutationOutcome<WorkSchedule>> delete(
    ScheduleId id, {
    required Revision expected,
  }) => _guard(() => repository.deleteSchedule(id, expected: expected));

  /// The field issues and overlaps that refuse [value], or null.
  Future<MutationOutcome<WorkSchedule>?> _check(
    WorkSchedule value, {
    WorkSchedule? replacing,
    WorkSchedule? closing,
  }) async {
    final issues = validateSchedule(value);
    if (issues.isNotEmpty) {
      final fields = <String, List<FieldIssue>>{};
      for (final issue in issues) {
        fields
            .putIfAbsent(issue.field ?? 'schedule', () => [])
            .add(const FieldIssue(FieldIssueCode.invalid));
      }
      return Invalid<WorkSchedule>(fields);
    }
    final others = [
      for (final other in await repository.schedulesFor(value.employmentId))
        if (!(replacing != null &&
            other.id == replacing.id &&
            other.version == replacing.version))
          other,
      ?closing,
    ];
    if (scheduleOverlaps(value, others)) {
      return const Invalid<WorkSchedule>({
        'inUseFrom': [FieldIssue(FieldIssueCode.conflict)],
      });
    }
    return null;
  }
}

WorkSchedule? _latest(List<WorkSchedule> all, ScheduleId id) {
  WorkSchedule? latest;
  for (final value in all) {
    if (value.id != id) continue;
    if (latest == null || value.version > latest.version) latest = value;
  }
  return latest;
}

WorkSchedule _build(
  ScheduleDraft draft, {
  required ScheduleId id,
  required int version,
  required LocalDate inUseFrom,
  required DateTime createdAtUtc,
  required Revision revision,
}) => WorkSchedule(
  id: id,
  employmentId: draft.employmentId,
  name: draft.name.trim(),
  timezoneId: draft.timezoneId.trim(),
  version: version,
  cycleStart: draft.cycleStart,
  inUseFrom: inUseFrom,
  inUseUntil: draft.inUseUntil,
  shiftTypes: List.unmodifiable(draft.shiftTypes),
  blocks: List.unmodifiable(draft.blocks),
  createdAtUtc: createdAtUtc,
  revision: revision,
);

Invalid<WorkSchedule> _invalid(String field) => Invalid<WorkSchedule>({
  field: const [FieldIssue(FieldIssueCode.invalid)],
});

Future<MutationOutcome<WorkSchedule>> _guard(
  Future<MutationOutcome<WorkSchedule>> Function() body,
) async {
  try {
    return await body();
  } on DatabaseOpenFailure {
    return const Unavailable<WorkSchedule>(SafeFailureCode.storageUnavailable);
  } on DatabaseValidationFailure {
    return const Unavailable<WorkSchedule>(SafeFailureCode.storageUnavailable);
  }
}
