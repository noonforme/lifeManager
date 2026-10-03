import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../domain/agreement.dart' as domain;
import '../domain/day_exception.dart';
import '../domain/employment.dart' as domain;
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart' as domain;
import '../domain/payslip.dart' as domain;
import '../domain/schedule.dart';
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
      nightEnabled: value.nightEnabled,
      nightStartMinute: value.nightStartMinute,
      nightEndMinute: value.nightEndMinute,
      nightMultiplierNumerator: value.nightMultiplier.numerator,
      nightMultiplierDenominator: value.nightMultiplier.denominator,
      holidayCalendar: holidayCalendarText(value.holidayCalendar),
      holidayMultiplierNumerator: value.holidayMultiplier.numerator,
      holidayMultiplierDenominator: value.holidayMultiplier.denominator,
      premiumStacking: premiumStackingText(value.premiumStacking),
      vacationPayNumerator: Value(value.vacationPay.numerator),
      vacationPayDenominator: Value(value.vacationPay.denominator),
      sickPayNumerator: Value(value.sickPay.numerator),
      sickPayDenominator: Value(value.sickPay.denominator),
      sickEmployerDays: Value(value.sickEmployerDays),
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
    nightEnabled: row.nightEnabled,
    nightStartMinute: row.nightStartMinute,
    nightEndMinute: row.nightEndMinute,
    nightMultiplier: domain.RationalMultiplier(
      numerator: row.nightMultiplierNumerator,
      denominator: row.nightMultiplierDenominator,
    ),
    holidayCalendar: _holidayCalendar(row.holidayCalendar),
    holidayMultiplier: domain.RationalMultiplier(
      numerator: row.holidayMultiplierNumerator,
      denominator: row.holidayMultiplierDenominator,
    ),
    premiumStacking: _premiumStacking(row.premiumStacking),
    vacationPay: domain.RationalMultiplier(
      numerator: row.vacationPayNumerator,
      denominator: row.vacationPayDenominator,
    ),
    sickPay: domain.RationalMultiplier(
      numerator: row.sickPayNumerator,
      denominator: row.sickPayDenominator,
    ),
    sickEmployerDays: row.sickEmployerDays,
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
      note: Value(value.note),
      voidReason: Value(value.voidReason),
      replacementShiftId: Value(value.replacementShiftId?.value),
      replacedShiftId: Value(value.replacedShiftId?.value),
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
      scheduleId: Value(value.schedule?.scheduleId.value),
      scheduleVersion: Value(value.schedule?.scheduleVersion),
      plannedDate: Value(value.schedule?.plannedDate.toString()),
      plannedStartUtcMicros: Value(
        value.schedule?.plannedStartUtc.microsecondsSinceEpoch,
      ),
      plannedEndUtcMicros: Value(
        value.schedule?.plannedEndUtc.microsecondsSinceEpoch,
      ),
      isExtra: Value(value.schedule?.isExtra ?? false),
      extraCountsAsOvertime: Value(
        value.schedule?.extraCountsAsOvertime ?? false,
      ),
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
    schedule: _scheduleLink(row),
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

/// Stable stored names; renaming an enum value must not change them.
String holidayCalendarText(domain.HolidayCalendar value) => switch (value) {
  domain.HolidayCalendar.none => 'none',
  domain.HolidayCalendar.lithuania => 'lithuania',
};

String premiumStackingText(domain.PremiumStacking value) => switch (value) {
  domain.PremiumStacking.highest => 'highest',
  domain.PremiumStacking.additive => 'additive',
  domain.PremiumStacking.multiplicative => 'multiplicative',
};

domain.HolidayCalendar _holidayCalendar(String value) => switch (value) {
  'none' => domain.HolidayCalendar.none,
  'lithuania' => domain.HolidayCalendar.lithuania,
  _ => throw WorkDataCorruption(
    recordType: 'payAgreement',
    field: 'holidayCalendar',
    value: value,
  ),
};

domain.PremiumStacking _premiumStacking(String value) => switch (value) {
  'highest' => domain.PremiumStacking.highest,
  'additive' => domain.PremiumStacking.additive,
  'multiplicative' => domain.PremiumStacking.multiplicative,
  _ => throw WorkDataCorruption(
    recordType: 'payAgreement',
    field: 'premiumStacking',
    value: value,
  ),
};

