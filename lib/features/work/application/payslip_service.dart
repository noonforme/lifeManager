import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/payslip.dart';
import 'shift_lifecycle_service.dart' show CommitOutcomeUnknown;
import 'work_commands.dart';

abstract interface class PayslipRepository {
  Future<int> insertPayslip(Payslip value);

  Future<Payslip?> payslipById(PayslipId id);

  Future<MutationOutcome<Payslip>> correctPayslip(
    PayslipId originalId, {
    required Revision expected,
    required Payslip replacement,
    required String voidReason,
    required DateTime nowUtc,
  });
}

final class PayslipService {
  const PayslipService(
    this._repository, {
    required this.idFactory,
    required this.clock,
  });

  final PayslipRepository _repository;
  final WorkEvidenceIdFactory idFactory;
  final AppClock clock;

  Future<MutationOutcome<Payslip>> recordPayslip(
    RecordPayslipCommand command,
  ) async {
    try {
      final nowUtc = clock.nowUtc();
      final value = Payslip(
        id: command.id ?? idFactory.payslipId(),
        periodId: command.periodId,
        issuedDate: command.issuedDate,
        paidDate: command.paidDate,
        amount: Money(minorUnits: command.amountMinorUnits),
        basis: command.basis,
        grossMinorUnits: command.grossMinorUnits,
        netMinorUnits: command.netMinorUnits,
        deductionMinorUnits: command.deductionMinorUnits,
        reference: _trimOptional(command.reference),
        note: _trimOptional(command.note),
        state: PayslipState.effective,
        voidReason: null,
        replacementPayslipId: null,
        replacedPayslipId: null,
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
        revision: const Revision(0),
      );
      await _repository.insertPayslip(value);
      return Committed<Payslip>(value);
    } on ArgumentError {
      return const Invalid<Payslip>({
        'payslip': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on DatabaseOpenFailure {
      return const Unavailable<Payslip>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<Payslip>(SafeFailureCode.storageUnavailable);
    }
  }

  Future<MutationOutcome<Payslip>> correctPayslip(
    CorrectPayslipCommand command,
  ) async {
    try {
      final original = await _repository.payslipById(command.originalId);
      if (original == null) return const Missing<Payslip>();
      if (original.revision != command.expectedRevision) {
        return const Stale<Payslip>();
      }
      final nowUtc = clock.nowUtc();
      final facts = command.replacement;
      if (facts != null && facts.periodId != original.periodId) {
        return const Invalid<Payslip>({
          'period': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      final replacement = facts == null
          ? original.replacement(
              replacementId: command.replacementId,
              nowUtc: nowUtc,
            )
          : Payslip(
              id: command.replacementId,
              periodId: original.periodId,
              issuedDate: facts.issuedDate,
              paidDate: facts.paidDate,
              amount: Money(minorUnits: facts.amountMinorUnits),
              basis: facts.basis,
              grossMinorUnits: facts.grossMinorUnits,
              netMinorUnits: facts.netMinorUnits,
              deductionMinorUnits: facts.deductionMinorUnits,
              reference: _trimOptional(facts.reference),
              note: _trimOptional(facts.note),
              state: PayslipState.effective,
              voidReason: null,
              replacementPayslipId: null,
              replacedPayslipId: original.id,
              createdAtUtc: nowUtc,
              updatedAtUtc: nowUtc,
              revision: const Revision(0),
            );
      return await _repository.correctPayslip(
        command.originalId,
        expected: command.expectedRevision,
        replacement: replacement,
        voidReason: command.voidReason,
        nowUtc: nowUtc,
      );
    } on CommitOutcomeUnknown {
      return const Uncertain<Payslip>(SafeFailureCode.commitOutcomeUnknown);
    } on ArgumentError {
      return const Invalid<Payslip>({
        'correction': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on DatabaseOpenFailure {
      return const Unavailable<Payslip>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<Payslip>(SafeFailureCode.storageUnavailable);
    }
  }
}

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
