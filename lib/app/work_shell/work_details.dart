import 'package:flutter/foundation.dart' show VoidCallback;

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import 'employment_details.dart';

/// The Details box under the Work tree (spec 3). On the overview: how many
/// employments there are. For an employment: its terms, its open period
/// and last payslip, then the month's days and the next shift. Without
/// [details] (still reading, or unreadable) only its name shows. Links
/// arrive with their sheets (Phase 4b, 4c, 4f).
List<DetailsSection> workDetailsSections({
  required EmploymentDetails? details,
  required String? employmentName,
  required int employmentCount,
  void Function(AgreementId id)? onAgreement,
  void Function(ScheduleId id)? onSchedule,
  void Function(List<LocalDate> days)? onExtend,
  VoidCallback? onToConfirm,
  void Function(PayPeriodId)? onPeriod,
  void Function(PayslipId)? onPayslip,
}) {
  if (employmentName == null) {
    return [
      DetailsSection(facts: [DetailsFact('Employments', '$employmentCount')]),
    ];
  }
  if (details == null) return [DetailsSection(title: employmentName)];
  final agreement = details.agreement;
  final month = details.month;
  return [
    DetailsSection(
      title: employmentName,
      facts: [
        DetailsFact(
          'Agreement',
          agreement == null ? 'None yet' : 'From ${agreement.effectiveStart}',
          figure: false,
          onFollow: switch ((agreement, onAgreement)) {
            (final value?, final follow?) => () => follow(value.id),
            _ => null,
          },
        ),
        if (agreement != null) ...[
          DetailsFact(
            'Hourly rate',
            'EUR ${formatHourlyRate(agreement.hourlyRateMicroEur)} '
                '${_basis(agreement.basis)}',
          ),
          DetailsFact('Night premium', _night(agreement)),
        ],
        DetailsFact(
          'Schedule',
          details.schedule?.name ?? 'None in use',
          figure: false,
          onFollow: switch ((details.schedule, onSchedule)) {
            (final value?, final follow?) => () => follow(value.id),
            _ => null,
          },
        ),
      ],
    ),
    if (details.openPeriod != null || details.lastPayslip != null)
      DetailsSection(
        facts: [
          if (details.openPeriod case final period?)
            DetailsFact(
              'Open period',
              period.label ?? '${period.start} – ${period.end}',
              figure: false,
              onFollow: onPeriod == null ? null : () => onPeriod(period.id),
            ),
          if (details.confirmedSoFar case final money?)
            DetailsFact('Confirmed so far', formatMoney(money)),
          if (details.lastPayslip case final payslip?)
            DetailsFact(
              'Last payslip',
              '${formatMoney(payslip.amount)}, '
                  '${eraBoxDate(payslip.issuedDate)}',
              onFollow: onPayslip == null ? null : () => onPayslip(payslip.id),
            ),
        ],
      ),
    DetailsSection(
      title: eraMonthTitle(month.month),
      facts: [
        DetailsFact('Finalized', _count(month.finalized, 'shift')),
        DetailsFact('Planned', _count(month.planned, 'shift')),
        DetailsFact('Leave', _count(month.leave, 'day')),
        DetailsFact('Off', _count(month.off, 'day')),
        if (month.withoutAgreement > 0)
          DetailsFact(
            'Without a pay agreement',
            _count(month.withoutAgreement, 'day'),
            onFollow: switch (onExtend) {
              final extend? => () => extend(month.withoutAgreementDays),
              null => null,
            },
          ),
        if ((details.nextShift, details.nextShiftStart) case (
          final next?,
          final start?,
        ))
          DetailsFact(
            'Next shift',
            '${eraWeekdayShort(next.date)} ${_monthDay(next.date)} '
                '${next.type?.name ?? 'Extra'} ${_time(start)}',
            figure: false,
          ),
      ],
      warnings: [
        if (month.toConfirm > 0)
          DetailsWarning(
            'To confirm: ${_count(month.toConfirm, 'day')}',
            onFollow: onToConfirm,
          ),
      ],
    ),
  ];
}

String _count(int n, String noun) => n == 1 ? '1 $noun' : '$n ${noun}s';

String _basis(RateBasis basis) => switch (basis) {
  GrossBasis() => 'gross',
  NetBasis() => 'net',
};

String _night(PayAgreement agreement) {
  if (!agreement.nightEnabled) return 'None';
  String at(int minute) => _time(LocalTime(minute ~/ 60 % 24, minute % 60));
  return '×${formatMultiplier(agreement.nightMultiplier)}, '
      '${at(agreement.nightStartMinute)}–${at(agreement.nightEndMinute)}';
}

String _monthDay(LocalDate date) =>
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _time(LocalTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
