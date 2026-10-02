import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/journal/journal_projection.dart';
import 'package:lifeos/features/journal/journal_source.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  late AppDatabase database;
  late _Clock clock;
  late ProductionWorkProviders work;
  late UuidV7WorkIdFactory ids;
  late JournalSource journal;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    clock = _Clock();
    ids = UuidV7WorkIdFactory();
    final zones = IanaTimezoneService();
    work = buildWorkProviders(
      database: database,
      clock: clock,
      timezones: zones,
      currentTimezoneId: () => 'Europe/Vilnius',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    journal = DriftJournalSource(
      database,
      timezones: zones,
      defaultZone: () => 'Europe/Vilnius',
    );
  });

  tearDown(() => database.close());

  T committed<T>(MutationOutcome<T> outcome) => (outcome as Committed<T>).value;

  Future<Employment> setUpWork() async {
    final employment = committed(
      await work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Warehouse', legalLabel: null),
      ),
    );
    committed(
      await work.agreement.createAgreement(
        CreateAgreementCommand(
          employmentId: employment.id,
          version: 1,
          terms: const AgreementTerms(
            effectiveStart: LocalDate(2026, 9, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 20000000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      ),
    );
    return employment;
  }

  Future<WorkShift> manual(
    Employment employment,
    LocalDate date,
    int startHour,
    int endHour,
  ) async => committed(
    await work.manualShifts.createAndFinalize(
      CreateManualShiftCommand(
        employmentId: employment.id,
        localStartDate: date,
        localStartTime: LocalTime(startHour, 0),
        localEndDate: date,
        localEndTime: LocalTime(endHour, 0),
        timezoneId: 'Europe/Vilnius',
        startFold: null,
        endFold: null,
        note: null,
      ),
    ),
  );

  Future<List<JournalEntry>> read(LocalDate from, LocalDate to) =>
      journal.watch(from, to).first;

  test('Work events appear newest first with their own words', () async {
    final employment = await setUpWork();
    clock.now = DateTime.utc(2026, 9, 10, 8);
    final started = committed(
      await work.shifts.startShift(
        StartShiftCommand(
          employmentId: employment.id,
          timezoneId: 'Europe/Vilnius',
          note: null,
        ),
      ),
    );
    clock.now = DateTime.utc(2026, 9, 10, 16);
    final ended = committed(
      await work.shifts.endShift(
        EndShiftCommand(id: started.id, expectedRevision: started.revision),
      ),
    );
    clock.now = DateTime.utc(2026, 9, 10, 16, 5);
    committed(
      await work.shifts.finalizeShift(
        FinalizeShiftCommand(id: started.id, expectedRevision: ended.revision),
      ),
    );

    final entries = await read(
      const LocalDate(2026, 9, 1),
      const LocalDate(2026, 9, 30),
    );
    expect(entries.map((entry) => entry.kind), [
      JournalKind.shiftFinalized,
      JournalKind.shiftEnded,
      JournalKind.shiftStarted,
      JournalKind.agreementCreated,
      JournalKind.employmentCreated,
    ]);
    expect(entries.first.amount?.minorUnits, 16000);
    expect(entries.first.state, 'Finalized');
  });

  test(
    'a void-and-replace shows the original as Void and counts once',
    () async {
      final employment = await setUpWork();
      clock.now = DateTime.utc(2026, 9, 11, 18);
      final original = await manual(
        employment,
        const LocalDate(2026, 9, 11),
        8,
        16,
      );
      final replacementId = ids.shiftId();
      clock.now = DateTime.utc(2026, 9, 11, 19);
      committed(
        await work.shifts.correctShift(
          CorrectShiftCommand(
            originalId: original.id,
            replacementId: replacementId,
            expectedRevision: original.revision,
            voidReason: 'Synthetic end time',
          ),
        ),
      );
      final draft =
          (await work.workRepository.watchRecord(replacementId).first)!
              as ShiftRecordProjection;
      clock.now = DateTime.utc(2026, 9, 11, 19, 5);
      committed(
        await work.draftRevisions.reviseAndFinalize(
          ReviseShiftDraftCommand(
            id: replacementId,
            expectedRevision: draft.shift.revision,
            localStartDate: const LocalDate(2026, 9, 11),
            localStartTime: const LocalTime(8, 0),
            localEndDate: const LocalDate(2026, 9, 11),
            localEndTime: const LocalTime(15, 0),
            timezoneId: 'Europe/Vilnius',
            startFold: null,
            endFold: null,
            note: null,
          ),
        ),
      );

      final entries = await read(
        const LocalDate(2026, 9, 11),
        const LocalDate(2026, 9, 11),
      );
      final originalRows = entries.where(
        (entry) => entry.record.id == original.id,
      );
      expect(originalRows.map((entry) => entry.state).toSet(), {'Void'});
      expect(originalRows.every((entry) => entry.amount == null), isTrue);
      final replacementRows = entries.where(
        (entry) => entry.record.id == replacementId,
      );
      expect(replacementRows.single.kind, JournalKind.shiftFinalized);

      final day = journalDays(entries).single;
      expect(day.paidSeconds, 7 * 3600);
      expect(day.expected.minorUnits, 14000);
    },
  );

  test('day summaries are the sums of their rows', () async {
    final employment = await setUpWork();
    clock.now = DateTime.utc(2026, 9, 14, 18);
    await manual(employment, const LocalDate(2026, 9, 14), 8, 16);
    clock.now = DateTime.utc(2026, 9, 14, 19);
    await manual(employment, const LocalDate(2026, 9, 14), 17, 19);
    final period = committed(
      await work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: employment.id,
          start: const LocalDate(2026, 9, 1),
          end: const LocalDate(2026, 9, 30),
          label: null,
        ),
      ),
    );
    clock.now = DateTime.utc(2026, 9, 14, 20);
    committed(
      await work.payslips.recordPayslip(
        RecordPayslipCommand(
          periodId: period.id,
          issuedDate: const LocalDate(2026, 9, 14),
          paidDate: null,
          amountMinorUnits: 12345,
          basis: const GrossBasis(),
          grossMinorUnits: null,
          netMinorUnits: null,
          deductionMinorUnits: null,
          reference: null,
          note: null,
        ),
      ),
    );

    final entries = await read(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 14),
    );
    final day = journalDays(entries).single;
    expect(
      day.paidSeconds,
      entries.fold(0, (total, entry) => total + (entry.paidSeconds ?? 0)),
    );
    expect(day.paidSeconds, 10 * 3600);
    expect(day.expected.minorUnits, 20000);
    expect(day.paidIn.minorUnits, 12345);
  });

  test("a shift's day is read on its own timezone", () async {
    final employment = await setUpWork();
    // 23:30 UTC is 02:30 the next day in Vilnius.
    clock.now = DateTime.utc(2026, 9, 20, 23, 30);
    committed(
      await work.shifts.startShift(
        StartShiftCommand(
          employmentId: employment.id,
          timezoneId: 'Europe/Vilnius',
          note: null,
        ),
      ),
    );

    final entries = await read(
      const LocalDate(2026, 9, 21),
      const LocalDate(2026, 9, 21),
    );
    expect(entries.single.kind, JournalKind.shiftStarted);
    expect(entries.single.localDate, const LocalDate(2026, 9, 21));
    expect(
      await read(const LocalDate(2026, 9, 20), const LocalDate(2026, 9, 20)),
      isEmpty,
    );
  });
}

final class _Clock implements AppClock {
  DateTime now = DateTime.utc(2026, 9, 1, 8);

  @override
  DateTime nowUtc() => now;
}
