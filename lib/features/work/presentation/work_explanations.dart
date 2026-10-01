import '../../../core/explain/explanation.dart';
import '../../../core/time/timezone_service.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/reconciliation.dart';
import '../domain/shift.dart';
import 'work_formats.dart';
import 'work_route_state.dart';

/// Formula-bar explanations for Work's derived values (spec 6.3). Each is
/// built from the result object that produced the cell, never from a second
/// calculation, so the explanation's result always reads like the cell.

SourceRef _record(
  EmploymentId employment,
  WorkRecordKind kind,
  WorkRecordId id,
) => SourceRef(
  workRouteUri(
    WorkRouteState(
      employmentId: employment,
      scope: null,
      record: WorkRecordRef(kind: kind, id: id),
      mode: WorkInspectorMode.inspect,
    ),
  ),
);

String _agreementName(PayAgreement agreement) => agreement.label == null
    ? 'Agreement v${agreement.version}'
    : 'Agreement “${agreement.label}” v${agreement.version}';

/// Paid time: end − start − breaks, in the shift's own timezone.
Explanation explainPaidTime(FinalizationFacts facts, TimezoneService zones) {
  final shift = facts.shift;
  final end = shift.endUtc!;
  final zone = shift.timezoneId;
  String clock(DateTime utc) =>
      zones.localTimeAt(utc, zone).toString().substring(0, 5);
  final breakSeconds =
      end.difference(shift.startUtc).inSeconds - facts.paidSeconds;
  final source = _record(shift.employmentId, WorkRecordKind.shift, shift.id);
  return Explanation(
    label: 'Paid time, ${shift.localStartDate}',
    tokens: [
      OperandToken(clock(shift.startUtc), source),
      const TextToken(' → '),
      OperandToken(clock(end), source),
      const TextToken(' − breaks '),
      OperandToken(formatDuration(breakSeconds), source),
      const TextToken(' = '),
      ResultToken(formatDuration(facts.paidSeconds)),
    ],
    source: source,
    sourceLabel: 'Shift ${shift.localStartDate}',
  );
}

/// Expected pay under the shift's agreement: each group of paid time with
/// the same premiums, at the hourly rate times the multiplier they stack
/// to. The source names how the agreement stacks premiums.
Explanation explainExpectedPay(FinalizationFacts facts, ExpectedPay pay) {
  final shift = facts.shift;
  final agreement = facts.agreement;
  final shiftSource = _record(
    shift.employmentId,
    WorkRecordKind.shift,
    shift.id,
  );
  final agreementSource = _record(
    shift.employmentId,
    WorkRecordKind.agreement,
    agreement.id,
  );
  final rate = formatHourlyRate(agreement.hourlyRateMicroEur);
  const one = RationalMultiplier(numerator: 1, denominator: 1);
  return Explanation(
    label: 'Est. pay, ${shift.localStartDate}',
    tokens: [
      for (final (index, group) in pay.groups.indexed) ...[
        TextToken('${index == 0 ? '' : ' + '}${_groupName(group)} '),
        OperandToken(formatDuration(group.seconds), shiftSource),
        const TextToken(' × '),
        OperandToken(rate, agreementSource),
        if (group.multiplier != one) ...[
          const TextToken(' × '),
          OperandToken(formatMultiplier(group.multiplier), agreementSource),
        ],
      ],
      const TextToken(' = '),
      ResultToken(formatMoney(pay.amount)),
    ],
    source: agreementSource,
    sourceLabel:
        '${_agreementName(agreement)}, '
        '${_stackingWords(agreement.premiumStacking)}',
  );
}

String _groupName(PayGroup group) => group.isRegular
    ? 'regular'
    : [
        if (group.night) 'night',
        if (group.holiday) 'holiday',
        if (group.overtime) 'overtime',
      ].join(' & ');

String _stackingWords(PremiumStacking stacking) => switch (stacking) {
  PremiumStacking.highest => 'highest premium wins',
  PremiumStacking.additive => 'premium extras add up',
  PremiumStacking.multiplicative => 'premiums multiply',
};

String _basisWord(ReconciliationGroup group) => switch (group.basis) {
  GrossBasis() => 'gross',
  NetBasis() => 'net',
  null => 'mixed basis',
};

/// A period's expected total: the sum of its finalized shifts.
Explanation explainPeriodExpected(ReconciliationGroup group) {
  final source = _record(
    group.employmentId,
    WorkRecordKind.payPeriod,
    group.periodId,
  );
  final shifts = group.shiftIds.length;
  final expected = group.expected;
  return Explanation(
    label: 'Expected, ${_basisWord(group)}',
    tokens: [
      const TextToken('Σ '),
      OperandToken(
        shifts == 1 ? '1 finalized shift' : '$shifts finalized shifts',
        source,
      ),
      const TextToken(' = '),
      ResultToken(expected == null ? 'unavailable' : formatMoney(expected)),
    ],
    source: source,
    sourceLabel: 'Pay period',
  );
}

/// Paid evidence minus the expected total, with what the sign means.
Explanation explainDifference(ReconciliationGroup group) {
  final source = _record(
    group.employmentId,
    WorkRecordKind.payPeriod,
    group.periodId,
  );
  final paid = group.paid;
  final expected = group.expected;
  final difference = group.difference;
  if (paid == null || expected == null || difference == null) {
    return Explanation(
      label: 'Difference',
      tokens: [
        TextToken(switch (group.status) {
          MissingPayslip() => 'No payslip recorded for this period yet',
          UnmatchedPayslip() => 'A payslip has no matching shifts',
          MixedBasis() => 'Gross and net amounts cannot be compared',
          UnavailableReconciliation() => 'An agreement is missing',
          EmptyReconciliation() => 'No shifts or payslips in this period',
          Balanced() || Difference() => 'Not enough evidence to compare',
        }),
      ],
      source: source,
      sourceLabel: 'Pay period',
    );
  }
  final meaning = difference.minorUnits == 0
      ? 'matches'
      : difference.minorUnits < 0
      ? 'paid short'
      : 'paid over';
  return Explanation(
    label: 'Difference',
    tokens: [
      const TextToken('paid '),
      OperandToken(formatMoney(paid), source),
      const TextToken(' − expected '),
      OperandToken(formatMoney(expected), source),
      const TextToken(' = '),
      ResultToken(formatMoney(difference)),
      TextToken(' ($meaning)'),
    ],
    source: source,
    sourceLabel: 'Pay period',
  );
}
