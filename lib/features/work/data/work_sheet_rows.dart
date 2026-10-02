import '../domain/agreement.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import '../domain/pay_premiums.dart';
import '../domain/shift.dart';
import 'projections/work_register_projection.dart';

/// A shift's derived sheet columns: break and paid time in whole seconds,
/// and for a finalized or voided shift the pay its agreement gives.
ShiftSheetRow shiftSheetRow(
  WorkShift shift,
  List<ShiftBreak> breaks,
  Map<AgreementId, PayAgreement> agreements,
  PayPeriod? period,
  ZoneClocks zoneClocks,
) {
  int second(DateTime utc) => utc.microsecondsSinceEpoch ~/ 1000000;
  final breakSeconds = breaks.fold(
    0,
    (total, item) => item.endUtc == null
        ? total
        : total + second(item.endUtc!) - second(item.startUtc),
  );
  final end = shift.endUtc;
  final paidSeconds = end == null
      ? null
      : second(end) - second(shift.startUtc) - breakSeconds;
  final agreement = agreements[shift.agreementId];
  final facts =
      (shift.state == ShiftState.finalized ||
              shift.state == ShiftState.voided) &&
          agreement != null
      ? validateFinalization(
          shift: shift,
          breaks: breaks,
          agreements: [agreement],
        ).facts
      : null;
  final clock = zoneClocks(shift.timezoneId);
  return ShiftSheetRow(
    shift: shift,
    breaks: breaks,
    breakSeconds: breakSeconds,
    paidSeconds: paidSeconds,
    period: period,
    facts: facts,
    pay: facts?.expectedPay(
      toLocal: clock.toLocal,
      toInstants: clock.toInstants,
    ),
  );
}
