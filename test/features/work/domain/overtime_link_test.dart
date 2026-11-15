import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../../support/zone_clocks.dart';

void main() {
  WorkShift shift({ScheduleLink? link, required DateTime end}) => WorkShift(
    id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
    employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
    agreementId: null,
    state: ShiftState.draft,
    startUtc: DateTime.utc(2026, 9, 15, 4), // 07:00 Vilnius
    endUtc: end,
    timezoneId: 'Europe/Vilnius',
    localStartDate: const LocalDate(2026, 9, 15),
    note: null,
    voidReason: null,
    replacementShiftId: null,
    replacedShiftId: null,
    createdAtUtc: DateTime.utc(2026, 9, 15),
    updatedAtUtc: DateTime.utc(2026, 9, 15),
    revision: const Revision(0),
    schedule: link,
  );

  ExpectedPay pay(WorkShift value) {
    final facts = validateFinalization(
      shift: value,
      breaks: const [],
      agreements: [agreement()],
    ).facts!;
    final clock = testZoneClocks(value.timezoneId);
    return facts.expectedPay(
      toLocal: clock.toLocal,
      toInstants: clock.toInstants,
    );
  }

  final link = ScheduleLink(
    scheduleId: const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d01'),
    scheduleVersion: 1,
    plannedDate: const LocalDate(2026, 9, 15),
    plannedStartUtc: DateTime.utc(2026, 9, 15, 4),
    plannedEndUtc: DateTime.utc(2026, 9, 15, 16), // 19:00
  );

  test('a scheduled 12-hour shift worked as planned has no overtime', () {
    expect(
      pay(shift(link: link, end: DateTime.utc(2026, 9, 15, 16)))
          .overtimePaidSeconds,
      0,
    );
  });

  test('a scheduled shift run 45 minutes late has 45 minutes of overtime', () {
    expect(
      pay(shift(link: link, end: DateTime.utc(2026, 9, 15, 16, 45)))
          .overtimePaidSeconds,
      45 * 60,
    );
  });

  test('an unscheduled 12-hour shift keeps the 8-hour threshold', () {
    expect(
      pay(shift(end: DateTime.utc(2026, 9, 15, 16))).overtimePaidSeconds,
      4 * 3600,
    );
  });

  ScheduleLink extra({required bool overtime}) => ScheduleLink(
    scheduleId: link.scheduleId,
    scheduleVersion: 1,
    plannedDate: link.plannedDate,
    plannedStartUtc: link.plannedStartUtc,
    plannedEndUtc: link.plannedEndUtc,
    isExtra: true,
    extraCountsAsOvertime: overtime,
  );

  test('an extra shift marked as overtime is overtime throughout', () {
    expect(
      pay(
        shift(link: extra(overtime: true), end: DateTime.utc(2026, 9, 15, 10)),
      ).overtimePaidSeconds,
      6 * 3600,
    );
  });

  test('an extra shift not marked as overtime has none, even past 8 hours', () {
    expect(
      pay(
        shift(link: extra(overtime: false), end: DateTime.utc(2026, 9, 15, 16)),
      ).overtimePaidSeconds,
      0,
    );
  });

  test('the link survives finalizing and correction', () {
    final finalized = shift(
      link: link,
      end: DateTime.utc(2026, 9, 15, 16),
    ).finalizedWith(agreement());
    expect(finalized.schedule, link);
    expect(
      finalized
          .replacementDraft(
            replacementId: const ShiftId(
              '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32',
            ),
            nowUtc: DateTime.utc(2026, 9, 16),
          )
          .schedule,
      link,
    );
  });
}

PayAgreement agreement() => PayAgreement(
  id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  version: 1,
  effectiveStart: const LocalDate(2026, 1, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 18400000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
