import '../../../core/time/local_date.dart';
import 'agreement.dart';
import 'day_exception.dart';
import 'facts.dart';
import 'ids.dart';
import 'pay.dart';

enum LeaveState { confirmed, voided }

/// A confirmed leave day (schedules spec 3.6).
final class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.employmentId,
    required this.date,
    required this.leaveType,
    required this.illnessStartedOn,
    required this.paidMinutes,
    required this.agreementId,
    required this.scheduleId,
    required this.scheduleVersion,
    required this.state,
    required this.voidReason,
    required this.replacementId,
    required this.replacedId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  }) {
    if (paidMinutes <= 0) throw ArgumentError.value(paidMinutes, 'paidMinutes');
    if (leaveType != LeaveType.sick && illnessStartedOn != null) {
      throw ArgumentError.value(illnessStartedOn, 'illnessStartedOn');
    }
    if (state == LeaveState.voided &&
        (voidReason?.trim().isEmpty != false || replacementId == null)) {
      throw ArgumentError('Voided leave requires a reason and replacement.');
    }
  }

  final LeaveRecordId id;
  final EmploymentId employmentId;
  final LocalDate date;
  final LeaveType leaveType;
  final LocalDate? illnessStartedOn;
  final int paidMinutes;
  final AgreementId agreementId;
  final ScheduleId scheduleId;
  final int scheduleVersion;
  final LeaveState state;
  final String? voidReason;
  final LeaveRecordId? replacementId;
  final LeaveRecordId? replacedId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  bool get isEffective => state == LeaveState.confirmed;
}

/// A confirmed worked day's paid time and expected pay, for averages.
final class WorkedPay {
  const WorkedPay({
    required this.date,
    required this.paidSeconds,
    required this.pay,
  });

  final LocalDate date;
  final int paidSeconds;
  final Money pay;
}

/// How one leave day is priced, with what Working shows.
final class LeavePay {
  const LeavePay({
    required this.amount,
    required this.paidSeconds,
    required this.factor,
    required this.employerPaid,
    required this.usedFallback,
    required this.average,
  });

  final Money amount;
  final int paidSeconds;

  /// The agreement's percent, as a fraction; null when the employer does
  /// not pay this day.
  final RationalMultiplier? factor;
  final bool employerPaid;

  /// No confirmed paid time in the 3 months before: the agreement rate.
  final bool usedFallback;

  /// The window's totals behind the average, when not a fallback.
  final ({int minorUnits, int paidSeconds})? average;
}

/// Prices every effective leave record, oldest first, so a leave day's
/// average includes earlier priced leave (spec 4.3).
Map<LeaveRecordId, LeavePay> priceLeave({
  required List<LeaveRecord> leave,
  required List<WorkedPay> worked,
  required Iterable<PayAgreement> agreements,
}) {
  final byId = {for (final value in agreements) value.id: value};
  final ordered = [
    for (final item in leave)
      if (item.isEffective) item,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final priced = <LeaveRecordId, LeavePay>{};
  final pricedLeave = <WorkedPay>[];
  for (final item in ordered) {
    final agreement = byId[item.agreementId];
    if (agreement == null) continue;
    final windowStart = item.date.firstOfMonth.addMonths(-3);
    final windowEnd = item.date.firstOfMonth.addDays(-1);
    var minor = 0;
    var seconds = 0;
    for (final day in [...worked, ...pricedLeave]) {
      if (day.date.compareTo(windowStart) >= 0 &&
          day.date.compareTo(windowEnd) <= 0 &&
          day.paidSeconds > 0) {
        minor += day.pay.minorUnits;
        seconds += day.paidSeconds;
      }
    }
    final paidSeconds = item.paidMinutes * 60;
    final factor = switch (item.leaveType) {
      LeaveType.vacation => agreement.vacationPay,
      LeaveType.sick
          when item.date.daysSince(item.illnessStartedOn ?? item.date) <
              agreement.sickEmployerDays =>
        agreement.sickPay,
      LeaveType.sick => null,
    };
    final fallback = seconds == 0;
    final amount = factor == null
        ? 0
        : fallback
        // micro-EUR per hour → cents: ÷ 3600 s ÷ 10 000.
        ? roundHalfUpRatio(
            BigInt.from(paidSeconds) *
                BigInt.from(agreement.hourlyRateMicroEur) *
                BigInt.from(factor.numerator),
            BigInt.from(3600 * 10000) * BigInt.from(factor.denominator),
          )
        : roundHalfUpRatio(
            BigInt.from(paidSeconds) *
                BigInt.from(minor) *
                BigInt.from(factor.numerator),
            BigInt.from(seconds) * BigInt.from(factor.denominator),
          );
    final pay = LeavePay(
      amount: Money(minorUnits: amount),
      paidSeconds: paidSeconds,
      factor: factor,
      employerPaid: factor != null,
      usedFallback: fallback,
      average: fallback ? null : (minorUnits: minor, paidSeconds: seconds),
    );
    priced[item.id] = pay;
    if (factor != null) {
      pricedLeave.add(
        WorkedPay(date: item.date, paidSeconds: paidSeconds, pay: pay.amount),
      );
    }
  }
  return priced;
}

/// The default start of the illness [date] belongs to: the earliest sick
/// day of a run ending at [date] in which only Off days separate the sick
/// days (spec 4.3). Looks back at most a year.
LocalDate defaultIllnessStart(
  LocalDate date, {
  required bool Function(LocalDate) isSick,
  required bool Function(LocalDate) isOff,
}) {
  var start = date;
  for (var back = 1; back <= 366; back++) {
    final day = date.addDays(-back);
    if (isSick(day)) {
      start = day;
    } else if (!isOff(day)) {
      break;
    }
  }
  return start;
}
