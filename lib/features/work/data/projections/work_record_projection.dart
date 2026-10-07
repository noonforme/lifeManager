import '../../../../core/time/local_date.dart';
import '../../domain/agreement.dart';
import '../../domain/employment.dart';
import '../../domain/ids.dart';
import '../../domain/leave.dart';
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

/// What an agreement in use is evidence for.
enum AgreementUse { shifts, leave, both }

final class AgreementRecordProjection extends WorkRecordProjection {
  AgreementRecordProjection(
    this.agreement, {
    required this.finishedShifts,
    this.usedByLeave = false,
    this.firstUse,
    this.lastUse,
  }) : super(agreement.id);

  final PayAgreement agreement;

  /// Finished shifts paid under this agreement; any makes it evidence.
  final int finishedShifts;

  /// Whether leave was priced under it, which makes it evidence too.
  final bool usedByLeave;

  /// The first and last days a finished shift or confirmed leave was paid
  /// under it, which its dates must keep covering; null when none was.
  final LocalDate? firstUse;
  final LocalDate? lastUse;

  /// Evidence for finished shifts or for leave priced under it.
  bool get inUse => finishedShifts > 0 || agreement.usedByFinalizedShift;

  /// Who it pays, while in use; null when unused or not known.
  AgreementUse? get use => switch ((finishedShifts > 0, usedByLeave)) {
    (true, true) => AgreementUse.both,
    (true, false) => AgreementUse.shifts,
    (false, true) => AgreementUse.leave,
    (false, false) => null,
  };
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

final class LeaveRecordProjection extends WorkRecordProjection {
  LeaveRecordProjection(this.leave) : super(leave.id);

  final LeaveRecord leave;
}
