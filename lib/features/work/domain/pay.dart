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

/// Paid time sharing one set of premiums, and the multiplier they stack to.
final class PayGroup {
  const PayGroup({
    required this.night,
    required this.holiday,
    required this.overtime,
    required this.seconds,
    required this.multiplier,
  });

  final bool night;
  final bool holiday;
  final bool overtime;
  final int seconds;
  final RationalMultiplier multiplier;

  bool get isRegular => !night && !holiday && !overtime;
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
    this.groups = const [],
  });

  final int totalPaidSeconds;
  final int nightPaidSeconds;
  final int holidayPaidSeconds;
  final int overtimePaidSeconds;
  final int regularPaidSeconds;
  final Money amount;

  /// The paid time by premium combination, regular first; together the
  /// groups add up to [totalPaidSeconds] and give [amount].
  final List<PayGroup> groups;
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
  final grouped = <(bool, bool, bool), PayGroup>{};
  for (final segment in segments) {
    final key = (segment.night, segment.holiday, segment.overtime);
    final multiplier = segmentMultiplier(segment, agreement);
    final previous = grouped[key];
    grouped[key] = PayGroup(
      night: segment.night,
      holiday: segment.holiday,
      overtime: segment.overtime,
      seconds: (previous?.seconds ?? 0) + segment.seconds,
      multiplier: multiplier,
    );

    total += segment.seconds;
    if (segment.night) night += segment.seconds;
    if (segment.holiday) holiday += segment.seconds;
    if (segment.overtime) overtime += segment.seconds;
    if (!segment.hasPremium) regular += segment.seconds;

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
    groups: List.unmodifiable(
      grouped.values.toList()..sort((a, b) => _order(a).compareTo(_order(b))),
    ),
  );
}

/// Regular, then night, holiday and overtime, then their combinations.
int _order(PayGroup group) {
  final flags = [group.night, group.holiday, group.overtime];
  final count = flags.where((flag) => flag).length;
  return count * 8 +
      (group.overtime ? 4 : 0) +
      (group.holiday ? 2 : 0) +
      (group.night ? 1 : 0);
}
