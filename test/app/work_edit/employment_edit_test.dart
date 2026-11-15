import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/employment_edit.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/features/work/application/employment_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/facts.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

void main() {
  late ScheduleFixture fixture;
  late WorkReads reads;
  late EmploymentService service;
  late EmploymentAdapter adapter;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    reads = WorkReads(fixture.database);
    service = EmploymentService(
      DriftWorkRepository(fixture.database, clock: fixture.clock),
      idFactory: fixture.ids,
      clock: fixture.clock,
    );
    adapter = EmploymentAdapter(
      service: service,
      reads: reads,
      clock: fixture.clock,
    );
  });

  tearDown(() => fixture.dispose());

  RecordEditSession<EmploymentRecord, EmploymentValues> open([
    EmploymentRecord? record,
  ]) {
    final edit = RecordEditSession(adapter: adapter, baseline: record);
    addTearDown(edit.dispose);
    return edit;
  }

  Future<EmploymentRecord> depot() async =>
      (await reads.employment(fixtureEmployment))!;

  test('a new employment left untouched creates nothing', () async {
    final confirm = ScriptedConfirm();
    expect(await open().leave(confirm.call), LeaveDecision.proceed);
    expect(confirm.asked, isEmpty);
    expect(await reads.employments(), hasLength(1));
  });

  test('a new employment left with a name asks Save / Discard / Cancel and '
      'saves on Save', () async {
    final edit = open()
      ..edit(const EmploymentValues(name: ' Harbour ', legalLabel: ''));
    final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(await edit.leave(confirm.call), LeaveDecision.proceed);
    expect(confirm.asked.single, same(newRecordRequest));
    expect(edit.baseline!.value.name, 'Harbour');
    expect(edit.baseline!.value.legalLabel, isNull);
    expect(await reads.employments(), hasLength(2));
  });

  test('a blank name is refused before any write', () async {
    final edit = open()..edit(const EmploymentValues(name: '  '));
    expect(edit.issues, {'name': EmploymentProblems.name});
    expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(await reads.employments(), hasLength(1));
  });

  test('renaming saves without asking at the next revision', () async {
    final edit = open(await depot())
      ..edit(const EmploymentValues(name: 'Depot', legalLabel: 'UAB Depot'));
    final confirm = ScriptedConfirm();
    expect(await edit.save(confirm.call), SaveResult.committed);
    expect(confirm.asked, isEmpty);
    expect(edit.baseline!.value.revision, const Revision(1));
    expect((await depot()).value.legalLabel, 'UAB Depot');
  });

  test('an employment renamed elsewhere meanwhile is stale', () async {
    final edit = open(await depot())
      ..edit(const EmploymentValues(name: 'Depot'));
    await service.updateEmployment(
      const UpdateEmploymentCommand(
        employmentId: fixtureEmployment,
        expectedRevision: Revision(0),
        name: 'Elsewhere',
        legalLabel: null,
      ),
    );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.stale);
    await edit.reload();
    expect(edit.draft.name, 'Elsewhere');
  });

  test('an archived employment refuses a rename', () async {
    await service.archiveEmployment(
      const ArchiveEmploymentCommand(
        employmentId: fixtureEmployment,
        expectedRevision: Revision(0),
      ),
    );
    final edit = open(await depot())
      ..edit(const EmploymentValues(name: 'Depot'));
    expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(edit.problem, EmploymentProblems.archived);
  });

  test('read back finds a new employment the session sent', () async {
    const values = EmploymentValues(name: 'Harbour');
    await adapter.submit(null, values);
    final found = await adapter.readBack(null, values);
    expect((found as ReadFound<EmploymentRecord>).saved, isTrue);
    expect(found.value.value.name, 'Harbour');
  });
}
