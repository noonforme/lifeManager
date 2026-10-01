import 'package:drift/drift.dart' show TableUpdateQuery;

import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/history/record_events.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/timezone_service.dart';
import '../../../core/time/wall_clock.dart';
import '../application/pay_period_service.dart';
import '../application/payslip_service.dart';
import '../application/work_commands.dart';
import '../application/work_query_service.dart';
import '../domain/agreement.dart';
import '../domain/correction.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import '../domain/pay_premiums.dart';
import '../domain/payslip.dart';
import '../domain/reconciliation.dart';
import '../domain/shift.dart';
import 'daos/agreement_dao.dart';
import 'daos/employment_dao.dart';
import 'daos/pay_period_dao.dart';
import 'daos/payslip_dao.dart';
import 'daos/shift_dao.dart';
import 'projections/reconciliation_projection.dart';
import 'projections/work_record_projection.dart';
import 'projections/work_register_projection.dart';
import 'work_history.dart';
import 'work_write_store.dart';

final class DriftWorkRepository
    implements
        WorkWriteStore,
        WorkCommandRepository,
        PayPeriodRepository,
        PayslipRepository,
        WorkQueryRepository {
  /// Expected pay reads each shift on its own wall clock through
  /// [timezones]; history entries are stamped by [clock].
  DriftWorkRepository(
    this._database, {
    TimezoneService? timezones,
    AppClock? clock,
  }) : _zoneClocks = zoneClocksOf(timezones ?? IanaTimezoneService()),
       _history = WorkHistoryWriter(_database, clock ?? SystemAppClock()),
       _employments = EmploymentDao(_database),
       _agreements = AgreementDao(_database),
       _periods = PayPeriodDao(_database),
       _payslips = PayslipDao(_database),
       _shifts = ShiftDao(_database);

  final AppDatabase _database;
  final ZoneClocks _zoneClocks;
  final WorkHistoryWriter _history;
  final EmploymentDao _employments;
  final AgreementDao _agreements;
  final PayPeriodDao _periods;
  final PayslipDao _payslips;
  final ShiftDao _shifts;

  @override
  Future<T> transaction<T>(Future<T> Function(WorkWriteStore store) body) =>
      _database.transaction(() => body(this));

  @override
  Future<int> insertEmployment(Employment value) =>
      _database.transaction(() async {
        final inserted = await _employments.insert(value);
        await _history.record(
          WorkRecordKinds.employment,
          value.id.value,
          kind: RecordEventKind.created,
          after: employmentFacts(value),
          revisionAfter: value.revision,
        );
        return inserted;
      });

  @override
  Future<int> updateEmployment(
    Employment value, {
    required Revision expected,
  }) => _database.transaction(() async {
    final before = await _employments.byId(value.id);
    final changed = await _employments.update(value, expected);
    if (changed == 0 || before == null) return changed;
    await _history.record(
      WorkRecordKinds.employment,
      value.id.value,
      kind: RecordEventKind.changed,
      before: employmentFacts(before),
      after: employmentFacts(value),
      revisionAfter: expected.next(),
    );
    return changed;
  });

  @override
  Future<Employment?> employmentById(EmploymentId id) => _employments.byId(id);

  @override
  Future<bool> employmentHasHistory(EmploymentId id) =>
      _employments.hasHistory(id);

  @override
  Future<int> deleteEmployment(EmploymentId id, {required Revision expected}) =>
      _database.transaction(() async {
        final agreements = await _agreements.forEmployment(id);
        final deleted = await _employments.deleteWithAgreements(id, expected);
        if (deleted == 0) return 0;
        // A deleted record takes its history with it.
        await _history.events.deleteFor(WorkRecordKinds.employment, id.value);
        for (final agreement in agreements) {
          await _history.events.deleteFor(
            WorkRecordKinds.agreement,
            agreement.id.value,
          );
        }
        return deleted;
      });

  Stream<Employment?> watchEmployment(EmploymentId id) =>
      _employments.watchById(id);

  @override
  Future<List<PayAgreement>> agreementsFor(EmploymentId id) =>
      _agreements.forEmployment(id);

  Stream<List<PayAgreement>> watchAgreements(EmploymentId id) =>
      _agreements.watchForEmployment(id);

  @override
  Future<int> insertAgreement(PayAgreement value) =>
      _database.transaction(() async {
        final inserted = await _agreements.insert(value);
        await _recordAgreementCreated(value);
        return inserted;
      });

  Future<void> _recordAgreementCreated(PayAgreement value) => _history.record(
    WorkRecordKinds.agreement,
    value.id.value,
    kind: RecordEventKind.created,
    after: agreementFacts(value),
    revisionAfter: value.revision,
  );

  Future<MutationOutcome<PayAgreement>> createAgreement(PayAgreement value) {
    return _database.transaction(() async {
      final existing = await _agreements.forEmployment(value.employmentId);
      final validation = validateAgreementSet([...existing, value]);
      if (!validation.isValid) {
        return const Invalid<PayAgreement>({
          'effectiveRange': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      await _agreements.insert(value);
      await _recordAgreementCreated(value);
      return Committed<PayAgreement>(value);
    });
  }

  @override
  Future<int> updateUnusedAgreement(
    PayAgreement value, {
    required Revision expected,
  }) {
    return _database.transaction(() async {
      final existing = await _agreements.forEmployment(value.employmentId);
      final withoutCurrent = existing.where((item) => item.id != value.id);
      final validation = validateAgreementSet([...withoutCurrent, value]);
      if (!validation.isValid) return 0;
      final before = existing.where((item) => item.id == value.id).firstOrNull;
      final changed = await _agreements.updateUnused(value, expected);
      if (changed == 0 || before == null) return changed;
      await _history.record(
        WorkRecordKinds.agreement,
        value.id.value,
        kind: RecordEventKind.changed,
        before: agreementFacts(before),
        after: agreementFacts(value),
        revisionAfter: expected.next(),
      );
      return changed;
    });
  }

  Future<List<PayPeriod>> periodsFor(EmploymentId id) =>
      _periods.forEmployment(id);

  @override
  Future<MutationOutcome<PayPeriod>> createPeriod(PayPeriod value) {
    return _database.transaction(() async {
      final existing = await _periods.forEmployment(value.employmentId);
      final overlaps = existing.any(
        (item) =>
            item.start.compareTo(value.end) <= 0 &&
            value.start.compareTo(item.end) <= 0,
      );
      if (overlaps) {
        return const Invalid<PayPeriod>({
          'range': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      await _periods.insert(value);
      await _history.record(
        WorkRecordKinds.payPeriod,
        value.id.value,
        kind: RecordEventKind.created,
        after: periodFacts(value),
        revisionAfter: value.revision,
      );
      return Committed<PayPeriod>(value);
    });
  }

  @override
  Future<MutationOutcome<PayPeriod>> setPeriodState(
    PayPeriodId id, {
    required PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  }) => _database.transaction(() async {
    final existing = await _periods.byId(id);
    if (existing == null) return const Missing<PayPeriod>();
    final changed = await _periods.setState(
      id,
      state: state,
      expected: expected,
      nowUtc: nowUtc,
    );
    if (changed == 0) return const Stale<PayPeriod>();
    final after = (await _periods.byId(id))!;
    await _history.record(
      WorkRecordKinds.payPeriod,
      id.value,
      kind: state == PayPeriodState.reviewed
          ? RecordEventKind.reviewed
          : RecordEventKind.changed,
      before: periodFacts(existing),
      after: periodFacts(after),
      revisionAfter: after.revision,
    );
    return Committed<PayPeriod>(after);
  });

  @override
  Future<int> insertPayslip(Payslip value) => _database.transaction(() async {
    final inserted = await _payslips.insert(value);
    await _history.record(
      WorkRecordKinds.payslip,
      value.id.value,
      kind: RecordEventKind.created,
      after: payslipFacts(value),
      revisionAfter: value.revision,
    );
    return inserted;
  });

  @override
  Future<Payslip?> payslipById(PayslipId id) => _payslips.byId(id);

  @override
  Future<MutationOutcome<Payslip>> correctPayslip(
    PayslipId originalId, {
    required Revision expected,
    required Payslip replacement,
    required String voidReason,
    required DateTime nowUtc,
  }) async {
    try {
      return await _database.transaction(() async {
        final original = await _payslips.byId(originalId);
        if (original == null) return const Missing<Payslip>();
        if (original.revision != expected) return const Stale<Payslip>();
        final prepared = preparePayslipCorrection(
          original: original,
          replacementId: replacement.id,
          voidReason: voidReason,
          nowUtc: nowUtc,
        );
        if (replacement.periodId != prepared.replacement.periodId ||
            replacement.replacedPayslipId != original.id) {
          return const Invalid<Payslip>({
            'replacement': [FieldIssue(FieldIssueCode.invalid)],
          });
        }
        await _payslips.insert(replacement);
        final changed = await _payslips.voidForCorrection(
          prepared.voidedOriginal,
          expected: expected,
        );
        if (changed == 0) throw const _StalePayslipCorrection();
        await _history.record(
          WorkRecordKinds.payslip,
          original.id.value,
          kind: RecordEventKind.voided,
          before: payslipFacts(original),
          after: payslipFacts(prepared.voidedOriginal),
          revisionAfter: prepared.voidedOriginal.revision,
          reason: prepared.voidedOriginal.voidReason,
        );
        await _history.record(
          WorkRecordKinds.payslip,
          replacement.id.value,
          kind: RecordEventKind.replaced,
          after: payslipFacts(replacement),
          revisionAfter: replacement.revision,
        );
        return Committed<Payslip>(replacement);
      });
    } on _StalePayslipCorrection {
      return const Stale<Payslip>();
    }
  }

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) async* {
    final employmentId = scope.employmentId;
    if (employmentId == null) {
      yield WorkRegisterProjection.empty(
        scope,
        availableEmployments: await _employments.active(),
      );
      await for (final _ in _database.tableUpdates(
        TableUpdateQuery.onAllTables([_database.employments]),
      )) {
        yield WorkRegisterProjection.empty(
          scope,
          availableEmployments: await _employments.active(),
        );
      }
      return;
    }
    // Every sheet derives from several tables, so any Work commit re-reads.
    yield await _loadRegister(scope, employmentId);
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([
        _database.employments,
        _database.payAgreements,
        _database.payPeriods,
        _database.workShifts,
        _database.shiftBreaks,
        _database.payslips,
      ]),
    )) {
      yield await _loadRegister(scope, employmentId);
    }
  }

  Future<WorkRegisterProjection> _loadRegister(
    WorkScope scope,
    EmploymentId employmentId,
  ) async {
    final temporal = scope.temporal;
    final employment = await _employments.byId(employmentId);
    final agreements = await _agreements.forEmployment(employmentId);
    final periods = await _periods.forEmployment(employmentId);
    final shifts = await _shifts.forEmployment(employmentId);
    final breaks = await _shifts.breaksForShifts(shifts.map((s) => s.id));
    final payslips = await _payslips.forEmployment(employmentId);
    final agreementsById = {for (final a in agreements) a.id: a};

    PayPeriod? periodOf(WorkShift shift) => periods
        .where((period) => period.contains(shift.localStartDate))
        .firstOrNull;
    bool inScope(WorkShift shift) => switch (temporal) {
      null => true,
      DateRangeScope(:final start, :final end) =>
        shift.localStartDate.compareTo(start) >= 0 &&
            shift.localStartDate.compareTo(end) <= 0,
      PayPeriodScope(:final periodId) => periodOf(shift)?.id == periodId,
    };

    final shiftSheet = [
      for (final shift in shifts)
        if (inScope(shift))
          _shiftSheetRow(
            shift,
            breaks.where((item) => item.shiftId == shift.id).toList(),
            agreementsById,
            periodOf(shift),
          ),
    ];
    final periodSheet = [
      for (final period in periods)
        PeriodSheetRow(
          period: period,
          shiftCount: shifts
              .where(
                (shift) =>
                    shift.state == ShiftState.finalized &&
                    period.contains(shift.localStartDate),
              )
              .length,
          groups: reconcilePeriod(
            employmentId: employmentId,
            period: period,
            shifts: shifts,
            breaks: breaks,
            agreements: agreements,
            payslips: payslips,
            zoneClocks: _zoneClocks,
          ),
        ),
    ];
    final agreementSheet = [
      for (final agreement in agreements)
        AgreementSheetRow(
          agreement: agreement,
          finishedShifts: await _agreements.finishedShiftCount(agreement.id),
        ),
    ];

    final selectedPeriod = switch (temporal) {
      PayPeriodScope(:final periodId) =>
        periods.where((period) => period.id == periodId).firstOrNull,
      _ => null,
    };
    final effectivePayslips = selectedPeriod == null
        ? const <Payslip>[]
        : payslips
              .where(
                (value) =>
                    value.periodId == selectedPeriod.id && value.isEffective,
              )
              .toList();
    final scopedFinalized = [
      for (final row in shiftSheet)
        if (row.shift.state == ShiftState.finalized) row.shift,
    ];

    return WorkRegisterProjection(
      scope: scope,
      period: selectedPeriod,
      shiftRows:
          temporal == null ||
              (temporal is PayPeriodScope && selectedPeriod == null)
          ? const []
          : [
              for (final shift in scopedFinalized)
                ShiftRegisterRow(
                  id: shift.id,
                  localStartDate: shift.localStartDate.toString(),
                  startUtc: shift.startUtc,
                  endUtc: shift.endUtc,
                  state: shift.state,
                ),
            ],
      payslipRows: [
        for (final value in effectivePayslips)
          PayslipRegisterRow(
            id: value.id,
            periodId: value.periodId,
            issuedDate: value.issuedDate.toString(),
            amount: value.amount,
            basis: value.basis,
            state: value.state,
          ),
      ],
      paid: Money(
        minorUnits: effectivePayslips.fold(
          0,
          (total, value) => total + value.amount.minorUnits,
        ),
      ),
      reconciliation: selectedPeriod == null
          ? null
          : projectReconciliation(
              employmentId: employmentId,
              period: selectedPeriod,
              shifts: scopedFinalized,
              breaks: breaks,
              agreements: agreements,
              payslips: payslips.where(
                (value) => value.periodId == selectedPeriod.id,
              ),
              zoneClocks: _zoneClocks,
            ),
      periodRows: temporal == null ? periods : const [],
      employment: employment,
      hasAgreement: agreements.isNotEmpty,
      currentAgreement: agreements.isEmpty
          ? null
          : agreements.reduce(
              (a, b) =>
                  a.effectiveStart.compareTo(b.effectiveStart) >= 0 ? a : b,
            ),
      canDeleteEmployment:
          employment != null && !await _employments.hasHistory(employmentId),
      availableEmployments: await _employments.active(),
      shiftSheet: shiftSheet,
      periodSheet: periodSheet,
      payslipSheet: payslips,
      agreementSheet: agreementSheet,
    );
  }

  ShiftSheetRow _shiftSheetRow(
    WorkShift shift,
    List<ShiftBreak> breaks,
    Map<AgreementId, PayAgreement> agreements,
    PayPeriod? period,
  ) {
    int second(DateTime utc) => utc.microsecondsSinceEpoch ~/ 1000000;
    final breakSeconds = breaks.fold(
      0,
      (total, item) => item.endUtc == null
          ? total
          : total + second(item.endUtc!) - second(item.startUtc),
    );
    final end = shift.endUtc;
    final paidSeconds = end == null
        ? null
        : second(end) - second(shift.startUtc) - breakSeconds;
    final agreement = agreements[shift.agreementId];
    final facts =
        (shift.state == ShiftState.finalized ||
                shift.state == ShiftState.voided) &&
            agreement != null
        ? validateFinalization(
            shift: shift,
            breaks: breaks,
            agreements: [agreement],
          ).facts
        : null;
    final clock = _zoneClocks(shift.timezoneId);
    return ShiftSheetRow(
      shift: shift,
      breakSeconds: breakSeconds,
      paidSeconds: paidSeconds,
      period: period,
      facts: facts,
      pay: facts?.expectedPay(
        toLocal: clock.toLocal,
        toInstants: clock.toInstants,
      ),
    );
  }

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) async* {
    // Re-read the selected record whenever any Work table commits, so the
    // inspector reflects state changes without re-selection.
    yield await _loadRecord(id);
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([
        _database.employments,
        _database.payAgreements,
        _database.payPeriods,
        _database.payslips,
        _database.workShifts,
        _database.shiftBreaks,
      ]),
    )) {
      yield await _loadRecord(id);
    }
  }

  Future<WorkRecordProjection?> _loadRecord(WorkRecordId id) async {
    if (id is PayslipId) {
      final value = await _payslips.byId(id);
      return value == null ? null : PayslipRecordProjection(value);
    }
    if (id is PayPeriodId) {
      final value = await _periods.byId(id);
      return value == null ? null : PayPeriodRecordProjection(value);
    }
    if (id is EmploymentId) {
      final value = await _employments.byId(id);
      return value == null ? null : EmploymentRecordProjection(value);
    }
    if (id is ShiftId) {
      final value = await _shifts.byId(id);
      return value == null ? null : _shiftRecord(value);
    }
    if (id is AgreementId) {
      final value = await _agreements.byId(id);
      return value == null
          ? null
          : AgreementRecordProjection(
              value,
              finishedShifts: await _agreements.finishedShiftCount(id),
            );
    }
    return null;
  }

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() async* {
    await for (final shift in _shifts.watchActive()) {
      yield shift == null ? null : await _shiftRecord(shift);
    }
  }

  Future<ShiftRecordProjection> _shiftRecord(WorkShift shift) async {
    final breaks = await _shifts.breaksFor(shift.id);
    final agreementId = shift.agreementId;
    if (shift.state != ShiftState.finalized || agreementId == null) {
      return ShiftRecordProjection(shift, breaks: breaks);
    }
    final agreement = await _agreements.byId(agreementId);
    final facts = agreement == null
        ? null
        : validateFinalization(
            shift: shift,
            breaks: breaks,
            agreements: [agreement],
          ).facts;
    if (facts == null) return ShiftRecordProjection(shift, breaks: breaks);
    final clock = _zoneClocks(shift.timezoneId);
    return ShiftRecordProjection(
      shift,
      breaks: breaks,
      facts: facts,
      pay: facts.expectedPay(
        toLocal: clock.toLocal,
        toInstants: clock.toInstants,
      ),
    );
  }
}

final class _StalePayslipCorrection implements Exception {
  const _StalePayslipCorrection();
}
