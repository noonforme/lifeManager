import '../../domain/employment.dart';
import '../../domain/ids.dart';
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

final class ShiftRecordProjection extends WorkRecordProjection {
  ShiftRecordProjection(
    this.shift, {
    required this.breaks,
    this.suggestedOvertimeMinutes,
  }) : super(shift.id);

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final int? suggestedOvertimeMinutes;
}

final class PayPeriodRecordProjection extends WorkRecordProjection {
  PayPeriodRecordProjection(this.period) : super(period.id);

  final PayPeriod period;
}

final class PayslipRecordProjection extends WorkRecordProjection {
  PayslipRecordProjection(this.payslip) : super(payslip.id);

  final Payslip payslip;
}
