import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../domain/employment.dart';
import 'work_commands.dart';

final class EmploymentService {
  const EmploymentService(
    this._repository, {
    required this._idFactory,
    required this._clock,
  });

  final WorkCommandRepository _repository;
  final WorkIdFactory _idFactory;
  final AppClock _clock;

  Future<MutationOutcome<Employment>> createEmployment(
    CreateEmploymentCommand command,
  ) async {
    late final Employment value;
    try {
      value = Employment.create(
        id: _idFactory.employmentId(),
        name: command.name,
        legalLabel: command.legalLabel,
        nowUtc: _clock.nowUtc(),
      );
    } on ArgumentError {
      return const Invalid<Employment>({
        'name': [FieldIssue(FieldIssueCode.required)],
      });
    }
    try {
      return await _repository.transaction((store) async {
        await store.insertEmployment(value);
        return Committed<Employment>(value);
      });
    } on DatabaseOpenFailure {
      return const Unavailable<Employment>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<Employment>(SafeFailureCode.storageUnavailable);
    }
  }

  Future<MutationOutcome<Employment>> archiveEmployment(
    ArchiveEmploymentCommand command,
  ) async {
    try {
      return await _repository.transaction((store) async {
        final current = await store.employmentById(command.employmentId);
        if (current == null) return const Missing<Employment>();
        if (current.revision != command.expectedRevision) {
          return const Stale<Employment>();
        }
        final archived = current.archive(nowUtc: _clock.nowUtc());
        final changed = await store.updateEmployment(
          archived,
          expected: command.expectedRevision,
        );
        return changed == 0
            ? const Stale<Employment>()
            : Committed<Employment>(archived);
      });
    } on DatabaseOpenFailure {
      return const Unavailable<Employment>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<Employment>(SafeFailureCode.storageUnavailable);
    }
  }
}
