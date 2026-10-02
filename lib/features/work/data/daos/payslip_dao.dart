import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../../domain/pay.dart';
import '../../domain/payslip.dart' as domain;
import '../work_converters.dart';

final class PayslipRegisterRow {
  const PayslipRegisterRow({
    required this.id,
    required this.periodId,
    required this.issuedDate,
    required this.amount,
    required this.basis,
    required this.state,
  });

  final PayslipId id;
  final PayPeriodId periodId;
  final String issuedDate;
  final Money amount;
  final RateBasis basis;
  final domain.PayslipState state;
  String? get note => null;
}

final class PayslipDao {
  const PayslipDao(this.database);

  final db.AppDatabase database;

  Future<int> insert(domain.Payslip value) =>
      database.into(database.payslips).insert(payslipToCompanion(value));

  Future<domain.Payslip?> byId(PayslipId id) async {
    final row = await (database.select(
      database.payslips,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : payslipFromRow(row);
  }

  /// Every payslip in the employment's pay periods, effective or void.
  Future<List<domain.Payslip>> forEmployment(EmploymentId id) async {
    final query =
        database.select(database.payslips).join([
            innerJoin(
              database.payPeriods,
              database.payPeriods.id.equalsExp(database.payslips.periodId),
            ),
          ])
          ..where(database.payPeriods.employmentId.equals(id.value))
          ..orderBy([OrderingTerm.asc(database.payslips.issuedDate)]);
    final rows = await query.get();
    return [
      for (final row in rows) payslipFromRow(row.readTable(database.payslips)),
    ];
  }

  Future<int> voidForCorrection(
    domain.Payslip value, {
    required Revision expected,
  }) {
    return database.customUpdate(
      '''
      UPDATE payslips
      SET state = 'voided', void_reason = ?, replacement_payslip_id = ?,
          updated_at_utc_micros = ?, revision = revision + 1
      WHERE id = ? AND revision = ? AND state = 'effective'
      ''',
      variables: [
        Variable(value.voidReason),
        Variable(value.replacementPayslipId!.value),
        Variable(value.updatedAtUtc.microsecondsSinceEpoch),
        Variable(value.id.value),
        Variable(expected.value),
      ],
      updates: {database.payslips},
    );
  }
}
