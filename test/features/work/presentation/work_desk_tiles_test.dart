import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_desk_tiles.dart';

void main() {
  group('Needs you', () {
    test('lists the running shift, drafts and open periods that differ', () {
      final running = _row(_id(1), ShiftState.running, _day(2));
      final items = needsYou(
        active: ShiftRecordProjection(running.shift, breaks: const []),
        activeLabel: (_) => 'Shift running since 08:00',
        registers: [
          _register(
            shifts: [
              running,
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
        'Shift running since 08:00',
        'Shift on 2026-10-01 is a draft and needs finalizing',
        'Pay period P1 differs from expected by EUR -12.00',
      ]);
      expect(items.first.route, contains('record=shift'));
      expect(items.first.route, contains(_id(1).value));
      expect(items[1].route, contains(_id(2).value));
      expect(items.last.route, contains('record=payPeriod'));
    });

    test('is empty when nothing waits', () {
      expect(
        needsYou(
          active: null,
          activeLabel: (_) => '',
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
        'No drafts or running shifts',
        'All recorded',
        'Nothing left to review',
      ]);
    });

    test('names what is still open', () {
      final checks = monthChecklist([
        _register(
          shifts: [
            _row(_id(1), ShiftState.draft, _day(1)),
            _row(_id(2), ShiftState.running, _day(2)),
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
        '2 shifts still open',
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
  final finished = state != ShiftState.running && state != ShiftState.onBreak;
  return ShiftSheetRow(
    shift: WorkShift(
      id: id,
      employmentId: _employmentId,
      agreementId: state == ShiftState.draft
          ? null
          : const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
      state: state,
      startUtc: DateTime.utc(date.year, date.month, date.day, 6),
      endUtc: finished
          ? DateTime.utc(date.year, date.month, date.day, 14)
          : null,
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
    paidSeconds: finished ? 8 * 3600 : null,
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
