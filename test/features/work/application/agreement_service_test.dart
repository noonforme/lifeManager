import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_write_store.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  late _FakeRepository repository;
  late AgreementService service;

  setUp(() {
    repository = _FakeRepository();
    service = AgreementService(
      repository,
      idFactory: const _Ids(),
      clock: const _Clock(),
    );
  });

  test(
    'invalid agreement returns field issues without opening a write',
    () async {
      final result = await service.createAgreement(
        _command(hourlyRateMicroEur: 0),
      );

      expect(result, isA<Invalid<PayAgreement>>());
      expect(repository.transactionCount, 0);
    },
  );

  test('invalid multiplier returns issues without opening a write', () async {
    final result = await service.createAgreement(
      _command(overtimeMultiplierDenominator: 0),
    );

    expect(result, isA<Invalid<PayAgreement>>());
    expect(repository.transactionCount, 0);
  });

  test('create agreement writes normalized facts in one transaction', () async {
    final outcome = await service.createAgreement(_command());

    final value = (outcome as Committed<PayAgreement>).value;
    expect(repository.transactionCount, 1);
    expect(value.id, _agreementId);
    expect(value.createdAtUtc, _now);
    expect(value.label, 'Synthetic agreement');
    expect(value.note, 'Synthetic note');
  });

  test('zero-row close maps to stale', () async {
    repository.store.agreements = [_agreement()];
    repository.store.nextAgreementUpdateCount = 0;

    final outcome = await service.closeAgreement(
      const CloseAgreementCommand(
        agreementId: _agreementId,
        employmentId: _employmentId,
        end: LocalDate(2026, 9, 30),
        expectedRevision: Revision(0),
      ),
    );

    expect(outcome, isA<Stale<PayAgreement>>());
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
final _now = DateTime.utc(2026, 9, 30, 10);

CreateAgreementCommand _command({
  int hourlyRateMicroEur = 20000000,
  int overtimeMultiplierDenominator = 2,
}) => CreateAgreementCommand(
  employmentId: _employmentId,
  version: 1,
  effectiveStart: const LocalDate(2026, 9, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: hourlyRateMicroEur,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplierNumerator: 3,
  overtimeMultiplierDenominator: overtimeMultiplierDenominator,
  label: '  Synthetic agreement  ',
  note: '  Synthetic note  ',
);

PayAgreement _agreement() => PayAgreement(
  id: _agreementId,
  employmentId: _employmentId,
  version: 1,
  effectiveStart: const LocalDate(2026, 9, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 20000000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026, 9, 1),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);

final class _FakeRepository implements WorkCommandRepository {
  final _FakeStore store = _FakeStore();
  int transactionCount = 0;

  @override
  Future<T> transaction<T>(Future<T> Function(WorkWriteStore store) body) {
    transactionCount++;
    return body(store);
  }
}

final class _FakeStore implements WorkWriteStore {
  List<PayAgreement> agreements = [];
  int nextAgreementUpdateCount = 1;

  @override
  Future<List<PayAgreement>> agreementsFor(EmploymentId id) async => agreements;

  @override
  Future<int> insertAgreement(PayAgreement value) async {
    agreements = [...agreements, value];
    return 1;
  }

  @override
  Future<int> updateUnusedAgreement(
    PayAgreement value, {
    required Revision expected,
  }) async {
    if (nextAgreementUpdateCount == 1) agreements = [value];
    return nextAgreementUpdateCount;
  }

  @override
  Future<Employment?> employmentById(EmploymentId id) async => null;

  @override
  Future<int> insertEmployment(Employment value) async => 1;

  @override
  Future<int> updateEmployment(
    Employment value, {
    required Revision expected,
  }) async => 1;
}

final class _Ids implements WorkIdFactory {
  const _Ids();

  @override
  EmploymentId employmentId() => _employmentId;

  @override
  AgreementId agreementId() => _agreementId;
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}
