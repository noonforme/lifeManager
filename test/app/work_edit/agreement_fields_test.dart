import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/agreement_edit.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';

const _terms = AgreementTerms(
  effectiveStart: LocalDate(2026, 9, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 18400000,
  basis: GrossBasis(),
  label: null,
  note: null,
);

AgreementTerms _set(String field, Object? value) {
  final result = withAgreementField(_terms, field, value);
  expect(result.problem, isNull, reason: field);
  return result.terms!;
}

String? _problem(String field, Object? value) {
  final result = withAgreementField(_terms, field, value);
  expect(result.terms, isNull, reason: field);
  return result.problem;
}

void main() {
  test('each field of the terms takes its value', () {
    expect(
      _set(AgreementField.nightMultiplier, '1.75').nightMultiplier,
      const RationalMultiplier(numerator: 7, denominator: 4),
    );
    expect(
      _set(AgreementField.overtimeHours, '7.5').overtimeThresholdMinutes,
      450,
    );
    expect(
      _set(AgreementField.overtimeMultiplier, '2').overtimeMultiplier,
      const RationalMultiplier(numerator: 2, denominator: 1),
    );
    expect(
      _set(AgreementField.vacationPercent, '62.06').vacationPay,
      const RationalMultiplier(numerator: 3103, denominator: 5000),
    );
    expect(
      _set(AgreementField.sickPercent, '80').sickPay,
      const RationalMultiplier(numerator: 4, denominator: 5),
    );
    expect(_set(AgreementField.sickDays, '2').sickEmployerDays, 2);
    expect(_set(AgreementField.basis, const NetBasis()).basis, isA<NetBasis>());
    expect(
      _set(AgreementField.stacking, PremiumStacking.additive).premiumStacking,
      PremiumStacking.additive,
    );
    expect(
      _set(AgreementField.holidays, HolidayCalendar.none).holidayCalendar,
      HolidayCalendar.none,
    );
    expect(_set(AgreementField.nightEnabled, false).nightEnabled, isFalse);
    expect(
      _set(AgreementField.nightStart, const LocalTime(21, 0)).nightStartMinute,
      1260,
    );
    expect(
      _set(AgreementField.nightEnd, const LocalTime(5, 30)).nightEndMinute,
      330,
    );
    expect(
      _set(AgreementField.holidayMultiplier, '2').holidayMultiplier,
      const RationalMultiplier(numerator: 2, denominator: 1),
    );
    expect(
      _set(AgreementField.hourlyRate, '19.20').hourlyRateMicroEur,
      19200000,
    );
    expect(
      _set(
        AgreementField.effectiveStart,
        const LocalDate(2026, 10, 1),
      ).effectiveStart,
      const LocalDate(2026, 10, 1),
    );
    expect(
      _set(
        AgreementField.effectiveEnd,
        const LocalDate(2026, 12, 31),
      ).effectiveEnd,
      const LocalDate(2026, 12, 31),
    );
    expect(_set(AgreementField.effectiveEnd, null).effectiveEnd, isNull);
    expect(_set(AgreementField.label, '  Night rate ').label, 'Night rate');
    expect(_set(AgreementField.note, '').note, isNull);
  });

  test('a value that is not one says why', () {
    expect(
      _problem(AgreementField.nightMultiplier, '0.9'),
      AgreementProblems.multiplier,
    );
    expect(_problem(AgreementField.sickDays, '31'), AgreementProblems.sickDays);
    expect(
      _problem(AgreementField.overtimeHours, '0'),
      AgreementProblems.hours,
    );
    expect(
      _problem(AgreementField.vacationPercent, '0'),
      AgreementProblems.percent,
    );
    expect(_problem(AgreementField.hourlyRate, 'lots'), AgreementProblems.rate);
    expect(
      _problem(AgreementField.effectiveStart, null),
      AgreementProblems.startRequired,
    );
    expect(
      _problem(AgreementField.effectiveEnd, 'x'),
      AgreementProblems.notEditable,
    );
    expect(_problem('colour', 'red'), AgreementProblems.notEditable);
  });
}
