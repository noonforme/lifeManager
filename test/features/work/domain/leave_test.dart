import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/features/work/domain/pay.dart';

void main() {
  test('vacation pays the 3-month average hourly earnings in full', () {
    final priced = priceLeave(
      leave: [leaveOn(const LocalDate(2026, 10, 7), LeaveType.vacation)],
      worked: [
        // July–September: 100 h earning EUR 2,500.00 → EUR 25.00 an hour.
        WorkedPay(
          date: const LocalDate(2026, 7, 10),
          paidSeconds: 60 * 3600,
          pay: const Money(minorUnits: 150000),
        ),
        WorkedPay(
          date: const LocalDate(2026, 9, 30),
          paidSeconds: 40 * 3600,
          pay: const Money(minorUnits: 100000),
        ),
        // October and June are outside the window.
        WorkedPay(
          date: const LocalDate(2026, 10, 1),
          paidSeconds: 10 * 3600,
          pay: const Money(minorUnits: 99900),
        ),
        WorkedPay(
          date: const LocalDate(2026, 6, 30),
          paidSeconds: 10 * 3600,
          pay: const Money(minorUnits: 99900),
        ),
      ],
      agreements: [agreement()],
    );
    final pay = priced.values.single;
    // 11:30 × EUR 25.00.
    expect(pay.amount.minorUnits, 28750);
    expect(pay.usedFallback, isFalse);
  });

  test('with no work in the window the agreement rate is used, and said', () {
    final pay = priceLeave(
      leave: [leaveOn(const LocalDate(2026, 10, 7), LeaveType.vacation)],
      worked: const [],
      agreements: [agreement()],
    ).values.single;
    expect(pay.usedFallback, isTrue);
    // 11:30 × EUR 18.40.
    expect(pay.amount.minorUnits, 21160);
  });

  test('sick leave pays 62.06 % for the first two days of an illness only', () {
    final worked = [
      WorkedPay(
        date: const LocalDate(2026, 9, 1),
        paidSeconds: 100 * 3600,
        pay: const Money(minorUnits: 250000),
      ),
    ];
    final priced = priceLeave(
      leave: [
        leaveOn(
          const LocalDate(2026, 10, 5),
          LeaveType.sick,
          illness: const LocalDate(2026, 10, 4),
          id: 'a',
        ),
        leaveOn(
          const LocalDate(2026, 10, 6),
          LeaveType.sick,
          illness: const LocalDate(2026, 10, 4),
          id: 'b',
        ),
      ],
      worked: worked,
      agreements: [agreement()],
    );
    // Day 2 of the illness: 11:30 × 25.00 × 0.6206 = 178.4225 → 178.42.
    expect(priced[id('a')]!.amount.minorUnits, 17842);
    expect(priced[id('a')]!.employerPaid, isTrue);
    // Day 3: paid by the social insurer, not on the payslip.
    expect(priced[id('b')]!.amount.minorUnits, 0);
    expect(priced[id('b')]!.employerPaid, isFalse);
  });

  test('an illness starts at the first sick day, across Off days only', () {
    final sick = {
      const LocalDate(2026, 10, 1),
      const LocalDate(2026, 10, 2),
      const LocalDate(2026, 10, 7),
    };
    final off = {for (var d = 3; d <= 6; d++) LocalDate(2026, 10, d)};
    expect(
      defaultIllnessStart(
        const LocalDate(2026, 10, 7),
        isSick: sick.contains,
        isOff: off.contains,
      ),
      const LocalDate(2026, 10, 1),
    );
    // A worked day in between ends the run.
    expect(
      defaultIllnessStart(
        const LocalDate(2026, 10, 7),
        isSick: sick.contains,
        isOff: (date) =>
            off.contains(date) && date != const LocalDate(2026, 10, 4),
      ),
      const LocalDate(2026, 10, 7),
    );
  });
}

LeaveRecordId id(String suffix) =>
    LeaveRecordId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4f0$suffix');

LeaveRecord leaveOn(
  LocalDate date,
  LeaveType type, {
  LocalDate? illness,
  String id = '1',
}) => LeaveRecord(
  id: LeaveRecordId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4f0$id'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  date: date,
  leaveType: type,
  illnessStartedOn: illness,
  paidMinutes: 11 * 60 + 30,
  agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  scheduleId: const ScheduleId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4d01'),
  scheduleVersion: 1,
  state: LeaveState.confirmed,
  voidReason: null,
  replacementId: null,
  replacedId: null,
  createdAtUtc: DateTime.utc(2026, 10),
  updatedAtUtc: DateTime.utc(2026, 10),
  revision: const Revision(0),
);

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
