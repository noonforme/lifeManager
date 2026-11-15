import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/schedule_edit.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

/// The depot's values (3 Day, 3 off, 3 Night, 3 off) from [from].
ScheduleValues _depot({LocalDate from = const LocalDate(2026, 10, 5)}) {
  final draft = depotDraft(from: from);
  return ScheduleValues(
    name: draft.name,
    timezoneId: draft.timezoneId,
    cycleStart: draft.cycleStart,
    inUseFrom: draft.inUseFrom,
    inUseUntil: draft.inUseUntil,
    types: draft.shiftTypes,
    blocks: draft.blocks,
  );
}

final _empty = ScheduleValues(
  name: '',
  timezoneId: 'Europe/Vilnius',
  cycleStart: const LocalDate(2026, 12, 1),
  inUseFrom: const LocalDate(2026, 12, 1),
  inUseUntil: null,
  types: const [],
  blocks: const [],
);

void main() {
  late ScheduleFixture fixture;
  late WorkReads reads;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    reads = WorkReads(fixture.database);
  });
  tearDown(() => fixture.dispose());

  ScheduleService service(ScheduleRepository repository) => ScheduleService(
    repository: repository,
    ids: fixture.ids,
    clock: fixture.clock,
  );

  ScheduleSession session({
    ScheduleRecord? baseline,
    ScheduleRepository? repository,
    bool versioning = false,
    LocalDate? versionStart,
    LocalDate? lastConfirmed,
    ScheduleValues? defaults,
  }) {
    final made = ScheduleSession(
      adapter: ScheduleAdapter(
        employmentId: fixtureEmployment,
        defaults: defaults ?? _empty,
        service: service(repository ?? fixture.repository),
        reads: reads,
        clock: fixture.clock,
        versioning: versioning,
        versionStart: versionStart,
        lastConfirmed: lastConfirmed,
      ),
      baseline: baseline,
    );
    addTearDown(made.dispose);
    return made;
  }

  Future<ScheduleRecord> depot() async =>
      ScheduleRecord(await fixture.saveDepot());

  test('a new schedule saves with its types and cycle', () async {
    final edit = session();
    expect(edit.edit(_depot(from: const LocalDate(2026, 12, 1))), isNull);
    expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
    final row = (await reads.scheduleRows(fixtureEmployment)).single;
    expect(row.schedule.shiftTypes, hasLength(2));
    expect(row.schedule.cycleLength, 12);
    expect(edit.baseline!.value.id, row.schedule.id);
  });

  test('an unused version is edited in place', () async {
    final stored = await depot();
    final edit = session(baseline: stored);
    final four = withBlockField(edit.draft, 0, ScheduleField.blockDays, '4');
    expect(edit.edit(four.values!), isNull);
    expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
    final row = (await reads.scheduleRows(fixtureEmployment)).single;
    expect(row.schedule.version, 1);
    expect(row.schedule.cycleLength, 13);
    expect(row.schedule.revision, isNot(stored.value.revision));
  });

  test('a used version needs Change schedule from', () async {
    final stored = await depot();
    await fixture.markUsed(stored.value);
    final used = (await reads.schedule(fixtureEmployment, stored.value.id))!;
    final edit = session(baseline: used);
    edit.edit(
      withBlockField(edit.draft, 0, ScheduleField.blockDays, '4').values!,
    );
    await edit.save(ScriptedConfirm().call);
    expect(
      edit.issues[ScheduleField.versionFrom],
      ScheduleProblems.versionFromRequired,
    );
    expect(
      (await reads.scheduleRows(fixtureEmployment)).single.schedule.cycleLength,
      12,
    );
  });

  ScheduleSession versioningSession(
    ScheduleRecord used, {
    ScheduleRepository? repository,
  }) => session(
    baseline: used,
    repository: repository,
    versioning: true,
    versionStart: used.value.inUseFrom,
    lastConfirmed: const LocalDate(2026, 10, 5),
    defaults: ScheduleValues.of(used.value)
        .copyWith(versionFrom: () => const LocalDate(2026, 10, 19)),
  );

  test('a new version from a day after the last confirmed one', () async {
    final stored = await depot();
    await fixture.markUsed(stored.value);
    final used = (await reads.schedule(fixtureEmployment, stored.value.id))!;
    final edit = versioningSession(used);
    expect(edit.draft.versionFrom, const LocalDate(2026, 10, 19));
    edit.edit(
      withBlockField(edit.draft, 0, ScheduleField.blockDays, '4').values!,
    );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
    final rows = await reads.scheduleRows(fixtureEmployment);
    expect(rows, hasLength(2));
    expect(rows.first.schedule.inUseUntil, const LocalDate(2026, 10, 18));
    expect(rows.last.schedule.inUseFrom, const LocalDate(2026, 10, 19));
    expect(rows.last.schedule.cycleLength, 13);
    expect(edit.baseline!.value.version, 2);
  });

  test('a From after the schedule ends is refused on the From', () async {
    final stored = await depot();
    await fixture.markUsed(stored.value);
    final used = (await reads.schedule(fixtureEmployment, stored.value.id))!;
    final edit = versioningSession(used);
    edit.edit(
      edit.draft.copyWith(
        inUseUntil: () => const LocalDate(2026, 10, 31),
        versionFrom: () => const LocalDate(2026, 11, 2),
      ),
    );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(
      edit.issues[ScheduleField.versionFrom],
      ScheduleProblems.afterUntil(const LocalDate(2026, 10, 31)),
    );
    expect(edit.issues.containsKey(ScheduleField.inUseUntil), isFalse);
  });

  test('a From on the last confirmed day is refused in words', () async {
    final stored = await depot();
    await fixture.markUsed(stored.value);
    final used = (await reads.schedule(fixtureEmployment, stored.value.id))!;
    final edit = versioningSession(used);
    edit.edit(
      edit.draft.copyWith(versionFrom: () => const LocalDate(2026, 10, 5)),
    );
    await edit.save(ScriptedConfirm().call);
    expect(
      edit.issues[ScheduleField.versionFrom],
      ScheduleProblems.confirmedUpTo(const LocalDate(2026, 10, 5)),
    );
    // Without confirmed days to name, a day on or before the start says so.
    final unconfirmed = session(
      baseline: used,
      versioning: true,
      versionStart: used.value.inUseFrom,
      defaults: ScheduleValues.of(used.value)
          .copyWith(versionFrom: () => const LocalDate(2026, 10, 4)),
    );
    unconfirmed.edit(
      withBlockField(
        unconfirmed.draft,
        0,
        ScheduleField.blockDays,
        '4',
      ).values!,
    );
    await unconfirmed.save(ScriptedConfirm().call);
    expect(
      unconfirmed.issues[ScheduleField.versionFrom],
      ScheduleProblems.afterStart(const LocalDate(2026, 10, 5)),
    );
    expect(await reads.scheduleRows(fixtureEmployment), hasLength(1));
    expect(
      describeScheduleIssues(
        {
          'newVersionFrom': const [FieldIssue(FieldIssueCode.conflict)],
        },
        versionStart: null,
        lastConfirmed: const LocalDate(2026, 10, 5),
      ),
      {
        ScheduleField.versionFrom: ScheduleProblems.confirmedUpTo(
          const LocalDate(2026, 10, 5),
        ),
      },
    );
  });

  test('an overlapping schedule is refused on In use from', () async {
    await depot();
    final edit = session();
    edit.edit(
      _depot(from: const LocalDate(2026, 11, 1)).copyWith(name: 'Second'),
    );
    await edit.save(ScriptedConfirm().call);
    expect(edit.issues[ScheduleField.inUseFrom], ScheduleProblems.overlap);
    expect(edit.draft.name, 'Second');
  });

  test('a save the store refuses is Unavailable', () async {
    final edit = session(repository: RefusingSchedules(fixture.repository));
    edit.edit(_depot(from: const LocalDate(2026, 12, 1)));
    await edit.save(ScriptedConfirm().call);
    expect(edit.problem, EditProblems.unavailable);
    expect(edit.draft.name, 'Depot rotation');
    expect(await reads.scheduleRows(fixtureEmployment), isEmpty);
  });

  test('an unknown result is settled by Reload and check', () async {
    final edit = session(repository: LosingSchedules(fixture.repository));
    edit.edit(_depot(from: const LocalDate(2026, 12, 1)));
    await edit.save(ScriptedConfirm().call);
    expect(edit.phase, EditPhase.uncertain);
    await edit.check();
    expect(edit.phase, isNot(EditPhase.uncertain));
    expect(edit.dirty, isFalse);
    final row = (await reads.scheduleRows(fixtureEmployment)).single;
    expect(edit.baseline!.value.id, row.schedule.id);
  });

  test('an unknown new version is found by Reload and check', () async {
    final stored = await depot();
    await fixture.markUsed(stored.value);
    final used = (await reads.schedule(fixtureEmployment, stored.value.id))!;
    final edit = versioningSession(
      used,
      repository: LosingSchedules(fixture.repository),
    );
    edit.edit(
      withBlockField(edit.draft, 0, ScheduleField.blockDays, '4').values!,
    );
    await edit.save(ScriptedConfirm().call);
    expect(edit.phase, EditPhase.uncertain);
    await edit.check();
    expect(edit.phase, isNot(EditPhase.uncertain));
    expect(edit.baseline!.value.version, 2);
  });

  test('a check that finds nothing offers Save again', () async {
    final edit = session(
      repository: LosingSchedules(fixture.repository, before: true),
    );
    edit.edit(_depot(from: const LocalDate(2026, 12, 1)));
    await edit.save(ScriptedConfirm().call);
    expect(edit.phase, EditPhase.uncertain);
    await edit.check();
    expect(edit.phase, isNot(EditPhase.uncertain));
    expect(edit.isNew, isTrue);
    expect(edit.dirty, isTrue);
  });
}
