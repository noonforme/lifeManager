import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../../domain/shift.dart' as domain;
import '../work_converters.dart';

final class ShiftRegisterRow {
  const ShiftRegisterRow({
    required this.id,
    required this.localStartDate,
    required this.startUtc,
    required this.endUtc,
    required this.state,
  });

  final ShiftId id;
  final String localStartDate;
  final DateTime startUtc;
  final DateTime? endUtc;
  final domain.ShiftState state;
  String? get note => null;
}

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

  Future<List<domain.WorkShift>> finalizedForRange(
    EmploymentId employmentId, {
    required String start,
    required String end,
  }) async {
    final rows =
        await (database.select(database.workShifts)
              ..where(
                (table) =>
                    table.employmentId.equals(employmentId.value) &
                    table.state.equals('finalized') &
                    table.localStartDate.isBiggerOrEqualValue(start) &
                    table.localStartDate.isSmallerOrEqualValue(end),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.startUtcMicros)]))
            .get();
    return rows.map(shiftFromRow).toList(growable: false);
  }

  Stream<List<ShiftRegisterRow>> watchRowsForRange(
    EmploymentId employmentId, {
    required String start,
    required String end,
  }) {
    final query = database.selectOnly(database.workShifts)
      ..addColumns([
        database.workShifts.id,
        database.workShifts.localStartDate,
        database.workShifts.startUtcMicros,
        database.workShifts.endUtcMicros,
        database.workShifts.state,
      ])
      ..where(
        database.workShifts.employmentId.equals(employmentId.value) &
            database.workShifts.localStartDate.isBiggerOrEqualValue(start) &
            database.workShifts.localStartDate.isSmallerOrEqualValue(end) &
            database.workShifts.state.equals('finalized'),
      )
      ..orderBy([OrderingTerm.asc(database.workShifts.startUtcMicros)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ShiftRegisterRow(
              id: ShiftId(row.read(database.workShifts.id)!),
              localStartDate: row.read(database.workShifts.localStartDate)!,
              startUtc: DateTime.fromMicrosecondsSinceEpoch(
                row.read(database.workShifts.startUtcMicros)!,
                isUtc: true,
              ),
              endUtc: _nullableUtc(row.read(database.workShifts.endUtcMicros)),
              state: domain.ShiftState.finalized,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<domain.ShiftBreak>> breaksForShifts(
    Iterable<ShiftId> shiftIds,
  ) async {
    final ids = shiftIds.map((id) => id.value).toList(growable: false);
    if (ids.isEmpty) return const [];
    final rows =
        await (database.select(database.shiftBreaks)
              ..where((table) => table.shiftId.isIn(ids))
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

  Future<int> setOvertime(
    ShiftId id, {
    required int overtimeMinutes,
    required Revision expected,
    required DateTime updatedAtUtc,
  }) {
    return database.customUpdate(
      '''
      UPDATE work_shifts
      SET overtime_minutes = ?, updated_at_utc_micros = ?
      WHERE id = ? AND revision = ? AND state = 'draft'
      ''',
      variables: [
        Variable(overtimeMinutes),
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

DateTime? _nullableUtc(int? microseconds) => microseconds == null
    ? null
    : DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
