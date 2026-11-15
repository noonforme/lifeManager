import 'dart:async';

import 'package:drift/drift.dart' show Table, TableInfo, TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart' show AppDatabase;
import '../../core/streams/watch_reads.dart';
import '../../core/time/local_date.dart';
import '../../features/work/data/daos/agreement_dao.dart';
import '../../features/work/data/daos/employment_dao.dart';
import '../../features/work/data/daos/pay_period_dao.dart';
import '../../features/work/data/daos/payslip_dao.dart';
import '../../features/work/data/daos/schedule_dao.dart';
import '../../features/work/data/daos/shift_dao.dart';
import '../../features/work/data/work_history.dart' show scheduleRecordId;
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/employment.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay_period.dart';
import '../../features/work/domain/payslip.dart';
import '../../features/work/domain/schedule.dart';
import '../../features/work/domain/shift.dart';

/// A stored shift with its breaks: the parent and children one edit
/// session saves together (spec 4.2). Two records are equal when they are
/// the same shift at the same revision and state.
@immutable
final class ShiftRecord {
  const ShiftRecord({required this.shift, required this.breaks});

  final WorkShift shift;
  final List<ShiftBreak> breaks;

  @override
  bool operator ==(Object other) =>
      other is ShiftRecord &&
      other.shift.id == shift.id &&
      other.shift.revision == shift.revision &&
      other.shift.state == shift.state;

  @override
  int get hashCode => Object.hash(shift.id, shift.revision, shift.state);
}

/// A stored employment, equal to another at the same id and revision.
@immutable
final class EmploymentRecord {
  const EmploymentRecord(this.value);

  final Employment value;

  @override
  bool operator ==(Object other) =>
      other is EmploymentRecord &&
      other.value.id == value.id &&
      other.value.revision == value.revision;

  @override
  int get hashCode => Object.hash(value.id, value.revision);
}

/// A stored pay agreement, equal to another at the same id and revision.
@immutable
final class AgreementRecord {
  const AgreementRecord(this.value);

  final PayAgreement value;

  @override
  bool operator ==(Object other) =>
      other is AgreementRecord &&
      other.value.id == value.id &&
      other.value.revision == value.revision;

  @override
  int get hashCode => Object.hash(value.id, value.revision);
}

/// How many records each of an employment's sheets lists, for the Work
/// tree: shifts and leave not void, schedules (not their versions), pay
/// periods, payslips in effect, agreement versions.
@immutable
final class SheetCounts {
  const SheetCounts({
    required this.shifts,
    required this.leave,
    required this.schedules,
    required this.periods,
    required this.payslips,
    required this.agreements,
  });

  static const none = SheetCounts(
    shifts: 0,
    leave: 0,
    schedules: 0,
    periods: 0,
    payslips: 0,
    agreements: 0,
  );

  final int shifts;
  final int leave;
  final int schedules;
  final int periods;
  final int payslips;
  final int agreements;

  @override
  bool operator ==(Object other) =>
      other is SheetCounts &&
      other.shifts == shifts &&
      other.leave == leave &&
      other.schedules == schedules &&
      other.periods == periods &&
      other.payslips == payslips &&
      other.agreements == agreements;

  @override
  int get hashCode =>
      Object.hash(shifts, leave, schedules, periods, payslips, agreements);
}

/// An employment and how many records each of its sheets lists, for the
/// Employments sheet and the Work tree.
@immutable
final class EmploymentSummary {
  const EmploymentSummary(
    this.employment, {
    required this.counts,
    required this.hasHistory,
  });

  final Employment employment;
  final SheetCounts counts;

  /// Whether work is recorded for it (shifts of any state, pay periods,
  /// schedules, day changes, leave, payslips): then it can only be
  /// archived, never deleted.
  final bool hasHistory;

  /// Its pay agreement versions.
  int get agreements => counts.agreements;
}

