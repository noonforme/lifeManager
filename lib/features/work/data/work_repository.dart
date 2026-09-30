import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/outcomes/mutation_outcome.dart';
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
import '../domain/payslip.dart';
import 'daos/agreement_dao.dart';
import 'daos/employment_dao.dart';
import 'daos/pay_period_dao.dart';
import 'daos/payslip_dao.dart';
import 'daos/shift_dao.dart';
import 'projections/reconciliation_projection.dart';
import 'projections/work_record_projection.dart';
import 'projections/work_register_projection.dart';
import 'work_write_store.dart';

final class DriftWorkRepository
    implements
        WorkWriteStore,
        WorkCommandRepository,
        PayPeriodRepository,
        PayslipRepository,
        WorkQueryRepository {
  DriftWorkRepository(this._database)
    : _employments = EmploymentDao(_database),
      _agreements = AgreementDao(_database),
      _periods = PayPeriodDao(_database),
      _payslips = PayslipDao(_database),
      _shifts = ShiftDao(_database);

  final AppDatabase _database;
  final EmploymentDao _employments;
  final AgreementDao _agreements;
  final PayPeriodDao _periods;
  final PayslipDao _payslips;
  final ShiftDao _shifts;

  @override
  Future<T> transaction<T>(Future<T> Function(WorkWriteStore store) body) =>
      _database.transaction(() => body(this));

  @override
  Future<int> insertEmployment(Employment value) => _employments.insert(value);

  @override
  Future<int> updateEmployment(
    Employment value, {
    required Revision expected,
  }) => _employments.update(value, expected);

  @override
  Future<Employment?> employmentById(EmploymentId id) => _employments.byId(id);

  Stream<Employment?> watchEmployment(EmploymentId id) =>
      _employments.watchById(id);

  @override
  Future<List<PayAgreement>> agreementsFor(EmploymentId id) =>
      _agreements.forEmployment(id);

  Stream<List<PayAgreement>> watchAgreements(EmploymentId id) =>
      _agreements.watchForEmployment(id);

  @override
  Future<int> insertAgreement(PayAgreement value) => _agreements.insert(value);

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
      return _agreements.updateUnused(value, expected);
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
      return Committed<PayPeriod>(value);
    });
  }

  @override
  Future<MutationOutcome<PayPeriod>> setPeriodState(
    PayPeriodId id, {
    required PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  }) async {
    final existing = await _periods.byId(id);
    if (existing == null) return const Missing<PayPeriod>();
    final changed = await _periods.setState(
      id,
      state: state,
      expected: expected,
      nowUtc: nowUtc,
    );
    if (changed == 0) return const Stale<PayPeriod>();
    return Committed<PayPeriod>((await _periods.byId(id))!);
  }

  @override
  Future<int> insertPayslip(Payslip value) => _payslips.insert(value);

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
        return Committed<Payslip>(replacement);
      });
    } on _StalePayslipCorrection {
      return const Stale<Payslip>();
    }
  }

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) async* {
    final employmentId = scope.employmentId;
    final temporal = scope.temporal;
    if (employmentId == null || temporal == null) {
      yield WorkRegisterProjection.empty(scope);
      return;
    }
    if (temporal is DateRangeScope) {
      await for (final rows in _shifts.watchRowsForRange(
        employmentId,
        start: temporal.start.toString(),
        end: temporal.end.toString(),
      )) {
        yield WorkRegisterProjection(
          scope: scope,
          period: null,
          shiftRows: rows,
          payslipRows: const [],
          paid: const Money(minorUnits: 0),
          reconciliation: null,
        );
      }
      return;
    }
    if (temporal is! PayPeriodScope) {
      yield WorkRegisterProjection.empty(scope);
      return;
    }
    final period = await _periods.byId(temporal.periodId);
    if (period == null || period.employmentId != employmentId) {
      yield WorkRegisterProjection.empty(scope);
      return;
    }
    await for (final rows in _payslips.watchEffectiveRows(period.id)) {
      final paidMinorUnits = rows.fold(
        0,
        (total, row) => total + row.amount.minorUnits,
      );
      final shifts = await _shifts.finalizedForRange(
        employmentId,
        start: period.start.toString(),
        end: period.end.toString(),
      );
      final breaks = await _shifts.breaksForShifts(
        shifts.map((shift) => shift.id),
      );
      final agreements = await _agreements.forEmployment(employmentId);
      final payslips = await _payslips.forPeriod(period.id);
      yield WorkRegisterProjection(
        scope: scope,
        period: period,
        shiftRows: [
          for (final shift in shifts)
            ShiftRegisterRow(
              id: shift.id,
              localStartDate: shift.localStartDate.toString(),
              startUtc: shift.startUtc,
              endUtc: shift.endUtc,
              state: shift.state,
            ),
        ],
        payslipRows: rows,
        paid: Money(minorUnits: paidMinorUnits),
        reconciliation: projectReconciliation(
          employmentId: employmentId,
          period: period,
          shifts: shifts,
          breaks: breaks,
          agreements: agreements,
          payslips: payslips,
        ),
      );
    }
  }

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) async* {
    if (id is PayslipId) {
      final value = await _payslips.byId(id);
      yield value == null ? null : PayslipRecordProjection(value);
      return;
    }
    if (id is PayPeriodId) {
      final value = await _periods.byId(id);
      yield value == null ? null : PayPeriodRecordProjection(value);
      return;
    }
    if (id is EmploymentId) {
      final value = await _employments.byId(id);
      yield value == null ? null : EmploymentRecordProjection(value);
      return;
    }
    if (id is ShiftId) {
      final value = await _shifts.byId(id);
      yield value == null
          ? null
          : ShiftRecordProjection(value, breaks: await _shifts.breaksFor(id));
      return;
    }
    yield null;
  }
}

final class _StalePayslipCorrection implements Exception {
  const _StalePayslipCorrection();
}
