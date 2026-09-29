import 'agreement.dart';
import 'facts.dart';
import 'ids.dart';
import 'pay.dart';
import 'pay_period.dart';
import 'payslip.dart';
import 'shift.dart';

sealed class ReconciliationStatus {
  const ReconciliationStatus();
}

final class Balanced extends ReconciliationStatus {
  const Balanced();
}

final class Difference extends ReconciliationStatus {
  const Difference();
}

final class MissingPayslip extends ReconciliationStatus {
  const MissingPayslip();
}

final class UnmatchedPayslip extends ReconciliationStatus {
  const UnmatchedPayslip();
}

final class MixedBasis extends ReconciliationStatus {
  const MixedBasis();
}

final class UnavailableReconciliation extends ReconciliationStatus {
  const UnavailableReconciliation();
}

final class EmptyReconciliation extends ReconciliationStatus {
  const EmptyReconciliation();
}

final class ReconciliationGroup {
  const ReconciliationGroup({
    required this.employmentId,
    required this.periodId,
    required this.currency,
    required this.basis,
    required this.regularPaidSeconds,
    required this.overtimePaidSeconds,
    required this.expected,
    required this.paid,
    required this.difference,
    required this.shiftIds,
    required this.payslipIds,
    required this.status,
  });

  final EmploymentId employmentId;
  final PayPeriodId periodId;
  final CurrencyCode currency;
  final RateBasis? basis;
  final int regularPaidSeconds;
  final int overtimePaidSeconds;
  final Money? expected;
  final Money? paid;
  final Money? difference;
  final List<ShiftId> shiftIds;
  final List<PayslipId> payslipIds;
  final ReconciliationStatus status;
}

List<ReconciliationGroup> reconcilePeriod({
  required EmploymentId employmentId,
  required PayPeriod period,
  required Iterable<WorkShift> shifts,
  required Iterable<ShiftBreak> breaks,
  required Iterable<PayAgreement> agreements,
  required Iterable<Payslip> payslips,
}) {
  final evidence = <_Evidence>[];
  var unavailable = false;
  final agreementsById = {
    for (final agreement in agreements) agreement.id: agreement,
  };
  final allBreaks = [...breaks];

  if (period.employmentId == employmentId) {
    for (final shift in shifts) {
      if (shift.employmentId != employmentId ||
          shift.state != ShiftState.finalized ||
          !period.contains(shift.localStartDate)) {
        continue;
      }
      final agreementId = shift.agreementId;
      final agreement = agreementId == null
          ? null
          : agreementsById[agreementId];
      if (agreement == null || agreement.employmentId != employmentId) {
        unavailable = true;
        continue;
      }
      final validation = validateFinalization(
        shift: shift,
        breaks: allBreaks.where((item) => item.shiftId == shift.id),
        agreements: [agreement],
      );
      final facts = validation.facts;
      if (facts == null || facts.agreement.id != agreementId) {
        unavailable = true;
        continue;
      }
      final expectedPay = calculateExpectedPay(facts.toExpectedPayInput());
      evidence.add(
        _Evidence.expected(
          basis: agreement.basis,
          money: expectedPay.amount,
          regularPaidSeconds: expectedPay.regularPaidSeconds,
          overtimePaidSeconds: expectedPay.overtimePaidSeconds,
          shiftId: shift.id,
        ),
      );
    }
  }

  for (final payslip in payslips) {
    if (period.employmentId != employmentId ||
        payslip.periodId != period.id ||
        !payslip.isEffective) {
      continue;
    }
    evidence.add(
      _Evidence.paid(
        basis: payslip.basis,
        money: payslip.amount,
        payslipId: payslip.id,
      ),
    );
  }

  if (unavailable) {
    return [
      _group(
        employmentId: employmentId,
        periodId: period.id,
        currency: const CurrencyCode.eur(),
        status: const UnavailableReconciliation(),
        evidence: evidence,
      ),
    ];
  }
  if (evidence.isEmpty) {
    return [
      _group(
        employmentId: employmentId,
        periodId: period.id,
        currency: const CurrencyCode.eur(),
        status: const EmptyReconciliation(),
        evidence: const [],
      ),
    ];
  }

  final byCurrency = <CurrencyCode, List<_Evidence>>{};
  for (final item in evidence) {
    byCurrency.putIfAbsent(item.money.currency, () => []).add(item);
  }
  final groups = <ReconciliationGroup>[];
  for (final entry in byCurrency.entries) {
    final bases = entry.value.map((item) => item.basis.runtimeType).toSet();
    if (bases.length > 1) {
      groups.add(
        _group(
          employmentId: employmentId,
          periodId: period.id,
          currency: entry.key,
          status: const MixedBasis(),
          evidence: entry.value,
        ),
      );
      continue;
    }

    final expected = entry.value.where((item) => item.isExpected).toList();
    final paid = entry.value.where((item) => !item.isExpected).toList();
    final expectedTotal = _sum(expected);
    final paidTotal = _sum(paid);
    final status = switch ((expected.isNotEmpty, paid.isNotEmpty)) {
      (true, true) when expectedTotal == paidTotal => const Balanced(),
      (true, true) => const Difference(),
      (true, false) => const MissingPayslip(),
      (false, true) => const UnmatchedPayslip(),
      (false, false) => const EmptyReconciliation(),
    };
    groups.add(
      _group(
        employmentId: employmentId,
        periodId: period.id,
        currency: entry.key,
        basis: entry.value.first.basis,
        status: status,
        evidence: entry.value,
        expected: expected.isEmpty
            ? null
            : Money(minorUnits: expectedTotal, currency: entry.key),
        paid: paid.isEmpty
            ? null
            : Money(minorUnits: paidTotal, currency: entry.key),
        difference: expected.isEmpty || paid.isEmpty
            ? null
            : Money(minorUnits: paidTotal - expectedTotal, currency: entry.key),
      ),
    );
  }
  groups.sort((a, b) {
    final currency = a.currency.value.compareTo(b.currency.value);
    if (currency != 0) return currency;
    return _basisName(a.basis).compareTo(_basisName(b.basis));
  });
  return List.unmodifiable(groups);
}

