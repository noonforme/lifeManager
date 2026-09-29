import 'dart:math' as math;

import 'agreement.dart';
import 'facts.dart';

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

final class ExpectedPay {
  const ExpectedPay({
    required this.regularPaidSeconds,
    required this.overtimePaidSeconds,
    required this.amount,
  });

  final int regularPaidSeconds;
  final int overtimePaidSeconds;
  final Money amount;
}

ExpectedPay calculateExpectedPay(ExpectedPayInput input) {
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
