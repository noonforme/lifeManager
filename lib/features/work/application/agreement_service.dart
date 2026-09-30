import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import 'work_commands.dart';

final class AgreementService {
  const AgreementService(
    this._repository, {
    required this._idFactory,
    required this._clock,
  });

  final WorkCommandRepository _repository;
  final WorkIdFactory _idFactory;
  final AppClock _clock;

  Future<MutationOutcome<PayAgreement>> createAgreement(
    CreateAgreementCommand command,
  ) async {
    if (command.version <= 0 ||
        command.hourlyRateMicroEur <= 0 ||
        command.overtimeThresholdMinutes <= 0 ||
        command.overtimeMultiplierNumerator <= 0 ||
        command.overtimeMultiplierDenominator <= 0 ||
        (command.effectiveEnd != null &&
            command.effectiveEnd!.compareTo(command.effectiveStart) < 0)) {
      return const Invalid<PayAgreement>({
        'agreement': [FieldIssue(FieldIssueCode.invalid)],
      });
    }
    late final PayAgreement value;
    try {
      value = PayAgreement(
        id: _idFactory.agreementId(),
        employmentId: command.employmentId,
        version: command.version,
        effectiveStart: command.effectiveStart,
        effectiveEnd: command.effectiveEnd,
        hourlyRateMicroEur: command.hourlyRateMicroEur,
        basis: command.basis,
        overtimeThresholdMinutes: command.overtimeThresholdMinutes,
        overtimeMultiplier: RationalMultiplier(
          numerator: command.overtimeMultiplierNumerator,
          denominator: command.overtimeMultiplierDenominator,
        ),
        label: _trimOptional(command.label),
        note: _trimOptional(command.note),
        createdAtUtc: _clock.nowUtc(),
        revision: const Revision(0),
        usedByFinalizedShift: false,
      );
    } on ArgumentError {
      return const Invalid<PayAgreement>({
        'agreement': [FieldIssue(FieldIssueCode.invalid)],
      });
    }

    try {
      return await _repository.transaction((store) async {
        final existing = await store.agreementsFor(value.employmentId);
        if (!validateAgreementSet([...existing, value]).isValid) {
          return const Invalid<PayAgreement>({
            'effectiveRange': [FieldIssue(FieldIssueCode.conflict)],
          });
        }
        await store.insertAgreement(value);
        return Committed<PayAgreement>(value);
      });
    } on DatabaseOpenFailure {
      return const Unavailable<PayAgreement>(
        SafeFailureCode.storageUnavailable,
      );
    } on DatabaseValidationFailure {
      return const Unavailable<PayAgreement>(
        SafeFailureCode.storageUnavailable,
      );
    }
  }

  Future<MutationOutcome<PayAgreement>> closeAgreement(
    CloseAgreementCommand command,
  ) async {
    try {
      return await _repository.transaction((store) async {
        final agreements = await store.agreementsFor(command.employmentId);
        final matches = agreements.where(
          (value) => value.id == command.agreementId,
        );
        if (matches.isEmpty) return const Missing<PayAgreement>();
        final current = matches.single;
        if (current.revision != command.expectedRevision) {
          return const Stale<PayAgreement>();
        }
        late final PayAgreement closed;
        try {
          closed = current.withRangeEnd(command.end);
        } on ArgumentError {
          return const Invalid<PayAgreement>({
            'effectiveEnd': [FieldIssue(FieldIssueCode.invalid)],
          });
        } on StateError {
          return const Invalid<PayAgreement>({
            'effectiveEnd': [FieldIssue(FieldIssueCode.invalid)],
          });
        }
        final withoutCurrent = agreements.where(
          (value) => value.id != current.id,
        );
        if (!validateAgreementSet([...withoutCurrent, closed]).isValid) {
          return const Invalid<PayAgreement>({
            'effectiveRange': [FieldIssue(FieldIssueCode.conflict)],
          });
        }
        final changed = await store.updateUnusedAgreement(
          closed,
          expected: command.expectedRevision,
        );
        return changed == 0
            ? const Stale<PayAgreement>()
            : Committed<PayAgreement>(closed);
      });
    } on DatabaseOpenFailure {
      return const Unavailable<PayAgreement>(
        SafeFailureCode.storageUnavailable,
      );
    } on DatabaseValidationFailure {
      return const Unavailable<PayAgreement>(
        SafeFailureCode.storageUnavailable,
      );
    }
  }
}

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
