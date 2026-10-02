import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/domain/pay.dart';

void main() {
  test('rounds a positive half cent upward using integer arithmetic', () {
    expect(roundHalfUpRatio(BigInt.from(15000), BigInt.from(10000)), 2);
    expect(roundHalfUpRatio(BigInt.from(14999), BigInt.from(10000)), 1);
  });

  test(
    'rounds negative values symmetrically and rejects invalid denominator',
    () {
      expect(roundHalfUpRatio(BigInt.from(-15000), BigInt.from(10000)), -2);
      expect(
        () => roundHalfUpRatio(BigInt.one, BigInt.zero),
        throwsArgumentError,
      );
    },
  );

  test('money has value equality for projection grouping', () {
    expect(const Money(minorUnits: 1200), const Money(minorUnits: 1200));
  });
}
