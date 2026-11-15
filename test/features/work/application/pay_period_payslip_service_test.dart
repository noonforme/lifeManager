import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/pay_period_service.dart';
import 'package:lifeos/features/work/application/payslip_service.dart';
import 'package:lifeos/features/work/application/shift_lifecycle_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';

void main() {
  late AppDatabase database;
  late DriftWorkRepository repository;
  late PayPeriodService periods;
  late PayslipService payslips;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWorkRepository(database);
    await repository.insertEmployment(_employment());
    periods = PayPeriodService(
      repository,
      idFactory: _Ids(),
      clock: const _Clock(),
    );
    payslips = PayslipService(
      repository,
      idFactory: _Ids(),
      clock: const _Clock(),
    );
  });

  tearDown(() => database.close());

  test('overlap is invalid and reviewed periods can reopen', () async {
    expect(
      await periods.createPeriod(_createPeriod),
      isA<Committed<PayPeriod>>(),
    );
    expect(
      await periods.createPeriod(
        const CreatePayPeriodCommand(
          employmentId: _employmentId,
          start: LocalDate(2026, 9, 30),
          end: LocalDate(2026, 10, 15),
          label: null,
        ),
      ),
      isA<Invalid<PayPeriod>>(),
    );
    expect(
      await periods.setState(
        const SetPayPeriodStateCommand(
          id: _periodId,
          state: PayPeriodState.reviewed,
          expectedRevision: Revision(0),
        ),
      ),
      isA<Committed<PayPeriod>>(),
    );
    final reopened = await periods.setState(
      const SetPayPeriodStateCommand(
        id: _periodId,
        state: PayPeriodState.open,
        expectedRevision: Revision(1),
      ),
    );
    expect((reopened as Committed<PayPeriod>).value.state, PayPeriodState.open);
  });

  test('stale period state mutation remains explicit', () async {
    await periods.createPeriod(_createPeriod);
    final outcome = await periods.setState(
      const SetPayPeriodStateCommand(
        id: _periodId,
        state: PayPeriodState.reviewed,
        expectedRevision: Revision(2),
      ),
    );
    expect(outcome, isA<Stale<PayPeriod>>());
  });

  test('stale payslip correction creates no replacement', () async {
    await periods.createPeriod(_createPeriod);
    await payslips.recordPayslip(_recordPayslip);

    final outcome = await payslips.correctPayslip(
      const CorrectPayslipCommand(
        originalId: _payslipId,
        replacementId: _replacementPayslipId,
        expectedRevision: Revision(1),
        voidReason: 'Synthetic correction',
      ),
    );

    expect(outcome, isA<Stale<Payslip>>());
    expect(await repository.payslipById(_replacementPayslipId), isNull);
    expect((await repository.payslipById(_payslipId))!.isEffective, isTrue);
  });

  test('known storage failure returns unavailable', () async {
    final unavailable = PayPeriodService(
      const _UnavailableEvidenceRepository(),
      idFactory: _Ids(),
      clock: const _Clock(),
    );

    final outcome = await unavailable.createPeriod(_createPeriod);

    expect(
      outcome,
      isA<Unavailable<PayPeriod>>().having(
        (value) => value.code,
        'code',
        SafeFailureCode.storageUnavailable,
      ),
    );
  });

  test(
    'payslip correction ambiguity is uncertain and is not retried',
    () async {
      final ambiguousRepository = _AmbiguousPayslipRepository();
      final service = PayslipService(
        ambiguousRepository,
        idFactory: _Ids(),
        clock: const _Clock(),
      );

      final outcome = await service.correctPayslip(
        const CorrectPayslipCommand(
          originalId: _payslipId,
          replacementId: _replacementPayslipId,
          expectedRevision: Revision(0),
          voidReason: 'Synthetic correction',
        ),
      );

      expect(
        outcome,
        isA<Uncertain<Payslip>>().having(
          (value) => value.code,
          'code',
          SafeFailureCode.commitOutcomeUnknown,
        ),
      );
      expect(ambiguousRepository.correctionAttempts, 1);
    },
  );
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _overlapPeriodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c52');
const _payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
const _replacementPayslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c62');
final _now = DateTime.utc(2026, 10, 1);

const _createPeriod = CreatePayPeriodCommand(
  employmentId: _employmentId,
  start: LocalDate(2026, 9, 1),
  end: LocalDate(2026, 9, 30),
  label: ' September ',
);

const _recordPayslip = RecordPayslipCommand(
  periodId: _periodId,
  issuedDate: LocalDate(2026, 9, 30),
  paidDate: LocalDate(2026, 10, 1),
  amountMinorUnits: 100000,
  basis: GrossBasis(),
  grossMinorUnits: 100000,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: ' Synthetic ',
  note: null,
);

Employment _employment() => Employment.create(
  id: _employmentId,
  name: 'Synthetic employer',
  legalLabel: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final class _UnavailableEvidenceRepository implements PayPeriodRepository {
  const _UnavailableEvidenceRepository();

  @override
  Future<MutationOutcome<PayPeriod>> createPeriod(PayPeriod value) async =>
      throw const DatabaseOpenFailure();

  @override
  Future<MutationOutcome<PayPeriod>> setPeriodState(
    PayPeriodId id, {
    required PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  }) async => throw const DatabaseOpenFailure();
}

final class _AmbiguousPayslipRepository implements PayslipRepository {
  var correctionAttempts = 0;

  @override
  Future<int> insertPayslip(Payslip value) async => 1;

  @override
  Future<Payslip?> payslipById(PayslipId id) async =>
      _payslip(id: _payslipId, replacedPayslipId: null);

  @override
  Future<MutationOutcome<Payslip>> correctPayslip(
    PayslipId originalId, {
    required Revision expected,
    required Payslip replacement,
    required String voidReason,
    required DateTime nowUtc,
  }) async {
    correctionAttempts++;
    throw const CommitOutcomeUnknown();
  }
}

Payslip _payslip({
  required PayslipId id,
  required PayslipId? replacedPayslipId,
}) => Payslip(
  id: id,
  periodId: _periodId,
  issuedDate: const LocalDate(2026, 9, 30),
  paidDate: const LocalDate(2026, 10, 1),
  amount: const Money(minorUnits: 100000),
  basis: const GrossBasis(),
  grossMinorUnits: 100000,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: null,
  note: null,
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: replacedPayslipId,
  createdAtUtc: _now,
  updatedAtUtc: _now,
  revision: const Revision(0),
);

final class _Ids implements WorkEvidenceIdFactory {
  var _periodCalls = 0;

  @override
  PayPeriodId payPeriodId() =>
      _periodCalls++ == 0 ? _periodId : _overlapPeriodId;

  @override
  PayslipId payslipId() => _payslipId;
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}
