import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  test('finalizes only a closed non-overlapping break set within bounds', () {
    final outcome = validateFinalization(
      shift: candidate(),
      breaks: [closedBreak('2026-10-26T08:30:00Z', '2026-10-26T09:00:00Z')],
      agreements: [effectiveAgreement()],
    );

    expect(outcome.isValid, isTrue);
    expect(outcome.facts!.shift.state, ShiftState.finalized);
    expect(outcome.facts!.shift.agreementId, effectiveAgreement().id);
    expect(outcome.facts!.paidSeconds, 12600);
  });

  test('rejects open, overlapping, and out-of-bounds break sets', () {
    final cases = <List<ShiftBreak>>[
      [shiftBreak(start: '2026-10-26T08:30:00Z', end: null)],
      [
        closedBreak('2026-10-26T08:30:00Z', '2026-10-26T09:00:00Z'),
        closedBreak('2026-10-26T08:45:00Z', '2026-10-26T09:15:00Z'),
      ],
      [closedBreak('2026-10-26T07:30:00Z', '2026-10-26T08:15:00Z')],
    ];

    for (final breaks in cases) {
      expect(
        validateFinalization(
          shift: candidate(),
          breaks: breaks,
          agreements: [effectiveAgreement()],
        ).isValid,
        isFalse,
      );
    }
  });

  test('rejects zero-length breaks when factual values are constructed', () {
    expect(
      () => shiftBreak(
        start: '2026-10-26T08:30:00Z',
        end: '2026-10-26T08:30:00Z',
      ),
      throwsArgumentError,
    );
  });

  test('uses UTC elapsed through DST fold and captured date for agreement', () {
    final outcome = validateFinalization(
      shift: candidate(
        start: '2026-10-25T00:30:00Z',
        end: '2026-10-25T03:30:00Z',
        localStart: '2026-10-25',
      ),
      breaks: const [],
      agreements: [effectiveAgreement(start: '2026-10-25')],
    );

    expect(outcome.facts!.shift.elapsedSeconds, 10800);
    expect(
      outcome.facts!.agreement.effectiveStart,
      LocalDate.parse('2026-10-25'),
    );
  });

  test('attributes a cross-midnight shift wholly to captured start date', () {
    final result = validateFinalization(
      shift: candidate(
        start: '2026-09-30T21:00:00Z',
        end: '2026-10-01T05:00:00Z',
        localStart: '2026-09-30',
      ),
      breaks: const [],
      agreements: [
        effectiveAgreement(start: '2026-09-01', end: '2026-09-30'),
        effectiveAgreement(version: 2, start: '2026-10-01'),
      ],
    );

    expect(result.facts!.agreement.version, 1);
  });

  test('rejects missing and ambiguous agreement resolution', () {
    expect(
      validateFinalization(
        shift: candidate(),
        breaks: const [],
        agreements: const [],
      ).issues.single.code,
      contains('MissingAgreement'),
    );
    expect(
      validateFinalization(
        shift: candidate(),
        breaks: const [],
        agreements: [effectiveAgreement(), effectiveAgreement(version: 2)],
      ).issues.single.code,
      contains('AmbiguousAgreement'),
    );
  });

  test(
    'rejects nonpositive paid duration and overtime beyond whole minutes',
    () {
      final allBreak = closedBreak(
        '2026-10-26T08:00:00Z',
        '2026-10-26T12:00:00Z',
      );
      expect(
        validateFinalization(
          shift: candidate(),
          breaks: [allBreak],
          agreements: [effectiveAgreement()],
        ).issues.map((issue) => issue.code),
        contains('shift.paidDurationNotPositive'),
      );
      expect(
        validateFinalization(
          shift: candidate(overtimeMinutes: 241),
          breaks: const [],
          agreements: [effectiveAgreement()],
        ).issues.map((issue) => issue.code),
        contains('shift.overtimeExceedsPaidMinutes'),
      );
    },
  );

  test('finalization facts convert to exact expected-pay input', () {
    final facts = validateFinalization(
      shift: candidate(overtimeMinutes: 30),
      breaks: const [],
      agreements: [effectiveAgreement()],
    ).facts!;

    final input = facts.toExpectedPayInput();
    expect(input.paidSeconds, 14400);
    expect(input.overtimeMinutes, 30);
    expect(input.hourlyRateMicroEur, 20000000);
  });
}

WorkShift candidate({
  String start = '2026-10-26T08:00:00Z',
  String? end = '2026-10-26T12:00:00Z',
  String localStart = '2026-10-26',
  int overtimeMinutes = 0,
}) {
  return WorkShift(
    id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
    employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
    agreementId: null,
    state: ShiftState.draft,
    startUtc: DateTime.parse(start),
    endUtc: end == null ? null : DateTime.parse(end),
    timezoneId: 'Europe/Berlin',
    localStartDate: LocalDate.parse(localStart),
    overtimeMinutes: overtimeMinutes,
    note: null,
    voidReason: null,
    replacementShiftId: null,
    replacedShiftId: null,
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
  );
}

ShiftBreak closedBreak(String start, String end) =>
    shiftBreak(start: start, end: end);

ShiftBreak shiftBreak({required String start, required String? end}) {
  return ShiftBreak(
    id: const ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c41'),
    shiftId: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
    startUtc: DateTime.parse(start),
    endUtc: end == null ? null : DateTime.parse(end),
    createdAtUtc: DateTime.utc(2026),
    updatedAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
  );
}

PayAgreement effectiveAgreement({
  int version = 1,
  String start = '2026-10-01',
  String? end,
}) {
  return PayAgreement(
    id: AgreementId(
      version == 1
          ? '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'
          : '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22',
    ),
    employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
    version: version,
    effectiveStart: LocalDate.parse(start),
    effectiveEnd: end == null ? null : LocalDate.parse(end),
    hourlyRateMicroEur: 20000000,
    basis: const GrossBasis(),
    overtimeThresholdMinutes: 480,
    overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
    label: null,
    note: null,
    createdAtUtc: DateTime.utc(2026),
    revision: const Revision(0),
    usedByFinalizedShift: false,
  );
}
