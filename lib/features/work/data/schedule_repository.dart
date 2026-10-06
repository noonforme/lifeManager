import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/database/sqlite_errors.dart';
import '../../../core/history/record_events.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/local_date.dart';
import '../application/day_plan_service.dart';
import '../application/schedule_service.dart';
import '../domain/day_exception.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/schedule.dart';
import 'daos/agreement_dao.dart';
import 'daos/day_exception_dao.dart';
import 'daos/leave_dao.dart';
import 'daos/schedule_dao.dart';
import 'work_history.dart';

/// Schedules, day exceptions, confirmed days and leave in SQLite.
final class DriftScheduleRepository
    implements ScheduleRepository, DayPlanRepository {
  /// History entries are stamped by [clock].
  DriftScheduleRepository(this._database, {AppClock? clock})
    : _history = WorkHistoryWriter(_database, clock ?? SystemAppClock()),
      _schedules = ScheduleDao(_database),
      _exceptions = DayExceptionDao(_database),
      _agreements = AgreementDao(_database),
      _leave = LeaveDao(_database);

  final AppDatabase _database;
  final WorkHistoryWriter _history;
  final ScheduleDao _schedules;
  final DayExceptionDao _exceptions;
  final AgreementDao _agreements;
  final LeaveDao _leave;

  @override
  Future<List<WorkSchedule>> schedulesFor(EmploymentId id) =>
      _schedules.forEmployment(id);

  @override
  Stream<List<WorkSchedule>> watchSchedules(EmploymentId id) async* {
    yield await _schedules.forEmployment(id);
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([
        _database.workSchedules,
        _database.workScheduleShiftTypes,
        _database.workScheduleBlocks,
        _database.workShifts,
        _database.workLeaveRecords,
      ]),
    )) {
      yield await _schedules.forEmployment(id);
    }
  }

  @override
  Future<LocalDate?> lastConfirmedDate(ScheduleId id, int version) =>
      _schedules.lastConfirmedDate(id, version);

  @override
  Future<MutationOutcome<WorkSchedule>> insertVersion(
    WorkSchedule value, {
    WorkSchedule? closing,
    Revision? closingExpected,
  }) => _database.transaction(() async {
    if (closing != null) {
      final before = await _schedules.version(closing.id, closing.version);
      if (before == null) return const Missing<WorkSchedule>();
      final closed = await _schedules.closeVersion(
        closing.id,
        closing.version,
        closing.inUseUntil!,
        expected: closingExpected ?? before.revision,
      );
      if (closed == 0) return const Stale<WorkSchedule>();
      final after = (await _schedules.version(closing.id, closing.version))!;
      await _history.record(
        WorkRecordKinds.schedule,
        scheduleRecordId(after),
        kind: RecordEventKind.changed,
        before: scheduleFacts(before),
        after: scheduleFacts(after),
        revisionAfter: after.revision,
      );
    }
    await _schedules.insertVersion(value);
    await _history.record(
      WorkRecordKinds.schedule,
      scheduleRecordId(value),
      kind: RecordEventKind.created,
      after: scheduleFacts(value),
      revisionAfter: value.revision,
    );
    return Committed<WorkSchedule>(
      (await _schedules.version(value.id, value.version))!,
    );
  });

  @override
  Future<MutationOutcome<WorkSchedule>> replaceVersion(
    WorkSchedule value, {
    required Revision expected,
  }) => _database.transaction(() async {
    final before = await _schedules.version(value.id, value.version);
    if (before == null) return const Missing<WorkSchedule>();
    // A day confirmed since the edit began makes this version evidence.
    if (before.usedByConfirmedDay) return const Stale<WorkSchedule>();
    final changed = await _schedules.replaceVersion(value, expected: expected);
    if (changed == 0) return const Stale<WorkSchedule>();
    final after = (await _schedules.version(value.id, value.version))!;
    await _history.record(
      WorkRecordKinds.schedule,
      scheduleRecordId(after),
      kind: RecordEventKind.changed,
      before: scheduleFacts(before),
      after: scheduleFacts(after),
      revisionAfter: after.revision,
    );
    return Committed<WorkSchedule>(after);
  });

  @override
  Future<MutationOutcome<WorkSchedule>> deleteSchedule(
    ScheduleId id, {
    required Revision expected,
  }) => _database.transaction(() async {
    final versions = await _schedules.versionsOf(id);
    if (versions.isEmpty) return const Missing<WorkSchedule>();
    final latest = versions.reduce((a, b) => a.version > b.version ? a : b);
    if (latest.revision != expected) return const Stale<WorkSchedule>();
    if (await _schedules.scheduleUsed(id)) {
      return const Invalid<WorkSchedule>({
        'schedule': [FieldIssue(FieldIssueCode.conflict)],
      });
    }
    await _schedules.deleteSchedule(id);
    for (final value in versions) {
      await _history.events.deleteFor(
        WorkRecordKinds.schedule,
        scheduleRecordId(value),
      );
    }
    return Committed<WorkSchedule>(latest);
  });

  @override
  Future<PlanInputs> planInputs(EmploymentId id) => _database.transaction(
    () async => PlanInputs(
      schedules: await _schedules.forEmployment(id),
      exceptions: await _exceptions.forEmployment(id),
      confirmedDates: await _confirmedDates(id),
      agreements: await _agreements.forEmployment(id),
    ),
  );

  @override
  Stream<PlanInputs> watchPlanInputs(EmploymentId id) {
    late StreamController<PlanInputs> controller;
    late StreamSubscription<void> updates;

    controller = StreamController<PlanInputs>(
      onListen: () async {
        // Emit initial value
        final initial = await planInputs(id);
        if (!controller.isClosed) {
          controller.add(initial);
        }
        // Listen for updates
        updates = _database
            .tableUpdates(
              TableUpdateQuery.onAllTables([
                _database.workSchedules,
                _database.workScheduleShiftTypes,
                _database.workScheduleBlocks,
                _database.workDayExceptions,
                _database.workShifts,
                _database.workLeaveRecords,
                _database.payAgreements,
              ]),
            )
            .listen(
              (_) async {
                final updated = await planInputs(id);
                if (!controller.isClosed) {
                  controller.add(updated);
                }
              },
              onError: controller.addError,
              onDone: controller.close,
            );
      },
      onCancel: () async {
        await updates.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<MutationOutcome<DayException>> putException(
    DayException value, {
    Revision? expected,
  }) => _database.transaction(() async {
    if ((await _confirmedDates(value.employmentId)).contains(value.date)) {
      return const Invalid<DayException>({
        'date': [FieldIssue(FieldIssueCode.conflict)],
      });
    }
    if (expected == null) {
      final taken = (await _exceptions.forEmployment(value.employmentId))
          .any((other) => other.date == value.date);
      if (taken) return const Stale<DayException>();
      await _exceptions.insert(value);
    } else {
      final changed = await _exceptions.replace(value, expected: expected);
      if (changed == 0) return const Stale<DayException>();
    }
    return Committed<DayException>((await _exceptions.byId(value.id))!);
  });

  @override
  Future<MutationOutcome<DayException>> removeException(
    DayExceptionId id, {
    required Revision expected,
  }) => _database.transaction(() async {
    final value = await _exceptions.byId(id);
    if (value == null) return const Missing<DayException>();
    if ((await _confirmedDates(value.employmentId)).contains(value.date)) {
      return const Invalid<DayException>({
        'date': [FieldIssue(FieldIssueCode.conflict)],
      });
    }
    final removed = await _exceptions.delete(id, expected: expected);
    if (removed == 0) return const Stale<DayException>();
    return Committed<DayException>(value);
  });

  @override
  Future<List<LeaveRecord>> leaveFor(EmploymentId id) =>
      _leave.forEmployment(id);

  @override
  Future<LeaveRecord?> leaveById(LeaveRecordId id) => _leave.byId(id);

  @override
  Stream<List<LeaveRecord>> watchLeave(EmploymentId id) async* {
    yield await _leave.forEmployment(id);
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([_database.workLeaveRecords]),
    )) {
      yield await _leave.forEmployment(id);
    }
  }

  @override
  Future<MutationOutcome<LeaveRecord>> insertLeave(LeaveRecord value) async {
    try {
      return await _database.transaction(() async {
        if ((await _confirmedDates(value.employmentId)).contains(value.date)) {
          return const Stale<LeaveRecord>();
        }
        await _leave.insert(value);
        await _history.record(
          WorkRecordKinds.leave,
          value.id.value,
          kind: RecordEventKind.created,
          after: leaveFacts(value),
          revisionAfter: value.revision,
        );
        return Committed<LeaveRecord>(value);
      });
    } on Object catch (error) {
      // one_confirmed_leave_per_day: another confirm won the date.
      if (isUniqueViolation(error)) return const Stale<LeaveRecord>();
      rethrow;
    }
  }

  @override
  Future<MutationOutcome<LeaveRecord>> correctLeave(
    LeaveRecordId id, {
    required Revision expected,
    required LeaveRecord replacement,
    required String reason,
  }) => _database.transaction(() async {
    final original = await _leave.byId(id);
    if (original == null) return const Missing<LeaveRecord>();
    if (!original.isEffective || original.revision != expected) {
      return const Stale<LeaveRecord>();
    }
    final voided = await _leave.voidConfirmed(
      id,
      expected: expected,
      reason: reason,
      nowUtc: replacement.createdAtUtc,
    );
    if (voided == 0) return const Stale<LeaveRecord>();
    await _leave.insert(replacement);
    await _leave.linkReplacement(id, replacement.id);
    final after = (await _leave.byId(id))!;
    await _history.record(
      WorkRecordKinds.leave,
      id.value,
      kind: RecordEventKind.voided,
      before: leaveFacts(original),
      after: leaveFacts(after),
      revisionAfter: after.revision,
      reason: reason,
    );
    await _history.record(
      WorkRecordKinds.leave,
      replacement.id.value,
      kind: RecordEventKind.replaced,
      after: leaveFacts(replacement),
      revisionAfter: replacement.revision,
    );
    return Committed<LeaveRecord>(replacement);
  });

  Future<Set<LocalDate>> _confirmedDates(EmploymentId id) =>
      _schedules.confirmedDates(id);
}
