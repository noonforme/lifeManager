import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  late AppDatabase database;
  late DriftWorkRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWorkRepository(database);
  });

  tearDown(() => database.close());

  test(
    'stale employment update affects zero rows and preserves newer data',
    () async {
      final original = _employment();
      await repository.insertEmployment(original);
      final newer = Employment(
        id: original.id,
        name: 'Newer synthetic name',
        legalLabel: original.legalLabel,
        status: original.status,
        createdAtUtc: original.createdAtUtc,
        updatedAtUtc: DateTime.utc(2026, 9, 29, 11),
        revision: const Revision(1),
      );
      final stale = Employment(
        id: original.id,
        name: 'Stale synthetic name',
        legalLabel: original.legalLabel,
        status: original.status,
        createdAtUtc: original.createdAtUtc,
        updatedAtUtc: DateTime.utc(2026, 9, 29, 12),
        revision: const Revision(1),
      );

      expect(
        await repository.updateEmployment(newer, expected: const Revision(0)),
        1,
      );
      expect(
        await repository.updateEmployment(stale, expected: const Revision(0)),
        0,
      );
      expect((await repository.employmentById(original.id))!.name, newer.name);
    },
  );

  test('employment watcher publishes committed archive', () async {
    final original = _employment();
    await repository.insertEmployment(original);
    final archived = original.archive(nowUtc: DateTime.utc(2026, 9, 29, 11));
    final states = repository.watchEmployment(original.id).take(2).toList();

    await Future<void>.delayed(Duration.zero);
    await repository.updateEmployment(archived, expected: original.revision);

    expect((await states).map((value) => value?.status), [
      EmploymentStatus.active,
      EmploymentStatus.archived,
    ]);
  });

  test('concurrent agreement creation cannot commit an overlap', () async {
    await repository.insertEmployment(_employment());

    final outcomes = await Future.wait([
      repository.createAgreement(_agreement(version: 1)),
      repository.createAgreement(
        _agreement(
          id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22'),
          version: 2,
          start: const LocalDate(2026, 9, 15),
        ),
      ),
    ]);

    expect(outcomes.whereType<Committed<PayAgreement>>(), hasLength(1));
    expect(outcomes.whereType<Invalid<PayAgreement>>(), hasLength(1));
    expect(await repository.agreementsFor(_employmentId), hasLength(1));
  });

  test('adjacent inclusive agreement ranges do not overlap', () async {
    await repository.insertEmployment(_employment());
    final first = _agreement(end: const LocalDate(2026, 9, 30));
    final second = _agreement(
      id: const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c22'),
      version: 2,
      start: const LocalDate(2026, 10, 1),
    );

    expect(
      await repository.createAgreement(first),
      isA<Committed<PayAgreement>>(),
    );
    expect(
      await repository.createAgreement(second),
      isA<Committed<PayAgreement>>(),
    );
  });

  test('agreement referenced by finalized shift is immutable', () async {
    await repository.insertEmployment(_employment());
    final agreement = _agreement();
    await repository.insertAgreement(agreement);
    await database.customStatement(
      '''
      INSERT INTO work_shifts (
        id, employment_id, agreement_id, state, start_utc_micros,
        end_utc_micros, timezone_id, local_start_date,
        note, void_reason, replacement_shift_id, replaced_shift_id,
        created_at_utc_micros, updated_at_utc_micros, revision
      ) VALUES (?, ?, ?, 'finalized', 1, 2, 'Europe/Berlin', '2026-09-29',
        NULL, NULL, NULL, NULL, 1, 2, 1)
      ''',
      [
        '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31',
        _employmentId.value,
        agreement.id.value,
      ],
    );
    final changed = PayAgreement(
      id: agreement.id,
      employmentId: agreement.employmentId,
      version: agreement.version,
      effectiveStart: agreement.effectiveStart,
      effectiveEnd: const LocalDate(2026, 9, 30),
      hourlyRateMicroEur: agreement.hourlyRateMicroEur,
      basis: agreement.basis,
      overtimeThresholdMinutes: agreement.overtimeThresholdMinutes,
      overtimeMultiplier: agreement.overtimeMultiplier,
      label: agreement.label,
      note: agreement.note,
      createdAtUtc: agreement.createdAtUtc,
      revision: agreement.revision.next(),
      usedByFinalizedShift: true,
    );

    expect(
      await repository.updateUnusedAgreement(
        changed,
        expected: agreement.revision,
      ),
      0,
    );
    expect(
      (await repository.agreementsFor(_employmentId)).single.effectiveEnd,
      isNull,
    );
    expect(
      (await repository.agreementsFor(_employmentId))
          .single
          .usedByFinalizedShift,
      isTrue,
    );
  });
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

Employment _employment() => Employment.create(
  id: _employmentId,
  name: 'Synthetic employer',
  legalLabel: null,
  nowUtc: DateTime.utc(2026, 9, 29, 10),
);

PayAgreement _agreement({
  AgreementId id = const AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21'),
  int version = 1,
  LocalDate start = const LocalDate(2026, 9, 1),
  LocalDate? end,
}) => PayAgreement(
  id: id,
  employmentId: _employmentId,
  version: version,
  effectiveStart: start,
  effectiveEnd: end,
  hourlyRateMicroEur: 20000000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: 'Synthetic agreement',
  note: null,
  createdAtUtc: DateTime.utc(2026, 9, 1),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