domain.ShiftState _shiftState(String value) => switch (value) {
  'draft' => domain.ShiftState.draft,
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

/// "dayOffset:minuteOfDay:minutes" per break, joined by ";".
String encodeBreaks(List<FixedBreak> breaks) => breaks
    .map(
      (item) =>
          '${item.dayOffset}:${item.start.hour * 60 + item.start.minute}:'
          '${item.minutes}',
    )
    .join(';');

/// The breaks [encodeBreaks] wrote; malformed text is stored corruption.
List<FixedBreak> decodeBreaks(String text) => [
  for (final part in text.split(';'))
    if (part.isNotEmpty) _decodeBreak(part),
];

FixedBreak _decodeBreak(String part) {
  final fields = part.split(':').map(int.tryParse).toList();
  if (fields.length != 3 || fields.contains(null)) {
    throw WorkDataCorruption(
      recordType: 'schedule',
      field: 'breaks',
      value: part,
    );
  }
  final [offset!, minute!, minutes!] = fields;
  if (minute < 0 || minute > 1439) {
    throw WorkDataCorruption(
      recordType: 'schedule',
      field: 'breaks',
      value: part,
    );
  }
  return FixedBreak(
    start: LocalTime(minute ~/ 60, minute % 60),
    dayOffset: offset,
    minutes: minutes,
  );
}

/// The link a confirmed scheduled shift keeps; null for a manual shift.
domain.ScheduleLink? _scheduleLink(db.WorkShift row) {
  final id = row.scheduleId;
  if (id == null) return null;
  final version = row.scheduleVersion;
  final start = row.plannedStartUtcMicros;
  final end = row.plannedEndUtcMicros;
  final date = row.plannedDate;
  if (version == null || start == null || end == null || date == null) {
    throw WorkDataCorruption(
      recordType: 'workShift',
      field: 'schedule',
      value: id,
    );
  }
  return domain.ScheduleLink(
    scheduleId: _requiredId('workShift', 'scheduleId', id, ScheduleId.tryParse),
    scheduleVersion: version,
    plannedDate: _date('workShift', 'plannedDate', date),
    plannedStartUtc: _utc(start),
    plannedEndUtc: _utc(end),
    isExtra: row.isExtra,
    extraCountsAsOvertime: row.extraCountsAsOvertime,
  );
}

db.WorkSchedulesCompanion scheduleToCompanion(WorkSchedule value) =>
    db.WorkSchedulesCompanion.insert(
      id: value.id.value,
      version: value.version,
      employmentId: value.employmentId.value,
      name: value.name,
      timezoneId: value.timezoneId,
      cycleStart: value.cycleStart.toString(),
      inUseFrom: value.inUseFrom.toString(),
      inUseUntil: Value(value.inUseUntil?.toString()),
      createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
      revision: value.revision.value,
    );

List<db.WorkScheduleShiftTypesCompanion> shiftTypesToCompanions(
  WorkSchedule value,
) => [
  for (final (position, type) in value.shiftTypes.indexed)
    db.WorkScheduleShiftTypesCompanion.insert(
      scheduleId: value.id.value,
      scheduleVersion: value.version,
      id: type.id.value,
      position: position,
      name: type.name,
      startMinute: type.startMinute,
      endMinute: type.end.hour * 60 + type.end.minute,
      endDayOffset: type.endDayOffset,
      breaks: encodeBreaks(type.breaks),
    ),
];

List<db.WorkScheduleBlocksCompanion> blocksToCompanions(WorkSchedule value) => [
  for (final (position, block) in value.blocks.indexed)
    db.WorkScheduleBlocksCompanion.insert(
      scheduleId: value.id.value,
      scheduleVersion: value.version,
      position: position,
      count: block.count,
      shiftTypeId: Value(block.shiftTypeId?.value),
    ),
];

/// A stored schedule version with its types and blocks, both in position
/// order.
WorkSchedule scheduleFromRows(
  db.WorkSchedule row, {
  required List<db.WorkScheduleShiftType> types,
  required List<db.WorkScheduleBlock> blocks,
  required bool usedByConfirmedDay,
}) => _decode(
  'schedule',
  () => WorkSchedule(
    id: _requiredId('schedule', 'id', row.id, ScheduleId.tryParse),
    employmentId: _requiredId(
      'schedule',
      'employmentId',
      row.employmentId,
      EmploymentId.tryParse,
    ),
    name: row.name,
    timezoneId: row.timezoneId,
    version: row.version,
    cycleStart: _date('schedule', 'cycleStart', row.cycleStart),
    inUseFrom: _date('schedule', 'inUseFrom', row.inUseFrom),
    inUseUntil: _nullableDate('schedule', 'inUseUntil', row.inUseUntil),
    shiftTypes: [
      for (final type in types)
        ShiftType(
          id: ShiftTypeId(type.id),
          name: type.name,
          start: LocalTime(type.startMinute ~/ 60, type.startMinute % 60),
          end: LocalTime(type.endMinute ~/ 60, type.endMinute % 60),
          endDayOffset: type.endDayOffset,
          breaks: decodeBreaks(type.breaks),
        ),
    ],
    blocks: [
      for (final block in blocks)
        CycleBlock(
          count: block.count,
          shiftTypeId: block.shiftTypeId == null
              ? null
              : ShiftTypeId(block.shiftTypeId!),
        ),
    ],
    createdAtUtc: _utc(row.createdAtUtcMicros),
    revision: Revision.checked(row.revision),
    usedByConfirmedDay: usedByConfirmedDay,
  ),
);

db.WorkDayExceptionsCompanion dayExceptionToCompanion(DayException value) {
  int minute(LocalTime time) => time.hour * 60 + time.minute;
  final base = db.WorkDayExceptionsCompanion.insert(
    id: value.id.value,
    employmentId: value.employmentId.value,
    date: value.date.toString(),
    kind: switch (value) {
      ChangedDay() => 'changed',
      CancelledDay() => 'cancelled',
      LeaveDay() => 'leave',
      ExtraDay() => 'extra',
    },
    createdAtUtcMicros: value.createdAtUtc.microsecondsSinceEpoch,
    updatedAtUtcMicros: value.updatedAtUtc.microsecondsSinceEpoch,
    revision: value.revision.value,
  );
  return switch (value) {
    ChangedDay() => base.copyWith(
      startMinute: Value(minute(value.start)),
      endMinute: Value(minute(value.end)),
      endDayOffset: Value(value.endDayOffset),
      breaks: Value(encodeBreaks(value.breaks)),
      shiftTypeId: Value(value.shiftTypeId?.value),
    ),
    CancelledDay() => base.copyWith(
      reason: Value(value.reason.name),
      note: Value(value.note),
    ),
    LeaveDay() => base.copyWith(
      leaveType: Value(value.leaveType.name),
      illnessStartedOn: Value(value.illnessStartedOn?.toString()),
    ),
    ExtraDay() => base.copyWith(
      startMinute: Value(minute(value.start)),
      endMinute: Value(minute(value.end)),
      endDayOffset: Value(value.endDayOffset),
      breaks: Value(encodeBreaks(value.breaks)),
      shiftTypeId: Value(value.shiftTypeId?.value),
      countsAsOvertime: Value(value.countsAsOvertime),
    ),
  };
}

DayException dayExceptionFromRow(
  db.WorkDayException row,
) => _decode('dayException', () {
  final id = _requiredId('dayException', 'id', row.id, DayExceptionId.tryParse);
  final employmentId = _requiredId(
    'dayException',
    'employmentId',
    row.employmentId,
    EmploymentId.tryParse,
  );
  final date = _date('dayException', 'date', row.date);
  final createdAtUtc = _utc(row.createdAtUtcMicros);
  final updatedAtUtc = _utc(row.updatedAtUtcMicros);
  final revision = Revision.checked(row.revision);
  LocalTime time(int? minute, String field) {
    if (minute == null || minute < 0 || minute > 1439) {
      throw WorkDataCorruption(
        recordType: 'dayException',
        field: field,
        value: minute,
      );
    }
    return LocalTime(minute ~/ 60, minute % 60);
  }

  T named<T extends Enum>(List<T> values, String? text, String field) =>
      values.where((value) => value.name == text).firstOrNull ??
      (throw WorkDataCorruption(
        recordType: 'dayException',
        field: field,
        value: text,
      ));
  final typeId = row.shiftTypeId == null ? null : ShiftTypeId(row.shiftTypeId!);
  return switch (row.kind) {
    'changed' => ChangedDay(
      id: id,
      employmentId: employmentId,
      date: date,
      start: time(row.startMinute, 'startMinute'),
      end: time(row.endMinute, 'endMinute'),
      endDayOffset: row.endDayOffset ?? 0,
      breaks: decodeBreaks(row.breaks ?? ''),
      shiftTypeId: typeId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision,
    ),
    'cancelled' => CancelledDay(
      id: id,
      employmentId: employmentId,
      date: date,
      reason: named(CancelReason.values, row.reason, 'reason'),
      note: row.note,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision,
    ),
    'leave' => LeaveDay(
      id: id,
      employmentId: employmentId,
      date: date,
      leaveType: named(LeaveType.values, row.leaveType, 'leaveType'),
      illnessStartedOn: _nullableDate(
        'dayException',
        'illnessStartedOn',
        row.illnessStartedOn,
      ),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision,
    ),
    'extra' => ExtraDay(
      id: id,
      employmentId: employmentId,
      date: date,
      start: time(row.startMinute, 'startMinute'),
      end: time(row.endMinute, 'endMinute'),
      endDayOffset: row.endDayOffset ?? 0,
      breaks: decodeBreaks(row.breaks ?? ''),
      shiftTypeId: typeId,
      countsAsOvertime: row.countsAsOvertime,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision,
    ),
    final kind => throw WorkDataCorruption(
      recordType: 'dayException',
      field: 'kind',
      value: kind,
    ),
  };
});
