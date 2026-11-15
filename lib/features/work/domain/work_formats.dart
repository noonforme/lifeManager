import 'agreement.dart';
import 'pay.dart';

/// Formats shared by Work cells and their formula-bar explanations, so an
/// explanation's result always reads exactly like its cell.

/// "EUR 1219.00", or "EUR -27.60".
String formatMoney(Money money) {
  final negative = money.minorUnits < 0;
  final absolute = money.minorUnits.abs();
  final major = absolute ~/ 100;
  final minor = absolute.remainder(100).toString().padLeft(2, '0');
  return '${money.currency.value} ${negative ? '-' : ''}$major.$minor';
}

/// Whole minutes as "h:mm", for example 29700 seconds as "8:15".
String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

/// An hourly rate in micro-euros as "18.40/h", keeping any extra precision
/// the agreement records.
String formatHourlyRate(int microEur) {
  final whole = microEur ~/ 1000000;
  var fraction = (microEur % 1000000).toString().padLeft(6, '0');
  while (fraction.length > 2 && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  return '$whole.$fraction/h';
}

/// A rational multiplier as a decimal when it terminates within three
/// places ("1.5"), otherwise as a fraction ("4/3").
String formatMultiplier(RationalMultiplier value) {
  for (final scale in [1, 10, 100, 1000]) {
    if ((value.numerator * scale) % value.denominator == 0) {
      final scaled = value.numerator * scale ~/ value.denominator;
      if (scale == 1) return '$scaled';
      final digits = scale.toString().length - 1;
      final text = scaled.toString().padLeft(digits + 1, '0');
      var decimals = text.substring(text.length - digits);
      while (decimals.endsWith('0')) {
        decimals = decimals.substring(0, decimals.length - 1);
      }
      final integer = text.substring(0, text.length - digits);
      return decimals.isEmpty ? integer : '$integer.$decimals';
    }
  }
  return '${value.numerator}/${value.denominator}';
}

/// A decimal multiplier of at most three places, as an exact fraction; null
/// when it is unparseable or below 1. "1.5" or "1,5" is 3/2.
RationalMultiplier? parseMultiplier(String text) {
  final match = RegExp(r'^(\d+)(?:[.,](\d{1,3}))?$').firstMatch(text.trim());
  if (match == null) return null;
  final decimals = match.group(2) ?? '';
  var denominator = 1;
  for (var i = 0; i < decimals.length; i++) {
    denominator *= 10;
  }
  final numerator = int.parse('${match.group(1)}$decimals');
  if (numerator < denominator) return null;
  final divisor = numerator.gcd(denominator);
  return RationalMultiplier(
    numerator: numerator ~/ divisor,
    denominator: denominator ~/ divisor,
  );
}

/// Decimal hours as whole minutes ("7.5" or "7,5" is 450); null unless
/// above zero.
int? parseHoursAsMinutes(String text) {
  final match = RegExp(r'^(\d+)(?:[.,](\d{1,2}))?$').firstMatch(text.trim());
  if (match == null) return null;
  final hundredths =
      int.parse(match.group(1)!) * 100 +
      int.parse((match.group(2) ?? '').padRight(2, '0'));
  final minutes = (hundredths * 60 + 50) ~/ 100;
  return minutes > 0 ? minutes : null;
}

/// A percent with up to two decimals, such as "62.06", as an exact
/// fraction of 1; null unless above zero.
RationalMultiplier? parsePercent(String text) {
  final match = RegExp(r'^(\d+)(?:[.,](\d{1,2}))?$').firstMatch(text.trim());
  if (match == null) return null;
  final decimals = match.group(2) ?? '';
  final numerator = int.parse('${match.group(1)}$decimals');
  if (numerator <= 0) return null;
  var denominator = 100;
  for (var i = 0; i < decimals.length; i++) {
    denominator *= 10;
  }
  final divisor = numerator.gcd(denominator);
  return RationalMultiplier(
    numerator: numerator ~/ divisor,
    denominator: denominator ~/ divisor,
  );
}

/// A fraction of 1 as a percent with up to two decimals: 3103/5000 is
/// "62.06".
String formatPercent(RationalMultiplier value) {
  final hundredths =
      (value.numerator * 10000 + value.denominator ~/ 2) ~/ value.denominator;
  final whole = hundredths ~/ 100;
  final fraction = hundredths % 100;
  if (fraction == 0) return '$whole';
  final text = fraction.toString().padLeft(2, '0');
  return '$whole.${text.endsWith('0') ? text[0] : text}';
}

String formatClock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

/// Minutes as decimal hours: 480 is "8", 450 is "7.5".
String formatHours(int minutes) {
  if (minutes % 60 == 0) return '${minutes ~/ 60}';
  final hundredths = (minutes * 100 + 30) ~/ 60;
  var text =
      '${hundredths ~/ 100}.${(hundredths % 100).toString().padLeft(2, '0')}';
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// [text] as an hourly rate in micro-euros: "18.40", "18,4", "18", ".5"
/// or "18."; null when it is not one.
int? parseHourlyRate(String text) {
  final match = RegExp(r'^(\d{0,9})(?:[.,](\d{0,6}))?$')
      .firstMatch(text.trim());
  if (match == null) return null;
  final whole = match.group(1)!;
  final fraction = match.group(2) ?? '';
  if (whole.isEmpty && fraction.isEmpty) return null;
  return int.parse(whole.isEmpty ? '0' : whole) * 1000000 +
      int.parse(fraction.padRight(6, '0'));
}
