import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/domain/agreement.dart'
    show RationalMultiplier;
import 'package:lifeos/features/work/domain/work_formats.dart';

void main() {
  test('a multiplier takes a decimal point or comma', () {
    const half = RationalMultiplier(numerator: 3, denominator: 2);
    expect(parseMultiplier('1.5'), half);
    expect(parseMultiplier('1,5'), half);
    expect(
      parseMultiplier(' 2 '),
      const RationalMultiplier(numerator: 2, denominator: 1),
    );
    expect(parseMultiplier('0,5'), isNull);
    expect(parseMultiplier('1,5,0'), isNull);
  });

  test('hours take a decimal point or comma', () {
    expect(parseHoursAsMinutes('7.5'), 450);
    expect(parseHoursAsMinutes('7,5'), 450);
    expect(parseHoursAsMinutes('0'), isNull);
  });

  test('a percent takes a decimal point or comma', () {
    expect(parsePercent('62,06'), parsePercent('62.06'));
  });
}
