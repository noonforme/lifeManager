import 'dart:math' as math;

import 'agreement.dart';
import 'facts.dart';
import 'pay_premiums.dart';

int roundHalfUpRatio(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) {
    throw ArgumentError.value(denominator, 'denominator');
  }
  final negative = numerator.isNegative;
  final absolute = numerator.abs();
  final rounded = (absolute + denominator ~/ BigInt.two) ~/ denominator;
  return (negative ? -rounded : rounded).toInt();
}

final class Money {
  const Money({
    required this.minorUnits,
    this.currency = const CurrencyCode.eur(),
  });

  final int minorUnits;
  final CurrencyCode currency;

  @override
  bool operator ==(Object other) =>
      other is Money &&
      minorUnits == other.minorUnits &&
      currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}

final class ExpectedPayInput {
  const ExpectedPayInput({
    required this.paidSeconds,
    required this.overtimeMinutes,
    required this.hourlyRateMicroEur,
    required this.multiplier,
    required this.currency,
  });

  final int paidSeconds;
  final int overtimeMinutes;
  final int hourlyRateMicroEur;
  final RationalMultiplier multiplier;
  final CurrencyCode currency;

  ExpectedPayInput copyWith({
    int? paidSeconds,
    int? overtimeMinutes,
    int? hourlyRateMicroEur,
    RationalMultiplier? multiplier,
    CurrencyCode? currency,
  }) {
    return ExpectedPayInput(
      paidSeconds: paidSeconds ?? this.paidSeconds,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      hourlyRateMicroEur: hourlyRateMicroEur ?? this.hourlyRateMicroEur,
      multiplier: multiplier ?? this.multiplier,
      currency: currency ?? this.currency,
    );
  }
}

/// Expected pay for one shift with its paid-time breakdown (spec 5.3). The
/// categories overlap, so they need not add up to [totalPaidSeconds];
/// [regularPaidSeconds] is paid time with no premium.
final class ExpectedPay {
  const ExpectedPay({
    required this.totalPaidSeconds,
    required this.nightPaidSeconds,
    required this.holidayPaidSeconds,
    required this.overtimePaidSeconds,
    required this.regularPaidSeconds,
    required this.amount,
  });

  final int totalPaidSeconds;
  final int nightPaidSeconds;
  final int holidayPaidSeconds;
  final int overtimePaidSeconds;
  final int regularPaidSeconds;
  final Money amount;
}

/// Σ(seconds × rate × multiplier) / 3600 over [segments], summed exactly and
/// rounded half-up once, at the end.
ExpectedPay calculateExpectedPay({
  required List<PaySegment> segments,
  required int hourlyRateMicroEur,
  required PayAgreement agreement,
  required CurrencyCode currency,
}) {
  if (segments.isEmpty || segments.any((item) => item.seconds <= 0)) {
    throw ArgumentError.value(segments, 'segments');
  }
  if (hourlyRateMicroEur <= 0) {
    throw ArgumentError.value(hourlyRateMicroEur, 'hourlyRateMicroEur');
  }
  var total = 0, night = 0, holiday = 0, overtime = 0, regular = 0;
  var numerator = BigInt.zero;
  var denominator = BigInt.one;
  for (final segment in segments) {
    total += segment.seconds;
    if (segment.night) night += segment.seconds;
    if (segment.holiday) holiday += segment.seconds;
    if (segment.overtime) overtime += segment.seconds;
    if (!segment.hasPremium) regular += segment.seconds;

    final multiplier = segmentMultiplier(segment, agreement);
    final d = BigInt.from(multiplier.denominator);
    numerator =
        numerator * d +
        BigInt.from(segment.seconds) *
            BigInt.from(multiplier.numerator) *
            denominator;
    denominator *= d;
    final divisor = numerator.gcd(denominator);
    numerator ~/= divisor;
    denominator ~/= divisor;
  }
  return ExpectedPay(
    totalPaidSeconds: total,
    nightPaidSeconds: night,
    holidayPaidSeconds: holiday,
    overtimePaidSeconds: overtime,
    regularPaidSeconds: regular,
    amount: Money(
      minorUnits: roundHalfUpRatio(
        numerator * BigInt.from(hourlyRateMicroEur),
        denominator * BigInt.from(3600 * 10000),
      ),
      currency: currency,
    ),
  );
}

/// Pay from manually entered overtime. Removed with manual overtime.
ExpectedPay calculateManualOvertimePay(ExpectedPayInput input) {
  if (input.paidSeconds <= 0) {
    throw ArgumentError.value(input.paidSeconds, 'paidSeconds');
  }
  if (input.overtimeMinutes < 0) {
    throw ArgumentError.value(input.overtimeMinutes, 'overtimeMinutes');
  }
  if (input.hourlyRateMicroEur <= 0) {
    throw ArgumentError.value(input.hourlyRateMicroEur, 'hourlyRateMicroEur');
  }

  final overtimeSeconds = input.overtimeMinutes * 60;
  if (overtimeSeconds > input.paidSeconds) {
    throw ArgumentError.value(input.overtimeMinutes, 'overtimeMinutes');
  }
  final regularSeconds = input.paidSeconds - overtimeSeconds;
  final rate = BigInt.from(input.hourlyRateMicroEur);
  final multiplierNumerator = BigInt.from(input.multiplier.numerator);
  final multiplierDenominator = BigInt.from(input.multiplier.denominator);
  final weightedSeconds =
      BigInt.from(regularSeconds) * multiplierDenominator +
      BigInt.from(overtimeSeconds) * multiplierNumerator;
  final numerator = rate * weightedSeconds;
  final denominator = BigInt.from(3600 * 10000) * multiplierDenominator;

  return ExpectedPay(
    totalPaidSeconds: input.paidSeconds,
    nightPaidSeconds: 0,
    holidayPaidSeconds: 0,
    regularPaidSeconds: regularSeconds,
    overtimePaidSeconds: overtimeSeconds,
    amount: Money(
      minorUnits: roundHalfUpRatio(numerator, denominator),
      currency: input.currency,
    ),
  );
}

int suggestedOvertimeMinutes({
  required int paidWholeMinutes,
  required PayAgreement agreement,
}) {
  if (paidWholeMinutes < 0) {
    throw ArgumentError.value(paidWholeMinutes, 'paidWholeMinutes');
  }
  return math.max(0, paidWholeMinutes - agreement.overtimeThresholdMinutes);
}
