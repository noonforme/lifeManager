import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';

void main() {
  test('rounds a positive half cent upward using integer arithmetic', () {
    expect(roundHalfUpRatio(BigInt.from(15000), BigInt.from(10000)), 2);
    expect(roundHalfUpRatio(BigInt.from(14999), BigInt.from(10000)), 1);
  });

  test(
    'rounds negative values symmetrically and rejects invalid denominator',
    () {
      expect(roundHalfUpRatio(BigInt.from(-15000), BigInt.from(10000)), -2);
      expect(
        () => roundHalfUpRatio(BigInt.one, BigInt.zero),
        throwsArgumentError,
      );
    },
  );

  test('calculates regular and overtime amounts without floating point', () {
    final result = calculateManualOvertimePay(
      const ExpectedPayInput(
        hourlyRateMicroEur: 20000000,
        paidSeconds: 3600,
        overtimeMinutes: 20,
        multiplier: RationalMultiplier(numerator: 3, denominator: 2),
        currency: CurrencyCode.eur(),
      ),
    );

    expect(result.regularPaidSeconds, 2400);
    expect(result.overtimePaidSeconds, 1200);
    expect(result.amount.minorUnits, 2333);
  });

  test('rounds once after combining regular and overtime rational amounts', () {
    final result = calculateManualOvertimePay(
      const ExpectedPayInput(
        hourlyRateMicroEur: 1000000,
        paidSeconds: 54,
        overtimeMinutes: 0,
        multiplier: RationalMultiplier(numerator: 3, denominator: 2),
        currency: CurrencyCode.eur(),
      ),
    );

    expect(result.amount.minorUnits, 2);
  });

  test('rejects invalid duration and overtime facts', () {
    const valid = ExpectedPayInput(
      hourlyRateMicroEur: 20000000,
      paidSeconds: 3600,
      overtimeMinutes: 20,
      multiplier: RationalMultiplier(numerator: 3, denominator: 2),
      currency: CurrencyCode.eur(),
    );
    expect(
      () => calculateManualOvertimePay(valid.copyWith(paidSeconds: 0)),
      throwsArgumentError,
    );
    expect(
      () => calculateManualOvertimePay(valid.copyWith(overtimeMinutes: -1)),
      throwsArgumentError,
    );
    expect(
      () => calculateManualOvertimePay(valid.copyWith(overtimeMinutes: 61)),
      throwsArgumentError,
    );
  });

  test('suggests only whole paid minutes beyond per-shift threshold', () {
    final item = agreement(thresholdMinutes: 480);
    expect(suggestedOvertimeMinutes(paidWholeMinutes: 481, agreement: item), 1);
    expect(suggestedOvertimeMinutes(paidWholeMinutes: 479, agreement: item), 0);
  });

  test('money has value equality for projection grouping', () {
    expect(const Money(minorUnits: 1200), const Money(minorUnits: 1200));
  });
}

PayAgreement agreement({required int thresholdMinutes}) {
  return PayAgreement(
    id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
    employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
    version: 1,
    effectiveStart: LocalDate.parse('2026-09-01'),
    effectiveEnd: null,
    hourlyRateMicroEur: 20000000,
    basis: const GrossBasis(),
    overtimeThresholdMinutes: thresholdMinutes,
    overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
    label: null,
    note: null,
    createdAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
    usedByFinalizedShift: false,
  );
}