ReconciliationGroup _group({
  required EmploymentId employmentId,
  required PayPeriodId periodId,
  required CurrencyCode currency,
  required ReconciliationStatus status,
  required List<_Evidence> evidence,
  RateBasis? basis,
  Money? expected,
  Money? paid,
  Money? difference,
}) {
  final shiftIds =
      evidence.map((item) => item.shiftId).whereType<ShiftId>().toList()
        ..sort((a, b) => a.value.compareTo(b.value));
  final payslipIds =
      evidence.map((item) => item.payslipId).whereType<PayslipId>().toList()
        ..sort((a, b) => a.value.compareTo(b.value));
  return ReconciliationGroup(
    employmentId: employmentId,
    periodId: periodId,
    currency: currency,
    basis: basis,
    regularPaidSeconds: evidence.fold(
      0,
      (total, item) => total + item.regularPaidSeconds,
    ),
    overtimePaidSeconds: evidence.fold(
      0,
      (total, item) => total + item.overtimePaidSeconds,
    ),
    expected: expected,
    paid: paid,
    difference: difference,
    shiftIds: List.unmodifiable(shiftIds),
    payslipIds: List.unmodifiable(payslipIds),
    status: status,
  );
}

int _sum(Iterable<_Evidence> items) =>
    items.fold(0, (total, item) => total + item.money.minorUnits);

String _basisName(RateBasis? basis) => switch (basis) {
  GrossBasis() => 'gross',
  NetBasis() => 'net',
  null => 'mixed',
};

final class _Evidence {
  const _Evidence._({
    required this.basis,
    required this.money,
    required this.isExpected,
    required this.regularPaidSeconds,
    required this.overtimePaidSeconds,
    required this.shiftId,
    required this.payslipId,
  });

  const _Evidence.expected({
    required RateBasis basis,
    required Money money,
    required int regularPaidSeconds,
    required int overtimePaidSeconds,
    required ShiftId shiftId,
  }) : this._(
         basis: basis,
         money: money,
         isExpected: true,
         regularPaidSeconds: regularPaidSeconds,
         overtimePaidSeconds: overtimePaidSeconds,
         shiftId: shiftId,
         payslipId: null,
       );

  const _Evidence.paid({
    required RateBasis basis,
    required Money money,
    required PayslipId payslipId,
  }) : this._(
         basis: basis,
         money: money,
         isExpected: false,
         regularPaidSeconds: 0,
         overtimePaidSeconds: 0,
         shiftId: null,
         payslipId: payslipId,
       );

  final RateBasis basis;
  final Money money;
  final bool isExpected;
  final int regularPaidSeconds;
  final int overtimePaidSeconds;
  final ShiftId? shiftId;
  final PayslipId? payslipId;
}
