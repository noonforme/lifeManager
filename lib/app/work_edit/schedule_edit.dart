import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/app_clock.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/schedule_service.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/schedule.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import '../edit_session/record_edit_session.dart';
import 'schedule_fields.dart';
import 'work_outcomes.dart';
import 'work_records.dart';

/// A schedule's edit session.
typedef ScheduleSession = RecordEditSession<ScheduleRecord, ScheduleValues>;

/// Saves a schedule through `ScheduleService` (spec 4.2 save matrix,
/// schedule rows): a new one with `create`; the latest version no
/// confirmed day uses with `update` in place; and, in [versioning] mode,
/// a used version as a new version from `ScheduleValues.versionFrom` with
/// `update(newVersionFrom:)` ("Change schedule from…"). Fields, shift types
/// and cycle save together. One adapter serves one session.
final class ScheduleAdapter
    implements RecordEditAdapter<ScheduleRecord, ScheduleValues> {
  ScheduleAdapter({
    required this.employmentId,
    required this.defaults,
    required this.service,
    required this.reads,
    required this.clock,
    this.versioning = false,
    this.versionStart,
    this.lastConfirmed,
  });

  final EmploymentId employmentId;

  /// What a new schedule starts with; in [versioning] mode, the new
  /// version's start is taken from its `versionFrom`.
  final ScheduleValues defaults;
  final ScheduleService service;
  final WorkReads reads;
  final AppClock clock;

  /// Saving makes the next version of a used one.
  final bool versioning;

  /// The changed version's start and its last confirmed day: a new version
  /// starts after both.
  final LocalDate? versionStart;
  final LocalDate? lastConfirmed;

  /// When the last create was sent.
  DateTime? _sentAt;

  @override
  ScheduleValues draftOf(ScheduleRecord? saved) {
    if (saved == null) return defaults;
    final values = ScheduleValues.of(saved.value);
    return versioning
        ? values.copyWith(versionFrom: () => defaults.versionFrom)
        : values;
  }

  @override
  Map<String, String> validate(ScheduleValues draft) {
    final issues = {...scheduleIssues(draft, employmentId: employmentId)};
    if (!versioning) return issues;
    final from = draft.versionFrom;
    final start = versionStart;
    final last = lastConfirmed;
    // Confirmed days lie on or after the start, so their words come first.
    if (from == null) {
      issues[ScheduleField.versionFrom] = ScheduleProblems.versionFromRequired;
    } else if (last != null && from.compareTo(last) <= 0) {
      issues[ScheduleField.versionFrom] = ScheduleProblems.confirmedUpTo(last);
    } else if (start != null && from.compareTo(start) <= 0) {
      issues[ScheduleField.versionFrom] = ScheduleProblems.afterStart(start);
    } else if (draft.inUseUntil case final until?
        when from.compareTo(until) > 0) {
      // The new version keeps the schedule's end: its own Until is not
      // edited here, so the From says it.
      issues
        ..remove(ScheduleField.inUseUntil)
        ..[ScheduleField.versionFrom] = ScheduleProblems.afterUntil(until);
    }
    return issues;
  }

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) =>
      describeScheduleIssues(
        fields,
        versionStart: versionStart,
        lastConfirmed: lastConfirmed,
      );

  @override
  Future<ConfirmRequest?> guard(
    ScheduleRecord? baseline,
    ScheduleValues draft,
  ) async => null;

  @override
  Future<SubmitResult<ScheduleRecord>> submit(
    ScheduleRecord? baseline,
    ScheduleValues draft, {
    Object? consent,
  }) async {
    final schedule = draft.toDraft(employmentId);
    if (baseline == null) {
      _sentAt = clock.nowUtc();
      return Submitted(await settle(await service.create(schedule), _read));
    }
    final current = baseline.value;
    final outcome = await service.update(
      current.id,
      expected: current.revision,
      draft: schedule,
      newVersionFrom: versioning ? draft.versionFrom : null,
    );
    return Submitted(await settle(outcome, _read));
  }

  Future<ScheduleRecord?> _read(WorkSchedule value) =>
      reads.schedule(employmentId, value.id, version: value.version);

  @override
  Future<ReadBack<ScheduleRecord>> readBack(
    ScheduleRecord? baseline,
    ScheduleValues? submitted,
  ) async {
    if (baseline != null) {
      final current = baseline.value;
      if (versioning && submitted != null) {
        final latest = await reads.schedule(employmentId, current.id);
        if (latest == null) return const ReadGone();
        final value = latest.value;
        if (value.version == current.version + 1 &&
            ScheduleValues.of(value) == _stored(submitted)) {
          return ReadFound(latest, saved: true);
        }
      }
      final same = await reads.schedule(
        employmentId,
        current.id,
        version: current.version,
      );
      if (same == null) return const ReadGone();
      return ReadFound(
        same,
        saved:
            !versioning &&
            submitted != null &&
            same.value.revision != current.revision &&
            ScheduleValues.of(same.value) == _stored(submitted),
      );
    }
    final sentAt = _sentAt;
    if (submitted == null || sentAt == null) return const ReadUnknown();
    // Any matching schedule created since the send counts, even one made
    // identically elsewhere meanwhile: the result is the same, and telling
    // them apart would need an idempotency key, new service behaviour.
    for (final row in await reads.scheduleRows(employmentId)) {
      final value = row.schedule;
      if (!value.createdAtUtc.isBefore(sentAt) &&
          ScheduleValues.of(value) == _stored(submitted)) {
        return ReadFound(ScheduleRecord(value), saved: true);
      }
    }
    return const ReadNotSaved();
  }
}

/// [values] as the service stores them: name and timezone trimmed, and a
/// new version starting on its `versionFrom`.
ScheduleValues _stored(ScheduleValues values) => values.copyWith(
  name: values.name.trim(),
  timezoneId: values.timezoneId.trim(),
  inUseFrom: values.versionFrom ?? values.inUseFrom,
  versionFrom: () => null,
);
