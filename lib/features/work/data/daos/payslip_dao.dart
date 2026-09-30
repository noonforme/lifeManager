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

  Future<List<domain.Payslip>> forPeriod(PayPeriodId id) async {
    final rows =
        await (database.select(database.payslips)
              ..where((table) => table.periodId.equals(id.value))
              ..orderBy([(table) => OrderingTerm.asc(table.issuedDate)]))
            .get();
    return rows.map(payslipFromRow).toList(growable: false);
  }

  Stream<List<PayslipRegisterRow>> watchEffectiveRows(PayPeriodId id) {
    final query = database.selectOnly(database.payslips)
      ..addColumns([
        database.payslips.id,
        database.payslips.periodId,
        database.payslips.issuedDate,
        database.payslips.amountMinorUnits,
        database.payslips.currency,
        database.payslips.basis,
        database.payslips.state,
      ])
      ..where(
        database.payslips.periodId.equals(id.value) &
            database.payslips.state.equals('effective'),
      )
      ..orderBy([OrderingTerm.asc(database.payslips.issuedDate)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => PayslipRegisterRow(
              id: PayslipId(row.read(database.payslips.id)!),
              periodId: PayPeriodId(row.read(database.payslips.periodId)!),
              issuedDate: row.read(database.payslips.issuedDate)!,
              amount: Money(
                minorUnits: row.read(database.payslips.amountMinorUnits)!,
                currency: _currency(row.read(database.payslips.currency)!),
              ),
              basis: _basis(row.read(database.payslips.basis)!),
              state: domain.PayslipState.effective,
            ),
          )
          .toList(growable: false),
    );
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

CurrencyCode _currency(String value) => switch (value) {
  'EUR' => const CurrencyCode.eur(),
  _ => throw StateError('Unsupported stored currency.'),
};

RateBasis _basis(String value) => switch (value) {
  'gross' => const GrossBasis(),
  'net' => const NetBasis(),
  _ => throw StateError('Unsupported stored pay basis.'),
};
