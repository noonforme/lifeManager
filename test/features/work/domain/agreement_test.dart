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
  group('premium fields', () {
    test('a new agreement carries the Labour Code defaults', () {
      final value = PayAgreement(
        id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
        employmentId: const EmploymentId(
          '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
        ),
        version: 1,
        effectiveStart: LocalDate.parse('2026-09-01'),
        effectiveEnd: null,
        hourlyRateMicroEur: 18400000,
        basis: const GrossBasis(),
        overtimeThresholdMinutes: AgreementDefaults.overtimeThresholdMinutes,
        overtimeMultiplier: AgreementDefaults.overtimeMultiplier,
        label: null,
        note: null,
        createdAtUtc: DateTime.utc(2026),
        revision: const Revision(0),
        usedByFinalizedShift: false,
      );
      expect(value.nightEnabled, isTrue);
      expect(value.nightStartMinute, 22 * 60);
      expect(value.nightEndMinute, 6 * 60);
      expect(
        value.nightMultiplier,
        const RationalMultiplier(numerator: 3, denominator: 2),
      );
      expect(value.holidayCalendar, HolidayCalendar.lithuania);
      expect(
        value.holidayMultiplier,
        const RationalMultiplier(numerator: 2, denominator: 1),
      );
      expect(value.premiumStacking, PremiumStacking.highest);
    });

    test('every multiplier must be at least ×1', () {
      const half = RationalMultiplier(numerator: 1, denominator: 2);
      expect(() => agreement(overtime: half), throwsArgumentError);
      expect(() => agreement(night: half), throwsArgumentError);
      expect(() => agreement(holiday: half), throwsArgumentError);
      const one = RationalMultiplier(numerator: 1, denominator: 1);
      expect(agreement(overtime: one, night: one, holiday: one), isNotNull);
    });

    test('the night window stays within a day and must not be empty', () {
      expect(() => agreement(nightStart: -1), throwsArgumentError);
      expect(() => agreement(nightEnd: 1440), throwsArgumentError);
      expect(
        () => agreement(nightStart: 600, nightEnd: 600),
        throwsArgumentError,
      );
    });

    test('a switched-off window is kept so it can be switched back on', () {
      final off = agreement(nightEnabled: false, nightStart: 1260);
      expect(off.nightEnabled, isFalse);
      expect(off.nightStartMinute, 1260);
    });

    test('closing an unused agreement keeps its premiums', () {
      final value = agreement(
        nightEnabled: false,
        nightStart: 1260,
        night: const RationalMultiplier(numerator: 5, denominator: 4),
      );
      final closed = value.withRangeEnd(LocalDate.parse('2026-12-31'));
      expect(closed.nightEnabled, isFalse);
      expect(closed.nightStartMinute, 1260);
      expect(closed.nightMultiplier, value.nightMultiplier);
      expect(closed.holidayMultiplier, value.holidayMultiplier);
      expect(closed.premiumStacking, value.premiumStacking);
    });
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
  RationalMultiplier overtime = const RationalMultiplier(
    numerator: 3,
    denominator: 2,
  ),
  bool nightEnabled = true,
  int nightStart = 1320,
  int nightEnd = 360,
  RationalMultiplier night = const RationalMultiplier(
    numerator: 3,
    denominator: 2,
  ),
  RationalMultiplier holiday = const RationalMultiplier(
    numerator: 2,
    denominator: 1,
  ),
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
    overtimeMultiplier: overtime,
    label: null,
    note: null,
    createdAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
    usedByFinalizedShift: usedByFinalizedShift,
    nightEnabled: nightEnabled,
    nightStartMinute: nightStart,
    nightEndMinute: nightEnd,
    nightMultiplier: night,
    holidayMultiplier: holiday,
  );
}
