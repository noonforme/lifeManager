import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../../domain/leave.dart';
import '../work_converters.dart';

/// Confirmed and voided leave days.
final class LeaveDao {
  const LeaveDao(this.database);

  final db.AppDatabase database;

  Future<List<LeaveRecord>> forEmployment(EmploymentId id) async {
    final rows =
        await (database.select(database.workLeaveRecords)
              ..where((table) => table.employmentId.equals(id.value))
              ..orderBy([(table) => OrderingTerm.asc(table.date)]))
            .get();
    return rows.map(leaveFromRow).toList(growable: false);
  }

  Future<LeaveRecord?> byId(LeaveRecordId id) async {
    final row = await (database.select(
      database.workLeaveRecords,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : leaveFromRow(row);
  }

  Future<void> insert(LeaveRecord value) =>
      database.into(database.workLeaveRecords).insert(leaveToCompanion(value));

  /// Voids a confirmed record without naming its replacement yet, so the
  /// replacement can take the date (one confirmed leave per date); 0 when
  /// the revision moved on.
  Future<int> voidConfirmed(
    LeaveRecordId id, {
    required Revision expected,
    required String reason,
    required DateTime nowUtc,
  }) => database.customUpdate(
    "UPDATE work_leave_records SET state = 'voided', void_reason = ?, "
    'updated_at_utc_micros = ?, revision = revision + 1 '
    "WHERE id = ? AND revision = ? AND state = 'confirmed'",
    variables: [
      Variable(reason),
      Variable(nowUtc.microsecondsSinceEpoch),
      Variable(id.value),
      Variable(expected.value),
    ],
    updates: {database.workLeaveRecords},
  );

  Future<void> linkReplacement(LeaveRecordId id, LeaveRecordId replacement) =>
      database.customUpdate(
        'UPDATE work_leave_records SET replacement_leave_id = ? WHERE id = ?',
        variables: [Variable(replacement.value), Variable(id.value)],
        updates: {database.workLeaveRecords},
      );
}
