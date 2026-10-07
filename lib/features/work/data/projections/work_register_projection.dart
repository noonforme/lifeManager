import '../../../../core/time/local_date.dart';
import '../../domain/agreement.dart';
import '../../domain/employment.dart';
import '../../domain/ids.dart';
import '../../domain/leave.dart';
import '../../domain/pay.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../../domain/planner.dart';
import '../../domain/reconciliation.dart';
import '../../domain/shift.dart';
import '../daos/payslip_dao.dart';
import '../daos/shift_dao.dart';
import 'reconciliation_projection.dart';

sealed class WorkTemporalScope {
  const WorkTemporalScope();
}

final class PayPeriodScope extends WorkTemporalScope {
  const PayPeriodScope(this.periodId);

  final PayPeriodId periodId;

  @override
  bool operator ==(Object other) =>
      other is PayPeriodScope && other.periodId == periodId;

  @override
  int get hashCode => periodId.hashCode;
}

final class DateRangeScope extends WorkTemporalScope {
  const DateRangeScope({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;

  @override
  bool operator ==(Object other) =>
      other is DateRangeScope && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The sheets an employment's Work desk shows, in the Books tree's order
/// (schedules spec 5).
enum WorkSheet {
  calendar,
  shifts,
  leave,
  schedules,
  periods,
  payslips,
  agreements,
}

/// A shift with its derived columns: break and paid time, and for a
/// finalized shift the pay breakdown with the facts it came from.
final class ShiftSheetRow {
  const ShiftSheetRow({
    required this.shift,
    required this.breakSeconds,
    required this.paidSeconds,
    required this.period,
    this.breaks = const [],
    this.facts,
    this.pay,
    this.typeName,
  });

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final int breakSeconds;

  /// The shift type a schedule planned it as, or "Extra"; null for a
  /// manual shift.
  final String? typeName;

  /// Null while the shift has no end yet.
  final int? paidSeconds;

  /// The pay period whose dates contain the shift, if any.
  final PayPeriod? period;
  final FinalizationFacts? facts;
  final ExpectedPay? pay;
}

/// A planned, changed or extra work day in the Shifts sheet's scope that
/// no confirmed record covers yet. Derived from the plan and never stored
/// (schedules spec 2): confirming the day records its real shift.
final class PlannedShiftRow {
  const PlannedShiftRow({
    required this.day,
    required this.toConfirm,
    required this.period,
    required this.pay,
  });

  final PlannedShift day;

  /// The day is today or past on its schedule's clock, so it can be
  /// confirmed.
  final bool toConfirm;

  /// The pay period whose dates contain the day, if any.
  final PayPeriod? period;

  /// Planned pay, night and holiday premiums but never overtime (spec
  /// 4.1); null when no agreement covers the date.
  final ExpectedPay? pay;
}

/// A leave record with its price; null when its agreement is missing or the
/// record is void.
final class LeaveSheetRow {
  const LeaveSheetRow({required this.record, required this.pay});

  final LeaveRecord record;
  final LeavePay? pay;
}

/// A pay period with its finalized shifts reconciled against payslips.
final class PeriodSheetRow {
  const PeriodSheetRow({
    required this.period,
    required this.shiftCount,
    required this.groups,
  });

  final PayPeriod period;
  final int shiftCount;
  final List<ReconciliationGroup> groups;

  /// The single comparable group, or null when bases are mixed.
  ReconciliationGroup? get group => groups.length == 1 ? groups.single : null;
}

final class AgreementSheetRow {
  const AgreementSheetRow({
    required this.agreement,
    required this.finishedShifts,
  });

  final PayAgreement agreement;
  final int finishedShifts;
}

final class WorkScope {
  const WorkScope({required this.employmentId, required this.temporal});

  final EmploymentId? employmentId;
  final WorkTemporalScope? temporal;
}

final class WorkRegisterProjection {
  const WorkRegisterProjection({
    required this.scope,
    required this.period,
    required this.shiftRows,
    required this.payslipRows,
    required this.paid,
    required this.reconciliation,
    this.periodRows = const [],
    this.employment,
    this.hasAgreement = false,
    this.currentAgreement,
    this.canDeleteEmployment = false,
    this.availableEmployments = const [],
    this.shiftSheet = const [],
    this.periodSheet = const [],
    this.payslipSheet = const [],
    this.agreementSheet = const [],
    this.leaveSheet = const [],
    this.plannedNotConfirmed = 0,
  });

  final WorkScope scope;
  final PayPeriod? period;
  final List<ShiftRegisterRow> shiftRows;
  final List<PayslipRegisterRow> payslipRows;
  final Money paid;
  final ReconciliationProjection? reconciliation;

  /// Pay periods of the selected employment, listed when no temporal scope is
  /// chosen so the owner can pick one explicitly.
  final List<PayPeriod> periodRows;

  /// The selected employment, when it exists.
  final Employment? employment;

  /// Whether the selected employment has at least one pay agreement.
  final bool hasAgreement;

  /// The selected employment's latest agreement, the one setup edits.
  final PayAgreement? currentAgreement;

  /// Whether a finalized shift uses [currentAgreement], so it is evidence
  /// and can no longer be edited.
  bool get agreementInUse => currentAgreement?.usedByFinalizedShift ?? false;

  /// Whether the selected employment has no shifts, pay periods or payslips
  /// and can be deleted.
  final bool canDeleteEmployment;

  /// Active employments, listed when no employment is selected so Work can
  /// reopen an existing one instead of restarting setup.
  final List<Employment> availableEmployments;

  /// The selected employment's sheets. Shifts follow the temporal scope;
  /// the other sheets list everything.
  final List<ShiftSheetRow> shiftSheet;
  final List<PeriodSheetRow> periodSheet;
  final List<Payslip> payslipSheet;
  final List<AgreementSheetRow> agreementSheet;

  /// Leave records in the temporal scope, priced (schedules spec 4.3).
  final List<LeaveSheetRow> leaveSheet;

  /// Planned days in the temporal scope that are past and not confirmed
  /// (spec 4.4).
  final int plannedNotConfirmed;

  factory WorkRegisterProjection.empty(
    WorkScope scope, {
    List<Employment> availableEmployments = const [],
  }) => WorkRegisterProjection(
    scope: scope,
    period: null,
    shiftRows: const [],
    payslipRows: const [],
    paid: const Money(minorUnits: 0),
    reconciliation: null,
    availableEmployments: availableEmployments,
  );
}
