import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/employment.dart' as domain;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../work_converters.dart';

final class EmploymentDao {
  const EmploymentDao(this.database);

  final db.AppDatabase database;

  Future<int> insert(domain.Employment value) =>
      database.into(database.employments).insert(employmentToCompanion(value));

  Future<int> update(domain.Employment value, Revision expected) {
    return database.customUpdate(
      '''
      UPDATE employments
      SET name = ?, legal_label = ?, status = ?, updated_at_utc_micros = ?,
          revision = revision + 1
      WHERE id = ? AND revision = ?
      ''',
      variables: [
        Variable(value.name),
        Variable(value.legalLabel),
        Variable(value.status.name),
        Variable(value.updatedAtUtc.microsecondsSinceEpoch),
        Variable(value.id.value),
        Variable(expected.value),
      ],
      updates: {database.employments},
    );
  }

  Future<domain.Employment?> byId(EmploymentId id) async {
    final row = await (database.select(
      database.employments,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : employmentFromRow(row);
  }

  Future<List<domain.Employment>> active() async {
    final rows =
        await (database.select(database.employments)
              ..where((table) => table.status.equals('active'))
              ..orderBy([
                (table) => OrderingTerm.asc(table.createdAtUtcMicros),
              ]))
            .get();
    return rows.map(employmentFromRow).toList(growable: false);
  }

  Stream<domain.Employment?> watchById(EmploymentId id) {
    return (database.select(database.employments)
          ..where((table) => table.id.equals(id.value)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : employmentFromRow(row));
  }
}
