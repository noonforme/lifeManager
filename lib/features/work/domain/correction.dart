import 'ids.dart';
import 'payslip.dart';
import 'shift.dart';

final class ShiftCorrection {
  const ShiftCorrection({
    required this.voidedOriginal,
    required this.replacement,
  });

  final WorkShift voidedOriginal;
  final WorkShift replacement;
}

final class PayslipCorrection {
  const PayslipCorrection({
    required this.voidedOriginal,
    required this.replacement,
  });

  final Payslip voidedOriginal;
  final Payslip replacement;
}

ShiftCorrection prepareShiftCorrection({
  required WorkShift original,
  required ShiftId replacementId,
  required String voidReason,
  required DateTime nowUtc,
}) {
  if (original.state != ShiftState.finalized) {
    throw StateError('Only finalized shifts can be corrected.');
  }
  _validateCorrection(replacementId, original.id, voidReason, nowUtc);
  final reason = voidReason.trim();
  return ShiftCorrection(
    voidedOriginal: original.voidedForCorrection(
      replacementId: replacementId,
      voidReason: reason,
      nowUtc: nowUtc,
    ),
    replacement: original.replacementDraft(
      replacementId: replacementId,
      nowUtc: nowUtc,
    ),
  );
}

PayslipCorrection preparePayslipCorrection({
  required Payslip original,
  required PayslipId replacementId,
  required String voidReason,
  required DateTime nowUtc,
}) {
  if (!original.isEffective) {
    throw StateError('Only effective payslips can be corrected.');
  }
  _validateCorrection(replacementId, original.id, voidReason, nowUtc);
  final reason = voidReason.trim();
  return PayslipCorrection(
    voidedOriginal: original.voidedForCorrection(
      replacementId: replacementId,
      voidReason: reason,
      nowUtc: nowUtc,
    ),
    replacement: original.replacement(
      replacementId: replacementId,
      nowUtc: nowUtc,
    ),
  );
}

void _validateCorrection(
  WorkRecordId replacementId,
  WorkRecordId originalId,
  String voidReason,
  DateTime nowUtc,
) {
  if (replacementId.value == originalId.value) {
    throw ArgumentError.value(replacementId.value, 'replacementId');
  }
  if (voidReason.trim().isEmpty) {
    throw ArgumentError.value(voidReason, 'voidReason');
  }
  if (!nowUtc.isUtc) {
    throw ArgumentError.value(nowUtc, 'nowUtc');
  }
}