/// One version of a pay agreement as the Agreements sheet lists it, with
/// what it paid: finished shifts (and the void originals they replaced),
/// whether leave was priced under it, and the first and last days it paid.
@immutable
final class AgreementRow {
  const AgreementRow({
    required this.agreement,
    required this.paidShifts,
    required this.paysLeave,
    required this.firstUse,
    required this.lastUse,
  });

  final PayAgreement agreement;
  final int paidShifts;
  final bool paysLeave;
  final LocalDate? firstUse;
  final LocalDate? lastUse;

  /// Evidence for what it paid: it cannot be removed, and correcting it
  /// reprices.
  bool get inUse => agreement.usedByFinalizedShift;

  @override
  bool operator ==(Object other) =>
      other is AgreementRow &&
      other.agreement.id == agreement.id &&
      other.agreement.revision == agreement.revision &&
      other.agreement.usedByFinalizedShift == agreement.usedByFinalizedShift &&
      other.paidShifts == paidShifts &&
      other.paysLeave == paysLeave &&
      other.firstUse == firstUse &&
      other.lastUse == lastUse;

  @override
  int get hashCode => Object.hash(
    agreement.id,
    agreement.revision,
    paidShifts,
    paysLeave,
    firstUse,
    lastUse,
  );
}

/// A stored schedule version: what one schedule edit session saves (spec
/// 4.2). Two records are equal when they are the same version at the same
/// revision.
@immutable
final class ScheduleRecord {
  const ScheduleRecord(this.value);

  final WorkSchedule value;

  @override
  bool operator ==(Object other) =>
      other is ScheduleRecord &&
      other.value.id == value.id &&
      other.value.version == value.version &&
      other.value.revision == value.revision;

  @override
  int get hashCode => Object.hash(value.id, value.version, value.revision);
}

/// One version of a schedule as the Schedules sheet lists it, with the
/// days confirmed from it.
@immutable
final class ScheduleRow {
  const ScheduleRow({
    required this.schedule,
    required this.confirmedDays,
    required this.lastConfirmed,
    required this.latest,
  });

  final WorkSchedule schedule;

  /// Planned dates confirmed from this version, as a shift or as leave.
  final int confirmedDays;
  final LocalDate? lastConfirmed;

  /// Whether it is its schedule's latest version, the only one changed.
  final bool latest;

  /// Its row id, `<schedule id>@<version>`.
  String get rowId => scheduleRecordId(schedule);

  /// Confirmed days use it: it is never edited in place.
  bool get used => schedule.usedByConfirmedDay;

  @override
  bool operator ==(Object other) =>
      other is ScheduleRow &&
      other.schedule.id == schedule.id &&
      other.schedule.version == schedule.version &&
      other.schedule.revision == schedule.revision &&
      other.schedule.usedByConfirmedDay == schedule.usedByConfirmedDay &&
      other.confirmedDays == confirmedDays &&
      other.lastConfirmed == lastConfirmed &&
      other.latest == latest;

  @override
  int get hashCode => Object.hash(
    schedule.id,
    schedule.version,
    schedule.revision,
    confirmedDays,
    lastConfirmed,
    latest,
  );
}

/// What the Work adapters read to settle a save and to check one after an
/// uncertain outcome, over the existing data access. Nothing here writes.
final class WorkReads {
  WorkReads(AppDatabase database)
    : _database = database,
      _shifts = ShiftDao(database),
      _employments = EmploymentDao(database),
      _agreements = AgreementDao(database),
      _schedules = ScheduleDao(database);

  final AppDatabase _database;
  final ShiftDao _shifts;
  final EmploymentDao _employments;
  final AgreementDao _agreements;
  final ScheduleDao _schedules;

  Future<PayPeriod?> period(PayPeriodId id) => PayPeriodDao(_database).byId(id);
  Future<Payslip?> payslip(PayslipId id) => PayslipDao(_database).byId(id);

