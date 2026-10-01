import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/explain/explanation.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_explanations.dart';
import 'package:lifeos/features/work/presentation/work_formats.dart';

const _employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');

void main() {
  final zones = IanaTimezoneService();

  group('expected pay', () {
    test('the result reads exactly like the cell, from the same result', () {
      final facts = _facts(overtimeMinutes: 15);
      final pay = calculateExpectedPay(facts.toExpectedPayInput());
      final explanation = explainExpectedPay(facts, pay);

      final result = explanation.tokens.whereType<ResultToken>().single;
      expect(result.text, formatMoney(pay.amount));
      expect(result.text, 'EUR 154.10');
      expect(
        explanation.plainText,
        'Est. pay, 2026-09-29 = regular 8:00 × 18.40/h'
        ' + overtime 0:15 × 18.40/h × 1.5 = EUR 154.10',
      );
      expect(explanation.sourceLabel, 'Agreement “Standard” v1');
    });

    test('a shift without overtime shows regular time only', () {
      final facts = _facts(overtimeMinutes: 0);
      final pay = calculateExpectedPay(facts.toExpectedPayInput());
      final explanation = explainExpectedPay(facts, pay);

      expect(explanation.plainText, isNot(contains('overtime')));
      expect(
        explanation.tokens.whereType<ResultToken>().single.text,
        formatMoney(pay.amount),
      );
    });
  });

  test('paid time reads end − start − breaks in the shift timezone', () {
    final facts = _facts(overtimeMinutes: 15);
    final explanation = explainPaidTime(facts, zones);

    expect(
      explanation.plainText,
      'Paid time, 2026-09-29 = 07:00 → 15:45 − breaks 0:30 = 8:15',
    );
    expect(
      explanation.tokens.whereType<ResultToken>().single.text,
      formatDuration(facts.paidSeconds),
    );
  });

  test('operand routes carry only structural state', () {
    final facts = _facts(overtimeMinutes: 15);
    final pay = calculateExpectedPay(facts.toExpectedPayInput());
    final explanations = [
      explainExpectedPay(facts, pay),
      explainPaidTime(facts, zones),
      explainPeriodExpected(_group()),
      explainDifference(_group()),
    ];
    for (final explanation in explanations) {
      for (final operand in explanation.tokens.whereType<OperandToken>()) {
        final route = operand.source.route;
        expect(
          route.queryParameters.keys.toSet().difference({
            'employment',
            'record',
            'mode',
          }),
          isEmpty,
          reason: route.toString(),
        );
        for (final private in ['18.40', 'Standard', '154', '1219', 'EUR']) {
          expect(route.toString(), isNot(contains(private)));
        }
      }
    }
  });

  group('reconciliation', () {
    test('period expected sums its finalized shifts', () {
      expect(
        explainPeriodExpected(_group()).plainText,
        'Expected, gross = Σ 8 finalized shifts = EUR 1246.60',
      );
    });

    test('a difference says what its sign means', () {
      expect(
        explainDifference(_group()).plainText,
        'Difference = paid EUR 1219.00 − expected EUR 1246.60'
        ' = EUR -27.60 (paid short)',
      );
      expect(
        explainDifference(_group(paid: 124660, difference: 0)).plainText,
        endsWith('(matches)'),
      );
    });

    test('missing evidence is stated, not computed', () {
      final explanation = explainDifference(
        _group(paid: null, difference: null, status: const MissingPayslip()),
      );
      expect(explanation.tokens.whereType<ResultToken>(), isEmpty);
      expect(
        explanation.plainText,
        'Difference = No payslip recorded for this period yet',
      );
    });
  });

  group('formats', () {
    test('multipliers read as short decimals or fractions', () {
      String format(int n, int d) =>
          formatMultiplier(RationalMultiplier(numerator: n, denominator: d));
      expect(format(3, 2), '1.5');
      expect(format(2, 1), '2');
      expect(format(5, 4), '1.25');
      expect(format(4, 3), '4/3');
    });

    test('hourly rates keep recorded precision', () {
      expect(formatHourlyRate(18400000), '18.40/h');
      expect(formatHourlyRate(18405000), '18.405/h');
    });

    test('durations read as hours and minutes', () {
      expect(formatDuration(29700), '8:15');
      expect(formatDuration(1800), '0:30');
    });
  });
}

FinalizationFacts _facts({required int overtimeMinutes}) {
  final shift = WorkShift(
    id: _shiftId,
    employmentId: _employment,
    agreementId: null,
    state: ShiftState.draft,
    // 07:00 to 15:45 in Berlin (UTC+2) with a 30-minute break.
    startUtc: DateTime.utc(2026, 9, 29, 5),
    endUtc: DateTime.utc(2026, 9, 29, 13, 45),
    timezoneId: 'Europe/Berlin',
    localStartDate: LocalDate.parse('2026-09-29'),
    overtimeMinutes: overtimeMinutes,
    note: null,
    voidReason: null,
    replacementShiftId: null,
    replacedShiftId: null,
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
  );
  final breaks = [
    ShiftBreak(
      id: const ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41'),
      shiftId: _shiftId,
      startUtc: DateTime.utc(2026, 9, 29, 9, 30),
      endUtc: DateTime.utc(2026, 9, 29, 10),
      createdAtUtc: DateTime.utc(2026),
      updatedAtUtc: DateTime.utc(2026),
      revision: const Revision(0),
    ),
  ];
  final agreement = PayAgreement(
    id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
    employmentId: _employment,
    version: 1,
    effectiveStart: LocalDate.parse('2026-09-01'),
    effectiveEnd: null,
    hourlyRateMicroEur: 18400000,
    basis: const GrossBasis(),
    overtimeThresholdMinutes: 480,
    overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
    label: 'Standard',
    note: null,
    createdAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
    usedByFinalizedShift: false,
  );
  return validateFinalization(
    shift: shift,
    breaks: breaks,
    agreements: [agreement],
  ).facts!;
}

ReconciliationGroup _group({
  int? paid = 121900,
  int? difference = -2760,
  ReconciliationStatus status = const Difference(),
}) => ReconciliationGroup(
  employmentId: _employment,
  periodId: _periodId,
  currency: const CurrencyCode.eur(),
  basis: const GrossBasis(),
  regularPaidSeconds: 230400,
  overtimePaidSeconds: 9000,
  expected: const Money(minorUnits: 124660),
  paid: paid == null ? null : Money(minorUnits: paid),
  difference: difference == null ? null : Money(minorUnits: difference),
  shiftIds: List.filled(8, _shiftId),
  payslipIds: const [],
  status: status,
);
