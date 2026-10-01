import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/database/app_database.dart';
import '../core/time/app_clock.dart';
import '../core/time/timezone_service.dart';
import '../features/work/application/agreement_service.dart';
import '../features/work/application/employment_service.dart';
import '../features/work/application/manual_shift_service.dart';
import '../features/work/application/pay_period_service.dart';
import '../features/work/application/payslip_service.dart';
import '../features/work/application/shift_lifecycle_service.dart';
import '../features/work/application/work_commands.dart';
import '../features/work/data/shift_repository.dart';
import '../features/work/data/work_repository.dart';
import '../features/work/presentation/work_controller.dart';

ProductionWorkProviders buildWorkProviders({
  required AppDatabase database,
  required AppClock clock,
  required TimezoneService timezones,
  required CurrentTimezoneId currentTimezoneId,
  required WorkIdFactory workIds,
  required ShiftIdFactory shiftIds,
  required WorkEvidenceIdFactory evidenceIds,
}) {
  final workRepository = DriftWorkRepository(database);
  final shiftRepository = DriftShiftRepository(
    database,
    createBreakId: shiftIds.shiftBreakId,
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
    timezones: timezones,
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
    currentTimezoneId: currentTimezoneId,
    shiftIds: shiftIds,
    evidenceIds: evidenceIds,
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
    required this.currentTimezoneId,
    required this.shiftIds,
    required this.evidenceIds,
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
  final CurrentTimezoneId currentTimezoneId;
  final ShiftIdFactory shiftIds;
  final WorkEvidenceIdFactory evidenceIds;

  List<Override> get _overrides => [
    workQueryRepositoryProvider.overrideWithValue(workRepository),
    createEmploymentProvider.overrideWithValue(employment.createEmployment),
    createAgreementProvider.overrideWithValue(agreement.createAgreement),
    startShiftProvider.overrideWithValue(shifts.startShift),
    startBreakProvider.overrideWithValue(shifts.startBreak),
    endBreakProvider.overrideWithValue(shifts.endBreak),
    endShiftProvider.overrideWithValue(shifts.endShift),
    finalizeShiftProvider.overrideWithValue(shifts.finalizeShift),
    saveManualShiftProvider.overrideWithValue(manualShifts.createAndFinalize),
    createPayPeriodProvider.overrideWithValue(periods.createPeriod),
    setPayPeriodStateProvider.overrideWithValue(periods.setState),
    recordPayslipProvider.overrideWithValue(payslips.recordPayslip),
    correctPayslipProvider.overrideWithValue(payslips.correctPayslip),
    correctShiftProvider.overrideWithValue(shifts.correctShift),
    reviseShiftDraftProvider.overrideWithValue(draftRevisions.reviseAndFinalize),
    timezoneServiceProvider.overrideWithValue(timezones),
    currentTimezoneIdProvider.overrideWithValue(currentTimezoneId),
    nextReplacementShiftIdProvider.overrideWithValue(shiftIds.shiftId),
    nextReplacementPayslipIdProvider.overrideWithValue(evidenceIds.payslipId),
  ];

  ProviderContainer createContainer() =>
      ProviderContainer(overrides: _overrides);

  Widget scope(Widget child) =>
      ProviderScope(overrides: _overrides, child: child);
}
