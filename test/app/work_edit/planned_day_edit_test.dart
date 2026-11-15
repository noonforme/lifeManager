import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/planned_day_edit.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

/// The first Day of the depot rotation: 07:00–19:00 in Vilnius (UTC+3 in
/// October) with a 30-minute break at 12:00.
const _monday = LocalDate(2026, 10, 5);

/// An Off day of the rotation.
const _offDay = LocalDate(2026, 10, 8);

/// Submits through [inner], then throws: the write happened, but the
/// session cannot know it.
final class _ThrowsAfterWrite
    implements RecordEditAdapter<PlannedDayRecord, PlannedDayValues> {
  _ThrowsAfterWrite(this.inner);

  final PlannedDayAdapter inner;

  @override
  PlannedDayValues draftOf(PlannedDayRecord? saved) => inner.draftOf(saved);

  @override
  Map<String, String> validate(PlannedDayValues draft) => inner.validate(draft);

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) =>
      inner.describe(fields);

  @override
  Future<ConfirmRequest?> guard(
    PlannedDayRecord? baseline,
    PlannedDayValues draft,
  ) async => null;

  @override
  Future<SubmitResult<PlannedDayRecord>> submit(
    PlannedDayRecord? baseline,
    PlannedDayValues draft, {
    Object? consent,
  }) async {
    await inner.submit(baseline, draft, consent: consent);
    throw StateError('connection lost after the commit');
  }

  @override
  Future<ReadBack<PlannedDayRecord>> readBack(
    PlannedDayRecord? baseline,
    PlannedDayValues? submitted,
  ) => inner.readBack(baseline, submitted);
}

