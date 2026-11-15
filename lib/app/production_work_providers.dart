import 'package:flutter/widgets.dart';

import '../core/database/app_database.dart';
import '../core/history/record_event_dao.dart';
import '../core/history/record_events.dart';
import '../core/time/app_clock.dart';
import '../core/time/timezone_service.dart';
import '../core/time/wall_clock.dart';
import '../features/work/application/agreement_service.dart';
import '../features/work/application/day_plan_service.dart';
import '../features/work/application/employment_service.dart';
import '../features/work/application/manual_shift_service.dart';
import '../features/work/application/pay_period_service.dart';
import '../features/work/application/payslip_service.dart';
import '../features/work/application/schedule_service.dart';
import '../features/work/application/shift_lifecycle_service.dart';
import '../features/work/application/uuid_v7_work_id_factory.dart';
import '../features/work/application/work_commands.dart';
import '../features/work/data/schedule_repository.dart';
import '../features/work/data/shift_repository.dart';
import '../features/work/data/work_repository.dart';

typedef CurrentTimezoneId = String? Function();

ProductionWorkProviders buildWorkProviders({
  required AppDatabase database,
  required AppClock clock,
  required TimezoneService timezones,
  required CurrentTimezoneId currentTimezoneId,
  required WorkIdFactory workIds,
  required ShiftIdFactory shiftIds,
  required WorkEvidenceIdFactory evidenceIds,
  ScheduleIdFactory? scheduleIds,
}) {
  final scheduleIdFactory = scheduleIds ?? UuidV7WorkIdFactory();
  final workRepository = DriftWorkRepository(
    database,
    timezones: timezones,
    clock: clock,
  );
  final shiftRepository = DriftShiftRepository(
    database,
    createBreakId: shiftIds.shiftBreakId,
    clock: clock,
  );
  final employment = EmploymentService(
    workRepository,
    idFactory: workIds,
    clock: clock,
  );
  final agreement = AgreementService(
    workRepository,
    idFactory: workIds,
    clock: clock,
  );
  final shifts = ShiftLifecycleService(
    shiftRepository,
    idFactory: shiftIds,
    clock: clock,
  );
  final manualShifts = ManualShiftService(
    shiftRepository,
    idFactory: shiftIds,
    clock: clock,
    timezones: timezones,
  );
  final draftRevisions = ShiftDraftRevisionService(
    shiftRepository,
    idFactory: shiftIds,
    clock: clock,
    timezones: timezones,
  );
  final periods = PayPeriodService(
    workRepository,
    idFactory: evidenceIds,
    clock: clock,
  );
  final payslips = PayslipService(
    workRepository,
    idFactory: evidenceIds,
    clock: clock,
  );
  final scheduleRepository = DriftScheduleRepository(database, clock: clock);
  final schedules = ScheduleService(
    repository: scheduleRepository,
    ids: scheduleIdFactory,
    clock: clock,
  );
  final plans = DayPlanService(
    repository: scheduleRepository,
    shifts: shiftRepository,
    ids: scheduleIdFactory,
    clock: clock,
    zoneClocks: zoneClocksOf(timezones),
  );

  return ProductionWorkProviders._(
    workRepository: workRepository,
    employment: employment,
    agreement: agreement,
    shifts: shifts,
    manualShifts: manualShifts,
    draftRevisions: draftRevisions,
    timezones: timezones,
    periods: periods,
    payslips: payslips,
    schedules: schedules,
    plans: plans,
    currentTimezoneId: currentTimezoneId,
    shiftIds: shiftIds,
    evidenceIds: evidenceIds,
    clock: clock,
    history: RecordEventDao(database),
  );
}

final class ProductionWorkProviders {
  const ProductionWorkProviders._({
    required this.workRepository,
    required this.employment,
    required this.agreement,
    required this.shifts,
    required this.manualShifts,
    required this.draftRevisions,
    required this.timezones,
    required this.periods,
    required this.payslips,
    required this.schedules,
    required this.plans,
    required this.currentTimezoneId,
    required this.shiftIds,
    required this.evidenceIds,
    required this.clock,
    required this.history,
  });

  final DriftWorkRepository workRepository;
  final EmploymentService employment;
  final AgreementService agreement;
  final ShiftLifecycleService shifts;
  final ManualShiftService manualShifts;
  final ShiftDraftRevisionService draftRevisions;
  final TimezoneService timezones;
  final PayPeriodService periods;
  final PayslipService payslips;
  final ScheduleService schedules;
  final DayPlanService plans;
  final CurrentTimezoneId currentTimezoneId;
  final ShiftIdFactory shiftIds;
  final WorkEvidenceIdFactory evidenceIds;
  final AppClock clock;
  final RecordHistory history;

  /// These providers with [agreement], [employment], [schedules] and [plans] in
  /// place of their own, so a test can make those commands fail.
  @visibleForTesting
  ProductionWorkProviders replacing({
    ShiftLifecycleService? shifts,
    AgreementService? agreement,
    EmploymentService? employment,
    ScheduleService? schedules,
    DayPlanService? plans,
    PayPeriodService? periods,
    PayslipService? payslips,
  }) => ProductionWorkProviders._(
    workRepository: workRepository,
    employment: employment ?? this.employment,
    agreement: agreement ?? this.agreement,
    shifts: shifts ?? this.shifts,
    manualShifts: manualShifts,
    draftRevisions: draftRevisions,
    timezones: timezones,
    periods: periods ?? this.periods,
    payslips: payslips ?? this.payslips,
    schedules: schedules ?? this.schedules,
    plans: plans ?? this.plans,
    currentTimezoneId: currentTimezoneId,
    shiftIds: shiftIds,
    evidenceIds: evidenceIds,
    clock: clock,
    history: history,
  );
}
