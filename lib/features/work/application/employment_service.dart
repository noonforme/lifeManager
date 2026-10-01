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

  Future<MutationOutcome<Employment>> updateEmployment(
    UpdateEmploymentCommand command,
  ) {
    return _guard(
      () => _repository.transaction((store) async {
        final current = await store.employmentById(command.employmentId);
        if (current == null) return const Missing<Employment>();
        if (current.revision != command.expectedRevision) {
          return const Stale<Employment>();
        }
        late final Employment renamed;
        try {
          renamed = current.renamed(
            name: command.name,
            legalLabel: command.legalLabel,
            nowUtc: _clock.nowUtc(),
          );
        } on ArgumentError {
          return const Invalid<Employment>({
            'name': [FieldIssue(FieldIssueCode.required)],
          });
        } on StateError {
          return const Invalid<Employment>({
            'employment': [FieldIssue(FieldIssueCode.unavailable)],
          });
        }
        final changed = await store.updateEmployment(
          renamed,
          expected: command.expectedRevision,
        );
        return changed == 0
            ? const Stale<Employment>()
            : Committed<Employment>(renamed);
      }),
    );
  }

  /// Deletes an employment and its agreements in one transaction, but only
  /// while nothing has been recorded against it.
  Future<MutationOutcome<Employment>> deleteEmployment(
    DeleteEmploymentCommand command,
  ) {
    return _guard(
      () => _repository.transaction((store) async {
        final current = await store.employmentById(command.employmentId);
        if (current == null) return const Missing<Employment>();
        if (current.revision != command.expectedRevision) {
          return const Stale<Employment>();
        }
        if (await store.employmentHasHistory(current.id)) {
          return const Invalid<Employment>({
            'employment.hasHistory': [FieldIssue(FieldIssueCode.conflict)],
          });
        }
        final deleted = await store.deleteEmployment(
          current.id,
          expected: command.expectedRevision,
        );
        return deleted == 0
            ? const Stale<Employment>()
            : Committed<Employment>(current);
      }),
    );
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

Future<MutationOutcome<Employment>> _guard(
  Future<MutationOutcome<Employment>> Function() body,
) async {
  try {
    return await body();
  } on DatabaseOpenFailure {
    return const Unavailable<Employment>(SafeFailureCode.storageUnavailable);
  } on DatabaseValidationFailure {
    return const Unavailable<Employment>(SafeFailureCode.storageUnavailable);
  }
}