void main() {
  late ScheduleFixture fixture;
  late PlannedDayAdapter adapter;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    await fixture.saveDepot();
    adapter = PlannedDayAdapter(fixture.plans);
  });

  tearDown(() => fixture.dispose());

  Future<PlannedDayRecord> read(LocalDate date) async =>
      (await readPlannedDay(fixture.plans, fixtureEmployment, date))!;

  Future<RecordEditSession<PlannedDayRecord, PlannedDayValues>> open(
    LocalDate date,
  ) async {
    final edit = RecordEditSession(
      adapter: adapter,
      baseline: await read(date),
    );
    addTearDown(edit.dispose);
    return edit;
  }

  Future<List<DayException>> exceptions() async =>
      (await fixture.plans.repository.planInputs(fixtureEmployment)).exceptions;

  test('a planned day starts from its cycle times', () async {
    final record = await read(_monday);
    expect(record.exception, isNull);
    expect(
      record.values,
      const PlannedDayValues(
        start: LocalTime(7, 0),
        end: LocalTime(19, 0),
        endDayOffset: 0,
        breaks: [
          FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30),
        ],
      ),
    );
  });

  test('an off day holds no planned work day', () async {
    expect(
      await readPlannedDay(fixture.plans, fixtureEmployment, _offDay),
      isNull,
    );
  });

  test('saving writes a day exception without asking; the day stays '
      'unconfirmed', () async {
    final edit = await open(_monday);
    edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
    final confirm = ScriptedConfirm();
    expect(await edit.save(confirm.call), SaveResult.committed);
    expect(confirm.asked, isEmpty);
    final saved = edit.baseline!;
    expect(saved.exception, isA<ChangedDay>());
    expect(saved.exception!.revision, const Revision(0));
    expect(saved.day.endUtc, DateTime.utc(2026, 10, 5, 15));
    expect(saved.values.end, const LocalTime(18, 0));
    expect(edit.dirty, isFalse);
    final inputs = await fixture.plans.repository.planInputs(fixtureEmployment);
    expect(inputs.confirmedDates, isEmpty);
  });

  test('a second save edits the same exception at its revision', () async {
    final edit = await open(_monday);
    edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
    await edit.save(ScriptedConfirm().call);
    edit.edit(edit.draft.copyWith(end: const LocalTime(17, 0)));
    expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
    expect(edit.baseline!.exception!.revision, const Revision(1));
    expect(await exceptions(), hasLength(1));
  });

  test('leaving a changed day saves it without asking', () async {
    final edit = await open(_monday);
    edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
    final confirm = ScriptedConfirm();
    expect(await edit.leave(confirm.call), LeaveDecision.proceed);
    expect(confirm.asked, isEmpty);
    expect(await exceptions(), hasLength(1));
  });

  test('times that do not make a shift are refused before any write', () async {
    final edit = await open(_monday);
    edit.edit(
      edit.draft.copyWith(end: const LocalTime(7, 0), breaks: const []),
    );
    expect(edit.issues, {'end': PlannedDayProblems.end});
    expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(await exceptions(), isEmpty);
  });

  test('a break outside the shift is refused', () async {
    final edit = await open(_monday);
    edit.edit(
      edit.draft.copyWith(
        breaks: const [
          FixedBreak(start: LocalTime(19, 30), dayOffset: 0, minutes: 30),
        ],
      ),
    );
    expect(edit.issues, {'breaks': PlannedDayProblems.breaks});
  });

  test(
    'a day changed elsewhere meanwhile is stale; Reload record shows it',
    () async {
      final first = await open(_monday);
      final second = await open(_monday);
      first.edit(first.draft.copyWith(end: const LocalTime(18, 0)));
      await first.save(ScriptedConfirm().call);
      second.edit(second.draft.copyWith(end: const LocalTime(17, 0)));
      expect(await second.save(ScriptedConfirm().call), SaveResult.stale);
      expect(second.phase, EditPhase.stale);
      expect(second.draft.end, const LocalTime(17, 0));
      await second.reload();
      expect(second.phase, EditPhase.idle);
      expect(second.baseline!.values.end, const LocalTime(18, 0));
      expect(second.draft.end, const LocalTime(18, 0));
    },
  );

  test(
    'a day marked leave elsewhere meanwhile is stale and the leave stays',
    () async {
      final edit = await open(_monday);
      edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
      await fixture.plans.markLeave(
        fixtureEmployment,
        _monday,
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      expect(await edit.save(ScriptedConfirm().call), SaveResult.stale);
      expect((await exceptions()).single, isA<LeaveDay>());
      await edit.reload();
      expect(edit.gone, isTrue);
      expect(edit.draft.end, const LocalTime(18, 0));
    },
  );

  test('a day whose schedule changed meanwhile is stale, not saved over the '
      'new plan', () async {
    final edit = await open(_monday);
    edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
    final version = (await fixture.plans.repository.planInputs(
      fixtureEmployment,
    )).schedules.single;
    await fixture.schedules.update(
      version.id,
      expected: version.revision,
      draft: depotDraft(
        blocks: const [
          CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
          CycleBlock(count: 3, shiftTypeId: null),
          CycleBlock(count: 3, shiftTypeId: ShiftTypeId('day')),
          CycleBlock(count: 3, shiftTypeId: null),
        ],
      ),
    );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.stale);
    expect(await exceptions(), isEmpty);
    await edit.reload();
    expect(edit.baseline!.values.start, const LocalTime(19, 0));
  });

  test('a day confirmed meanwhile is refused on its date', () async {
    final edit = await open(_monday);
    edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
    expect(
      await fixture.plans.confirm(fixtureEmployment, _monday),
      isA<Committed<Object?>>(),
    );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(edit.issues, {'date': PlannedDayProblems.confirmed});
    expect(edit.problem, PlannedDayProblems.confirmed);
    expect(edit.draft.end, const LocalTime(18, 0));
  });

  test(
    'an extra day is saved as an extra and keeps counting as overtime',
    () async {
      await fixture.plans.addExtra(
        fixtureEmployment,
        _offDay,
        start: const LocalTime(8, 0),
        end: const LocalTime(16, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
        countsAsOvertime: true,
      );
      final edit = await open(_offDay);
      expect(edit.baseline!.day.isExtra, isTrue);
      edit.edit(edit.draft.copyWith(end: const LocalTime(17, 0)));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
      final saved = edit.baseline!.exception! as ExtraDay;
      expect(saved.countsAsOvertime, isTrue);
      expect(saved.end, const LocalTime(17, 0));
      expect(saved.revision, const Revision(1));
    },
  );

  test('read back: saved once the plan holds the submitted times, gone once '
      'confirmed', () async {
    final record = await read(_monday);
    final wanted = record.values.copyWith(end: const LocalTime(18, 0));
    final before = await adapter.readBack(record, wanted);
    expect((before as ReadFound<PlannedDayRecord>).saved, isFalse);
    await fixture.plans.changeDay(
      fixtureEmployment,
      _monday,
      start: wanted.start,
      end: wanted.end,
      endDayOffset: wanted.endDayOffset,
      breaks: wanted.breaks,
      shiftTypeId: null,
    );
    final after = await adapter.readBack(record, wanted);
    expect((after as ReadFound<PlannedDayRecord>).saved, isTrue);
    await fixture.plans.confirm(fixtureEmployment, _monday);
    expect(await adapter.readBack(record, wanted), isA<ReadGone<Object?>>());
  });

  test(
    'Reload and check after an uncertain save finds the saved day',
    () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final edit = RecordEditSession(
        adapter: _ThrowsAfterWrite(adapter),
        baseline: await read(_monday),
      );
      addTearDown(edit.dispose);
      edit.edit(edit.draft.copyWith(end: const LocalTime(18, 0)));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.uncertain);
      expect(reported.single.exception, isA<StateError>());
      await edit.check();
      expect(edit.phase, EditPhase.committed);
      expect(edit.baseline!.values.end, const LocalTime(18, 0));
      expect(edit.frozen, isFalse);
    },
  );
  test('a changed type is saved with the day', () async {
    final edit = await open(_monday);
    edit.edit(
      edit.draft.copyWith(
        start: const LocalTime(19, 0),
        end: const LocalTime(7, 0),
        endDayOffset: 1,
        breaks: const [
          FixedBreak(start: LocalTime(0, 0), dayOffset: 1, minutes: 30),
        ],
        shiftTypeId: () => const ShiftTypeId('night'),
      ),
    );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
    final saved = (await exceptions()).single as ChangedDay;
    expect(saved.shiftTypeId, const ShiftTypeId('night'));
    expect(saved.start, const LocalTime(19, 0));
    expect(saved.endDayOffset, 1);
  });

  test('an extra day keeps and changes Counts as overtime', () async {
    await fixture.plans.addExtra(
      fixtureEmployment,
      _offDay,
      start: const LocalTime(8, 0),
      end: const LocalTime(14, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: null,
      countsAsOvertime: false,
    );
    final edit = await open(_offDay);
    expect(edit.draft.countsAsOvertime, isFalse);
    edit.edit(edit.draft.copyWith(countsAsOvertime: true));
    expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
    final saved = (await exceptions()).single as ExtraDay;
    expect(saved.countsAsOvertime, isTrue);
    expect(edit.baseline!.values.countsAsOvertime, isTrue);
  });
}
