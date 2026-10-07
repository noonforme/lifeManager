import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/shift.dart';
import 'work_commands.dart';

final class CommitOutcomeUnknown implements Exception {
  const CommitOutcomeUnknown();
}

/// Finalizing and correcting shifts. The live start, break and end
/// commands were removed with the tracker (schedules spec 3.8).
abstract interface class ShiftLifecycleRepository {
  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required Revision expected,
  });

  Future<MutationOutcome<WorkShift>> commitCorrection(
    ShiftId originalId, {
    required Revision expected,
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  });

  /// Removes a draft or finalized shift: void with [voidReason] and no
  /// replacement. A blank reason is Invalid on `voidReason`, a void shift
  /// Invalid on `state`.
  Future<MutationOutcome<WorkShift>> commitVoid(
    ShiftId id, {
    required Revision expected,
    required String voidReason,
    required DateTime nowUtc,
  });
}

final class ShiftLifecycleService {
  const ShiftLifecycleService(
    this._repository, {
    required this.idFactory,
    required this.clock,
  });

  final ShiftLifecycleRepository _repository;
  final ShiftIdFactory idFactory;
  final AppClock clock;

  Future<MutationOutcome<WorkShift>> finalizeShift(
    FinalizeShiftCommand command,
  ) {
    return _mapStorageFailure(
      () => _repository.commitFinalization(
        command.id,
        expected: command.expectedRevision,
      ),
    );
  }

  Future<MutationOutcome<WorkShift>> correctShift(CorrectShiftCommand command) {
    return _mapCommitFailure(
      () => _repository.commitCorrection(
        command.originalId,
        expected: command.expectedRevision,
        replacementId: command.replacementId,
        voidReason: command.voidReason,
        nowUtc: clock.nowUtc(),
      ),
    );
  }

  /// "Remove this shift": void without a replacement (spec 10.7).
  Future<MutationOutcome<WorkShift>> voidShift(VoidShiftCommand command) {
    return _mapCommitFailure(
      () => _repository.commitVoid(
        command.id,
        expected: command.expectedRevision,
        voidReason: command.voidReason,
        nowUtc: clock.nowUtc(),
      ),
    );
  }
}

/// As [_mapStorageFailure], and a commit whose result is unknown is
/// Uncertain rather than retried.
Future<MutationOutcome<WorkShift>> _mapCommitFailure(
  Future<MutationOutcome<WorkShift>> Function() operation,
) async {
  try {
    return await _mapStorageFailure(operation);
  } on CommitOutcomeUnknown {
    return const Uncertain<WorkShift>(SafeFailureCode.commitOutcomeUnknown);
  }
}

Future<MutationOutcome<WorkShift>> _mapStorageFailure(
  Future<MutationOutcome<WorkShift>> Function() operation,
) async {
  try {
    return await operation();
  } on DatabaseOpenFailure {
    return const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable);
  } on DatabaseValidationFailure {
    return const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable);
  }
}
