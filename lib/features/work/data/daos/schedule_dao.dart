import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/time/local_date.dart';
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../../domain/schedule.dart';
import '../work_converters.dart';

/// Schedule versions with their shift types and cycle blocks.
final class ScheduleDao {
  const ScheduleDao(this.database);

  final db.AppDatabase database;

  /// Every version of every schedule of the employment, by id then version.
  Future<List<WorkSchedule>> forEmployment(EmploymentId id) async {
    final rows =
        await (database.select(database.workSchedules)
              ..where((table) => table.employmentId.equals(id.value))
              ..orderBy([
                (table) => OrderingTerm.asc(table.id),
                (table) => OrderingTerm.asc(table.version),
              ]))
            .get();
    return [for (final row in rows) await _withParts(row)];
  }

  /// Every version of one schedule, oldest first.
  Future<List<WorkSchedule>> versionsOf(ScheduleId id) async {
    final rows =
        await (database.select(database.workSchedules)
              ..where((table) => table.id.equals(id.value))
              ..orderBy([(table) => OrderingTerm.asc(table.version)]))
            .get();
    return [for (final row in rows) await _withParts(row)];
  }

  /// One version, or null.
  Future<WorkSchedule?> version(ScheduleId id, int version) async {
    final row =
        await (database.select(database.workSchedules)..where(
              (table) =>
                  table.id.equals(id.value) & table.version.equals(version),
            ))
            .getSingleOrNull();
    return row == null ? null : _withParts(row);
  }

  /// Whether a confirmed day was planned from any version of [id].
  Future<bool> scheduleUsed(ScheduleId id) async {
    final row = await database
        .customSelect(
          'SELECT EXISTS (SELECT 1 FROM work_shifts WHERE schedule_id = ?1 '
          "AND state <> 'voided') OR EXISTS (SELECT 1 FROM work_leave_records "
          "WHERE schedule_id = ?1 AND state = 'confirmed') AS used",
          variables: [Variable(id.value)],
        )
        .getSingle();
    return row.read<bool>('used');
  }

  Future<void> insertVersion(WorkSchedule value) async {
    await database
        .into(database.workSchedules)
        .insert(scheduleToCompanion(value));
    await _insertParts(value);
  }

  /// Rewrites an unused version in place; 0 when the revision moved on.
  Future<int> replaceVersion(
    WorkSchedule value, {
    required Revision expected,
  }) async {
    final changed = await database.customUpdate(
      'UPDATE work_schedules SET name = ?, timezone_id = ?, cycle_start = ?, '
      'in_use_from = ?, in_use_until = ?, revision = revision + 1 '
      'WHERE id = ? AND version = ? AND revision = ?',
      variables: [
        Variable(value.name),
        Variable(value.timezoneId),
        Variable(value.cycleStart.toString()),
        Variable(value.inUseFrom.toString()),
        Variable(value.inUseUntil?.toString()),
        Variable(value.id.value),
        Variable(value.version),
        Variable(expected.value),
      ],
      updates: {database.workSchedules},
    );
    if (changed == 0) return 0;
    await _deleteParts(value.id, value.version);
    await _insertParts(value);
    return changed;
  }

  /// Ends a version on [until]; 0 when the revision moved on.
  Future<int> closeVersion(
    ScheduleId id,
    int version,
    LocalDate until, {
    required Revision expected,
  }) => database.customUpdate(
    'UPDATE work_schedules SET in_use_until = ?, revision = revision + 1 '
    'WHERE id = ? AND version = ? AND revision = ?',
    variables: [
      Variable(until.toString()),
      Variable(id.value),
      Variable(version),
      Variable(expected.value),
    ],
    updates: {database.workSchedules},
  );

  /// Deletes every version; types and blocks cascade.
  Future<int> deleteSchedule(ScheduleId id) => (database.delete(
    database.workSchedules,
  )..where((table) => table.id.equals(id.value))).go();

  Future<WorkSchedule> _withParts(db.WorkSchedule row) async {
    final types =
        await (database.select(database.workScheduleShiftTypes)
              ..where(
                (table) =>
                    table.scheduleId.equals(row.id) &
                    table.scheduleVersion.equals(row.version),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    final blocks =
        await (database.select(database.workScheduleBlocks)
              ..where(
                (table) =>
                    table.scheduleId.equals(row.id) &
                    table.scheduleVersion.equals(row.version),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.position)]))
            .get();
    final used = await database
        .customSelect(
          'SELECT EXISTS (SELECT 1 FROM work_shifts WHERE schedule_id = ?1 '
          "AND schedule_version = ?2 AND state <> 'voided') OR EXISTS "
          '(SELECT 1 FROM work_leave_records WHERE schedule_id = ?1 '
          "AND schedule_version = ?2 AND state = 'confirmed') AS used",
          variables: [Variable(row.id), Variable(row.version)],
        )
        .getSingle();
    return scheduleFromRows(
      row,
      types: types,
      blocks: blocks,
      usedByConfirmedDay: used.read<bool>('used'),
    );
  }

  Future<void> _insertParts(WorkSchedule value) async {
    for (final type in shiftTypesToCompanions(value)) {
      await database.into(database.workScheduleShiftTypes).insert(type);
    }
    for (final block in blocksToCompanions(value)) {
      await database.into(database.workScheduleBlocks).insert(block);
    }
  }

  Future<void> _deleteParts(ScheduleId id, int version) async {
    await (database.delete(database.workScheduleShiftTypes)..where(
          (table) =>
              table.scheduleId.equals(id.value) &
              table.scheduleVersion.equals(version),
        ))
        .go();
    await (database.delete(database.workScheduleBlocks)..where(
          (table) =>
              table.scheduleId.equals(id.value) &
              table.scheduleVersion.equals(version),
        ))
        .go();
  }
}
