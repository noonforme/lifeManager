import '../domain/agreement.dart';
import '../domain/pay.dart';

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
