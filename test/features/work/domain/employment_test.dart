import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  const id = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

  test('employment trims required name and factual optional label', () {
    final result = Employment.create(
      id: id,
      name: '  North Dock  ',
      legalLabel: '  Dock Works Ltd  ',
      nowUtc: DateTime.utc(2026, 9, 29),
    );

    expect(result.name, 'North Dock');
    expect(result.legalLabel, 'Dock Works Ltd');
    expect(result.status, EmploymentStatus.active);
    expect(result.revision, const Revision(0));
    expect(result.createdAtUtc, DateTime.utc(2026, 9, 29));
    expect(result.updatedAtUtc, DateTime.utc(2026, 9, 29));
  });

  test('employment rejects an empty trimmed name and non-UTC time', () {
    expect(
      () => Employment.create(
        id: id,
        name: '  ',
        legalLabel: null,
        nowUtc: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => Employment.create(
        id: id,
        name: 'Synthetic work',
        legalLabel: null,
        nowUtc: DateTime(2026),
      ),
      throwsArgumentError,
    );
  });

  test('archive returns a higher-revision immutable copy', () {
    final original = Employment.create(
      id: id,
      name: 'Synthetic work',
      legalLabel: null,
      nowUtc: DateTime.utc(2026, 1, 1),
    );

    final archived = original.archive(nowUtc: DateTime.utc(2026, 2, 1));

    expect(original.status, EmploymentStatus.active);
    expect(archived.status, EmploymentStatus.archived);
    expect(archived.revision, const Revision(1));
    expect(archived.updatedAtUtc, DateTime.utc(2026, 2, 1));
  });
}
