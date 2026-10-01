import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../../domain/pay_period.dart' as domain;
import '../work_converters.dart';

final class PayPeriodDao {
  const PayPeriodDao(this.database);

  final db.AppDatabase database;

  Future<int> insert(domain.PayPeriod value) =>
      database.into(database.payPeriods).insert(payPeriodToCompanion(value));

  Future<domain.PayPeriod?> byId(PayPeriodId id) async {
    final row = await (database.select(
      database.payPeriods,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : payPeriodFromRow(row);
  }

  Future<List<domain.PayPeriod>> forEmployment(EmploymentId id) async {
    final rows =
        await (database.select(database.payPeriods)
              ..where((table) => table.employmentId.equals(id.value))
              ..orderBy([(table) => OrderingTerm.asc(table.start)]))
            .get();
    return rows.map(payPeriodFromRow).toList(growable: false);
  }

  Stream<List<domain.PayPeriod>> watchForEmployment(EmploymentId id) =>
      (database.select(database.payPeriods)
            ..where((table) => table.employmentId.equals(id.value))
            ..orderBy([(table) => OrderingTerm.asc(table.start)]))
          .watch()
          .map((rows) => rows.map(payPeriodFromRow).toList(growable: false));

  Future<int> setState(
    PayPeriodId id, {
    required domain.PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  }) {
    return database.customUpdate(
      '''
      UPDATE pay_periods
      SET state = ?, updated_at_utc_micros = ?, revision = revision + 1
      WHERE id = ? AND revision = ?
      ''',
      variables: [
        Variable(state.name),
        Variable(nowUtc.microsecondsSinceEpoch),
        Variable(id.value),
        Variable(expected.value),
      ],
      updates: {database.payPeriods},
    );
  }
}
