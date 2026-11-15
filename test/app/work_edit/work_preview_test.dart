import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/planned_day_edit.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_edit/work_preview.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';

import '../../support/schedule_fixture.dart';

const _monday = LocalDate(2026, 10, 5);
const _night = LocalDate(2026, 10, 11);
const _offDay = LocalDate(2026, 10, 8);
const _day = LocalDate(2026, 10, 20);

void main() {
  late ScheduleFixture fixture;
  late PlanInputs inputs;
  final timezones = IanaTimezoneService();
  final zoneClocks = zoneClocksOf(timezones);

  setUp(() async {
    fixture = await ScheduleFixture.create();
    await fixture.saveDepot();
    inputs = await fixture.plans.repository.planInputs(fixtureEmployment);
  });

  tearDown(() => fixture.dispose());

  Future<PlannedDayRecord> read(LocalDate date) async =>
      (await readPlannedDay(fixture.plans, fixtureEmployment, date))!;

  WorkPreview? plannedPreview(
    PlannedDayRecord record,
    PlannedDayValues values,
  ) =>
      previewPlannedDay(record, values, inputs: inputs, zoneClocks: zoneClocks);

  WorkPreview? shiftPreview(ShiftValues values) => previewShift(
    values,
    employmentId: fixtureEmployment,
    agreements: inputs.agreements,
    timezones: timezones,
    zoneClocks: zoneClocks,
  );

  ShiftValues shift({
    LocalDate date = _day,
    LocalTime start = const LocalTime(8, 0),
    LocalTime end = const LocalTime(16, 0),
    List<BreakValues> breaks = const [],
  }) => ShiftValues(
    startDate: date,
    start: start,
    endDate: date,
    end: end,
    timezoneId: 'Europe/Vilnius',
    breaks: breaks,
  );

  test('an unchanged planned day previews as planned', () async {
    final record = await read(_monday);
    final preview = plannedPreview(record, record.values)!;
    expect(preview.paidSeconds, 41400);
    expect(preview.breakSeconds, 1800);
    expect(preview.planDifferenceSeconds, 0);
    expect(preview.pay!.amount.minorUnits, 21160);
  });

  test(
    'a shorter day previews its paid time, pay and plan difference',
    () async {
      final record = await read(_monday);
      final preview = plannedPreview(
        record,
        record.values.copyWith(end: const LocalTime(18, 0)),
      )!;
      expect(preview.paidSeconds, 37800);
      expect(preview.planDifferenceSeconds, -3600);
      expect(preview.pay!.amount.minorUnits, 19320);
    },
  );

  test('a planned night previews its night premium', () async {
    final record = await read(_night);
    final pay = plannedPreview(record, record.values)!.pay!;
    expect(pay.nightPaidSeconds, 27000);
    expect(pay.overtimePaidSeconds, 0);
    expect(pay.amount.minorUnits, 28060);
  });

  test(
    'a night across the autumn clock change counts the hour gained',
    () async {
      // Vilnius clocks go back from 04:00 to 03:00 on 2026-10-25, inside the
      // night that starts on the 24th.
      final record = await read(const LocalDate(2026, 10, 24));
      final preview = plannedPreview(record, record.values)!;
      expect(preview.paidSeconds, 45000);
      expect(preview.planDifferenceSeconds, 0);
    },
  );

  test('an extra day has no plan to differ from', () async {
    await fixture.plans.addExtra(
      fixtureEmployment,
      _offDay,
      start: const LocalTime(8, 0),
      end: const LocalTime(16, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: null,
      countsAsOvertime: false,
    );
    inputs = await fixture.plans.repository.planInputs(fixtureEmployment);
    final record = await read(_offDay);
    final preview = plannedPreview(record, record.values)!;
    expect(preview.paidSeconds, 28800);
    expect(preview.planDifferenceSeconds, isNull);
  });

  test('times that make no planned shift preview nothing', () async {
    final record = await read(_monday);
    expect(
      plannedPreview(
        record,
        record.values.copyWith(end: const LocalTime(7, 0), breaks: const []),
      ),
      isNull,
    );
  });

  test('a manual shift previews its breaks and pay', () {
    final preview = shiftPreview(
      shift(
        breaks: const [
          BreakValues(
            startDate: _day,
            start: LocalTime(12, 0),
            endDate: _day,
            end: LocalTime(12, 30),
          ),
        ],
      ),
    )!;
    expect(preview.paidSeconds, 27000);
    expect(preview.breakSeconds, 1800);
    expect(preview.planDifferenceSeconds, isNull);
    expect(preview.pay!.amount.minorUnits, 13800);
  });

  test("a manual shift past the agreement's threshold previews overtime", () {
    final pay = shiftPreview(
      shift(start: const LocalTime(6, 0), end: const LocalTime(17, 0)),
    )!.pay!;
    expect(pay.overtimePaidSeconds, 10800);
    expect(pay.amount.minorUnits, 23000);
  });

  test('a date no agreement covers previews time without pay', () {
    final preview = shiftPreview(shift(date: const LocalDate(2026, 8, 20)))!;
    expect(preview.paidSeconds, 28800);
    expect(preview.pay, isNull);
  });

  test('a time that does not exist in the zone previews nothing', () {
    expect(
      shiftPreview(
        shift(
          date: const LocalDate(2027, 3, 28),
          start: const LocalTime(3, 30),
        ),
      ),
      isNull,
    );
  });

  test('a shift that ends before it starts previews nothing', () {
    expect(shiftPreview(shift(end: const LocalTime(7, 0))), isNull);
  });
}
