import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' as db;
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/work_converters.dart';
import 'package:lifeos/features/work/domain/agreement.dart' as domain_agreement;
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart' as domain;

void main() {
  test('finalized shift round trips every historical field', () {
    final fact = domain.WorkShift(
      id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
      employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
      agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
      state: domain.ShiftState.finalized,
      startUtc: DateTime.utc(2026, 9, 29, 6, 30),
      endUtc: DateTime.utc(2026, 9, 29, 15, 45),
      timezoneId: 'Europe/Berlin',
      localStartDate: const LocalDate(2026, 9, 29),
      note: 'Synthetic shift',
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c30'),
      createdAtUtc: DateTime.utc(2026, 9, 28, 20),
      updatedAtUtc: DateTime.utc(2026, 9, 29, 16),
      revision: const Revision(4),
    );

    final restored = shiftFromRow(_shiftRow(shiftToCompanion(fact)));

    expect(restored.id, fact.id);
    expect(restored.employmentId, fact.employmentId);
    expect(restored.agreementId, fact.agreementId);
    expect(restored.state, fact.state);
    expect(restored.startUtc, fact.startUtc);
    expect(restored.endUtc, fact.endUtc);
    expect(restored.timezoneId, fact.timezoneId);
    expect(restored.localStartDate, fact.localStartDate);
    expect(restored.note, fact.note);
    expect(restored.voidReason, fact.voidReason);
    expect(restored.replacementShiftId, fact.replacementShiftId);
    expect(restored.replacedShiftId, fact.replacedShiftId);
    expect(restored.createdAtUtc, fact.createdAtUtc);
    expect(restored.updatedAtUtc, fact.updatedAtUtc);
    expect(restored.revision, fact.revision);
  });

  test('unknown stored enum text throws bounded corruption error', () {
    final row = _validShiftRow(state: 'unexpected');

    expect(
      () => shiftFromRow(row),
      throwsA(
        isA<WorkDataCorruption>()
            .having((error) => error.field, 'field', 'state')
            .having((error) => error.value, 'value', 'unexpected'),
      ),
    );
  });

  test('unknown stored basis and currency throw bounded corruption errors', () {
    expect(
      () => agreementFromRow(
        _validAgreementRow(basis: 'hourly-ish'),
        usedByFinalizedShift: false,
      ),
      throwsA(
        isA<WorkDataCorruption>().having(
          (error) => error.field,
          'field',
          'basis',
        ),
      ),
    );
    expect(
      () => payslipFromRow(_validPayslipRow(currency: 'USD')),
      throwsA(
        isA<WorkDataCorruption>().having(
          (error) => error.field,
          'field',
          'currency',
        ),
      ),
    );
  });

  test('agreement premium fields round trip by stable names', () {
    for (final calendar in domain_agreement.HolidayCalendar.values) {
      for (final stacking in domain_agreement.PremiumStacking.values) {
        final fact = domain_agreement.PayAgreement(
          id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
          employmentId: const EmploymentId(
            '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
          ),
          version: 2,
          effectiveStart: const LocalDate(2026, 9, 1),
          effectiveEnd: null,
          hourlyRateMicroEur: 18400000,
          basis: const GrossBasis(),
          overtimeThresholdMinutes: 600,
          overtimeMultiplier: const domain_agreement.RationalMultiplier(
            numerator: 2,
            denominator: 1,
          ),
          label: 'Synthetic',
          note: null,
          createdAtUtc: DateTime.utc(2026, 9),
          revision: const Revision(3),
          usedByFinalizedShift: false,
          nightEnabled: false,
          nightStartMinute: 21 * 60,
          nightEndMinute: 7 * 60,
          nightMultiplier: const domain_agreement.RationalMultiplier(
            numerator: 5,
            denominator: 4,
          ),
          holidayCalendar: calendar,
          holidayMultiplier: const domain_agreement.RationalMultiplier(
            numerator: 3,
            denominator: 1,
          ),
          premiumStacking: stacking,
        );

        final restored = agreementFromRow(
          _agreementRow(agreementToCompanion(fact)),
          usedByFinalizedShift: false,
        );

        expect(restored.nightEnabled, fact.nightEnabled);
        expect(restored.nightStartMinute, fact.nightStartMinute);
        expect(restored.nightEndMinute, fact.nightEndMinute);
        expect(restored.nightMultiplier, fact.nightMultiplier);
        expect(restored.holidayCalendar, calendar);
        expect(restored.holidayMultiplier, fact.holidayMultiplier);
        expect(restored.premiumStacking, stacking);
        expect(restored.overtimeThresholdMinutes, 600);
        expect(restored.overtimeMultiplier, fact.overtimeMultiplier);
      }
    }
    expect(
      holidayCalendarText(domain_agreement.HolidayCalendar.lithuania),
      'lithuania',
    );
    expect(
      premiumStackingText(domain_agreement.PremiumStacking.multiplicative),
      'multiplicative',
    );
  });

  test('unknown stored premium names throw bounded corruption errors', () {
    expect(
      () => agreementFromRow(
        _validAgreementRow(holidayCalendar: 'atlantis'),
        usedByFinalizedShift: false,
      ),
      throwsA(
        isA<WorkDataCorruption>().having(
          (error) => error.field,
          'field',
          'holidayCalendar',
        ),
      ),
    );
    expect(
      () => agreementFromRow(
        _validAgreementRow(premiumStacking: 'sum'),
        usedByFinalizedShift: false,
      ),
      throwsA(
        isA<WorkDataCorruption>().having(
          (error) => error.field,
          'field',
          'premiumStacking',
        ),
      ),
    );
  });

  test('malformed stored identifiers and dates throw corruption errors', () {
    expect(
      () => employmentFromRow(_validEmploymentRow(id: 'not-a-uuid')),
      throwsA(isA<WorkDataCorruption>()),
    );
    expect(
      () => payPeriodFromRow(_validPeriodRow(start: '2026-02-30')),
      throwsA(isA<WorkDataCorruption>()),
    );
  });
}

