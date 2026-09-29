import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/correction.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  test('voids finalized shift and creates linked replacement draft', () {
    final correction = prepareShiftCorrection(
      original: finalizedShift(),
      replacementId: replacementShiftId,
      voidReason: '  Correct end time  ',
      nowUtc: DateTime.utc(2026, 9, 29),
    );

    expect(correction.voidedOriginal.state, ShiftState.voided);
    expect(correction.voidedOriginal.voidReason, 'Correct end time');
    expect(correction.voidedOriginal.replacementShiftId, replacementShiftId);
    expect(correction.voidedOriginal.revision, const Revision(2));
    expect(correction.replacement.state, ShiftState.draft);
    expect(correction.replacement.replacedShiftId, finalizedShift().id);
    expect(correction.replacement.agreementId, finalizedShift().agreementId);
    expect(correction.replacement.revision, const Revision(0));
  });

  test('rejects correction of draft or already voided shift', () {
    expect(
      () => prepareShiftCorrection(
        original: draftShift(),
        replacementId: replacementShiftId,
        voidReason: 'Reason',
        nowUtc: DateTime.utc(2026),
      ),
      throwsStateError,
    );
    expect(
      () => prepareShiftCorrection(
        original: voidedShift(),
        replacementId: replacementShiftId,
        voidReason: 'Reason',
        nowUtc: DateTime.utc(2026),
      ),
      throwsStateError,
    );
  });

  test('discarding replacement cannot reactivate voided original', () {
    final correction = prepareShiftCorrection(
      original: finalizedShift(),
      replacementId: replacementShiftId,
      voidReason: 'Correction',
      nowUtc: DateTime.utc(2026),
    );

    expect(correction.voidedOriginal.state, ShiftState.voided);
    expect(correction.replacement.state, ShiftState.draft);
    expect(
      correction.voidedOriginal.replacementShiftId,
      correction.replacement.id,
    );
  });

  test('voids effective payslip and creates reciprocal replacement', () {
    final correction = preparePayslipCorrection(
      original: effectivePayslip(),
      replacementId: replacementPayslipId,
      voidReason: '  Correct amount  ',
      nowUtc: DateTime.utc(2026, 9, 29),
    );

    expect(correction.voidedOriginal.state, PayslipState.voided);
    expect(correction.voidedOriginal.voidReason, 'Correct amount');
    expect(
      correction.voidedOriginal.replacementPayslipId,
      replacementPayslipId,
    );
    expect(correction.replacement.state, PayslipState.effective);
    expect(correction.replacement.replacedPayslipId, effectivePayslip().id);
    expect(correction.replacement.revision, const Revision(0));
  });

  test('rejects blank reasons, non-UTC timestamps, and voided payslips', () {
    expect(
      () => prepareShiftCorrection(
        original: finalizedShift(),
        replacementId: replacementShiftId,
        voidReason: ' ',
        nowUtc: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => preparePayslipCorrection(
        original: effectivePayslip(),
        replacementId: replacementPayslipId,
        voidReason: 'Reason',
        nowUtc: DateTime(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => preparePayslipCorrection(
        original: voidedPayslip(),
        replacementId: replacementPayslipId,
        voidReason: 'Reason',
        nowUtc: DateTime.utc(2026),
      ),
      throwsStateError,
    );
  });
}

const originalShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const replacementShiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const originalPayslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const replacementPayslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62');

WorkShift finalizedShift() => WorkShift(
  id: originalShiftId,
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  state: ShiftState.finalized,
  startUtc: DateTime.parse('2026-09-10T08:00:00Z'),
  endUtc: DateTime.parse('2026-09-10T16:00:00Z'),
  timezoneId: 'Europe/Berlin',
  localStartDate: LocalDate.parse('2026-09-10'),
  overtimeMinutes: 0,
  note: 'Synthetic note',
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  revision: const Revision(1),
);

WorkShift draftShift() => WorkShift(
  id: originalShiftId,
  employmentId: finalizedShift().employmentId,
  agreementId: null,
  state: ShiftState.draft,
  startUtc: finalizedShift().startUtc,
  endUtc: finalizedShift().endUtc,
  timezoneId: finalizedShift().timezoneId,
  localStartDate: finalizedShift().localStartDate,
  overtimeMinutes: 0,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
);

WorkShift voidedShift() => finalizedShift().voidedForCorrection(
  replacementId: replacementShiftId,
  voidReason: 'Old correction',
  nowUtc: DateTime.utc(2026),
);

Payslip effectivePayslip() => Payslip(
  id: originalPayslipId,
  periodId: const PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51'),
  issuedDate: LocalDate.parse('2026-10-01'),
  paidDate: null,
  amount: const Money(minorUnits: 16000),
  basis: const GrossBasis(),
  grossMinorUnits: 16000,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: 'Synthetic reference',
  note: null,
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: null,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
);

Payslip voidedPayslip() => effectivePayslip().voidedForCorrection(
  replacementId: replacementPayslipId,
  voidReason: 'Old correction',
  nowUtc: DateTime.utc(2026),
);
