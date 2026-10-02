import '../../../../core/time/local_date.dart';
import '../../domain/agreement.dart';
import '../../domain/employment.dart';
import '../../domain/ids.dart';
import '../../domain/pay.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
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
}

final class DateRangeScope extends WorkTemporalScope {
  const DateRangeScope({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;
}

/// The four Work sheets (shell spec 7.2).
enum WorkSheet { shifts, periods, payslips, agreements }

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
  });

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final int breakSeconds;

  /// Null while the shift is still running.
  final int? paidSeconds;

  /// The pay period whose dates contain the shift, if any.
  final PayPeriod? period;
  final FinalizationFacts? facts;
  final ExpectedPay? pay;
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