  Future<ShiftRecord?> shift(ShiftId id) async {
    final shift = await _shifts.byId(id);
    if (shift == null) return null;
    return ShiftRecord(shift: shift, breaks: await _shifts.breaksFor(id));
  }

  /// Every shift of [employmentId], in start order.
  Future<List<WorkShift>> shiftsOf(EmploymentId employmentId) =>
      _shifts.forEmployment(employmentId);

  Future<EmploymentRecord?> employment(EmploymentId id) async =>
      switch (await _employments.byId(id)) {
        final value? => EmploymentRecord(value),
        null => null,
      };

  Future<List<Employment>> employments() => _employments.all();

  /// Every employment, oldest first, with its sheet counts; again
  /// whenever any of them changes. Changes are watched from before the
  /// first read, so none is lost, and reads run one after another, so a
  /// later snapshot never comes before an earlier one.
  Stream<List<EmploymentSummary>> watchEmployments() {
    final db = _database;
    return _watch([
      db.employments,
      db.payAgreements,
      db.workShifts,
      db.workLeaveRecords,
      db.workSchedules,
      db.workDayExceptions,
      db.payPeriods,
      db.payslips,
    ], _summaries);
  }

  /// [read] now and again after every change of [tables], as
  /// [watchEmployments] describes.
  Stream<T> _watch<T>(
    List<TableInfo<Table, Object?>> tables,
    Future<T> Function() read,
  ) {
    return watchReads(
      _database.tableUpdates(TableUpdateQuery.onAllTables(tables)),
      read,
    );
  }

  /// Every employment with its counts, in one query for the counts.
  Future<List<EmploymentSummary>> _summaries() async {
    final db = _database;
    String table(TableInfo<Table, Object?> info) => info.actualTableName;
    final rows = await db
        .customSelect(
          'SELECT e.id AS id, '
          '(SELECT COUNT(*) FROM ${table(db.workShifts)} s '
          "WHERE s.employment_id = e.id AND s.state <> 'voided') AS shifts, "
          '(SELECT COUNT(*) FROM ${table(db.workLeaveRecords)} l '
          "WHERE l.employment_id = e.id AND l.state <> 'voided') AS leave, "
          '(SELECT COUNT(DISTINCT w.id) FROM ${table(db.workSchedules)} w '
          'WHERE w.employment_id = e.id) AS schedules, '
          '(SELECT COUNT(*) FROM ${table(db.payPeriods)} p '
          'WHERE p.employment_id = e.id) AS periods, '
          '(SELECT COUNT(*) FROM ${table(db.payslips)} ps '
          'JOIN ${table(db.payPeriods)} pp ON ps.period_id = pp.id '
          "WHERE pp.employment_id = e.id AND ps.state = 'effective') "
          'AS payslips, '
          '(SELECT COUNT(*) FROM ${table(db.payAgreements)} a '
          'WHERE a.employment_id = e.id) AS agreements, '
          // The rule `EmploymentService.deleteEmployment` refuses on.
          '(EXISTS (SELECT 1 FROM ${table(db.workShifts)} hs '
          'WHERE hs.employment_id = e.id) '
          'OR EXISTS (SELECT 1 FROM ${table(db.payPeriods)} hp '
          'WHERE hp.employment_id = e.id) '
          'OR EXISTS (SELECT 1 FROM ${table(db.workSchedules)} hw '
          'WHERE hw.employment_id = e.id) '
          'OR EXISTS (SELECT 1 FROM ${table(db.workDayExceptions)} hd '
          'WHERE hd.employment_id = e.id) '
          'OR EXISTS (SELECT 1 FROM ${table(db.workLeaveRecords)} hl '
          'WHERE hl.employment_id = e.id)) AS history '
          'FROM ${table(db.employments)} e',
        )
        .get();
    final history = {
      for (final row in rows) row.read<String>('id'): row.read<bool>('history'),
    };
    final counts = {
      for (final row in rows)
        row.read<String>('id'): SheetCounts(
          shifts: row.read<int>('shifts'),
          leave: row.read<int>('leave'),
          schedules: row.read<int>('schedules'),
          periods: row.read<int>('periods'),
          payslips: row.read<int>('payslips'),
          agreements: row.read<int>('agreements'),
        ),
    };
    return [
      for (final value in await _employments.all())
        EmploymentSummary(
          value,
          counts: counts[value.id.value] ?? SheetCounts.none,
          // Payslips belong to pay periods, which count already.
          hasHistory: history[value.id.value] ?? false,
        ),
    ];
  }

