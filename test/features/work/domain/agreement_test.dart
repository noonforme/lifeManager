import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  test('resolves the sole inclusive agreement at local start date', () {
    final item = agreement(
      start: LocalDate.parse('2026-09-01'),
      end: LocalDate.parse('2026-09-30'),
    );

    final result = resolveAgreement(
      employmentId: item.employmentId,
      localStartDate: LocalDate.parse('2026-09-30'),
      agreements: [item],
    );

    expect(result, isA<ResolvedAgreement>());
  });

  test('allows adjacent ranges and rejects inclusive overlap', () {
    expect(
      validateAgreementSet([
        agreement(
          start: LocalDate.parse('2026-09-01'),
          end: LocalDate.parse('2026-09-15'),
        ),
        agreement(version: 2, start: LocalDate.parse('2026-09-16'), end: null),
      ]).isValid,
      isTrue,
    );
    expect(
      validateAgreementSet([
        agreement(
          start: LocalDate.parse('2026-09-01'),
          end: LocalDate.parse('2026-09-15'),
        ),
        agreement(version: 2, start: LocalDate.parse('2026-09-15'), end: null),
      ]).issues.single.code,
      'agreement.rangeOverlap',
    );
  });

  test('distinguishes foreign, missing, and ambiguous agreement', () {
    const requested = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
    expect(
      resolveAgreement(
        employmentId: requested,
        localStartDate: LocalDate.parse('2026-09-10'),
        agreements: [
          agreement(
            employmentId: const EmploymentId(
              '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c12',
            ),
          ),
        ],
      ),
      isA<ForeignAgreement>(),
    );
    expect(
      resolveAgreement(
        employmentId: requested,
        localStartDate: LocalDate.parse('2025-09-10'),
        agreements: [agreement()],
      ),
      isA<MissingAgreement>(),
    );
    expect(
      resolveAgreement(
        employmentId: requested,
        localStartDate: LocalDate.parse('2026-09-10'),
        agreements: [agreement(), agreement(version: 2)],
      ),
      isA<AmbiguousAgreement>(),
    );
  });

  test('used agreement cannot be edited but unused can close safely', () {
    final used = agreement(usedByFinalizedShift: true);
    expect(
      () => used.withRangeEnd(LocalDate.parse('2026-09-15')),
      throwsStateError,
    );
    expect(
      agreement().withRangeEnd(LocalDate.parse('2026-09-15')).effectiveEnd,
      LocalDate.parse('2026-09-15'),
    );
  });

  test('agreement rejects invalid factual values', () {
    expect(() => agreement(rate: 0), throwsArgumentError);
    expect(() => agreement(thresholdMinutes: 0), throwsArgumentError);
    expect(
      () => agreement(
        start: LocalDate.parse('2026-09-10'),
        end: LocalDate.parse('2026-09-09'),
      ),
      throwsArgumentError,
    );
  });
}

PayAgreement agreement({
  EmploymentId employmentId = const EmploymentId(
    '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
  ),
  int version = 1,
  LocalDate? start,
  LocalDate? end,
  int rate = 20000000,
  int thresholdMinutes = 480,
  bool usedByFinalizedShift = false,
}) {
  return PayAgreement(
    id: AgreementId(
      version == 1
          ? '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'
          : '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22',
    ),
    employmentId: employmentId,
    version: version,
    effectiveStart: start ?? LocalDate.parse('2026-09-01'),
    effectiveEnd: end,
    hourlyRateMicroEur: rate,
    basis: const GrossBasis(),
    overtimeThresholdMinutes: thresholdMinutes,
    overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
    label: null,
    note: null,
    createdAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
    usedByFinalizedShift: usedByFinalizedShift,
  );
}
