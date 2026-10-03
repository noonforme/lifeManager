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
  BoolColumn get nightEnabled => boolean()();
  IntColumn get nightStartMinute => integer().check(
    const CustomExpression<bool>('night_start_minute BETWEEN 0 AND 1439'),
  )();
  IntColumn get nightEndMinute => integer().check(
    const CustomExpression<bool>('night_end_minute BETWEEN 0 AND 1439'),
  )();
  IntColumn get nightMultiplierNumerator => integer().check(
    const CustomExpression<bool>('night_multiplier_numerator > 0'),
  )();
  IntColumn get nightMultiplierDenominator => integer().check(
    const CustomExpression<bool>('night_multiplier_denominator > 0'),
  )();
  TextColumn get holidayCalendar => text().check(
    const CustomExpression<bool>("holiday_calendar IN ('none', 'lithuania')"),
  )();
  IntColumn get holidayMultiplierNumerator => integer().check(
    const CustomExpression<bool>('holiday_multiplier_numerator > 0'),
  )();
  IntColumn get holidayMultiplierDenominator => integer().check(
    const CustomExpression<bool>('holiday_multiplier_denominator > 0'),
  )();
  TextColumn get premiumStacking => text().check(
    const CustomExpression<bool>(
      "premium_stacking IN ('highest', 'additive', 'multiplicative')",
    ),
  )();
  TextColumn get label => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  IntColumn get vacationPayNumerator =>
      integer().withDefault(const Constant(1))();
  IntColumn get vacationPayDenominator =>
      integer().withDefault(const Constant(1))();
  IntColumn get sickPayNumerator =>
      integer().withDefault(const Constant(3103))();
  IntColumn get sickPayDenominator =>
      integer().withDefault(const Constant(5000))();
  IntColumn get sickEmployerDays => integer().withDefault(const Constant(2))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (effective_end IS NULL OR effective_end >= effective_start)',
    'CHECK (overtime_multiplier_numerator >= overtime_multiplier_denominator)',
    'CHECK (night_multiplier_numerator >= night_multiplier_denominator)',
    'CHECK (holiday_multiplier_numerator >= holiday_multiplier_denominator)',
    'CHECK (night_start_minute <> night_end_minute)',
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

  /// The schedule a confirmed day was planned from (spec 3.6).
  TextColumn get scheduleId => text().nullable()();
  IntColumn get scheduleVersion => integer().nullable()();
  TextColumn get plannedDate => text().nullable()();
  IntColumn get plannedStartUtcMicros => integer().nullable()();
  IntColumn get plannedEndUtcMicros => integer().nullable()();
  BoolColumn get isExtra => boolean().withDefault(const Constant(false))();
  BoolColumn get extraCountsAsOvertime =>
      boolean().withDefault(const Constant(false))();

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

class WorkSchedules extends Table {
  TextColumn get id => text()();
  IntColumn get version =>
      integer().check(const CustomExpression<bool>('version > 0'))();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get timezoneId => text()();
  TextColumn get cycleStart => text()();
  TextColumn get inUseFrom => text()();
  TextColumn get inUseUntil => text().nullable()();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id, version};

  @override
  List<String> get customConstraints => [
    'CHECK (in_use_until IS NULL OR in_use_until >= in_use_from)',
  ];
}

class WorkScheduleShiftTypes extends Table {
  TextColumn get scheduleId => text()();
  IntColumn get scheduleVersion => integer()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  IntColumn get startMinute => integer().check(
    const CustomExpression<bool>('start_minute BETWEEN 0 AND 1439'),
  )();
  IntColumn get endMinute => integer().check(
    const CustomExpression<bool>('end_minute BETWEEN 0 AND 1439'),
  )();
  IntColumn get endDayOffset => integer().check(
    const CustomExpression<bool>('end_day_offset IN (0, 1)'),
  )();

  /// "dayOffset:minuteOfDay:minutes" per break, joined by ";".
  TextColumn get breaks => text()();

  @override
  Set<Column<Object>> get primaryKey => {scheduleId, scheduleVersion, id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (schedule_id, schedule_version) '
        'REFERENCES work_schedules (id, version) ON DELETE CASCADE',
  ];
}

class WorkScheduleBlocks extends Table {
  TextColumn get scheduleId => text()();
  IntColumn get scheduleVersion => integer()();
  IntColumn get position => integer()();
  IntColumn get count =>
      integer().check(const CustomExpression<bool>('count BETWEEN 1 AND 99'))();

  /// Null for Off.
  TextColumn get shiftTypeId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {scheduleId, scheduleVersion, position};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (schedule_id, schedule_version) '
        'REFERENCES work_schedules (id, version) ON DELETE CASCADE',
  ];
}

class WorkDayExceptions extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get date => text()();
  TextColumn get kind => text().check(
    const CustomExpression<bool>(
      "kind IN ('changed', 'cancelled', 'leave', 'extra')",
    ),
  )();
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();
  IntColumn get endDayOffset => integer().nullable()();
  TextColumn get breaks => text().nullable()();
  TextColumn get shiftTypeId => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get leaveType => text().nullable()();
  TextColumn get illnessStartedOn => text().nullable()();
  BoolColumn get countsAsOvertime =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAtUtcMicros => integer()();
  IntColumn get updatedAtUtcMicros => integer()();
  IntColumn get revision =>
      integer().check(const CustomExpression<bool>('revision >= 0'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (employment_id, date)'];
}

class WorkLeaveRecords extends Table {
  TextColumn get id => text()();
  TextColumn get employmentId =>
      text().references(Employments, #id, onDelete: KeyAction.restrict)();
  TextColumn get date => text()();
  TextColumn get leaveType => text().check(
    const CustomExpression<bool>("leave_type IN ('vacation', 'sick')"),
  )();
  TextColumn get illnessStartedOn => text().nullable()();
  IntColumn get paidMinutes =>
      integer().check(const CustomExpression<bool>('paid_minutes > 0'))();
  TextColumn get agreementId =>
      text().references(PayAgreements, #id, onDelete: KeyAction.restrict)();
  TextColumn get scheduleId => text()();
  IntColumn get scheduleVersion => integer()();
  TextColumn get state => text().check(
    const CustomExpression<bool>("state IN ('confirmed', 'voided')"),
  )();
  TextColumn get voidReason => text().nullable()();
  TextColumn get replacementLeaveId => text().nullable().references(
    WorkLeaveRecords,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get replacedLeaveId => text().nullable().references(
    WorkLeaveRecords,
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
