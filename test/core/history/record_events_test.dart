import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/history/record_event_dao.dart';
import 'package:lifeos/core/history/record_events.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/shift_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  late AppDatabase database;
  late _Clock clock;
  late ProductionWorkProviders work;
  late RecordEventDao history;
  late UuidV7WorkIdFactory ids;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    clock = _Clock();
    ids = UuidV7WorkIdFactory();
    work = buildWorkProviders(
      database: database,
      clock: clock,
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Vilnius',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    history = RecordEventDao(database);
  });

  tearDown(() => database.close());

  Future<List<RecordEventKind>> kinds(String kind, String id) async => [
    for (final event in await history.forRecord(kind, id)) event.kind,
  ];

  Future<int> total() async =>
      (await database
              .customSelect('SELECT COUNT(*) AS c FROM record_events')
              .getSingle())
          .read<int>('c');

  T committed<T>(MutationOutcome<T> outcome) => (outcome as Committed<T>).value;

  Future<Employment> employment() async => committed(
    await work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic', legalLabel: null),
    ),
  );

  Future<PayAgreement> agreement(Employment owner) async => committed(
    await work.agreement.createAgreement(
      CreateAgreementCommand(
        employmentId: owner.id,
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
    ),
  );

  test('employment and agreement commands append one event each', () async {
    final owner = await employment();
    final renamed = committed(
      await work.employment.updateEmployment(
        UpdateEmploymentCommand(
          employmentId: owner.id,
          expectedRevision: owner.revision,
          name: 'Warehouse',
          legalLabel: null,
        ),
      ),
    );
    final terms = await agreement(renamed);
    committed(
      await work.agreement.updateAgreement(
        UpdateAgreementCommand(
          agreementId: terms.id,
          employmentId: owner.id,
          expectedRevision: terms.revision,
          terms: const AgreementTerms(
            effectiveStart: LocalDate(2026, 9, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 19000000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      ),
    );

    final employmentEvents = await history.forRecord(
      'employment',
      owner.id.value,
    );
    expect(employmentEvents.map((e) => e.kind), [
      RecordEventKind.created,
      RecordEventKind.changed,
    ]);
    expect(employmentEvents.last.changes, [
      const FieldChange('Name', 'Synthetic', 'Warehouse'),
    ]);
    expect(employmentEvents.last.revisionAfter, 1);
    expect(employmentEvents.first.atUtc, clock.now);

    final agreementEvents = await history.forRecord(
      'agreement',
      terms.id.value,
    );
    expect(agreementEvents.map((e) => e.kind), [
      RecordEventKind.created,
      RecordEventKind.changed,
    ]);
    expect(agreementEvents.last.changes, [
      const FieldChange('Hourly rate', '18.40 EUR/h', '19.00 EUR/h'),
    ]);
  });

  test('the live shift lifecycle appends one event per command', () async {
    final owner = await employment();
    await agreement(owner);

    final started = committed(
      await work.shifts.startShift(
        StartShiftCommand(
          employmentId: owner.id,
          timezoneId: 'Europe/Vilnius',
          note: null,
        ),
      ),
    );
    clock.now = clock.now.add(const Duration(hours: 4));
    final onBreak = committed(
      await work.shifts.startBreak(
        StartBreakCommand(
          shiftId: started.id,
          expectedShiftRevision: started.revision,
        ),
      ),
    );
    final openBreak = (await DriftShiftRepository(
      database,
    ).breaksFor(started.id)).single;
    clock.now = clock.now.add(const Duration(minutes: 30));
    final running = committed(
      await work.shifts.endBreak(
        EndBreakCommand(
          shiftId: started.id,
          breakId: openBreak.id,
          expectedShiftRevision: onBreak.revision,
          expectedBreakRevision: openBreak.revision,
        ),
      ),
    );
    clock.now = clock.now.add(const Duration(hours: 4));
    final ended = committed(
      await work.shifts.endShift(
        EndShiftCommand(id: started.id, expectedRevision: running.revision),
      ),
    );
    final finalized = committed(
      await work.shifts.finalizeShift(
        FinalizeShiftCommand(id: started.id, expectedRevision: ended.revision),
      ),
    );

    final events = await history.forRecord('shift', started.id.value);
    expect(events.map((e) => e.kind), [
      RecordEventKind.created,
      RecordEventKind.changed,
      RecordEventKind.changed,
      RecordEventKind.changed,
      RecordEventKind.finalized,
    ]);
    expect(
      events[1].changes.map((c) => c.field),
      containsAll(['State', 'Breaks']),
    );
    expect(events.last.changes, [
      const FieldChange('State', 'draft', 'finalized'),
    ]);
    expect(events.last.revisionAfter, finalized.revision.value);
  });

  test('manual shifts, corrections and revisions', () async {
    final owner = await employment();
    await agreement(owner);
    final manual = committed(
      await work.manualShifts.createAndFinalize(
        CreateManualShiftCommand(
          employmentId: owner.id,
          localStartDate: const LocalDate(2026, 9, 10),
          localStartTime: const LocalTime(9, 0),
          localEndDate: const LocalDate(2026, 9, 10),
          localEndTime: const LocalTime(17, 0),
          timezoneId: 'Europe/Vilnius',
          startFold: null,
          endFold: null,
          note: null,
        ),
      ),
    );
    expect(await kinds('shift', manual.id.value), [RecordEventKind.created]);

    final replacementId = ids.shiftId();
    committed(
      await work.shifts.correctShift(
        CorrectShiftCommand(
          originalId: manual.id,
          replacementId: replacementId,
          expectedRevision: manual.revision,
          voidReason: 'Synthetic end time',
        ),
      ),
    );
    final voided = await history.forRecord('shift', manual.id.value);
    expect(voided.map((e) => e.kind), [
      RecordEventKind.created,
      RecordEventKind.voided,
    ]);
    expect(voided.last.reason, 'Synthetic end time');
    expect(await kinds('shift', replacementId.value), [
      RecordEventKind.replaced,
    ]);

    final draft = (await DriftShiftRepository(database)
        .shiftById(replacementId))!;
    committed(
      await work.draftRevisions.reviseAndFinalize(
        ReviseShiftDraftCommand(
          id: draft.id,
          expectedRevision: draft.revision,
          localStartDate: const LocalDate(2026, 9, 10),
          localStartTime: const LocalTime(9, 0),
          localEndDate: const LocalDate(2026, 9, 10),
          localEndTime: const LocalTime(16, 0),
          timezoneId: 'Europe/Vilnius',
          startFold: null,
          endFold: null,
          note: null,
        ),
      ),
    );
    final revised = await history.forRecord('shift', replacementId.value);
    expect(revised.map((e) => e.kind), [
      RecordEventKind.replaced,
      RecordEventKind.finalized,
    ]);
    expect(
      revised.last.changes.map((c) => c.field),
      containsAll(['State', 'End']),
    );
  });

  test('pay periods and payslips', () async {
    final owner = await employment();
    final period = committed(
      await work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: owner.id,
          start: const LocalDate(2026, 9, 1),
          end: const LocalDate(2026, 9, 30),
          label: null,
        ),
      ),
    );
    committed(
      await work.periods.setState(
        SetPayPeriodStateCommand(
          id: period.id,
          state: PayPeriodState.reviewed,
          expectedRevision: period.revision,
        ),
      ),
    );
    expect(await kinds('payPeriod', period.id.value), [
      RecordEventKind.created,
      RecordEventKind.reviewed,
    ]);

    final payslip = committed(
      await work.payslips.recordPayslip(
        RecordPayslipCommand(
          periodId: period.id,
          issuedDate: const LocalDate(2026, 9, 30),
          paidDate: null,
          amountMinorUnits: 150000,
          basis: const GrossBasis(),
          grossMinorUnits: null,
          netMinorUnits: null,
          deductionMinorUnits: null,
          reference: null,
          note: null,
        ),
      ),
    );
    final replacementId = ids.payslipId();
    committed(
      await work.payslips.correctPayslip(
        CorrectPayslipCommand(
          originalId: payslip.id,
          replacementId: replacementId,
          expectedRevision: payslip.revision,
          voidReason: 'Synthetic amount',
        ),
      ),
    );
    expect(await kinds('payslip', payslip.id.value), [
      RecordEventKind.created,
      RecordEventKind.voided,
    ]);
    expect(await kinds('payslip', replacementId.value), [
      RecordEventKind.replaced,
    ]);
  });

  test('stale, invalid and missing outcomes append nothing', () async {
    final owner = await employment();
    final before = await total();

    expect(
      await work.employment.updateEmployment(
        UpdateEmploymentCommand(
          employmentId: owner.id,
          expectedRevision: const Revision(9),
          name: 'Stale',
          legalLabel: null,
        ),
      ),
      isA<Stale<Employment>>(),
    );
    expect(
      await work.employment.createEmployment(
        const CreateEmploymentCommand(name: ' ', legalLabel: null),
      ),
      isA<Invalid<Employment>>(),
    );
    expect(
      await work.shifts.finalizeShift(
        FinalizeShiftCommand(
          id: ids.shiftId(),
          expectedRevision: const Revision(0),
        ),
      ),
      isA<Missing<WorkShift>>(),
    );
    expect(
      await work.shifts.startShift(
        StartShiftCommand(
          employmentId: owner.id,
          timezoneId: 'Europe/Vilnius',
          note: null,
        ),
      ),
      isA<Invalid<WorkShift>>(), // no agreement covers today
    );
    expect(await total(), before);
  });

  test('a failed commit leaves no orphan event', () async {
    final owner = await employment();
    await agreement(owner);
    final started = committed(
      await work.shifts.startShift(
        StartShiftCommand(
          employmentId: owner.id,
          timezoneId: 'Europe/Vilnius',
          note: null,
        ),
      ),
    );
    clock.now = clock.now.add(const Duration(hours: 8));
    final ended = committed(
      await work.shifts.endShift(
        EndShiftCommand(id: started.id, expectedRevision: started.revision),
      ),
    );
    final before = await kinds('shift', started.id.value);

    await expectLater(
      DriftShiftRepository(database, clock: clock).finalizeShift(
        started.id,
        expected: ended.revision,
        failAfterAgreementLinkForTest: true,
      ),
      throwsStateError,
    );

    expect(await kinds('shift', started.id.value), before);
    expect(
      (await DriftShiftRepository(database).shiftById(started.id))!.state,
      ShiftState.draft,
    );
  });

  test('deleting an employment deletes its history', () async {
    final owner = await employment();
    final terms = await agreement(owner);
    committed(
      await work.employment.deleteEmployment(
        DeleteEmploymentCommand(
          employmentId: owner.id,
          expectedRevision: owner.revision,
        ),
      ),
    );
    expect(await kinds('employment', owner.id.value), isEmpty);
    expect(await kinds('agreement', terms.id.value), isEmpty);
  });

  test('history streams follow appends, oldest first', () async {
    final owner = await employment();
    final stream = history.watch('employment', owner.id.value);
    expect((await stream.first).single.kind, RecordEventKind.created);
  });
}

final class _Clock implements AppClock {
  DateTime now = DateTime.utc(2026, 9, 10, 6);

  @override
  DateTime nowUtc() => now;
}
