import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/history/record_event_dao.dart';
import '../../../core/history/record_events.dart';
import '../../../core/time/app_clock.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/shift.dart';

/// Stable `record_kind` values, matching the route's record kinds.
abstract final class WorkRecordKinds {
  static const employment = 'employment';
  static const agreement = 'agreement';
  static const shift = 'shift';
  static const payPeriod = 'payPeriod';
  static const payslip = 'payslip';
}

/// Appends Work history inside the caller's transaction.
final class WorkHistoryWriter {
  WorkHistoryWriter(AppDatabase database, this._clock)
    : _events = RecordEventDao(database);

  final RecordEventDao _events;
  final AppClock _clock;

  RecordEventDao get events => _events;

  Future<void> record(
    String recordKind,
    String recordId, {
    required RecordEventKind kind,
    required Map<String, String?> after,
    required Revision revisionAfter,
    Map<String, String?> before = const {},
    String? reason,
  }) => _events.append(
    recordKind: recordKind,
    recordId: recordId,
    atUtc: _clock.nowUtc(),
    kind: kind,
    changes: diffFacts(before, after),
    reason: reason,
    revisionAfter: revisionAfter.value,
  );
}

Map<String, String?> employmentFacts(Employment value) => {
  'Name': value.name,
  'Legal name': value.legalLabel,
  'Status': value.status.name,
};

Map<String, String?> agreementFacts(PayAgreement value) => {
  'Version': '${value.version}',
  'Starts on': value.effectiveStart.toString(),
  'Ends on': value.effectiveEnd?.toString(),
  'Hourly rate': '${_micros(value.hourlyRateMicroEur)} EUR/h',
  'Basis': _basis(value.basis),
  'Overtime':
      'after ${value.overtimeThresholdMinutes} min ×${value.overtimeMultiplier}',
  'Night pay': value.nightEnabled
      ? '${_clock(value.nightStartMinute)}–${_clock(value.nightEndMinute)} '
            '×${value.nightMultiplier}'
      : 'off',
  'Public holidays': value.holidayCalendar == HolidayCalendar.none
      ? 'off'
      : '${value.holidayCalendar.name} ×${value.holidayMultiplier}',
  'When several apply': value.premiumStacking.name,
  'Label': value.label,
  'Note': value.note,
};

Map<String, String?> shiftFacts(WorkShift value, List<ShiftBreak> breaks) => {
  'State': value.state.name,
  'Start': _instant(value.startUtc),
  'End': value.endUtc == null ? null : _instant(value.endUtc!),
  'Timezone': value.timezoneId,
  'Local date': value.localStartDate.toString(),
  'Breaks': breaks.isEmpty
      ? null
      : [
          for (final item in breaks)
            '${_instant(item.startUtc)}–'
                '${item.endUtc == null ? '' : _instant(item.endUtc!)}',
        ].join(', '),
  'Note': value.note,
  'Void reason': value.voidReason,
};

Map<String, String?> periodFacts(PayPeriod value) => {
  'Start': value.start.toString(),
  'End': value.end.toString(),
  'Label': value.label,
  'State': value.state.name,
};

Map<String, String?> payslipFacts(Payslip value) => {
  'Issued': value.issuedDate.toString(),
  'Paid': value.paidDate?.toString(),
  'Amount': _money(value.amount),
  'Basis': _basis(value.basis),
  'Gross': _minor(value.grossMinorUnits, value.amount.currency),
  'Net': _minor(value.netMinorUnits, value.amount.currency),
  'Deductions': _minor(value.deductionMinorUnits, value.amount.currency),
  'Reference': value.reference,
  'Note': value.note,
  'State': value.state.name,
  'Void reason': value.voidReason,
};

String _basis(RateBasis basis) => switch (basis) {
  GrossBasis() => 'gross',
  NetBasis() => 'net',
};

String _instant(DateTime utc) =>
    '${utc.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} UTC';

String _clock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

String _micros(int micros) {
  var fraction = (micros % 1000000).toString().padLeft(6, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '${micros ~/ 1000000}.$fraction';
}

String _money(Money money) => _minor(money.minorUnits, money.currency)!;

String? _minor(int? minorUnits, CurrencyCode currency) {
  if (minorUnits == null) return null;
  final sign = minorUnits < 0 ? '-' : '';
  final absolute = minorUnits.abs();
  return '${currency.value} $sign${absolute ~/ 100}.'
      '${(absolute % 100).toString().padLeft(2, '0')}';
}
