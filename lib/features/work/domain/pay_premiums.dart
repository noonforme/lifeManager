import '../../../core/time/local_date.dart';
import 'agreement.dart';
import 'lithuanian_holidays.dart';

/// Local wall-clock view of an instant in the shift's zone.
typedef ToLocal = ({LocalDate date, int minuteOfDay}) Function(DateTime utc);

/// Every instant at which the shift's zone reads a local wall-clock time:
/// one normally, two in a daylight-saving overlap, and the first valid
/// instant after a daylight-saving gap.
typedef ToInstants = List<DateTime> Function(LocalDate date, int minuteOfDay);

/// A stretch of paid time with one set of premium flags (spec 5.1).
final class PaySegment {
  const PaySegment({
    required this.startUtc,
    required this.seconds,
    required this.night,
    required this.holiday,
    required this.overtime,
  });

  final DateTime startUtc;
  final int seconds;
  final bool night;
  final bool holiday;
  final bool overtime;

  bool get hasPremium => night || holiday || overtime;
}

/// Splits [paidIntervals] (the shift minus its breaks, in UTC, ordered and
/// not overlapping) at local midnights, the night window's start and end,
/// the overtime start and any change of UTC offset. Each segment's flags are
/// read at its start instant. Instants are truncated to whole seconds.
List<PaySegment> segmentPaidTime({
  required List<({DateTime start, DateTime end})> paidIntervals,
  required PayAgreement agreement,
  required ToLocal toLocal,
  required ToInstants toInstants,
}) {
  final intervals = [
    for (final interval in paidIntervals)
      (start: _wholeSecond(interval.start), end: _wholeSecond(interval.end)),
  ];
  for (var index = 0; index < intervals.length; index++) {
    final interval = intervals[index];
    if (!interval.start.isUtc || !interval.end.isUtc) {
      throw ArgumentError.value(paidIntervals, 'paidIntervals', 'not UTC');
    }
    if (!interval.end.isAfter(interval.start) ||
        (index > 0 && interval.start.isBefore(intervals[index - 1].end))) {
      throw ArgumentError.value(paidIntervals, 'paidIntervals');
    }
  }

  final overtimeStart = _overtimeStart(
    intervals,
    agreement.overtimeThresholdMinutes * 60,
  );
  final localMinutes = [
    0,
    if (agreement.nightEnabled) ...[
      agreement.nightStartMinute,
      agreement.nightEndMinute,
    ],
  ];

  final segments = <PaySegment>[];
  for (final (:start, :end) in intervals) {
    bool inside(DateTime instant) =>
        instant.isAfter(start) && instant.isBefore(end);

    final cuts = <DateTime>{
      if (overtimeStart != null && inside(overtimeStart)) overtimeStart,
      ..._offsetChanges(start, end, toLocal),
    };
    final last = toLocal(end).date;
    // A day either side covers boundaries that resolve across midnight.
    for (
      var date = _addDays(toLocal(start).date, -1);
      date.compareTo(_addDays(last, 1)) <= 0;
      date = _addDays(date, 1)
    ) {
      for (final minute in localMinutes) {
        cuts.addAll(toInstants(date, minute).map(_wholeSecond).where(inside));
      }
    }

    final points = [start, ...cuts.toList()..sort(), end];
    for (var index = 0; index < points.length - 1; index++) {
      final from = points[index];
      final local = toLocal(from);
      segments.add(
        PaySegment(
          startUtc: from,
          seconds: points[index + 1].difference(from).inSeconds,
          night:
              agreement.nightEnabled &&
              _inWindow(
                local.minuteOfDay,
                agreement.nightStartMinute,
                agreement.nightEndMinute,
              ),
          holiday: isPublicHoliday(agreement.holidayCalendar, local.date),
          overtime: overtimeStart != null && !from.isBefore(overtimeStart),
        ),
      );
    }
  }
  return List.unmodifiable(segments);
}

/// The combined multiplier of a segment's active premiums (spec 5.2), as a
/// reduced exact fraction.
RationalMultiplier segmentMultiplier(
  PaySegment segment,
  PayAgreement agreement,
) {
  final active = [
    if (segment.night) agreement.nightMultiplier,
    if (segment.holiday) agreement.holidayMultiplier,
    if (segment.overtime) agreement.overtimeMultiplier,
  ];
  if (active.isEmpty) {
    return const RationalMultiplier(numerator: 1, denominator: 1);
  }
  var numerator = BigInt.one;
  var denominator = BigInt.one;
  switch (agreement.premiumStacking) {
    case PremiumStacking.highest:
      final top = active.reduce(
        (a, b) =>
            a.numerator * b.denominator >= b.numerator * a.denominator ? a : b,
      );
      numerator = BigInt.from(top.numerator);
      denominator = BigInt.from(top.denominator);
    case PremiumStacking.additive:
      // 1 + Σ(m − 1), accumulated as n/d.
      for (final item in active) {
        final n = BigInt.from(item.numerator);
        final d = BigInt.from(item.denominator);
        numerator = numerator * d + (n - d) * denominator;
        denominator = denominator * d;
      }
    case PremiumStacking.multiplicative:
      for (final item in active) {
        numerator *= BigInt.from(item.numerator);
        denominator *= BigInt.from(item.denominator);
      }
  }
  final divisor = numerator.gcd(denominator);
  return RationalMultiplier(
    numerator: (numerator ~/ divisor).toInt(),
    denominator: (denominator ~/ divisor).toInt(),
  );
}

DateTime? _overtimeStart(
  List<({DateTime start, DateTime end})> intervals,
  int thresholdSeconds,
) {
  var remaining = thresholdSeconds;
  for (final (:start, :end) in intervals) {
    final seconds = end.difference(start).inSeconds;
    if (remaining < seconds) return start.add(Duration(seconds: remaining));
    remaining -= seconds;
    if (remaining == 0) return end;
  }
  return null;
}

/// Instants inside (start, end) where the zone's UTC offset changes, so a
/// repeated hour that re-enters the night window still gets its own segment.
Iterable<DateTime> _offsetChanges(
  DateTime start,
  DateTime end,
  ToLocal toLocal,
) sync* {
  int offset(DateTime utc) {
    final local = toLocal(utc);
    final wall = DateTime.utc(
      local.date.year,
      local.date.month,
      local.date.day,
    ).add(Duration(minutes: local.minuteOfDay));
    final minute = utc.subtract(Duration(seconds: utc.second));
    return wall.difference(minute).inMinutes;
  }

  var from = start;
  while (from.isBefore(end) && offset(from) != offset(end)) {
    var low = from;
    var high = end;
    final before = offset(low);
    while (high.difference(low).inSeconds > 1) {
      final middle = low.add(
        Duration(seconds: high.difference(low).inSeconds ~/ 2),
      );
      if (offset(middle) == before) {
        low = middle;
      } else {
        high = middle;
      }
    }
    if (high.isBefore(end)) yield high;
    from = high;
  }
}

bool _inWindow(int minute, int start, int end) => start < end
    ? minute >= start && minute < end
    : minute >= start || minute < end;

DateTime _wholeSecond(DateTime value) => value.subtract(
  Duration(microseconds: value.microsecondsSinceEpoch % 1000000),
);

LocalDate _addDays(LocalDate date, int days) {
  final value = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(value.year, value.month, value.day);
}
