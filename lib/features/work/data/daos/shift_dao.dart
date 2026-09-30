import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../../domain/shift.dart' as domain;
import '../work_converters.dart';

final class ShiftDao {
  const ShiftDao(this.database);

  final db.AppDatabase database;

  Future<int> insert(domain.WorkShift value) =>
      database.into(database.workShifts).insert(shiftToCompanion(value));

  Future<int> insertBreak(domain.ShiftBreak value) =>
      database.into(database.shiftBreaks).insert(shiftBreakToCompanion(value));

  Future<domain.WorkShift?> byId(ShiftId id) async {
    final row = await (database.select(
      database.workShifts,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : shiftFromRow(row);
  }

  Future<domain.WorkShift?> active() async {
    final row =
        await (database.select(
              database.workShifts,
            )..where((table) => table.state.isIn(const ['running', 'onBreak'])))
            .getSingleOrNull();
    return row == null ? null : shiftFromRow(row);
  }

  Stream<domain.WorkShift?> watchActive() {
    return (database.select(database.workShifts)
          ..where((table) => table.state.isIn(const ['running', 'onBreak'])))
        .watchSingleOrNull()
        .map((row) => row == null ? null : shiftFromRow(row));
  }

  Future<List<domain.ShiftBreak>> breaksFor(ShiftId shiftId) async {
    final rows =
        await (database.select(database.shiftBreaks)
              ..where((table) => table.shiftId.equals(shiftId.value))
              ..orderBy([(table) => OrderingTerm.asc(table.startUtcMicros)]))
            .get();
    return rows.map(shiftBreakFromRow).toList(growable: false);
  }

  Future<int> endShift(
    ShiftId id, {
    required DateTime endUtc,
    required Revision expected,
  }) {
    return database.customUpdate(
      '''
      UPDATE work_shifts
      SET state = 'draft', end_utc_micros = ?, updated_at_utc_micros = ?,
          revision = revision + 1
      WHERE id = ? AND revision = ? AND state = 'running'
      ''',
      variables: [
        Variable(endUtc.microsecondsSinceEpoch),
        Variable(endUtc.microsecondsSinceEpoch),
        Variable(id.value),
        Variable(expected.value),
      ],
      updates: {database.workShifts},
    );
  }

  Future<int> setOnBreak(ShiftId id, Revision expected, DateTime updatedAtUtc) {
    return database.customUpdate(
      '''
      UPDATE work_shifts
      SET state = 'onBreak', updated_at_utc_micros = ?, revision = revision + 1
      WHERE id = ? AND revision = ? AND state = 'running'
      ''',
      variables: [
        Variable(updatedAtUtc.microsecondsSinceEpoch),
        Variable(id.value),
        Variable(expected.value),
      ],
      updates: {database.workShifts},
    );
  }

  Future<int> closeBreak(
    ShiftBreakId id, {
    required ShiftId shiftId,
    required DateTime endUtc,
    required Revision expected,
  }) {
    return database.customUpdate(
      '''
      UPDATE shift_breaks
      SET end_utc_micros = ?, updated_at_utc_micros = ?, revision = revision + 1
      WHERE id = ? AND shift_id = ? AND revision = ? AND end_utc_micros IS NULL
      ''',
      variables: [
        Variable(endUtc.microsecondsSinceEpoch),
        Variable(endUtc.microsecondsSinceEpoch),
        Variable(id.value),
        Variable(shiftId.value),
        Variable(expected.value),
      ],
      updates: {database.shiftBreaks},
    );
  }

  Future<int> setRunning(ShiftId id, Revision expected, DateTime updatedAtUtc) {
    return database.customUpdate(
      '''
      UPDATE work_shifts
      SET state = 'running', updated_at_utc_micros = ?, revision = revision + 1
      WHERE id = ? AND revision = ? AND state = 'onBreak'
      ''',
      variables: [
        Variable(updatedAtUtc.microsecondsSinceEpoch),
        Variable(id.value),
        Variable(expected.value),
      ],
      updates: {database.workShifts},
    );
  }

  Future<int> finalize(domain.WorkShift value, {required Revision expected}) {
    return database.customUpdate(
      '''
      UPDATE work_shifts
      SET agreement_id = ?, state = 'finalized', updated_at_utc_micros = ?,
          revision = revision + 1
      WHERE id = ? AND revision = ? AND state = 'draft'
      ''',
      variables: [
        Variable(value.agreementId!.value),
        Variable(value.updatedAtUtc.microsecondsSinceEpoch),
        Variable(value.id.value),
        Variable(expected.value),
      ],
      updates: {database.workShifts},
    );
  }

  Future<int> voidForCorrection(
    domain.WorkShift value, {
    required Revision expected,
  }) {
    return database.customUpdate(
      '''
      UPDATE work_shifts
      SET state = 'voided', void_reason = ?, replacement_shift_id = ?,
          updated_at_utc_micros = ?, revision = revision + 1
      WHERE id = ? AND revision = ? AND state = 'finalized'
      ''',
      variables: [
        Variable(value.voidReason),
        Variable(value.replacementShiftId!.value),
        Variable(value.updatedAtUtc.microsecondsSinceEpoch),
        Variable(value.id.value),
        Variable(expected.value),
      ],
      updates: {database.workShifts},
    );
  }
}
