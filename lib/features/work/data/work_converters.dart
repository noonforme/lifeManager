import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/time/local_date.dart';
import '../domain/agreement.dart' as domain;
import '../domain/employment.dart' as domain;
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart' as domain;
import '../domain/payslip.dart' as domain;
import '../domain/shift.dart' as domain;

final class WorkDataCorruption implements Exception {
  const WorkDataCorruption({
    required this.recordType,
    required this.field,
    required this.value,
  });

  final String recordType;
  final String field;
  final Object? value;

  @override
  String toString() => 'Invalid stored $recordType.$field value.';
}

db.EmploymentsCompanion employmentToCompanion(domain.Employment value) =>
    db.EmploymentsCompanion.insert(
      id: value.id.value,
      name: value.name,
      legalLabel: Value(value.legalLabel),
      status: value.status.name,
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

domain.Employment employmentFromRow(db.Employment row) => _decode(
  'employment',
  () => domain.Employment(
    id: _requiredId('employment', 'id', row.id, EmploymentId.tryParse),
    name: row.name,
    legalLabel: row.legalLabel,
    status: _employmentStatus(row.status),
    createdAtUtc: _utc(row.createdAtUtcMicros),
    updatedAtUtc: _utc(row.updatedAtUtcMicros),
    revision: Revision.checked(row.revision),
  ),
);

db.PayAgreementsCompanion agreementToCompanion(domain.PayAgreement value) =>
    db.PayAgreementsCompanion.insert(
      id: value.id.value,
      employmentId: value.employmentId.value,
      version: value.version,
      effectiveStart: value.effectiveStart.toString(),
      effectiveEnd: Value(value.effectiveEnd?.toString()),
      hourlyRateMicroEur: value.hourlyRateMicroEur,
      basis: _basisText(value.basis),
      overtimeThresholdMinutes: value.overtimeThresholdMinutes,
      overtimeMultiplierNumerator: value.overtimeMultiplier.numerator,
      overtimeMultiplierDenominator: value.overtimeMultiplier.denominator,
      label: Value(value.label),
      note: Value(value.note),
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

domain.PayAgreement agreementFromRow(
  db.PayAgreement row, {
  required bool usedByFinalizedShift,
}) => _decode(
  'payAgreement',
  () => domain.PayAgreement(
    id: _requiredId('payAgreement', 'id', row.id, AgreementId.tryParse),
    employmentId: _requiredId(
      'payAgreement',
      'employmentId',
      row.employmentId,
      EmploymentId.tryParse,
    ),
    version: row.version,
    effectiveStart: _date('payAgreement', 'effectiveStart', row.effectiveStart),
    effectiveEnd: _nullableDate(
      'payAgreement',
      'effectiveEnd',
      row.effectiveEnd,
    ),
    hourlyRateMicroEur: row.hourlyRateMicroEur,
    basis: _basis('payAgreement', row.basis),
    overtimeThresholdMinutes: row.overtimeThresholdMinutes,
    overtimeMultiplier: domain.RationalMultiplier(
      numerator: row.overtimeMultiplierNumerator,
      denominator: row.overtimeMultiplierDenominator,
    ),
    label: row.label,
    note: row.note,
    createdAtUtc: _utc(row.createdAtUtcMicros),
    revision: Revision.checked(row.revision),
    usedByFinalizedShift: usedByFinalizedShift,
  ),
);

db.WorkShiftsCompanion shiftToCompanion(domain.WorkShift value) =>
    db.WorkShiftsCompanion.insert(
      id: value.id.value,
      employmentId: value.employmentId.value,
      agreementId: Value(value.agreementId?.value),
      state: value.state.name,
      startUtcMicros: value.startUtc.microsecondsSinceEpoch,
      endUtcMicros: Value(value.endUtc?.microsecondsSinceEpoch),
      timezoneId: value.timezoneId,
      localStartDate: value.localStartDate.toString(),
      overtimeMinutes: value.overtimeMinutes,
      note: Value(value.note),
      voidReason: Value(value.voidReason),
      replacementShiftId: Value(value.replacementShiftId?.value),
      replacedShiftId: Value(value.replacedShiftId?.value),
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

domain.WorkShift shiftFromRow(db.WorkShift row) => _decode(
  'workShift',
  () => domain.WorkShift(
    id: _requiredId('workShift', 'id', row.id, ShiftId.tryParse),
    employmentId: _requiredId(
      'workShift',
      'employmentId',
      row.employmentId,
      EmploymentId.tryParse,
    ),
    agreementId: _nullableId(
      'workShift',
      'agreementId',
      row.agreementId,
      AgreementId.tryParse,
    ),
    state: _shiftState(row.state),
    startUtc: _utc(row.startUtcMicros),
    endUtc: row.endUtcMicros == null ? null : _utc(row.endUtcMicros!),
    timezoneId: row.timezoneId,
    localStartDate: _date('workShift', 'localStartDate', row.localStartDate),
    overtimeMinutes: row.overtimeMinutes,
    note: row.note,
    voidReason: row.voidReason,
    replacementShiftId: _nullableId(
      'workShift',
      'replacementShiftId',
      row.replacementShiftId,
      ShiftId.tryParse,
    ),
    replacedShiftId: _nullableId(
      'workShift',
      'replacedShiftId',
      row.replacedShiftId,
      ShiftId.tryParse,
    ),
    createdAtUtc: _utc(row.createdAtUtcMicros),
    updatedAtUtc: _utc(row.updatedAtUtcMicros),
    revision: Revision.checked(row.revision),
  ),
);

db.ShiftBreaksCompanion shiftBreakToCompanion(domain.ShiftBreak value) =>
    db.ShiftBreaksCompanion.insert(
      id: value.id.value,
      shiftId: value.shiftId.value,
      startUtcMicros: value.startUtc.microsecondsSinceEpoch,
      endUtcMicros: Value(value.endUtc?.microsecondsSinceEpoch),
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

domain.ShiftBreak shiftBreakFromRow(db.ShiftBreak row) => _decode(
  'shiftBreak',
  () => domain.ShiftBreak(
    id: _requiredId('shiftBreak', 'id', row.id, ShiftBreakId.tryParse),
    shiftId: _requiredId(
      'shiftBreak',
      'shiftId',
      row.shiftId,
      ShiftId.tryParse,
    ),
    startUtc: _utc(row.startUtcMicros),
    endUtc: row.endUtcMicros == null ? null : _utc(row.endUtcMicros!),
    createdAtUtc: _utc(row.createdAtUtcMicros),
    updatedAtUtc: _utc(row.updatedAtUtcMicros),
    revision: Revision.checked(row.revision),
  ),
);

db.PayPeriodsCompanion payPeriodToCompanion(domain.PayPeriod value) =>
    db.PayPeriodsCompanion.insert(
      id: value.id.value,
      employmentId: value.employmentId.value,
      start: value.start.toString(),
      end: value.end.toString(),
      label: Value(value.label),
      state: value.state.name,
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

domain.PayPeriod payPeriodFromRow(db.PayPeriod row) => _decode(
  'payPeriod',
  () => domain.PayPeriod.rehydrate(
    id: _requiredId('payPeriod', 'id', row.id, PayPeriodId.tryParse),
    employmentId: _requiredId(
      'payPeriod',
      'employmentId',
      row.employmentId,
      EmploymentId.tryParse,
    ),
    start: _date('payPeriod', 'start', row.start),
    end: _date('payPeriod', 'end', row.end),
    label: row.label,
    state: _payPeriodState(row.state),
    createdAtUtc: _utc(row.createdAtUtcMicros),
    updatedAtUtc: _utc(row.updatedAtUtcMicros),
    revision: Revision.checked(row.revision),
  ),
);

db.PayslipsCompanion payslipToCompanion(domain.Payslip value) =>
    db.PayslipsCompanion.insert(
      id: value.id.value,
      periodId: value.periodId.value,
      issuedDate: value.issuedDate.toString(),
      paidDate: Value(value.paidDate?.toString()),
      amountMinorUnits: value.amount.minorUnits,
      currency: value.amount.currency.value,
      basis: _basisText(value.basis),
      grossMinorUnits: Value(value.grossMinorUnits),
      netMinorUnits: Value(value.netMinorUnits),
      deductionMinorUnits: Value(value.deductionMinorUnits),
      reference: Value(value.reference),
      note: Value(value.note),
      state: value.state.name,
      voidReason: Value(value.voidReason),
      replacementPayslipId: Value(value.replacementPayslipId?.value),
      replacedPayslipId: Value(value.replacedPayslipId?.value),
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

domain.Payslip payslipFromRow(db.Payslip row) => _decode(
  'payslip',
  () => domain.Payslip(
    id: _requiredId('payslip', 'id', row.id, PayslipId.tryParse),
    periodId: _requiredId(
      'payslip',
      'periodId',
      row.periodId,
      PayPeriodId.tryParse,
    ),
    issuedDate: _date('payslip', 'issuedDate', row.issuedDate),
    paidDate: _nullableDate('payslip', 'paidDate', row.paidDate),
    amount: Money(
      minorUnits: row.amountMinorUnits,
      currency: _currency(row.currency),
    ),
    basis: _basis('payslip', row.basis),
    grossMinorUnits: row.grossMinorUnits,
    netMinorUnits: row.netMinorUnits,
    deductionMinorUnits: row.deductionMinorUnits,
    reference: row.reference,
    note: row.note,
    state: _payslipState(row.state),
    voidReason: row.voidReason,
    replacementPayslipId: _nullableId(
      'payslip',
      'replacementPayslipId',
      row.replacementPayslipId,
      PayslipId.tryParse,
    ),
    replacedPayslipId: _nullableId(
      'payslip',
      'replacedPayslipId',
      row.replacedPayslipId,
      PayslipId.tryParse,
    ),
    createdAtUtc: _utc(row.createdAtUtcMicros),
    updatedAtUtc: _utc(row.updatedAtUtcMicros),
    revision: Revision.checked(row.revision),
  ),
);

T _decode<T>(String recordType, T Function() decode) {
  try {
    return decode();
  } on WorkDataCorruption {
    rethrow;
  } on Object {
    throw WorkDataCorruption(
      recordType: recordType,
      field: 'record',
      value: null,
    );
  }
}

T _requiredId<T>(
  String recordType,
  String field,
  String value,
  T? Function(String?) parse,
) {
  final parsed = parse(value);
  if (parsed == null) {
    throw WorkDataCorruption(
      recordType: recordType,
      field: field,
      value: value,
    );
  }
  return parsed;
}

T? _nullableId<T>(
  String recordType,
  String field,
  String? value,
  T? Function(String?) parse,
) {
  if (value == null) return null;
  return _requiredId(recordType, field, value, parse);
}

LocalDate _date(String recordType, String field, String value) {
  final parsed = LocalDate.tryParse(value);
  if (parsed == null) {
    throw WorkDataCorruption(
      recordType: recordType,
      field: field,
      value: value,
    );
  }
  return parsed;
}

LocalDate? _nullableDate(String recordType, String field, String? value) =>
    value == null ? null : _date(recordType, field, value);

DateTime _utc(int microseconds) =>
    DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);

domain.EmploymentStatus _employmentStatus(String value) => switch (value) {
  'active' => domain.EmploymentStatus.active,
  'archived' => domain.EmploymentStatus.archived,
  _ => throw WorkDataCorruption(
    recordType: 'employment',
    field: 'status',
    value: value,
  ),
};

domain.ShiftState _shiftState(String value) => switch (value) {
  'draft' => domain.ShiftState.draft,
  'running' => domain.ShiftState.running,
  'onBreak' => domain.ShiftState.onBreak,
  'finalized' => domain.ShiftState.finalized,
  'voided' => domain.ShiftState.voided,
  _ => throw WorkDataCorruption(
    recordType: 'workShift',
    field: 'state',
    value: value,
  ),
};

domain.PayPeriodState _payPeriodState(String value) => switch (value) {
  'open' => domain.PayPeriodState.open,
  'reviewed' => domain.PayPeriodState.reviewed,
  _ => throw WorkDataCorruption(
    recordType: 'payPeriod',
    field: 'state',
    value: value,
  ),
};

domain.PayslipState _payslipState(String value) => switch (value) {
  'effective' => domain.PayslipState.effective,
  'voided' => domain.PayslipState.voided,
  _ => throw WorkDataCorruption(
    recordType: 'payslip',
    field: 'state',
    value: value,
  ),
};

RateBasis _basis(String recordType, String value) => switch (value) {
  'gross' => const GrossBasis(),
  'net' => const NetBasis(),
  _ => throw WorkDataCorruption(
    recordType: recordType,
    field: 'basis',
    value: value,
  ),
};

String _basisText(RateBasis value) => switch (value) {
  GrossBasis() => 'gross',
  NetBasis() => 'net',
};

CurrencyCode _currency(String value) => switch (value) {
  'EUR' => const CurrencyCode.eur(),
  _ => throw WorkDataCorruption(
    recordType: 'payslip',
    field: 'currency',
    value: value,
  ),
};
