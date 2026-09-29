import '../../../core/time/local_date.dart';
import 'facts.dart';
import 'ids.dart';
import 'pay.dart';

enum PayslipState { effective, voided }

final class Payslip {
  Payslip({
    required this.id,
    required this.periodId,
    required this.issuedDate,
    required this.paidDate,
    required this.amount,
    required this.basis,
    required this.grossMinorUnits,
    required this.netMinorUnits,
    required this.deductionMinorUnits,
    required this.reference,
    required this.note,
    required this.state,
    required this.voidReason,
    required this.replacementPayslipId,
    required this.replacedPayslipId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  }) {
    if (amount.minorUnits <= 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    for (final entry in {
      'grossMinorUnits': grossMinorUnits,
      'netMinorUnits': netMinorUnits,
      'deductionMinorUnits': deductionMinorUnits,
    }.entries) {
      if (entry.value != null && entry.value! < 0) {
        throw ArgumentError.value(entry.value, entry.key);
      }
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
    if (!updatedAtUtc.isUtc) {
      throw ArgumentError.value(updatedAtUtc, 'updatedAtUtc');
    }
    if (state == PayslipState.voided &&
        (voidReason?.trim().isEmpty != false || replacementPayslipId == null)) {
      throw ArgumentError('Voided payslips require reason and replacement.');
    }
  }

  final PayslipId id;
  final PayPeriodId periodId;
  final LocalDate issuedDate;
  final LocalDate? paidDate;
  final Money amount;
  final RateBasis basis;
  final int? grossMinorUnits;
  final int? netMinorUnits;
  final int? deductionMinorUnits;
  final String? reference;
  final String? note;
  final PayslipState state;
  final String? voidReason;
  final PayslipId? replacementPayslipId;
  final PayslipId? replacedPayslipId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  bool get isEffective => state == PayslipState.effective;
}
