import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_edit/schedule_preview.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../support/schedule_fixture.dart';

void main() {
  late ScheduleFixture fixture;
  late WorkSchedule depot;
  final zoneClocks = zoneClocksOf(IanaTimezoneService());
  const october = LocalDate(2026, 10, 1);
  const today = LocalDate(2026, 10, 20);

  setUp(() async {
    fixture = await ScheduleFixture.create();
    depot = await fixture.saveDepot();
  });
  tearDown(() => fixture.dispose());

  Future<List<PreviewMonth>> preview(
    ScheduleValues draft, {
    WorkSchedule? baseline,
    int months = 1,
  }) async => previewMonths(
    draft: draft,
    baseline: ScheduleRecord(baseline ?? depot),
    employmentId: fixtureEmployment,
    inputs: await fixture.repository.planInputs(fixtureEmployment),
    firstMonth: october,
    months: months,
    today: today,
    zoneClocks: zoneClocks,
  );

  /// The stored inputs with [agreements] in place of the stored ones.
  Future<PlanInputs> inputsWith(List<PayAgreement> agreements) async {
    final inputs = await fixture.repository.planInputs(fixtureEmployment);
    return PlanInputs(
      schedules: inputs.schedules,
      exceptions: inputs.exceptions,
      confirmedDates: inputs.confirmedDates,
      agreements: agreements,
    );
  }

  /// The stored gross agreement until the day before [from], then EUR 10
  /// net.
  Future<List<PayAgreement>> netFrom(LocalDate from) async {
    final inputs = await fixture.repository.planInputs(fixtureEmployment);
    final gross = inputs.agreements.single;
    return [
      gross.withRange(start: gross.effectiveStart, end: from.addDays(-1)),
      PayAgreement(
        id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22'),
        employmentId: fixtureEmployment,
        version: 2,
        effectiveStart: from,
        effectiveEnd: null,
        hourlyRateMicroEur: 10000000,
        basis: const NetBasis(),
        overtimeThresholdMinutes: gross.overtimeThresholdMinutes,
        overtimeMultiplier: gross.overtimeMultiplier,
        label: null,
        note: null,
        createdAtUtc: gross.createdAtUtc,
        revision: const Revision(0),
        usedByFinalizedShift: false,
      ),
    ];
  }

  Future<SchedulePricing?> pricing({
    bool withAgreement = true,
    List<PayAgreement>? agreements,
  }) async {
    final inputs = await fixture.repository.planInputs(fixtureEmployment);
    return schedulePricing(
      draft: ScheduleValues.of(depot),
      baseline: ScheduleRecord(depot),
      employmentId: fixtureEmployment,
      inputs: agreements != null
          ? await inputsWith(agreements)
          : withAgreement
          ? inputs
          : await inputsWith(const []),
      today: today,
      zoneClocks: zoneClocks,
    );
  }

  test('each shift type and one whole cycle are priced as planned', () async {
    final priced = (await pricing())!;
    final [day, night] = depot.shiftTypes;
    // EUR 18.40 an hour for 11:30.
    expect(priced.types[day.id]!.amount.minorUnits, 21160);
    expect(priced.types[day.id]!.nightPaidSeconds, 0);
    // The same, plus ×1.5 over 7:30 of night.
    expect(priced.types[night.id]!.amount.minorUnits, 28060);
    expect(priced.types[night.id]!.nightPaidSeconds, 27000);
    // The next cycle starts on the 29th: three days and three nights.
    expect(priced.cycleFrom, const LocalDate(2026, 10, 29));
    expect(priced.cyclePay, {const GrossBasis(): 3 * 21160 + 3 * 28060});
  });

  test('with no agreement the types and the cycle have no price', () async {
    final priced = (await pricing(withAgreement: false))!;
    final [day, night] = depot.shiftTypes;
    expect(priced.types.keys, containsAll([day.id, night.id]));
    expect(priced.types[day.id], isNull);
    expect(priced.types[night.id], isNull);
    expect(priced.cyclePay, isNull);
  });

  test('October 2026 plans the rotation from its start', () async {
    final month = (await preview(ScheduleValues.of(depot))).single;
    expect(month.days, hasLength(31));
    expect(month.days.first.letter, '', reason: 'before the schedule starts');
    expect(month.days[4].letter, 'D');
    expect(month.days[10].letter, 'N');
    expect(month.days[10].typeIndex, 1);
    expect(month.days[7].letter, '');
    expect(month.shifts, 15);
    // Fourteen shifts of 11:30, and the night into the clock change 12:30.
    expect(month.paidSeconds, 14 * 41400 + 45000);
    // EUR 18.40 an hour for 173:30 is 3 192.40, plus the ×1.5 night
    // premium over 46 night hours (7:30 a night, 8:30 into the clock
    // change): 423.20.
    expect(month.pay, {const GrossBasis(): 319240 + 42320});
  });

  test('a month that changes basis keeps gross and net apart', () async {
    final inputs = await inputsWith(
      await netFrom(const LocalDate(2026, 10, 15)),
    );
    final month = previewMonths(
      draft: ScheduleValues.of(depot),
      baseline: ScheduleRecord(depot),
      employmentId: fixtureEmployment,
      inputs: inputs,
      firstMonth: october,
      months: 1,
      today: today,
      zoneClocks: zoneClocks,
    ).single;
    // Gross before the 15th: three days and three nights.
    expect(month.pay![const GrossBasis()], 3 * 21160 + 3 * 28060);
    expect(month.pay![const NetBasis()], isPositive);
    expect(month.pay!.keys, [const GrossBasis(), const NetBasis()]);
  });

  test('a cycle that changes basis keeps gross and net apart', () async {
    // The cycle from the 29th: three days on the old terms, three nights
    // on the new.
    final priced = (await pricing(
      agreements: await netFrom(const LocalDate(2026, 11, 1)),
    ))!;
    expect(priced.cyclePay![const GrossBasis()], 3 * 21160);
    expect(priced.cyclePay![const NetBasis()], isPositive);
  });

  test('today and confirmed days are marked', () async {
    await fixture.markUsed(depot);
    final month = (await preview(ScheduleValues.of(depot))).single;
    expect(month.days[19].today, isTrue);
    expect(month.days[4].confirmed, isTrue);
    expect(month.days[5].confirmed, isFalse);
  });

  test("another schedule's days name it", () async {
    final ended = await fixture.schedules.update(
      depot.id,
      expected: depot.revision,
      draft: depotDraft(until: const LocalDate(2026, 12, 31)),
    );
    depot = (ended as Committed<WorkSchedule>).value;
    await fixture.schedules.create(
      depotDraft(name: 'Winter rotation', from: const LocalDate(2027, 1, 1)),
    );
    final months = await preview(ScheduleValues.of(depot), months: 4);
    expect([for (final m in months) m.month], [10, 11, 12, 1]);
    final january = months.last;
    expect(
      january.days.every((day) => day.otherSchedule == 'Winter rotation'),
      isTrue,
    );
    expect(january.otherSchedule, 'Winter rotation');
    expect(january.days.first.letter, '');
    expect(months.first.otherSchedule, isNull);
  });

  test('the pending cycle shows before Save', () async {
    final four = withBlockField(
      ScheduleValues.of(depot),
      0,
      ScheduleField.blockDays,
      '4',
    ).values!;
    final month = (await preview(four)).single;
    expect(
      [for (final day in month.days.sublist(4, 9)) day.letter],
      ['D', 'D', 'D', 'D', ''],
    );
  });

  test('a draft that does not validate previews nothing', () async {
    final none = ScheduleValues.of(depot).copyWith(blocks: const []);
    expect(await preview(none), isEmpty);
  });

  test('the preview starts this month, or the month the schedule starts', () {
    final values = ScheduleValues.of(depot);
    expect(previewStart(values, today), october);
    expect(
      previewStart(
        values.copyWith(inUseFrom: const LocalDate(2027, 2, 10)),
        today,
      ),
      const LocalDate(2027, 2, 1),
    );
    expect(
      previewStart(
        values.copyWith(versionFrom: () => const LocalDate(2026, 12, 3)),
        today,
      ),
      const LocalDate(2026, 12, 1),
    );
  });
}
