import '../../../shared/workbench/era_icons.dart';
import '../data/projections/work_record_projection.dart';
import 'work_plan_view.dart' show leaveTypeLabel;

/// A record's name in captions and Details: "Shift 2026-09-08".
String recordName(WorkRecordProjection record) => switch (record) {
  ShiftRecordProjection(:final shift) => 'Shift ${shift.localStartDate}',
  PayPeriodRecordProjection(:final period) =>
    period.label ?? 'Pay period ${period.start} – ${period.end}',
  PayslipRecordProjection(:final payslip) => 'Payslip ${payslip.issuedDate}',
  EmploymentRecordProjection(:final employment) => employment.name,
  AgreementRecordProjection() => 'Pay agreement',
  LeaveRecordProjection(:final leave) =>
    '${leaveTypeLabel(leave.leaveType)} on ${leave.date}',
};

/// A record kind's painted icon.
EraIconKind recordIcon(WorkRecordProjection record) => switch (record) {
  ShiftRecordProjection() => EraIconKind.shift,
  PayPeriodRecordProjection() => EraIconKind.payPeriod,
  PayslipRecordProjection() => EraIconKind.payslip,
  EmploymentRecordProjection() => EraIconKind.employment,
  AgreementRecordProjection() => EraIconKind.agreement,
  LeaveRecordProjection() => EraIconKind.payPeriod,
};
