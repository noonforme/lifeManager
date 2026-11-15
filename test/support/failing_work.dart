import 'dart:async';

import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_write_store.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

/// Storage that refuses every write: each transaction throws as a database
/// that cannot be opened does, so the services answer Unavailable.
final class RefusingCommands implements WorkCommandRepository {
  @override
  Future<T> transaction<T>(Future<T> Function(WorkWriteStore store) body) =>
      Future.error(const DatabaseOpenFailure());
}

/// Runs every transaction through [inner], then throws [error] as if the
/// result were lost on the way back (it committed); with [before] set it
/// throws without running it (nothing committed).
final class LosingCommands implements WorkCommandRepository {
  LosingCommands(this.inner, {this.before = false});

  final WorkCommandRepository inner;
  bool before;

  /// Whether the next transaction throws; later ones run normally.
  bool armed = true;

  @override
  Future<T> transaction<T>(
    Future<T> Function(WorkWriteStore store) body,
  ) async {
    if (!armed) return inner.transaction(body);
    armed = false;
    if (before) throw StateError('The write was lost.');
    await inner.transaction(body);
    throw StateError('The answer was lost.');
  }
}

/// Holds every transaction until [release], then runs it through [inner]:
/// a command that is still running.
final class GatedCommands implements WorkCommandRepository {
  GatedCommands(this.inner);

  final WorkCommandRepository inner;
  final _gate = Completer<void>();

  /// Whether a transaction is waiting at the gate.
  bool waiting = false;

  void release() => _gate.complete();

  @override
  Future<T> transaction<T>(
    Future<T> Function(WorkWriteStore store) body,
  ) async {
    waiting = true;
    await _gate.future;
    return inner.transaction(body);
  }
}

/// Schedules read from [inner]; each write goes through [write].
abstract base class _WrappedSchedules implements ScheduleRepository {
  _WrappedSchedules(this.inner);

  final ScheduleRepository inner;

  Future<MutationOutcome<WorkSchedule>> write(
    Future<MutationOutcome<WorkSchedule>> Function() body,
  );

  @override
  Future<List<WorkSchedule>> schedulesFor(EmploymentId id) =>
      inner.schedulesFor(id);

  @override
  Stream<List<WorkSchedule>> watchSchedules(EmploymentId id) =>
      inner.watchSchedules(id);

  @override
  Future<LocalDate?> lastConfirmedDate(ScheduleId id, int version) =>
      inner.lastConfirmedDate(id, version);

  @override
  Future<MutationOutcome<WorkSchedule>> insertVersion(
    WorkSchedule value, {
    WorkSchedule? closing,
    Revision? closingExpected,
  }) => write(
    () => inner.insertVersion(
      value,
      closing: closing,
      closingExpected: closingExpected,
    ),
  );

  @override
  Future<MutationOutcome<WorkSchedule>> replaceVersion(
    WorkSchedule value, {
    required Revision expected,
  }) => write(() => inner.replaceVersion(value, expected: expected));

  @override
  Future<MutationOutcome<WorkSchedule>> deleteSchedule(
    ScheduleId id, {
    required Revision expected,
  }) => write(() => inner.deleteSchedule(id, expected: expected));
}

/// Every schedule write fails as unavailable storage.
final class RefusingSchedules extends _WrappedSchedules {
  RefusingSchedules(super.inner);

  @override
  Future<MutationOutcome<WorkSchedule>> write(
    Future<MutationOutcome<WorkSchedule>> Function() body,
  ) => Future.error(const DatabaseOpenFailure());
}

/// The next schedule write runs, then throws as if its answer were lost;
/// with [before] it throws without running.
final class LosingSchedules extends _WrappedSchedules {
  LosingSchedules(super.inner, {this.before = false});

  bool before;
  bool armed = true;

  @override
  Future<MutationOutcome<WorkSchedule>> write(
    Future<MutationOutcome<WorkSchedule>> Function() body,
  ) async {
    if (!armed) return body();
    armed = false;
    if (before) throw StateError('The write was lost.');
    await body();
    throw StateError('The answer was lost.');
  }
}

/// A plan store whose one-off read of the plan inputs fails while
/// [failing], or once a day's change is written with [failAfterWrite];
/// the rest goes through to [real].
final class PlanReadGate implements DayPlanRepository {
  PlanReadGate(this.real, {this.failing = true, this.failAfterWrite = false});

  final DayPlanRepository real;
  bool failing;
  bool failAfterWrite;
  void Function()? onExceptionCommitted;
  FutureOr<MutationOutcome<DayException>>? nextRemoval;
  bool removeBeforeReport = false;
  int failReadsAfterRemoval = 0;
  int _failedReads = 0;

  @override
  Future<PlanInputs> planInputs(EmploymentId id) async {
    if (failing || _failedReads-- > 0) {
      throw StateError('Local storage cannot be read.');
    }
    return real.planInputs(id);
  }

  @override
  Stream<PlanInputs> watchPlanInputs(EmploymentId id) =>
      real.watchPlanInputs(id);

  @override
  Future<MutationOutcome<DayException>> putException(
    DayException value, {
    Revision? expected,
  }) async {
    final outcome = await real.putException(value, expected: expected);
    onExceptionCommitted?.call();
    if (failAfterWrite) failing = true;
    return outcome;
  }

  @override
  Future<MutationOutcome<DayException>> removeException(
    DayExceptionId id, {
    required Revision expected,
  }) async {
    final script = nextRemoval;
    nextRemoval = null;
    if (script == null) return real.removeException(id, expected: expected);
    if (removeBeforeReport) await real.removeException(id, expected: expected);
    final result = await script;
    _failedReads = failReadsAfterRemoval;
    return result;
  }

  @override
  Future<List<LeaveRecord>> leaveFor(EmploymentId id) => real.leaveFor(id);

  @override
  Future<LeaveRecord?> leaveById(LeaveRecordId id) => real.leaveById(id);

  @override
  Stream<List<LeaveRecord>> watchLeave(EmploymentId id) => real.watchLeave(id);

  @override
  Future<MutationOutcome<LeaveRecord>> insertLeave(LeaveRecord value) =>
      real.insertLeave(value);

  @override
  Future<MutationOutcome<LeaveRecord>> correctLeave(
    LeaveRecordId id, {
    required Revision expected,
    required LeaveRecord replacement,
    required String reason,
  }) => real.correctLeave(
    id,
    expected: expected,
    replacement: replacement,
    reason: reason,
  );
}
