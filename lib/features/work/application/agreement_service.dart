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

  /// Rewrites an agreement's terms in place. One in use is corrected, as if
  /// it had always said this: whatever it pays is priced from it, so the
  /// change reprices them, and its history says so. Its dates still cover
  /// every day it paid. "Change terms from…" sets new terms from a date
  /// instead (premiums spec 7, added 2026-10-08).
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
        final revised = correctedAgreement(current, command.terms);
        // Terms that break the agreement's rules are invalid, in use or not.
        if (revised == null) return _invalidTerms;
        if (current.usedByFinalizedShift) {
          final first = await store.firstAgreementUse(current.id);
          if (first != null && revised.effectiveStart.compareTo(first) > 0) {
            return const Invalid<PayAgreement>({
              'effectiveStart': [FieldIssue(FieldIssueCode.conflict)],
            });
          }
          final last = await store.lastAgreementUse(current.id);
          final end = revised.effectiveEnd;
          if (last != null && end != null && end.compareTo(last) < 0) {
            return const Invalid<PayAgreement>({
              'effectiveEnd': [FieldIssue(FieldIssueCode.conflict)],
            });
          }
        }
        final others = agreements.where((value) => value.id != current.id);
        if (!validateAgreementSet([...others, revised]).isValid) {
          return _overlap;
        }
        final changed = current.usedByFinalizedShift
            ? await store.correctAgreement(
                revised,
                expected: command.expectedRevision,
                reason: revised.paysAs(current)
                    ? null
                    : agreementCorrectionReason,
              )
            : await store.updateUnusedAgreement(
                revised,
                expected: command.expectedRevision,
              );
        return changed == 0
            ? const Stale<PayAgreement>()
            : Committed<PayAgreement>(revised);
      }),
    );
  }

  /// "Change terms from…" in one transaction: the agreement ends the day
  /// before `from` and the next version starts on it. Shifts and leave
  /// already confirmed keep the agreement they were paid under, so `from`
  /// falls after the last of them (foundation spec 10.2).
  Future<MutationOutcome<PayAgreement>> changeAgreementTerms(
    ChangeAgreementTermsCommand command,
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
        final from = command.from;
        final end = current.effectiveEnd;
        if (from.compareTo(current.effectiveStart) <= 0 ||
            (end != null && from.compareTo(end) > 0)) {
          return const Invalid<PayAgreement>({
            'from': [FieldIssue(FieldIssueCode.outOfRange)],
          });
        }
        final lastUse = await store.lastAgreementUse(current.id);
        if (lastUse != null && from.compareTo(lastUse) <= 0) {
          return const Invalid<PayAgreement>({
            'from': [FieldIssue(FieldIssueCode.conflict)],
          });
        }
        final terms = command.terms;
        final next = _build(
          id: _idFactory.agreementId(),
          employmentId: current.employmentId,
          // One past the highest, so no two versions share a name.
          version: agreements.map((value) => value.version).reduce(_max) + 1,
          terms: AgreementTerms(
            effectiveStart: from,
            effectiveEnd: end,
            hourlyRateMicroEur: terms.hourlyRateMicroEur,
            basis: terms.basis,
            label: terms.label,
            note: terms.note,
            overtimeThresholdMinutes: terms.overtimeThresholdMinutes,
            overtimeMultiplier: terms.overtimeMultiplier,
            nightEnabled: terms.nightEnabled,
            nightStartMinute: terms.nightStartMinute,
            nightEndMinute: terms.nightEndMinute,
            nightMultiplier: terms.nightMultiplier,
            holidayCalendar: terms.holidayCalendar,
            holidayMultiplier: terms.holidayMultiplier,
            premiumStacking: terms.premiumStacking,
            vacationPay: terms.vacationPay,
            sickPay: terms.sickPay,
            sickEmployerDays: terms.sickEmployerDays,
          ),
          createdAtUtc: _clock.nowUtc(),
          revision: const Revision(0),
        );
        if (next == null) return _invalidTerms;
        final ended = current.withRange(
          start: current.effectiveStart,
          end: from.addDays(-1),
        );
        final others = agreements.where((value) => value.id != current.id);
        if (!validateAgreementSet([...others, ended, next]).isValid) {
          return _overlap;
        }
        final changed = await store.updateAgreementRange(
          ended,
          expected: command.expectedRevision,
        );
        if (changed == 0) return const Stale<PayAgreement>();
        await store.insertAgreement(next);
        return Committed<PayAgreement>(next);
      }),
    );
  }

  /// "Remove agreement…": deletes an agreement no finalized or void shift
  /// and no leave refers to. Draft shifts hold no agreement; they find
  /// one when they finalize.
  Future<MutationOutcome<PayAgreement>> deleteAgreement(
    DeleteAgreementCommand command,
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
        if (current.usedByFinalizedShift) return _inUse;
        final deleted = await store.deleteUnusedAgreement(
          current.id,
          expected: command.expectedRevision,
        );
        // The revision matched, so a shift still refers to it.
        return deleted == 0 ? _inUse : Committed<PayAgreement>(current);
      }),
    );
  }

  /// "End agreement…": [CloseAgreementCommand.end] becomes its last day,
  /// never before its start or a day it was used on.
  Future<MutationOutcome<PayAgreement>> closeAgreement(
    CloseAgreementCommand command,
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
        if (command.end.compareTo(current.effectiveStart) < 0) {
          return const Invalid<PayAgreement>({
            'effectiveEnd': [FieldIssue(FieldIssueCode.outOfRange)],
          });
        }
        final lastUse = await store.lastAgreementUse(current.id);
        if (lastUse != null && command.end.compareTo(lastUse) < 0) {
          return const Invalid<PayAgreement>({
            'effectiveEnd': [FieldIssue(FieldIssueCode.conflict)],
          });
        }
        final closed = current.withRange(
          start: current.effectiveStart,
          end: command.end,
        );
        final withoutCurrent = agreements.where(
          (value) => value.id != current.id,
        );
        if (!validateAgreementSet([...withoutCurrent, closed]).isValid) {
          return _overlap;
        }
        final changed = await store.updateAgreementRange(
          closed,
          expected: command.expectedRevision,
        );
        return changed == 0
            ? const Stale<PayAgreement>()
            : Committed<PayAgreement>(closed);
      }),
    );
  }
}

/// The history reason of a correction that reprices what an agreement
/// pays.
const agreementCorrectionReason =
    'Corrected in place; the shifts and leave it pays were repriced.';

/// [current] rewritten with [terms], keeping its identity, version and
/// creation; null when the terms break its rules. Saving and the
/// correction preview price the same agreement.
PayAgreement? correctedAgreement(PayAgreement current, AgreementTerms terms) =>
    _build(
      id: current.id,
      employmentId: current.employmentId,
      version: current.version,
      terms: terms,
      createdAtUtc: current.createdAtUtc,
      revision: current.revision.next(),
    );

int _max(int a, int b) => a > b ? a : b;

const _inUse = Invalid<PayAgreement>({
  'agreement.inUse': [FieldIssue(FieldIssueCode.conflict)],
});

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
      vacationPay: terms.vacationPay,
      sickPay: terms.sickPay,
      sickEmployerDays: terms.sickEmployerDays,
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
