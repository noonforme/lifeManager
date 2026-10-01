import '../../../../core/time/local_date.dart';
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

  factory WorkRegisterProjection.empty(WorkScope scope) =>
      WorkRegisterProjection(
        scope: scope,
        period: null,
        shiftRows: const [],
        payslipRows: const [],
        paid: const Money(minorUnits: 0),
        reconciliation: null,
      );
}
