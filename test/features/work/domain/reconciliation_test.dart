import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  test('period range is inclusive and cannot end before it starts', () {
    expect(period().contains(LocalDate.parse('2026-09-30')), isTrue);
    expect(
      () => PayPeriod.create(
        id: periodId,
        employmentId: employmentId,
        start: LocalDate.parse('2026-09-30'),
        end: LocalDate.parse('2026-09-01'),
        label: null,
        nowUtc: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });

  test('void payslips remain factual but do not contribute evidence', () {
    expect(payslip().isEffective, isTrue);
    expect(voidPayslip().isEffective, isFalse);
    final groups = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: const [],
      breaks: const [],
      agreements: const [],
      payslips: [voidPayslip()],
    );
    expect(groups.single.status, isA<EmptyReconciliation>());
  });

  test('keeps gross and net evidence in separate subtotals', () {
    final groups = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [finalizedShift()],
      breaks: const [],
      agreements: [agreement()],
      payslips: [payslip(basis: const NetBasis(), minorUnits: 16000)],
    );

    expect(groups, hasLength(2));
    expect(
      groups.where((group) => group.basis == const GrossBasis()).single.status,
      isA<MissingPayslip>(),
    );
    expect(
      groups.where((group) => group.basis == const NetBasis()).single.status,
      isA<UnmatchedPayslip>(),
    );
    expect(groups.every((group) => group.difference == null), isTrue);
  });

  test('reports balanced and difference for compatible evidence', () {
    expect(statusFor(paidMinorUnits: 16000), isA<Balanced>());
    expect(statusFor(paidMinorUnits: 15900), isA<Difference>());
  });

  test('reports missing, unmatched, unavailable, and empty', () {
    final missing = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [finalizedShift()],
      breaks: const [],
      agreements: [agreement()],
      payslips: const [],
    );
    final unmatched = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: const [],
      breaks: const [],
      agreements: const [],
      payslips: [payslip()],
    );
    final unavailable = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [finalizedShift()],
      breaks: const [],
      agreements: const [],
      payslips: const [],
    );
    final empty = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: const [],
      breaks: const [],
      agreements: const [],
      payslips: const [],
    );

    expect(missing.single.status, isA<MissingPayslip>());
    expect(unmatched.single.status, isA<UnmatchedPayslip>());
    expect(unavailable.single.status, isA<UnavailableReconciliation>());
    expect(empty.single.status, isA<EmptyReconciliation>());
  });
}

ReconciliationStatus statusFor({required int paidMinorUnits}) =>
    reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [finalizedShift()],
      breaks: const [],
      agreements: [agreement()],
      payslips: [payslip(minorUnits: paidMinorUnits)],
    ).single.status;

const employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

PayPeriod period() => PayPeriod.create(
  id: periodId,
  employmentId: employmentId,
  start: LocalDate.parse('2026-09-01'),
  end: LocalDate.parse('2026-09-30'),
  label: null,
  nowUtc: DateTime.utc(2026),
);

PayAgreement agreement() => PayAgreement(
  id: agreementId,
  employmentId: employmentId,
  version: 1,
  effectiveStart: LocalDate.parse('2026-09-01'),
  effectiveEnd: null,
  hourlyRateMicroEur: 20000000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
  usedByFinalizedShift: true,
);

WorkShift finalizedShift() => WorkShift(
  id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  employmentId: employmentId,
  agreementId: agreementId,
  state: ShiftState.finalized,
  startUtc: DateTime.parse('2026-09-10T08:00:00Z'),
  endUtc: DateTime.parse('2026-09-10T16:00:00Z'),
  timezoneId: 'Europe/Berlin',
  localStartDate: LocalDate.parse('2026-09-10'),
  overtimeMinutes: 0,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  revision: const Revision(1),
);

Payslip payslip({
  RateBasis basis = const GrossBasis(),
  int minorUnits = 16000,
}) => Payslip(
  id: const PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61'),
  periodId: periodId,
  issuedDate: LocalDate.parse('2026-10-01'),
  paidDate: null,
  amount: Money(minorUnits: minorUnits),
  basis: basis,
  grossMinorUnits: null,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: null,
  note: null,
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: null,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
);

Payslip voidPayslip() => Payslip(
  id: const PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62'),
  periodId: periodId,
  issuedDate: LocalDate.parse('2026-10-01'),
  paidDate: null,
  amount: const Money(minorUnits: 16000),
  basis: const GrossBasis(),
  grossMinorUnits: null,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: null,
  note: null,
  state: PayslipState.voided,
  voidReason: 'Synthetic correction',
  replacementPayslipId: const PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61'),
  replacedPayslipId: null,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  revision: const Revision(1),
);
