import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  test('typed IDs preserve a UUIDv7 value without cross-type equality', () {
    const raw = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11';
    expect(const EmploymentId(raw).value, raw);
    expect(const EmploymentId(raw), isNot(const AgreementId(raw)));
  });

  test('tryParse accepts canonical UUIDv7 and rejects other values', () {
    const raw = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11';
    expect(EmploymentId.tryParse(raw), const EmploymentId(raw));
    expect(EmploymentId.tryParse(raw.toUpperCase()), isNull);
    expect(
      EmploymentId.tryParse('018f0f9a-7d03-4e6a-8b0c-3d2e1f0a4c11'),
      isNull,
    );
    expect(EmploymentId.tryParse(null), isNull);
  });

  test('currency is EUR and revisions are non-negative', () {
    expect(const CurrencyCode.eur().value, 'EUR');
    expect(() => Revision(-1), throwsA(isA<AssertionError>()));
    expect(const Revision(2), const Revision(2));
    expect(const GrossBasis(), const GrossBasis());
    expect(const GrossBasis(), isNot(const NetBasis()));
  });
}
