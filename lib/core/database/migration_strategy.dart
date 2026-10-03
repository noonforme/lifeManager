import 'package:drift/drift.dart';

import 'app_database.dart';
import 'database_identity.dart';

MigrationStrategy lifeOsMigrationStrategy(AppDatabase database) {
  Future<void> scheduleIndexes() async {
    await database.customStatement(
      'CREATE UNIQUE INDEX one_confirmed_shift_per_planned_day '
      'ON work_shifts (employment_id, planned_date) '
      "WHERE planned_date IS NOT NULL AND state = 'finalized'",
    );
    await database.customStatement(
      'CREATE UNIQUE INDEX one_confirmed_leave_per_day '
      'ON work_leave_records (employment_id, date) '
      "WHERE state = 'confirmed'",
    );
  }

  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await scheduleIndexes();
      await database.customStatement(
        'CREATE INDEX record_events_by_record '
        'ON record_events (record_kind, record_id, id)',
      );
      await database
          .into(database.coreMetadata)
          .insert(const CoreMetadataCompanion(id: Value(1)));
    },
    // The released schema 1 moves to 3 (schedules). Anything else is from
    // a development build and was refused before Drift opened it.
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 3) {
        throw DatabaseFromEarlierBuild(from: from, to: to);
      }
      // Drift runs migrations outside a transaction; one keeps a failed
      // upgrade from leaving a half-migrated file behind.
      await database.transaction(() async {
        for (final table in <TableInfo<Table, dynamic>>[
          database.workSchedules,
          database.workScheduleShiftTypes,
          database.workScheduleBlocks,
          database.workDayExceptions,
          database.workLeaveRecords,
        ]) {
          await migrator.createTable(table);
        }
        final shifts = database.workShifts;
        for (final column in <GeneratedColumn<Object>>[
          shifts.scheduleId,
          shifts.scheduleVersion,
          shifts.plannedDate,
          shifts.plannedStartUtcMicros,
          shifts.plannedEndUtcMicros,
          shifts.isExtra,
          shifts.extraCountsAsOvertime,
        ]) {
          await migrator.addColumn(shifts, column);
        }
        final agreements = database.payAgreements;
        for (final column in <GeneratedColumn<Object>>[
          agreements.vacationPayNumerator,
          agreements.vacationPayDenominator,
          agreements.sickPayNumerator,
          agreements.sickPayDenominator,
          agreements.sickEmployerDays,
        ]) {
          await migrator.addColumn(agreements, column);
        }
        // The live tracker is gone (spec 3.8): a shift still running becomes
        // a draft to finish by hand; an unfinished break is dropped.
        await database.customStatement(
          'DELETE FROM shift_breaks WHERE end_utc_micros IS NULL',
        );
        await database.customStatement(
          "UPDATE work_shifts SET state = 'draft' "
          "WHERE state IN ('running', 'onBreak')",
        );
        await database.customStatement('DROP INDEX IF EXISTS one_active_shift');
        await scheduleIndexes();
      });
    },
    beforeOpen: (details) async {
      await database.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
