import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';

void main() {
  late AppDatabase database;
  late DriftWorkRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWorkRepository(database);
    await repository.insertEmployment(_employment());
  });

  tearDown(() => database.close());

  test('period overlap is rejected transactionally and adjacent periods are accepted', () async {
    expect(
      await repository.createPeriod(_september),
      isA<Committed<PayPeriod>>(),
    );
    expect(
      await repository.createPeriod(_overlapping),
      isA<Invalid<PayPeriod>>(),
    );
    expect(
      await repository.createPeriod(_october),
      isA<Committed<PayPeriod>>(),
    );
    expect(await repository.periodsFor(_employmentId), hasLength(2));
  });

  test('reviewed state can be reopened with a conditional revision', () async {
    await repository.createPeriod(_september);

    expect(
      await repository.setPeriodState(
        _periodId,
        state: PayPeriodState.reviewed,
        expected: const Revision(0),
        nowUtc: DateTime.utc(2026, 10, 1),
      ),
      isA<Committed<PayPeriod>>(),
    );
    final reopened = await repository.setPeriodState(
      _periodId,
      state: PayPeriodState.open,
      expected: const Revision(1),
      nowUtc: DateTime.utc(2026, 10, 2),
    );

    expect((reopened as Committed<PayPeriod>).value.state, PayPeriodState.open);
    expect(reopened.value.revision, const Revision(2));
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');

Employment _employment() => Employment.create(
  id: _employmentId,
  name: 'Synthetic employer',
  legalLabel: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _september = PayPeriod.create(
  id: _periodId,
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 1),
  end: const LocalDate(2026, 9, 30),
  label: 'September',
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _overlapping = PayPeriod.create(
  id: const PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c52'),
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 30),
  end: const LocalDate(2026, 10, 15),
  label: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _october = PayPeriod.create(
  id: const PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c53'),
  employmentId: _employmentId,
  start: const LocalDate(2026, 10, 1),
  end: const LocalDate(2026, 10, 31),
  label: 'October',
  nowUtc: DateTime.utc(2026, 10, 1),
);
