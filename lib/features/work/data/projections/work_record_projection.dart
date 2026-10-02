import '../../domain/agreement.dart';
import '../../domain/employment.dart';
import '../../domain/ids.dart';
import '../../domain/pay.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../../domain/shift.dart';

sealed class WorkRecordProjection {
  const WorkRecordProjection(this.id);

  final WorkRecordId id;
}

final class EmploymentRecordProjection extends WorkRecordProjection {
  EmploymentRecordProjection(this.employment) : super(employment.id);

  final Employment employment;
}

final class AgreementRecordProjection extends WorkRecordProjection {
  AgreementRecordProjection(this.agreement, {required this.finishedShifts})
    : super(agreement.id);

  final PayAgreement agreement;

  /// Finished shifts paid under this agreement; any makes it evidence.
  final int finishedShifts;

  bool get inUse => finishedShifts > 0;
}

final class ShiftRecordProjection extends WorkRecordProjection {
  ShiftRecordProjection(
    this.shift, {
    required this.breaks,
    this.facts,
    this.pay,
  }) : super(shift.id);

  final WorkShift shift;
  final List<ShiftBreak> breaks;

  /// For a finalized shift: the facts its expected pay was derived from.
  final FinalizationFacts? facts;

  /// For a finalized shift: expected pay with its premium breakdown.
  final ExpectedPay? pay;
}

final class PayPeriodRecordProjection extends WorkRecordProjection {
  PayPeriodRecordProjection(this.period) : super(period.id);

  final PayPeriod period;
}

final class PayslipRecordProjection extends WorkRecordProjection {
  PayslipRecordProjection(this.payslip) : super(payslip.id);

  final Payslip payslip;
}
