import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart' as db;
import '../../../../core/time/local_date.dart';
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
          vacation_pay_numerator = ?, vacation_pay_denominator = ?,
          sick_pay_numerator = ?, sick_pay_denominator = ?,
          sick_employer_days = ?,
          label = ?, note = ?,
          revision = revision + 1
      WHERE id = ? AND revision = ?
        AND NOT EXISTS (
          SELECT 1 FROM work_shifts
          WHERE agreement_id = pay_agreements.id
            AND state IN ('finalized', 'voided')
        )
        AND NOT EXISTS (
          SELECT 1 FROM work_leave_records
          WHERE agreement_id = pay_agreements.id
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
        Variable(value.vacationPay.numerator),
        Variable(value.vacationPay.denominator),
        Variable(value.sickPay.numerator),
        Variable(value.sickPay.denominator),
        Variable(value.sickEmployerDays),
        Variable(value.label),
        Variable(value.note),
        Variable(value.id.value),
        Variable(expected.value),
      ],
      updates: {database.payAgreements},
    );
  }

  /// Moves only the dates; whether the move keeps every used date inside
  /// is the caller's rule.
  Future<int> updateRange(domain.PayAgreement value, Revision expected) =>
      database.customUpdate(
        'UPDATE pay_agreements '
        'SET effective_start = ?, effective_end = ?, revision = revision + 1 '
        'WHERE id = ? AND revision = ?',
        variables: [
          Variable(value.effectiveStart.toString()),
          Variable(value.effectiveEnd?.toString()),
          Variable(value.id.value),
          Variable(expected.value),
        ],
        updates: {database.payAgreements},
      );

  /// Deletes the agreement while no shift (a draft included) and no leave
  /// refers to it.
  Future<int> deleteUnused(AgreementId id, Revision expected) =>
      database.customUpdate(
        '''
      DELETE FROM pay_agreements
      WHERE id = ? AND revision = ?
        AND NOT EXISTS (
          SELECT 1 FROM work_shifts WHERE agreement_id = pay_agreements.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM work_leave_records
          WHERE agreement_id = pay_agreements.id
        )
      ''',
        variables: [Variable(id.value), Variable(expected.value)],
        updates: {database.payAgreements},
        updateKind: UpdateKind.delete,
      );

  /// The latest local date a finalized shift or confirmed leave was paid
  /// under the agreement. Dates are ISO text, so the greatest sorts last.
  Future<LocalDate?> lastUse(AgreementId id) async {
    final row = await database
        .customSelect(
          'SELECT MAX(day) AS last FROM ('
          'SELECT local_start_date AS day FROM work_shifts '
          "WHERE agreement_id = ? AND state = 'finalized' "
          'UNION ALL '
          'SELECT date AS day FROM work_leave_records '
          "WHERE agreement_id = ? AND state = 'confirmed')",
          variables: [Variable(id.value), Variable(id.value)],
          readsFrom: {database.workShifts, database.workLeaveRecords},
        )
        .getSingle();
    final last = row.readNullable<String>('last');
    return last == null ? null : LocalDate.parse(last);
  }

  Future<domain.PayAgreement?> byId(AgreementId id) async {
    final row = await (database.select(
      database.payAgreements,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();
    if (row == null) return null;
    return agreementFromRow(
      row,
      usedByFinalizedShift:
          await finishedShiftCount(id) > 0 || await _usedByLeave(id),
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

  /// Leave records are evidence too: confirmed leave was priced by this
  /// agreement, and voided leave was replaced against it.
  Future<bool> _usedByLeave(AgreementId id) async {
    final row = await database
        .customSelect(
          'SELECT EXISTS (SELECT 1 FROM work_leave_records '
          'WHERE agreement_id = ?) AS used',
          variables: [Variable(id.value)],
          readsFrom: {database.workLeaveRecords},
        )
        .getSingle();
    return row.read<bool>('used');
  }

  Future<List<domain.PayAgreement>> forEmployment(EmploymentId id) async {
    final rows = await _rowsFor(id).get();
    return _decodeRows(rows, await _usedAgreementIds(id));
  }

  /// Re-reads whenever agreements, shifts or leave change, since either can
  /// put an agreement in use.
  Stream<List<domain.PayAgreement>> watchForEmployment(EmploymentId id) async* {
    yield await forEmployment(id);
    await for (final _ in database.tableUpdates(
      TableUpdateQuery.onAllTables([
        database.payAgreements,
        database.workShifts,
        database.workLeaveRecords,
      ]),
    )) {
      yield await forEmployment(id);
    }
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
    final leave = await database
        .customSelect(
          'SELECT DISTINCT agreement_id FROM work_leave_records '
          'WHERE employment_id = ?',
          variables: [Variable(employmentId.value)],
          readsFrom: {database.workLeaveRecords},
        )
        .get();
    return {
      for (final row in rows)
        if (row.read(database.workShifts.agreementId) case final String id) id,
      for (final row in leave) row.read<String>('agreement_id'),
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
