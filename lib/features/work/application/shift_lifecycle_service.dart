import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/timezone_service.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/shift.dart';
import 'work_commands.dart';

final class CommitOutcomeUnknown implements Exception {
  const CommitOutcomeUnknown();
}

abstract interface class ShiftLifecycleRepository {
  Future<MutationOutcome<WorkShift>> commitStart(WorkShift shift);

  Future<MutationOutcome<WorkShift>> commitStartBreak(
    ShiftBreak value, {
    required Revision expectedShift,
  });

  Future<MutationOutcome<WorkShift>> commitEndBreak(
    ShiftBreakId id, {
    required ShiftId shiftId,
    required DateTime endUtc,
    required Revision expectedBreak,
    required Revision expectedShift,
  });

  Future<MutationOutcome<WorkShift>> commitEndShift(
    ShiftId id, {
    required DateTime endUtc,
    required Revision expected,
  });

  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required int overtimeMinutes,
    required Revision expected,
  });

  Future<MutationOutcome<WorkShift>> commitCorrection(
    ShiftId originalId, {
    required Revision expected,
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  });
}

final class ShiftLifecycleService {
  const ShiftLifecycleService(
    this._repository, {
    required this.idFactory,
    required this.clock,
    required this.timezones,
  });

  final ShiftLifecycleRepository _repository;
  final ShiftIdFactory idFactory;
  final AppClock clock;
  final TimezoneService timezones;

  Future<MutationOutcome<WorkShift>> startShift(
    StartShiftCommand command,
  ) async {
    final nowUtc = clock.nowUtc();
    late final WorkShift shift;
    try {
      shift = WorkShift(
        id: idFactory.shiftId(),
        employmentId: command.employmentId,
        agreementId: null,
        state: ShiftState.running,
        startUtc: nowUtc,
        endUtc: null,
        timezoneId: command.timezoneId,
        localStartDate: timezones.localDateAt(nowUtc, command.timezoneId),
        overtimeMinutes: 0,
        note: _trimOptional(command.note),
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
        revision: const Revision(0),
      );
    } on UnknownTimezone {
      return const Invalid<WorkShift>({
        'timezoneId': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on ArgumentError {
      return const Invalid<WorkShift>({
        'shift': [FieldIssue(FieldIssueCode.invalid)],
      });
    }
    return _mapStorageFailure(() => _repository.commitStart(shift));
  }

  Future<MutationOutcome<WorkShift>> startBreak(StartBreakCommand command) {
    final nowUtc = clock.nowUtc();
    final value = ShiftBreak(
      id: idFactory.shiftBreakId(),
      shiftId: command.shiftId,
      startUtc: nowUtc,
      endUtc: null,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      revision: const Revision(0),
    );
    return _mapStorageFailure(
      () => _repository.commitStartBreak(
        value,
        expectedShift: command.expectedShiftRevision,
      ),
    );
  }

  Future<MutationOutcome<WorkShift>> endBreak(EndBreakCommand command) {
    return _mapStorageFailure(
      () => _repository.commitEndBreak(
        command.breakId,
        shiftId: command.shiftId,
        endUtc: clock.nowUtc(),
        expectedBreak: command.expectedBreakRevision,
        expectedShift: command.expectedShiftRevision,
      ),
    );
  }

  Future<MutationOutcome<WorkShift>> endShift(EndShiftCommand command) {
    return _mapStorageFailure(
      () => _repository.commitEndShift(
        command.id,
        endUtc: clock.nowUtc(),
        expected: command.expectedRevision,
      ),
    );
  }

  Future<MutationOutcome<WorkShift>> finalizeShift(
    FinalizeShiftCommand command,
  ) {
    if (command.overtimeMinutes < 0) {
      return Future.value(
        const Invalid<WorkShift>({
          'overtimeMinutes': [FieldIssue(FieldIssueCode.outOfRange)],
        }),
      );
    }
    return _mapStorageFailure(
      () => _repository.commitFinalization(
        command.id,
        overtimeMinutes: command.overtimeMinutes,
        expected: command.expectedRevision,
      ),
    );
  }

  Future<MutationOutcome<WorkShift>> correctShift(
    CorrectShiftCommand command,
  ) async {
    try {
      return await _repository.commitCorrection(
        command.originalId,
        expected: command.expectedRevision,
        replacementId: command.replacementId,
        voidReason: command.voidReason,
        nowUtc: clock.nowUtc(),
      );
    } on CommitOutcomeUnknown {
      return const Uncertain<WorkShift>(SafeFailureCode.commitOutcomeUnknown);
    } on DatabaseOpenFailure {
      return const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable);
    }
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

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
