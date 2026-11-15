import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

void main() {
  /// Waits until [condition] holds, letting the database's streams run.
  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  test(
    'planner observers share one storage read and replay late subscribers',
    () async {
      final count = ReadCount();
      final fixture = await ShiftsSheetFixture.create(
        executor: NativeDatabase.memory().interceptWith(count),
      );
      addTearDown(fixture.dispose);
      count.selects = 0;
      var first = 0;
      var second = 0;
      var past = 0;
      final one = fixture.work.plans
          .watchInputs(fixtureEmployment)
          .listen((_) => first++);
      await until(() => first == 1);
      final cost = count.selects;
      expect(cost, greaterThan(0));
      final two = fixture.work.plans
          .watchInputs(fixtureEmployment)
          .listen((_) => second++);
      final three = fixture.work.plans
          .watchPastDays(fixtureEmployment, today: ShiftsSheetFixture.today)
          .listen((_) => past++);
      await until(() => second == 1 && past == 1);
      expect(
        count.selects,
        cost,
        reason: 'late observers replay without re-reading',
      );
      await one.cancel();
      await two.cancel();
      await three.cancel();
      await fixture.work.plans.watchInputs(fixtureEmployment).first;
      expect(
        count.selects,
        2 * cost,
        reason: 'last cancellation drops the cached input',
      );
    },
  );

  test('summaries count each sheet of an employment', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final first = await fixture.finishShift(20);
    await fixture.finishShift(21);
    final corrected = await fixture.work.shifts.correctShift(
      CorrectShiftCommand(
        originalId: first.id,
        replacementId: fixture.schedule.ids.shiftId(),
        expectedRevision: first.revision,
        voidReason: 'Wrong end',
      ),
    );
    expect(corrected, isA<Committed<WorkShift>>());
    final summary = (await fixture.reads.watchEmployments().first).single;
    final counts = summary.counts;
    // The corrected original is void; its replacement draft counts.
    expect(counts.shifts, 2);
    expect(counts.schedules, 1);
    expect(counts.agreements, 1);
    expect(summary.agreements, 1);
    expect(counts.periods, 0);
    expect(counts.payslips, 0);
    expect(counts.leave, 0);
  });

  test(
    'one change re-reads every count in a bounded number of queries',
    () async {
      final count = ReadCount();
      final fixture = await ShiftsSheetFixture.create(
        executor: NativeDatabase.memory().interceptWith(count),
      );
      addTearDown(fixture.dispose);
      for (var number = 1; number < 30; number++) {
        await fixture.work.employment.createEmployment(
          CreateEmploymentCommand(
            name: 'Synthetic site $number',
            legalLabel: null,
          ),
        );
      }
      final values = <List<EmploymentSummary>>[];
      final feed = fixture.reads.watchEmployments().listen(values.add);
      addTearDown(feed.cancel);
      await until(() => values.isNotEmpty);
      expect(values.last, hasLength(30));
      final seen = values.length;
      count.selects = 0;
      final database = fixture.schedule.database;
      await database.customUpdate(
        'UPDATE employments SET name = name',
        updates: {database.employments},
      );
      await until(() => values.length > seen);
      expect(count.selects, lessThanOrEqualTo(7));
    },
  );

  test('a change right after subscribing is not lost', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final values = <List<EmploymentSummary>>[];
    final feed = fixture.reads.watchEmployments().listen(values.add);
    addTearDown(feed.cancel);
    await fixture.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic bakery', legalLabel: null),
    );
    await until(() => values.isNotEmpty && values.last.length == 2);
  });

  test('agreement rows count what each version paid', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    await fixture.finishShift(20);
    final row = (await fixture.reads.agreementRows(fixtureEmployment)).single;
    expect(row.agreement.id, fixtureAgreement);
    expect(row.paidShifts, 1);
    expect(row.paysLeave, isFalse);
    expect(row.firstUse, const LocalDate(2026, 10, 20));
    expect(row.lastUse, const LocalDate(2026, 10, 20));
    expect(row.inUse, isTrue);
  });

  test('the rows follow a change of terms', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final seen = <List<AgreementRow>>[];
    final feed = fixture.reads
        .watchAgreements(fixtureEmployment)
        .listen(seen.add);
    addTearDown(feed.cancel);
    await until(() => seen.isNotEmpty);
    final v1 = seen.last.single.agreement;
    final changed = await fixture.work.agreement.changeAgreementTerms(
      ChangeAgreementTermsCommand(
        agreementId: v1.id,
        employmentId: fixtureEmployment,
        expectedRevision: v1.revision,
        from: const LocalDate(2026, 11, 1),
        terms: AgreementTerms.of(v1),
      ),
    );
    expect(changed, isA<Committed<PayAgreement>>());
    await until(() => seen.last.length == 2);
    expect(
      seen.last.first.agreement.effectiveEnd,
      const LocalDate(2026, 10, 31),
    );
    expect(
      seen.last.last.agreement.effectiveStart,
      const LocalDate(2026, 11, 1),
    );
    expect(seen.last.last.agreement.version, 2);
  });

  test('an employment with only a void shift has history', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final created = await fixture.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic site', legalLabel: null),
    );
    final site = (created as Committed<Employment>).value;
    Future<bool> history(EmploymentId id) async =>
        (await fixture.reads.watchEmployments().first)
            .singleWhere((summary) => summary.employment.id == id)
            .hasHistory;
    expect(await history(site.id), isFalse);
    // The depot has a schedule; a day change alone counts too.
    expect(await history(fixtureEmployment), isTrue);
    // A voided shift is counted nowhere, yet it is work recorded.
    await fixture.work.agreement.createAgreement(
      CreateAgreementCommand(
        employmentId: site.id,
        version: 1,
        terms: const AgreementTerms(
          effectiveStart: LocalDate(2026, 9, 1),
          effectiveEnd: null,
          hourlyRateMicroEur: 18400000,
          basis: GrossBasis(),
          label: null,
          note: null,
        ),
      ),
    );
    const day = LocalDate(2026, 10, 7);
    final finished = await fixture.work.manualShifts.createAndFinalize(
      CreateManualShiftCommand(
        employmentId: site.id,
        localStartDate: day,
        localStartTime: LocalTime(8, 0),
        localEndDate: day,
        localEndTime: LocalTime(16, 0),
        timezoneId: ShiftsSheetFixture.zone,
        startFold: null,
        endFold: null,
        breaks: const [],
        note: null,
      ),
    );
    final shift = (finished as Committed<WorkShift>).value;
    await fixture.work.shifts.voidShift(
      VoidShiftCommand(
        id: shift.id,
        expectedRevision: shift.revision,
        voidReason: 'Entered by mistake',
      ),
    );
    final summary = (await fixture.reads.watchEmployments().first).singleWhere(
      (value) => value.employment.id == site.id,
    );
    expect(summary.counts.shifts, 0);
    expect(await history(site.id), isTrue);
  });

  test('schedule rows count confirmed days per version', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final depot = (await fixture.schedule.repository.schedulesFor(
      fixtureEmployment,
    )).single;
    await fixture.schedule.markUsed(depot);
    await fixture.schedule.markUsed(depot, date: const LocalDate(2026, 10, 6));
    final row = (await fixture.reads.scheduleRows(fixtureEmployment)).single;
    expect(row.confirmedDays, 2);
    expect(row.lastConfirmed, const LocalDate(2026, 10, 6));
    expect(row.used, isTrue);
    expect(row.latest, isTrue);
    expect(row.rowId, '${depot.id.value}@1');
    final record = await fixture.reads.schedule(fixtureEmployment, depot.id);
    expect(record!.value.version, 1);
  });

  test('a schedule row with no confirmed day counts none', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final row = (await fixture.reads.scheduleRows(fixtureEmployment)).single;
    expect(row.confirmedDays, 0);
    expect(row.lastConfirmed, isNull);
    expect(row.used, isFalse);
  });

  test('the schedule rows follow a new version', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final depot = (await fixture.schedule.repository.schedulesFor(
      fixtureEmployment,
    )).single;
    await fixture.schedule.markUsed(depot);
    final seen = <List<ScheduleRow>>[];
    final subscription = fixture.reads
        .watchSchedules(fixtureEmployment)
        .listen(seen.add);
    addTearDown(subscription.cancel);
    await until(() => seen.isNotEmpty);
    final used = (await fixture.schedule.repository.schedulesFor(
      fixtureEmployment,
    )).single;
    final outcome = await fixture.work.schedules.update(
      used.id,
      expected: used.revision,
      draft: depotDraft(),
      newVersionFrom: const LocalDate(2026, 10, 19),
    );
    expect(outcome, isA<Committed<WorkSchedule>>());
    await until(() => seen.last.length == 2);
    final rows = seen.last;
    expect(rows.first.latest, isFalse);
    expect(rows.first.schedule.inUseUntil, const LocalDate(2026, 10, 18));
    expect(rows.last.latest, isTrue);
    expect(rows.last.schedule.version, 2);
    final earlier = await fixture.reads.schedule(
      fixtureEmployment,
      depot.id,
      version: 1,
    );
    expect(earlier!.value.version, 1);
  });
}
