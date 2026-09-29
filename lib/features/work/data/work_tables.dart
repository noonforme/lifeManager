import 'package:drift/drift.dart';

class Employments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get legalLabel => text().nullable()();
  TextColumn get status => text()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PayAgreements extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  TextColumn get effectiveStart => text()();
  TextColumn get effectiveEnd => text().nullable()();
  IntColumn get hourlyRateMicroEur => integer().check(
    const CustomExpression<bool>('hourly_rate_micro_eur > 0'),
  )();
  TextColumn get basis => text()();
  IntColumn get overtimeThresholdMinutes => integer().check(
    const CustomExpression<bool>('overtime_threshold_minutes > 0'),
  )();
  IntColumn get overtimeMultiplierNumerator => integer().check(
    const CustomExpression<bool>('overtime_multiplier_numerator > 0'),
  )();
  IntColumn get overtimeMultiplierDenominator => integer().check(
    const CustomExpression<bool>('overtime_multiplier_denominator > 0'),
  )();
  TextColumn get label => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (effective_end IS NULL OR effective_end >= effective_start)',
    'UNIQUE (employment_id, version)',
  ];
}

class WorkShifts extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get agreementId => text().nullable().references(
    PayAgreements,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get state => text()();
  IntColumn get startUtcMicros => integer()();
  IntColumn get endUtcMicros => integer().nullable()();
  TextColumn get timezoneId => text()();
  TextColumn get localStartDate => text()();
  IntColumn get overtimeMinutes =>
      integer().check(const CustomExpression<bool>('overtime_minutes >= 0'))();
  TextColumn get note => text().nullable()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get replacementShiftId => text().nullable().references(
    WorkShifts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get replacedShiftId => text().nullable().references(
    WorkShifts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ShiftBreaks extends Table {
  TextColumn get id => text()();
  TextColumn get shiftId =>
      text().references(WorkShifts, #id, onDelete: KeyAction.restrict)();
  IntColumn get startUtcMicros => integer()();
  IntColumn get endUtcMicros => integer().nullable()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PayPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get start => text()();
  TextColumn get end => text()();
  TextColumn get label => text().nullable()();
  TextColumn get state => text()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK ("end" >= start)'];
}

class Payslips extends Table {
  TextColumn get id => text()();
  TextColumn get periodId =>
      text().references(PayPeriods, #id, onDelete: KeyAction.restrict)();
  TextColumn get issuedDate => text()();
  TextColumn get paidDate => text().nullable()();
  IntColumn get amountMinorUnits =>
      integer().check(const CustomExpression<bool>('amount_minor_units > 0'))();
  TextColumn get currency => text()();
  TextColumn get basis => text()();
  IntColumn get grossMinorUnits => integer().nullable().check(
    const CustomExpression<bool>(
      'gross_minor_units IS NULL OR gross_minor_units >= 0',
    ),
  )();
  IntColumn get netMinorUnits => integer().nullable().check(
    const CustomExpression<bool>(
      'net_minor_units IS NULL OR net_minor_units >= 0',
    ),
  )();
  IntColumn get deductionMinorUnits => integer().nullable().check(
    const CustomExpression<bool>(
      'deduction_minor_units IS NULL OR deduction_minor_units >= 0',
    ),
  )();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get state => text()();
  TextColumn get voidReason => text().nullable()();
  TextColumn get replacementPayslipId => text().nullable().references(
    Payslips,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get replacedPayslipId => text().nullable().references(
    Payslips,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
