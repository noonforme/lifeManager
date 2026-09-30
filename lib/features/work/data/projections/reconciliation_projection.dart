import '../../domain/agreement.dart';
import '../../domain/ids.dart';
import '../../domain/pay.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../../domain/reconciliation.dart';
import '../../domain/shift.dart';

final class ReconciliationProjection {
  const ReconciliationProjection({
    required this.period,
    required this.shiftFacts,
    required this.payslipEvidence,
    required this.groups,
  });

  final PayPeriod period;
  final List<WorkShift> shiftFacts;
  final List<Payslip> payslipEvidence;
  final List<ReconciliationGroup> groups;

  Money get paid => Money(
    minorUnits: groups.fold(
      0,
      (total, group) => total + (group.paid?.minorUnits ?? 0),
    ),
  );
}

ReconciliationProjection projectReconciliation({
  required EmploymentId employmentId,
  required PayPeriod period,
  required Iterable<WorkShift> shifts,
  required Iterable<ShiftBreak> breaks,
  required Iterable<PayAgreement> agreements,
  required Iterable<Payslip> payslips,
}) {
  final shiftFacts = shifts.toList(growable: false);
  final evidence = payslips
      .where((value) => value.isEffective)
      .toList(growable: false);
  return ReconciliationProjection(
    period: period,
    shiftFacts: shiftFacts,
    payslipEvidence: evidence,
    groups: reconcilePeriod(
      employmentId: employmentId,
      period: period,
      shifts: shiftFacts,
      breaks: breaks,
      agreements: agreements,
      payslips: evidence,
    ),
  );
}
