import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/reconciliation_service.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/reconciliation_projection.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';

void main() {
  late AppDatabase database;
  late DriftWorkRepository repository;
  late ReconciliationService reconciliation;
  late WorkQueryService queries;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWorkRepository(database);
    reconciliation = ReconciliationService(repository);
    queries = WorkQueryService(repository);
    await repository.insertEmployment(_employment());
    await repository.createPeriod(_period);
  });

  tearDown(() => database.close());

  test('compatible payslips sum while mixed basis remains separate', () async {
    await repository.insertPayslip(
      _payslip(_grossOne, 100000, const GrossBasis()),
    );
    await repository.insertPayslip(
      _payslip(_grossTwo, 150000, const GrossBasis()),
    );
    await repository.insertPayslip(_payslip(_net, 90000, const NetBasis()));

    final summary = await reconciliation.watch(_scope).first;

    expect(
      summary.groups
          .where((group) => group.basis == const GrossBasis())
          .single
          .paid,
      const Money(minorUnits: 250000),
    );
    expect(
      summary.groups
          .where((group) => group.basis == const NetBasis())
          .single
          .paid,
      const Money(minorUnits: 90000),
    );
    expect(summary.overallStatus, isA<MixedBasis>());
  });

  test('query service exposes scoped register and selected detail', () async {
    await repository.insertPayslip(
      _payslip(_grossOne, 100000, const GrossBasis()),
    );

    final register = await queries.watchRegister(_scope).first;
    final detail = await queries.watchRecord(_grossOne).first;

    expect(register.scope.employmentId, _employmentId);
    expect(register.payslipRows.single.id, _grossOne);
    expect(detail, isA<PayslipRecordProjection>());
  });

  test('paid evidence without work is unmatched', () async {
    await repository.insertPayslip(
      _payslip(_grossOne, 100000, const GrossBasis()),
    );

    final summary = await reconciliation.watch(_scope).first;

    expect(summary.groups.single.status, isA<UnmatchedPayslip>());
  });

  test(
    'missing agreement remains unavailable through the query service',
    () async {
      final service = ReconciliationService(
        _FixedQueryRepository(
          WorkRegisterProjection(
            scope: _scope,
            period: _period,
            shiftRows: const [],
            payslipRows: const [],
            paid: const Money(minorUnits: 0),
            reconciliation: projectReconciliation(
              employmentId: _employmentId,
              period: _period,
              shifts: [_finalizedShift()],
              breaks: const [],
              agreements: const [],
              payslips: const [],
            ),
          ),
        ),
      );

      final summary = await service.watch(_scope).first;

      expect(summary.overallStatus, isA<UnavailableReconciliation>());
    },
  );
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _grossOne = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const _grossTwo = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62');
const _net = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c63');
const _scope = WorkScope(
  employmentId: _employmentId,
  temporal: PayPeriodScope(_periodId),
);

Employment _employment() => Employment.create(
  id: _employmentId,
  name: 'Synthetic employer',
  legalLabel: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _period = PayPeriod.create(
  id: _periodId,
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 1),
  end: const LocalDate(2026, 9, 30),
  label: 'September',
  nowUtc: DateTime.utc(2026, 9, 1),
);

WorkShift _finalizedShift() => WorkShift(
  id: const ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31'),
  employmentId: _employmentId,
  agreementId: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  state: ShiftState.finalized,
  startUtc: DateTime.utc(2026, 9, 10, 8),
  endUtc: DateTime.utc(2026, 9, 10, 16),
  timezoneId: 'Europe/Berlin',
  localStartDate: const LocalDate(2026, 9, 10),
  overtimeMinutes: 0,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 9, 10, 8),
  updatedAtUtc: DateTime.utc(2026, 9, 10, 16),
  revision: const Revision(1),
);

final class _FixedQueryRepository implements WorkQueryRepository {
  const _FixedQueryRepository(this.register);

  final WorkRegisterProjection register;

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(register);

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

Payslip _payslip(PayslipId id, int amount, RateBasis basis) => Payslip(
  id: id,
  periodId: _periodId,
  issuedDate: const LocalDate(2026, 9, 30),
  paidDate: const LocalDate(2026, 10, 1),
  amount: Money(minorUnits: amount),
  basis: basis,
  grossMinorUnits: null,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: null,
  note: null,
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: null,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(0),
);