db.WorkShift _shiftRow(db.WorkShiftsCompanion value) => db.WorkShift(
  id: value.id.value,
  employmentId: value.employmentId.value,
  agreementId: value.agreementId.value,
  state: value.state.value,
  startUtcMicros: value.startUtcMicros.value,
  endUtcMicros: value.endUtcMicros.value,
  timezoneId: value.timezoneId.value,
  localStartDate: value.localStartDate.value,
  note: value.note.value,
  voidReason: value.voidReason.value,
  replacementShiftId: value.replacementShiftId.value,
  replacedShiftId: value.replacedShiftId.value,
  createdAtUtcMicros: value.createdAtUtcMicros.value,
  updatedAtUtcMicros: value.updatedAtUtcMicros.value,
  revision: value.revision.value,
);

db.WorkShift _validShiftRow({String state = 'finalized'}) => db.WorkShift(
  id: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31',
  employmentId: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
  agreementId: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21',
  state: state,
  startUtcMicros: DateTime.utc(2026, 9, 29, 6).microsecondsSinceEpoch,
  endUtcMicros: DateTime.utc(2026, 9, 29, 14).microsecondsSinceEpoch,
  timezoneId: 'Europe/Berlin',
  localStartDate: '2026-09-29',
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtcMicros: DateTime.utc(2026, 9, 29).microsecondsSinceEpoch,
  updatedAtUtcMicros: DateTime.utc(2026, 9, 29, 15).microsecondsSinceEpoch,
  revision: 1,
);

db.Employment _validEmploymentRow({
  String id = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
}) => db.Employment(
  id: id,
  name: 'Synthetic employer',
  legalLabel: null,
  status: 'active',
  createdAtUtcMicros: 1,
  updatedAtUtcMicros: 1,
  revision: 0,
);

db.PayAgreement _agreementRow(db.PayAgreementsCompanion value) =>
    db.PayAgreement(
      id: value.id.value,
      employmentId: value.employmentId.value,
      version: value.version.value,
      effectiveStart: value.effectiveStart.value,
      effectiveEnd: value.effectiveEnd.value,
      hourlyRateMicroEur: value.hourlyRateMicroEur.value,
      basis: value.basis.value,
      overtimeThresholdMinutes: value.overtimeThresholdMinutes.value,
      overtimeMultiplierNumerator: value.overtimeMultiplierNumerator.value,
      overtimeMultiplierDenominator: value.overtimeMultiplierDenominator.value,
      nightEnabled: value.nightEnabled.value,
      nightStartMinute: value.nightStartMinute.value,
      nightEndMinute: value.nightEndMinute.value,
      nightMultiplierNumerator: value.nightMultiplierNumerator.value,
      nightMultiplierDenominator: value.nightMultiplierDenominator.value,
      holidayCalendar: value.holidayCalendar.value,
      holidayMultiplierNumerator: value.holidayMultiplierNumerator.value,
      holidayMultiplierDenominator: value.holidayMultiplierDenominator.value,
      premiumStacking: value.premiumStacking.value,
      label: value.label.value,
      note: value.note.value,
      createdAtUtcMicros: value.createdAtUtcMicros.value,
      revision: value.revision.value,
    );

db.PayAgreement _validAgreementRow({
  String basis = 'gross',
  String holidayCalendar = 'lithuania',
  String premiumStacking = 'highest',
}) => db.PayAgreement(
  id: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21',
  employmentId: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
  version: 1,
  effectiveStart: '2026-09-01',
  effectiveEnd: null,
  hourlyRateMicroEur: 20000000,
  basis: basis,
  overtimeThresholdMinutes: 480,
  overtimeMultiplierNumerator: 3,
  overtimeMultiplierDenominator: 2,
  nightEnabled: true,
  nightStartMinute: 1320,
  nightEndMinute: 360,
  nightMultiplierNumerator: 3,
  nightMultiplierDenominator: 2,
  holidayCalendar: holidayCalendar,
  holidayMultiplierNumerator: 2,
  holidayMultiplierDenominator: 1,
  premiumStacking: premiumStacking,
  label: null,
  note: null,
  createdAtUtcMicros: 1,
  revision: 0,
);

db.PayPeriod _validPeriodRow({String start = '2026-09-01'}) => db.PayPeriod(
  id: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41',
  employmentId: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
  start: start,
  end: '2026-09-30',
  label: null,
  state: 'open',
  createdAtUtcMicros: 1,
  updatedAtUtcMicros: 1,
  revision: 0,
);

db.Payslip _validPayslipRow({String currency = 'EUR'}) => db.Payslip(
  id: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51',
  periodId: '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41',
  issuedDate: '2026-09-30',
  paidDate: null,
  amountMinorUnits: 100,
  currency: currency,
  basis: 'gross',
  grossMinorUnits: 100,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: null,
  note: null,
  state: 'effective',
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: null,
  createdAtUtcMicros: 1,
  updatedAtUtcMicros: 1,
  revision: 0,
);
