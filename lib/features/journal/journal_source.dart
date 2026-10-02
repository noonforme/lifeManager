import 'package:drift/drift.dart' show TableUpdateQuery;

import '../../core/database/app_database.dart' show AppDatabase;
import '../../core/history/record_event_dao.dart';
import '../../core/time/local_date.dart';
import '../../core/time/timezone_service.dart';
import '../../core/time/wall_clock.dart';
import '../work/data/daos/agreement_dao.dart';
import '../work/data/daos/employment_dao.dart';
import '../work/data/daos/pay_period_dao.dart';
import '../work/data/daos/payslip_dao.dart';
import '../work/data/daos/shift_dao.dart';
import '../work/data/projections/work_register_projection.dart';
import '../work/data/work_sheet_rows.dart';
import '../work/domain/agreement.dart';
import '../work/domain/employment.dart';
import '../work/domain/pay_period.dart';
import '../work/domain/pay_premiums.dart';
import '../work/domain/payslip.dart';
import 'journal_projection.dart';

abstract interface class JournalSource {
  /// Entries whose day is between [from] and [to] inclusive, newest first.
  Stream<List<JournalEntry>> watch(LocalDate from, LocalDate to);
}

/// Reads the Journal from Work's records and their history on every Work
/// commit. Phase 1 data is small and local, so each read is whole.
final class DriftJournalSource implements JournalSource {
  DriftJournalSource(
    this._database, {
    required TimezoneService timezones,
    required this._defaultZone,
  }) : _timezones = timezones,
       _zoneClocks = zoneClocksOf(timezones);

  final AppDatabase _database;
  final TimezoneService _timezones;

  /// The zone for records without one of their own, read on each load.
  final String Function() _defaultZone;
  final ZoneClocks _zoneClocks;

  @override
  Stream<List<JournalEntry>> watch(LocalDate from, LocalDate to) async* {
    yield await _load(from, to);
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([
        _database.recordEvents,
        _database.employments,
        _database.payAgreements,
        _database.payPeriods,
        _database.workShifts,
        _database.shiftBreaks,
        _database.payslips,
      ]),
    )) {
      yield await _load(from, to);
    }
  }

  Future<List<JournalEntry>> _load(LocalDate from, LocalDate to) async {
    // Every zone is within a day of UTC; the projection trims to local days.
    final events = await RecordEventDao(_database).between(
      DateTime.utc(from.year, from.month, from.day - 1),
      DateTime.utc(to.year, to.month, to.day + 2),
    );
    final employmentDao = EmploymentDao(_database);
    final agreementDao = AgreementDao(_database);
    final periodDao = PayPeriodDao(_database);
    final shiftDao = ShiftDao(_database);
    final payslipDao = PayslipDao(_database);

    final employments = <String, Employment>{};
    final agreements =
        <String, ({PayAgreement agreement, int finishedShifts})>{};
    final periods = <String, PayPeriod>{};
    final shifts = <String, ShiftSheetRow>{};
    final payslips = <String, Payslip>{};
    for (final employment in await employmentDao.all()) {
      employments[employment.id.value] = employment;
      final terms = await agreementDao.forEmployment(employment.id);
      for (final agreement in terms) {
        agreements[agreement.id.value] = (
          agreement: agreement,
          finishedShifts: await agreementDao.finishedShiftCount(agreement.id),
        );
      }
      final ownPeriods = await periodDao.forEmployment(employment.id);
      for (final period in ownPeriods) {
        periods[period.id.value] = period;
      }
      final ownShifts = await shiftDao.forEmployment(employment.id);
      final breaks = await shiftDao.breaksForShifts(ownShifts.map((s) => s.id));
      final byId = {for (final agreement in terms) agreement.id: agreement};
      for (final shift in ownShifts) {
        shifts[shift.id.value] = shiftSheetRow(
          shift,
          breaks.where((item) => item.shiftId == shift.id).toList(),
          byId,
          ownPeriods
              .where((period) => period.contains(shift.localStartDate))
              .firstOrNull,
          _zoneClocks,
        );
      }
      for (final payslip in await payslipDao.forEmployment(employment.id)) {
        payslips[payslip.id.value] = payslip;
      }
    }

    return journalEntries(
      JournalFacts(
        events: events,
        shifts: shifts,
        payslips: payslips,
        periods: periods,
        employments: employments,
        agreements: agreements,
      ),
      from: from,
      to: to,
      localDate: _timezones.localDateAt,
      defaultZone: _defaultZone(),
    );
  }
}
