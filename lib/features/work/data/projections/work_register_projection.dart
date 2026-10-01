import '../../../../core/time/local_date.dart';
import '../../domain/agreement.dart';
import '../../domain/employment.dart';
import '../../domain/ids.dart';
import '../../domain/pay.dart';
import '../../domain/pay_period.dart';
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
