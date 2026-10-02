import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
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
    final value = _build(
      id: _idFactory.agreementId(),
      employmentId: command.employmentId,
      version: command.version,
      terms: command.terms,
      createdAtUtc: _clock.nowUtc(),
      revision: const Revision(0),
    );
    if (value == null) return _invalidTerms;

    return _guard(
      () => _repository.transaction((store) async {
        final existing = await store.agreementsFor(value.employmentId);
        if (!validateAgreementSet([...existing, value]).isValid) {
          return _overlap;
        }
        await store.insertAgreement(value);
        return Committed<PayAgreement>(value);
      }),
    );
  }

  /// Rewrites an agreement's terms. An agreement used by a finalized shift
  /// is evidence and stays as it is.
  Future<MutationOutcome<PayAgreement>> updateAgreement(
    UpdateAgreementCommand command,
  ) {
    return _guard(
      () => _repository.transaction((store) async {
        final agreements = await store.agreementsFor(command.employmentId);
        final matches = agreements.where(
          (value) => value.id == command.agreementId,
        );
        if (matches.isEmpty) return const Missing<PayAgreement>();
        final current = matches.single;
        if (current.revision != command.expectedRevision) {
          return const Stale<PayAgreement>();
        }
        if (current.usedByFinalizedShift) {
          return const Invalid<PayAgreement>({
            'agreement.inUse': [FieldIssue(FieldIssueCode.conflict)],
          });
        }
        final revised = _build(
          id: current.id,
          employmentId: current.employmentId,
          version: current.version,
          terms: command.terms,
          createdAtUtc: current.createdAtUtc,
          revision: current.revision.next(),
        );
        if (revised == null) return _invalidTerms;
        final others = agreements.where((value) => value.id != current.id);
        if (!validateAgreementSet([...others, revised]).isValid) {
          return _overlap;
        }
        final changed = await store.updateUnusedAgreement(
          revised,
          expected: command.expectedRevision,
        );
        return changed == 0
            ? const Stale<PayAgreement>()
            : Committed<PayAgreement>(revised);
      }),
    );
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
          return _overlap;
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

const _invalidTerms = Invalid<PayAgreement>({
  'agreement': [FieldIssue(FieldIssueCode.invalid)],
});

const _overlap = Invalid<PayAgreement>({
  'effectiveRange': [FieldIssue(FieldIssueCode.conflict)],
});

/// The agreement the terms describe, or null when they break its rules.
PayAgreement? _build({
  required AgreementId id,
  required EmploymentId employmentId,
  required int version,
  required AgreementTerms terms,
  required DateTime createdAtUtc,
  required Revision revision,
}) {
  try {
    return PayAgreement(
      id: id,
      employmentId: employmentId,
      version: version,
      effectiveStart: terms.effectiveStart,
      effectiveEnd: terms.effectiveEnd,
      hourlyRateMicroEur: terms.hourlyRateMicroEur,
      basis: terms.basis,
      overtimeThresholdMinutes: terms.overtimeThresholdMinutes,
      overtimeMultiplier: terms.overtimeMultiplier,
      label: _trimOptional(terms.label),
      note: _trimOptional(terms.note),
      createdAtUtc: createdAtUtc,
      revision: revision,
      usedByFinalizedShift: false,
      nightEnabled: terms.nightEnabled,
      nightStartMinute: terms.nightStartMinute,
      nightEndMinute: terms.nightEndMinute,
      nightMultiplier: terms.nightMultiplier,
      holidayCalendar: terms.holidayCalendar,
      holidayMultiplier: terms.holidayMultiplier,
      premiumStacking: terms.premiumStacking,
    );
  } on ArgumentError {
    return null;
  }
}

Future<MutationOutcome<PayAgreement>> _guard(
  Future<MutationOutcome<PayAgreement>> Function() body,
) async {
  try {
    return await body();
  } on DatabaseOpenFailure {
    return const Unavailable<PayAgreement>(SafeFailureCode.storageUnavailable);
  } on DatabaseValidationFailure {
    return const Unavailable<PayAgreement>(SafeFailureCode.storageUnavailable);
  }
}

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
