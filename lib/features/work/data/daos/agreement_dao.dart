import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../domain/agreement.dart' as domain;
import '../../domain/facts.dart';
import '../../domain/ids.dart';
import '../work_converters.dart';

final class AgreementDao {
  const AgreementDao(this.database);

  final db.AppDatabase database;

  Future<int> insert(domain.PayAgreement value) =>
      database.into(database.payAgreements).insert(agreementToCompanion(value));

  Future<int> updateUnused(domain.PayAgreement value, Revision expected) {
    return database.customUpdate(
      '''
      UPDATE pay_agreements
      SET version = ?, effective_start = ?, effective_end = ?,
          hourly_rate_micro_eur = ?, basis = ?,
          overtime_threshold_minutes = ?,
          overtime_multiplier_numerator = ?,
          overtime_multiplier_denominator = ?,
          night_enabled = ?, night_start_minute = ?, night_end_minute = ?,
          night_multiplier_numerator = ?, night_multiplier_denominator = ?,
          holiday_calendar = ?, holiday_multiplier_numerator = ?,
          holiday_multiplier_denominator = ?, premium_stacking = ?,
          label = ?, note = ?,
          revision = revision + 1
      WHERE id = ? AND revision = ?
        AND NOT EXISTS (
          SELECT 1 FROM work_shifts
          WHERE agreement_id = pay_agreements.id
            AND state IN ('finalized', 'voided')
        )
      ''',
      variables: [
        Variable(value.version),
        Variable(value.effectiveStart.toString()),
        Variable(value.effectiveEnd?.toString()),
        Variable(value.hourlyRateMicroEur),
        Variable(_basisText(value.basis)),
        Variable(value.overtimeThresholdMinutes),
        Variable(value.overtimeMultiplier.numerator),
        Variable(value.overtimeMultiplier.denominator),
        Variable(value.nightEnabled),
        Variable(value.nightStartMinute),
        Variable(value.nightEndMinute),
        Variable(value.nightMultiplier.numerator),
        Variable(value.nightMultiplier.denominator),
        Variable(holidayCalendarText(value.holidayCalendar)),
        Variable(value.holidayMultiplier.numerator),
        Variable(value.holidayMultiplier.denominator),
        Variable(premiumStackingText(value.premiumStacking)),
        Variable(value.label),
        Variable(value.note),
        Variable(value.id.value),
        Variable(expected.value),
      ],
      updates: {database.payAgreements},
    );
  }

  Future<domain.PayAgreement?> byId(AgreementId id) async {
    final row = await (database.select(
      database.payAgreements,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    if (row == null) return null;
    return agreementFromRow(
      row,
      usedByFinalizedShift: await finishedShiftCount(id) > 0,
    );
  }

  /// Shifts whose pay this agreement fixed: finalized ones and the voided
  /// originals they replaced.
  Future<int> finishedShiftCount(AgreementId id) async {
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM work_shifts '
          "WHERE agreement_id = ? AND state IN ('finalized', 'voided')",
          variables: [Variable(id.value)],
          readsFrom: {database.workShifts},
        )
        .getSingle();
    return row.read<int>('count');
  }

  Future<List<domain.PayAgreement>> forEmployment(EmploymentId id) async {
    final rows = await _rowsFor(id).get();
    return _decodeRows(rows, await _usedAgreementIds(id));
  }

  Stream<List<domain.PayAgreement>> watchForEmployment(EmploymentId id) {
    final query = database.select(database.payAgreements).join([
      leftOuterJoin(
        database.workShifts,
        database.workShifts.agreementId.equalsExp(database.payAgreements.id) &
            database.workShifts.state.isIn(const ['finalized', 'voided']),
      ),
    ])..where(database.payAgreements.employmentId.equals(id.value));
    return query.watch().map((rows) {
      final byId = <String, ({db.PayAgreement row, bool used})>{};
      for (final result in rows) {
        final agreement = result.readTable(database.payAgreements);
        byId[agreement.id] = (
          row: agreement,
          used:
              byId[agreement.id]?.used == true ||
              result.readTableOrNull(database.workShifts) != null,
        );
      }
      final values = byId.values.toList(growable: false)
        ..sort(
          (left, right) =>
              left.row.effectiveStart.compareTo(right.row.effectiveStart),
        );
      return values
          .map(
            (value) =>
                agreementFromRow(value.row, usedByFinalizedShift: value.used),
          )
          .toList(growable: false);
    });
  }

  SimpleSelectStatement<db.$PayAgreementsTable, db.PayAgreement> _rowsFor(
    EmploymentId id,
  ) => database.select(database.payAgreements)
    ..where((table) => table.employmentId.equals(id.value))
    ..orderBy([(table) => OrderingTerm.asc(table.effectiveStart)]);

  Future<Set<String>> _usedAgreementIds(EmploymentId employmentId) async {
    final rows =
        await (database.selectOnly(database.workShifts, distinct: true)
              ..addColumns([database.workShifts.agreementId])
              ..where(
                database.workShifts.employmentId.equals(employmentId.value) &
                    database.workShifts.agreementId.isNotNull() &
                    database.workShifts.state.isIn(const [
                      'finalized',
                      'voided',
                    ]),
              ))
            .get();
    return {
      for (final row in rows)
        if (row.read(database.workShifts.agreementId) case final String id) id,
    };
  }

  List<domain.PayAgreement> _decodeRows(
    List<db.PayAgreement> rows,
    Set<String> usedAgreementIds,
  ) => rows
      .map(
        (row) => agreementFromRow(
          row,
          usedByFinalizedShift: usedAgreementIds.contains(row.id),
        ),
      )
      .toList(growable: false);
}

String _basisText(RateBasis value) => switch (value) {
  GrossBasis() => 'gross',
  NetBasis() => 'net',
};
