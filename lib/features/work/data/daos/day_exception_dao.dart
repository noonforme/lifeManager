import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/day_exception.dart';
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../work_converters.dart';

/// Owner changes to single planned dates.
final class DayExceptionDao {
  const DayExceptionDao(this.database);

  final db.AppDatabase database;

  Future<List<DayException>> forEmployment(EmploymentId id) async {
    final rows =
        await (database.select(database.workDayExceptions)
              ..where((table) => table.employmentId.equals(id.value))
              ..orderBy([(table) => OrderingTerm.asc(table.date)]))
            .get();
    return rows.map(dayExceptionFromRow).toList(growable: false);
  }

  Future<DayException?> byId(DayExceptionId id) async {
    final row = await (database.select(
      database.workDayExceptions,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : dayExceptionFromRow(row);
  }

  Future<void> insert(DayException value) => database
      .into(database.workDayExceptions)
      .insert(dayExceptionToCompanion(value));

  /// Replaces the exception's content, any kind for any kind; 0 when the
  /// revision moved on.
  Future<int> replace(DayException value, {required Revision expected}) =>
      (database.update(database.workDayExceptions)..where(
            (table) =>
                table.id.equals(value.id.value) &
                table.revision.equals(expected.value),
          ))
          .write(
            // Clear every kind's columns, then set this kind's.
            const db.WorkDayExceptionsCompanion(
              startMinute: Value(null),
              endMinute: Value(null),
              endDayOffset: Value(null),
              breaks: Value(null),
              shiftTypeId: Value(null),
              reason: Value(null),
              note: Value(null),
              leaveType: Value(null),
              illnessStartedOn: Value(null),
              countsAsOvertime: Value(false),
            ),
          )
          .then((changed) async {
            if (changed == 0) return 0;
            await (database.update(database.workDayExceptions)
                  ..where((table) => table.id.equals(value.id.value)))
                .write(dayExceptionToCompanion(value));
            return changed;
          });

  /// 0 when the revision moved on.
  Future<int> delete(DayExceptionId id, {required Revision expected}) =>
      (database.delete(database.workDayExceptions)..where(
            (table) =>
                table.id.equals(id.value) &
                table.revision.equals(expected.value),
          ))
          .go();
}
