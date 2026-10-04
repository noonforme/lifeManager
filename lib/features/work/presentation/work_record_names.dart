import '../data/projections/work_record_projection.dart';

/// A record's name in captions and Details: "Shift 2026-09-08".
String recordName(WorkRecordProjection record) => switch (record) {
  ShiftRecordProjection(:final shift) => 'Shift ${shift.localStartDate}',
  PayPeriodRecordProjection(:final period) =>
    period.label ?? 'Pay period ${period.start} – ${period.end}',
  PayslipRecordProjection(:final payslip) => 'Payslip ${payslip.issuedDate}',
  EmploymentRecordProjection(:final employment) => employment.name,
  AgreementRecordProjection() => 'Pay agreement',
};
