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

import '../../../support/zone_clocks.dart';

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
      zoneClocks: testZoneClocks,
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
      zoneClocks: testZoneClocks,
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

  test('expected pay includes derived night and overtime premiums', () {
    // 20:00 to 06:00 in Berlin: 10h, 8h of it night, the last 2h overtime.
    final night = finalizedShift(
      start: '2026-09-10T18:00:00Z',
      end: '2026-09-11T04:00:00Z',
    );
    final group = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [night],
      breaks: const [],
      agreements: [agreement()],
      payslips: const [],
      zoneClocks: testZoneClocks,
    ).single;

    // 2h × 20 + 6h × 20 × 1.5 + 2h × 20 × 1.5 (highest) = EUR 280.
    expect(group.expected, const Money(minorUnits: 28000));
    expect(group.overtimePaidSeconds, 2 * 3600);
    expect(group.regularPaidSeconds, 2 * 3600);
  });

  test('reports missing, unmatched, unavailable, and empty', () {
    final missing = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [finalizedShift()],
      breaks: const [],
      agreements: [agreement()],
      payslips: const [],
      zoneClocks: testZoneClocks,
    );
    final unmatched = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: const [],
      breaks: const [],
      agreements: const [],
      payslips: [payslip()],
      zoneClocks: testZoneClocks,
    );
    final unavailable = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: [finalizedShift()],
      breaks: const [],
      agreements: const [],
      payslips: const [],
      zoneClocks: testZoneClocks,
    );
    final empty = reconcilePeriod(
      employmentId: employmentId,
      period: period(),
      shifts: const [],
      breaks: const [],
      agreements: const [],
      payslips: const [],
      zoneClocks: testZoneClocks,
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
      zoneClocks: testZoneClocks,
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

WorkShift finalizedShift({
  String start = '2026-09-10T08:00:00Z',
  String end = '2026-09-10T16:00:00Z',
}) => WorkShift(
  id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  employmentId: employmentId,
  agreementId: agreementId,
  state: ShiftState.finalized,
  startUtc: DateTime.parse(start),
  endUtc: DateTime.parse(end),
  timezoneId: 'Europe/Berlin',
  localStartDate: LocalDate.parse('2026-09-10'),
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