  Future<List<PayAgreement>> agreementsOf(EmploymentId employmentId) =>
      _agreements.forEmployment(employmentId);

  /// [employmentId]'s agreement versions by start, with what each paid.
  Future<List<AgreementRow>> agreementRows(EmploymentId employmentId) async => [
    for (final value in await agreementsOf(employmentId))
      AgreementRow(
        agreement: value,
        paidShifts: await _agreements.finishedShiftCount(value.id),
        paysLeave: await _agreements.usedByLeave(value.id),
        firstUse: await _agreements.firstUse(value.id),
        lastUse: await _agreements.lastUse(value.id),
      ),
  ];

  /// [agreementRows] now and whenever agreements, shifts or leave change,
  /// as [watchEmployments] orders them.
  Stream<List<AgreementRow>> watchAgreements(EmploymentId employmentId) {
    final db = _database;
    return _watch([
      db.payAgreements,
      db.workShifts,
      db.workLeaveRecords,
    ], () => agreementRows(employmentId));
  }

  Future<AgreementRecord?> agreement(
    EmploymentId employmentId,
    AgreementId id,
  ) async {
    final found = (await agreementsOf(employmentId))
        .where((value) => value.id == id)
        .firstOrNull;
    return found == null ? null : AgreementRecord(found);
  }

  /// [employmentId]'s schedule versions by in-use-from, then version, with
  /// the days confirmed from each.
  Future<List<ScheduleRow>> scheduleRows(EmploymentId employmentId) async {
    final all = await _schedules.forEmployment(employmentId);
    final latest = <ScheduleId, int>{};
    for (final value in all) {
      final known = latest[value.id];
      if (known == null || value.version > known) {
        latest[value.id] = value.version;
      }
    }
    final confirmed = await _schedules.confirmedDaysOf(employmentId);
    final rows = [
      for (final value in all)
        ScheduleRow(
          schedule: value,
          confirmedDays: confirmed[(value.id.value, value.version)]?.days ?? 0,
          lastConfirmed: confirmed[(value.id.value, value.version)]?.last,
          latest: latest[value.id] == value.version,
        ),
    ];
    rows.sort((a, b) {
      final from = a.schedule.inUseFrom.compareTo(b.schedule.inUseFrom);
      return from != 0
          ? from
          : a.schedule.version.compareTo(b.schedule.version);
    });
    return rows;
  }

  /// [scheduleRows] now and whenever schedules, shifts or leave change,
  /// as [watchEmployments] orders them.
  Stream<List<ScheduleRow>> watchSchedules(EmploymentId employmentId) {
    final db = _database;
    return _watch([
      db.workSchedules,
      db.workScheduleShiftTypes,
      db.workScheduleBlocks,
      db.workShifts,
      db.workLeaveRecords,
    ], () => scheduleRows(employmentId));
  }

  /// Version [version] of schedule [id], or its latest when null.
  Future<ScheduleRecord?> schedule(
    EmploymentId employmentId,
    ScheduleId id, {
    int? version,
  }) async {
    WorkSchedule? found;
    for (final value in await _schedules.forEmployment(employmentId)) {
      if (value.id != id) continue;
      if (version != null) {
        if (value.version == version) found = value;
      } else if (found == null || value.version > found.version) {
        found = value;
      }
    }
    return found == null ? null : ScheduleRecord(found);
  }
}
