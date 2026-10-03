import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/data/schedule_repository.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  const employment = fixtureEmployment;
  late ScheduleFixture fixture;
  late ScheduleService service;
  late DriftScheduleRepository repository;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    service = fixture.schedules;
    repository = fixture.repository;
  });
  tearDown(() => fixture.dispose());

  Future<void> markUsed(WorkSchedule value) => fixture.markUsed(value);

  test('a valid rotation is saved as version 1', () async {
    final outcome = await service.create(depotDraft());
    final saved = (outcome as Committed<WorkSchedule>).value;
    expect(saved.version, 1);
    expect((await repository.schedulesFor(employment)).single.cycleLength, 12);
  });

  test('a block count of 0 is invalid on blocks[0].count', () async {
    final outcome = await service.create(depotDraft(firstCount: 0));
    expect(
      (outcome as Invalid<WorkSchedule>).fields.keys,
      contains('blocks[0].count'),
    );
  });

  test('a second schedule on the same dates is invalid on inUseFrom', () async {
    await service.create(depotDraft());
    final outcome = await service.create(depotDraft(name: 'Other'));
    expect((outcome as Invalid<WorkSchedule>).fields.keys, ['inUseFrom']);
  });

  test('an unused version is edited in place', () async {
    final saved =
        (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    final outcome = await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(name: 'Depot, new name'),
    );
    final updated = (outcome as Committed<WorkSchedule>).value;
    expect(updated.version, 1);
    expect(updated.name, 'Depot, new name');
  });

  test('a used version needs a date and starts version 2 from it', () async {
    final saved =
        (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    await markUsed(saved); // inserts a finalized shift linked to version 1
    final missing = await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(firstCount: 2),
    );
    expect((missing as Invalid<WorkSchedule>).fields.keys, ['newVersionFrom']);

    final outcome = await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(firstCount: 2),
      newVersionFrom: const LocalDate(2026, 11, 1),
    );
    final next = (outcome as Committed<WorkSchedule>).value;
    expect(next.version, 2);
    expect(next.inUseFrom, const LocalDate(2026, 11, 1));
    final versions = await repository.schedulesFor(employment);
    expect(
      versions.firstWhere((v) => v.version == 1).inUseUntil,
      const LocalDate(2026, 10, 31),
    );
  });

  test('a used schedule cannot be deleted', () async {
    final saved =
        (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    await markUsed(saved);
    final outcome = await service.delete(saved.id, expected: saved.revision);
    expect((outcome as Invalid<WorkSchedule>).fields.keys, ['schedule']);
  });

  test('an edit against an old revision is Stale', () async {
    final saved =
        (await service.create(depotDraft()) as Committed<WorkSchedule>).value;
    await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(name: 'A'),
    );
    final outcome = await service.update(
      saved.id,
      expected: saved.revision,
      draft: depotDraft(name: 'B'),
    );
    expect(outcome, isA<Stale<WorkSchedule>>());
  });
}
