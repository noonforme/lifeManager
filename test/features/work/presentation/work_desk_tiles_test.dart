import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_desk_tiles.dart';

import '../../../support/schedule_fixture.dart';
import '../../../support/schedule_views.dart';
import '../../../support/zone_clocks.dart';

void main() {
  group('Needs you', () {
    test('lists drafts and open periods that differ', () {
      final items = needsYou(
        registers: [
          _register(
            shifts: [
              _row(_id(2), ShiftState.draft, _day(1)),
              _row(_id(3), ShiftState.finalized, _day(1)),
            ],
            periods: [
              _periodRow(_period(1, PayPeriodState.open), _difference(-1200)),
              _periodRow(_period(2, PayPeriodState.reviewed), _difference(-50)),
              _periodRow(_period(3, PayPeriodState.open), _balanced()),
            ],
          ),
        ],
      );

      expect(items.map((item) => item.text), [
        'Shift on 2026-10-01 is a draft and needs finalizing',
        'Pay period P1 differs from expected by EUR -12.00',
      ]);
      expect(items.first.route, contains('record=shift'));
      expect(items.first.route, contains(_id(2).value));
      expect(items.last.route, contains('record=payPeriod'));
    });

    test('is empty when nothing waits', () {
      expect(
        needsYou(
          registers: [
            _register(shifts: [_row(_id(1), ShiftState.finalized, _day(1))]),
          ],
        ),
        isEmpty,
      );
    });
  });

  test('Work this period sums finalized shifts up to today', () {
    final rows = workThisPeriod([
      _register(
        shifts: [
          _row(_id(1), ShiftState.finalized, _day(1), pay: 10000),
          _row(_id(2), ShiftState.finalized, _day(2), pay: 5050),
          _row(_id(3), ShiftState.draft, _day(2)),
          _row(_id(4), ShiftState.finalized, _day(9), pay: 99999),
          _row(
            _id(5),
            ShiftState.finalized,
            const LocalDate(2026, 9, 30),
            pay: 77777,
          ),
        ],
        periods: [_periodRow(_period(1, PayPeriodState.open), _balanced())],
      ),
    ], _day(5));

    final row = rows.single;
    expect(row.employment, 'Warehouse');
    expect(row.paidSeconds, 2 * 8 * 3600);
    expect(row.expected, const Money(minorUnits: 15050));
    expect(
      workThisPeriod([_register()], _day(5)),
      isEmpty,
      reason: 'no pay period covers today',
    );
  });

  group('Month close checklist', () {
    final october = (
      start: const LocalDate(2026, 10, 1),
      end: const LocalDate(2026, 10, 31),
    );

    test('ticks only what the records show', () {
      final checks = monthChecklist([
        _register(
          shifts: [
            _row(_id(1), ShiftState.finalized, _day(1)),
            _row(_id(2), ShiftState.voided, _day(2)),
          ],
          periods: [
            _periodRow(_period(1, PayPeriodState.reviewed), _difference(-300)),
          ],
        ),
      ], october);

      expect([for (final check in checks) check.done], [true, true, true]);
      expect(checks.map((check) => check.detail), [
        'All confirmed',
        'All recorded',
        'Nothing left to review',
      ]);
    });

    test('names what is still open', () {
      final checks = monthChecklist([
        _register(
          shifts: [
            _row(_id(1), ShiftState.draft, _day(1)),
            _row(_id(2), ShiftState.draft, _day(2)),
            _row(_id(3), ShiftState.draft, const LocalDate(2026, 9, 30)),
          ],
          periods: [
            _periodRow(_period(1, PayPeriodState.open), _difference(-300)),
            _periodRow(_period(2, PayPeriodState.open), _missing()),
          ],
        ),
      ], october);

      expect([for (final check in checks) check.done], [false, false, false]);
      expect(checks.map((check) => check.detail), [
        '2 shifts still drafts',
        '1 period without one',
        '1 period to review',
      ]);
    });

    test('does not claim payslips for a month without pay periods', () {
      final checks = monthChecklist([_register()], october);
      expect(checks[1].done, isFalse);
      expect(checks[1].detail, 'No pay period covers this month yet');
    });
  });

  test('Next shifts are the next five planned shifts in date order', () {
    final plan = octoberPlan().where(
      (day) => day.date.compareTo(const LocalDate(2026, 10, 7)) >= 0,
    );
    final rows = nextShifts(
      [
        (
          employment: fixtureEmployment,
          plan: plan.toList(),
          agreements: const [],
        ),
      ],
      zoneClocks: testZoneClocks,
      timezones: testTimezones,
      now: DateTime.utc(2026, 10, 7, 3),
    );
    expect(rows.map((row) => row.date), const [
      LocalDate(2026, 10, 7),
      LocalDate(2026, 10, 11),
      LocalDate(2026, 10, 12),
      LocalDate(2026, 10, 13),
      LocalDate(2026, 10, 17),
    ]);
    expect(rows.first.text, 'Wed 2026-10-07 Day 07:00–19:00');
    expect(rows.first.route, contains('day=2026-10-07'));
  });

  test('a shift that ended today is no longer next', () {
    final plan = octoberPlan().where(
      (day) => day.date.compareTo(const LocalDate(2026, 10, 7)) >= 0,
    );
    // 07:00–19:00 in Vilnius ends at 16:00 UTC; it is 16:30 UTC.
    final rows = nextShifts(
      [
        (
          employment: fixtureEmployment,
          plan: plan.toList(),
          agreements: const [],
        ),
      ],
      zoneClocks: testZoneClocks,
      timezones: testTimezones,
      now: DateTime.utc(2026, 10, 7, 16, 30),
    );
    expect(rows.first.date, const LocalDate(2026, 10, 11));
    expect(
      rows.map((row) => row.date),
      isNot(contains(const LocalDate(2026, 10, 7))),
    );
  });

  test('Needs you says how many days wait to be confirmed', () {
    final register = WorkRegisterProjection.empty(
      const WorkScope(employmentId: fixtureEmployment, temporal: null),
    );
    final items = needsYou(
      registers: [register],
      daysToConfirm: {fixtureEmployment: 2},
    );
    expect(items.single.text, '2 days to confirm');
    expect(items.single.route, contains('confirm=1'));
  });

  test('the month checklist counts past planned days not confirmed', () {
    final checks = monthChecklist(
      const [],
      (start: const LocalDate(2026, 10, 1), end: const LocalDate(2026, 10, 31)),
      unconfirmed: const [LocalDate(2026, 10, 5), LocalDate(2026, 10, 6)],
    );
    expect(checks.first.label, 'Every past planned day is confirmed');
    expect(checks.first.done, isFalse);
    expect(checks.first.detail, '2 days to confirm');
  });

  test('a month whose only open days have no pay agreement is not done', () {
    const august = (start: LocalDate(2026, 8, 1), end: LocalDate(2026, 8, 31));
    final unpaid = [
      for (var day = 1; day <= 16; day++) LocalDate(2026, 8, day),
      // Outside the month: not counted.
      const LocalDate(2026, 7, 31),
    ];
    final only = monthChecklist(
      const [],
      august,
      withoutAgreement: unpaid,
    ).first;
    expect(only.done, isFalse);
    expect(only.detail, '16 days without a pay agreement');

    final both = monthChecklist(
      const [],
      august,
      unconfirmed: const [LocalDate(2026, 8, 20), LocalDate(2026, 8, 21)],
      withoutAgreement: unpaid,
    ).first;
    expect(both.done, isFalse);
    expect(both.detail, '2 days to confirm · 16 without a pay agreement');

    final one = monthChecklist(
      const [],
      august,
      withoutAgreement: const [LocalDate(2026, 8, 3)],
    ).first;
    expect(one.detail, '1 day without a pay agreement');
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

ShiftId _id(int n) =>
    ShiftId('00000000-0000-7000-8000-${n.toString().padLeft(12, '0')}');

LocalDate _day(int day) => LocalDate(2026, 10, day);

WorkRegisterProjection _register({
  List<ShiftSheetRow> shifts = const [],
  List<PeriodSheetRow> periods = const [],
}) => WorkRegisterProjection(
  scope: const WorkScope(employmentId: _employmentId, temporal: null),
  period: null,
  shiftRows: const [],
  payslipRows: const [],
  paid: const Money(minorUnits: 0),
  reconciliation: null,
  employment: Employment(
    id: _employmentId,
    name: 'Warehouse',
    legalLabel: null,
    status: EmploymentStatus.active,
    createdAtUtc: DateTime.utc(2026, 9),
    updatedAtUtc: DateTime.utc(2026, 9),
    revision: const Revision(0),
  ),
  shiftSheet: shifts,
  periodSheet: periods,
);

ShiftSheetRow _row(ShiftId id, ShiftState state, LocalDate date, {int? pay}) {
  return ShiftSheetRow(
    shift: WorkShift(
      id: id,
      employmentId: _employmentId,
      agreementId: state == ShiftState.draft
          ? null
          : const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
      state: state,
      startUtc: DateTime.utc(date.year, date.month, date.day, 6),
      endUtc: DateTime.utc(date.year, date.month, date.day, 14),
      timezoneId: 'Europe/Vilnius',
      localStartDate: date,
      note: null,
      voidReason: state == ShiftState.voided ? 'Synthetic' : null,
      replacementShiftId: state == ShiftState.voided ? _id(99) : null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 9),
      updatedAtUtc: DateTime.utc(2026, 9),
      revision: const Revision(1),
    ),
    breakSeconds: 0,
    paidSeconds: 8 * 3600,
    period: null,
    pay: pay == null
        ? null
        : ExpectedPay(
            totalPaidSeconds: 8 * 3600,
            nightPaidSeconds: 0,
            holidayPaidSeconds: 0,
            overtimePaidSeconds: 0,
            regularPaidSeconds: 8 * 3600,
            amount: Money(minorUnits: pay),
          ),
  );
}

/// Period 1 is October 2026; later numbers are later months.
PayPeriod _period(int n, PayPeriodState state) => PayPeriod.rehydrate(
  id: PayPeriodId('018f0f9a-7d03-7e6a-8b0c-${n.toString().padLeft(12, '0')}'),
  employmentId: _employmentId,
  start: n == 1 ? _day(1) : LocalDate(2026, 10, 10 + n),
  end: n == 1 ? _day(31) : LocalDate(2026, 10, 10 + n),
  label: 'P$n',
  state: state,
  createdAtUtc: DateTime.utc(2026, 10),
  updatedAtUtc: DateTime.utc(2026, 10),
  revision: const Revision(0),
);

PeriodSheetRow _periodRow(
  PayPeriod period,
  ({ReconciliationStatus status, int? paid, int? difference}) facts,
) => PeriodSheetRow(
  period: period,
  shiftCount: 1,
  groups: [
    ReconciliationGroup(
      employmentId: _employmentId,
      periodId: period.id,
      currency: const CurrencyCode.eur(),
      basis: const GrossBasis(),
      regularPaidSeconds: 0,
      overtimePaidSeconds: 0,
      expected: const Money(minorUnits: 10000),
      paid: facts.paid == null ? null : Money(minorUnits: facts.paid!),
      difference: facts.difference == null
          ? null
          : Money(minorUnits: facts.difference!),
      shiftIds: const [],
      payslipIds: const [],
      status: facts.status,
    ),
  ],
);

({ReconciliationStatus status, int? paid, int? difference}) _difference(
  int difference,
) => (
  status: const Difference(),
  paid: 10000 + difference,
  difference: difference,
);

({ReconciliationStatus status, int? paid, int? difference}) _balanced() =>
    (status: const Balanced(), paid: 10000, difference: 0);

({ReconciliationStatus status, int? paid, int? difference}) _missing() =>
    (status: const MissingPayslip(), paid: null, difference: null);
