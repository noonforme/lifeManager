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
          basis: const GrossBasis(),
        ),
        WorkedPay(
          date: const LocalDate(2026, 9, 30),
          paidSeconds: 40 * 3600,
          pay: const Money(minorUnits: 100000),
          basis: const GrossBasis(),
        ),
        // October and June are outside the window.
        WorkedPay(
          date: const LocalDate(2026, 10, 1),
          paidSeconds: 10 * 3600,
          pay: const Money(minorUnits: 99900),
          basis: const GrossBasis(),
        ),
        WorkedPay(
          date: const LocalDate(2026, 6, 30),
          paidSeconds: 10 * 3600,
          pay: const Money(minorUnits: 99900),
          basis: const GrossBasis(),
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

  test('net leave averages only net pay; gross history is left out', () {
    // Audit 9pk.4.34: 8 h gross at EUR 18.40 in September, then net
    // EUR 10.00 from October 1.
    final gross = WorkedPay(
      date: const LocalDate(2026, 9, 15),
      paidSeconds: 8 * 3600,
      pay: const Money(minorUnits: 14720),
      basis: const GrossBasis(),
    );
    final alone = priceLeave(
      leave: [leaveOn(const LocalDate(2026, 10, 6), LeaveType.vacation)],
      worked: [gross],
      agreements: [agreement(basis: const NetBasis(), rate: 10000000)],
    ).values.single;
    // 11:30 × the net agreement rate EUR 10.00, never × EUR 18.40.
    expect(alone.amount.minorUnits, 11500);
    expect(alone.usedFallback, isTrue);
    expect(alone.otherBasisLeftOut, isTrue);
    expect(alone.basis, const NetBasis());

    final mixed = priceLeave(
      leave: [leaveOn(const LocalDate(2026, 10, 6), LeaveType.vacation)],
      worked: [
        gross,
        WorkedPay(
          date: const LocalDate(2026, 9, 20),
          paidSeconds: 10 * 3600,
          pay: const Money(minorUnits: 12000),
          basis: const NetBasis(),
        ),
      ],
      agreements: [agreement(basis: const NetBasis(), rate: 10000000)],
    ).values.single;
    // The net days alone: EUR 120.00 / 10 h = EUR 12.00 × 11:30.
    expect(mixed.amount.minorUnits, 13800);
    expect(mixed.usedFallback, isFalse);
    expect(mixed.average, (minorUnits: 12000, paidSeconds: 10 * 3600));
    expect(mixed.otherBasisLeftOut, isTrue);
  });

  test('gross leave leaves out net work and earlier net leave', () {
    final net = agreement(basis: const NetBasis(), rate: 10000000);
    final gross = agreement(id: 'gross', from: const LocalDate(2026, 11, 1));
    final priced = priceLeave(
      leave: [
        leaveOn(const LocalDate(2026, 10, 6), LeaveType.vacation, id: 'a'),
        leaveOn(
          const LocalDate(2026, 11, 6),
          LeaveType.vacation,
          id: 'b',
          agreementId: gross.id,
        ),
      ],
      worked: [
        WorkedPay(
          date: const LocalDate(2026, 9, 15),
          paidSeconds: 8 * 3600,
          pay: const Money(minorUnits: 9600),
          basis: const NetBasis(),
        ),
        WorkedPay(
          date: const LocalDate(2026, 10, 15),
          paidSeconds: 10 * 3600,
          pay: const Money(minorUnits: 25000),
          basis: const GrossBasis(),
        ),
      ],
      agreements: [net, gross],
    );
    // October's net leave averages September's net EUR 12.00.
    expect(priced[id('a')]!.amount.minorUnits, 13800);
    expect(priced[id('a')]!.otherBasisLeftOut, isFalse);
    // November's gross leave averages only October's gross EUR 25.00; the
    // net September work and the net October leave stay out.
    expect(priced[id('b')]!.amount.minorUnits, 28750);
    expect(priced[id('b')]!.average, (minorUnits: 25000, paidSeconds: 36000));
    expect(priced[id('b')]!.otherBasisLeftOut, isTrue);
    expect(priced[id('b')]!.basis, const GrossBasis());
  });

  test('sick leave pays 62.06 % for the first two days of an illness only', () {
    final worked = [
      WorkedPay(
        date: const LocalDate(2026, 9, 1),
        paidSeconds: 100 * 3600,
        pay: const Money(minorUnits: 250000),
        basis: const GrossBasis(),
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
  AgreementId agreementId = const AgreementId(
    '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21',
  ),
}) => LeaveRecord(
  id: LeaveRecordId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4f0$id'),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  date: date,
  leaveType: type,
  illnessStartedOn: illness,
  paidMinutes: 11 * 60 + 30,
  agreementId: agreementId,
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

PayAgreement agreement({
  RateBasis basis = const GrossBasis(),
  int rate = 18400000,
  String? id,
  LocalDate from = const LocalDate(2026, 1, 1),
}) => PayAgreement(
  id: AgreementId(
    id == null
        ? '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'
        : '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22',
  ),
  employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
  version: 1,
  effectiveStart: from,
  effectiveEnd: null,
  hourlyRateMicroEur: rate,
  basis: basis,
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
