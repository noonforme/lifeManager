import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/features/work/application/employment_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_write_store.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  late _FakeRepository repository;
  late _FakeStore store;
  late EmploymentService service;

  setUp(() {
    repository = _FakeRepository();
    store = repository.store;
    service = EmploymentService(
      repository,
      idFactory: const _Ids(),
      clock: const _Clock(),
    );
  });

  test('create trims facts and uses injected identity and UTC time', () async {
    final outcome = await service.createEmployment(
      const CreateEmploymentCommand(
        name: '  Synthetic employer  ',
        legalLabel: '  Synthetic Ltd  ',
      ),
    );

    final value = (outcome as Committed<Employment>).value;
    expect(value.id, _employmentId);
    expect(value.name, 'Synthetic employer');
    expect(value.legalLabel, 'Synthetic Ltd');
    expect(value.createdAtUtc, _now);
  });

  test(
    'empty employment name returns issues without opening a write',
    () async {
      final outcome = await service.createEmployment(
        const CreateEmploymentCommand(name: '  ', legalLabel: null),
      );

      expect(outcome, isA<Invalid<Employment>>());
      expect(store.insertEmploymentCount, 0);
    },
  );

  test('zero-row archive maps to stale', () async {
    store.employment = _employment();
    store.nextUpdateCount = 0;

    final outcome = await service.archiveEmployment(
      const ArchiveEmploymentCommand(
        employmentId: _employmentId,
        expectedRevision: Revision(0),
      ),
    );

    expect(outcome, isA<Stale<Employment>>());
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
final _now = DateTime.utc(2026, 9, 30, 10);

Employment _employment() => Employment.create(
  id: _employmentId,
  name: 'Synthetic employer',
  legalLabel: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final class _FakeRepository implements WorkCommandRepository {
  final _FakeStore store = _FakeStore();

  @override
  Future<T> transaction<T>(Future<T> Function(WorkWriteStore store) body) =>
      body(store);
}

final class _FakeStore implements WorkWriteStore {
  @override
  Future<bool> employmentHasHistory(EmploymentId id) async => false;

  @override
  Future<int> deleteEmployment(
    EmploymentId id, {
    required Revision expected,
  }) async => 1;

  Employment? employment;
  int insertEmploymentCount = 0;
  int nextUpdateCount = 1;

  @override
  Future<Employment?> employmentById(EmploymentId id) async => employment;

  @override
  Future<int> insertEmployment(Employment value) async {
    insertEmploymentCount++;
    employment = value;
    return 1;
  }

  @override
  Future<int> updateEmployment(
    Employment value, {
    required Revision expected,
  }) async {
    if (nextUpdateCount == 1) employment = value;
    return nextUpdateCount;
  }

  @override
  Future<List<PayAgreement>> agreementsFor(EmploymentId id) async => const [];

  @override
  Future<int> insertAgreement(PayAgreement value) async => 1;

  @override
  Future<int> updateUnusedAgreement(
    PayAgreement value, {
    required Revision expected,
  }) async => 1;
}

final class _Ids implements WorkIdFactory {
  const _Ids();

  @override
  EmploymentId employmentId() => _employmentId;

  @override
  AgreementId agreementId() =>
      const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
}

final class _Clock implements AppClock {
  const _Clock();

  @override
  DateTime nowUtc() => _now;
}
