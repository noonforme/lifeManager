import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/manual_shift_service.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

const _day = LocalDate(2026, 10, 20);

/// 08:00–16:00 in Vilnius (UTC+3 in October) with a 30-minute break at
/// noon.
const _defaults = ShiftValues(
  startDate: _day,
  start: LocalTime(8, 0),
  endDate: _day,
  end: LocalTime(16, 0),
  timezoneId: 'Europe/Vilnius',
  breaks: [
    BreakValues(
      startDate: _day,
      start: LocalTime(12, 0),
      endDate: _day,
      end: LocalTime(12, 30),
    ),
  ],
);

/// Submits through [inner], then throws: the write happened, but the
/// session cannot know it.
final class _ThrowsAfterWrite
    implements RecordEditAdapter<ShiftRecord, ShiftValues> {
  _ThrowsAfterWrite(this.inner);

  final ShiftAdapter inner;

  @override
  ShiftValues draftOf(ShiftRecord? saved) => inner.draftOf(saved);

  @override
  Map<String, String> validate(ShiftValues draft) => inner.validate(draft);

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) =>
      inner.describe(fields);

  @override
  Future<ConfirmRequest?> guard(ShiftRecord? baseline, ShiftValues draft) =>
      inner.guard(baseline, draft);

  @override
  Future<SubmitResult<ShiftRecord>> submit(
    ShiftRecord? baseline,
    ShiftValues draft, {
    Object? consent,
  }) async {
    await inner.submit(baseline, draft, consent: consent);
    throw StateError('connection lost after the commit');
  }

  @override
  Future<ReadBack<ShiftRecord>> readBack(
    ShiftRecord? baseline,
    ShiftValues? submitted,
  ) => inner.readBack(baseline, submitted);
}

void main() {
  late ScheduleFixture fixture;
  late WorkReads reads;
  late ShiftAdapter adapter;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    reads = WorkReads(fixture.database);
    final timezones = IanaTimezoneService();
    adapter = ShiftAdapter(
      employmentId: fixtureEmployment,
      defaults: _defaults,
      create: ManualShiftService(
        fixture.shifts,
        idFactory: fixture.ids,
        clock: fixture.clock,
        timezones: timezones,
      ),
      revise: ShiftDraftRevisionService(
        fixture.shifts,
        idFactory: fixture.ids,
        clock: fixture.clock,
        timezones: timezones,
      ),
      reads: reads,
      timezones: timezones,
      clock: fixture.clock,
    );
  });

  tearDown(() => fixture.dispose());

  RecordEditSession<ShiftRecord, ShiftValues> open([ShiftRecord? record]) {
    final edit = RecordEditSession(adapter: adapter, baseline: record);
    addTearDown(edit.dispose);
    return edit;
  }

  /// A draft shift 07:00–15:00 on [_day], as a correction leaves its
  /// replacement; [withoutEnd] leaves its end unset.
  Future<ShiftRecord> draftShift({bool withoutEnd = false}) async {
    final id = fixture.ids.shiftId();
    await ShiftDao(fixture.database).insert(
      WorkShift(
        id: id,
        employmentId: fixtureEmployment,
        agreementId: null,
        state: ShiftState.draft,
        startUtc: DateTime.utc(2026, 10, 20, 4),
        endUtc: withoutEnd ? null : DateTime.utc(2026, 10, 20, 12),
        timezoneId: 'Europe/Vilnius',
        localStartDate: _day,
        note: null,
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: fixture.clock.value,
        updatedAtUtc: fixture.clock.value,
        revision: const Revision(0),
      ),
    );
    return (await reads.shift(id))!;
  }

  test(
    'a new shift holding only its defaults creates nothing on leave',
    () async {
      final edit = open();
      final confirm = ScriptedConfirm();
      expect(await edit.leave(confirm.call), LeaveDecision.proceed);
      expect(confirm.asked, isEmpty);
      expect(await reads.shiftsOf(fixtureEmployment), isEmpty);
    },
  );

  test(
    'saving a new shift asks to finalize, with Discard for Revert',
    () async {
      final edit = open()
        ..edit(_defaults.copyWith(end: const LocalTime(17, 0)));
      final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await edit.save(confirm.call), SaveResult.committed);
      final asked = confirm.asked.single;
      expect(asked.proceed, 'Save and finalize');
      expect(asked.revert, 'Discard');
      final saved = edit.baseline!;
      expect(saved.shift.state, ShiftState.finalized);
      expect(saved.shift.agreementId, fixtureAgreement);
      expect(saved.shift.startUtc, DateTime.utc(2026, 10, 20, 5));
      expect(saved.shift.endUtc, DateTime.utc(2026, 10, 20, 14));
      expect(saved.breaks, hasLength(1));
      expect(edit.draft, _defaults.copyWith(end: const LocalTime(17, 0)));
      expect(edit.dirty, isFalse);
    },
  );

  test(
    'leaving a new shift with values asks the finalization window once',
    () async {
      final edit = open()
        ..edit(_defaults.copyWith(end: const LocalTime(17, 0)));
      final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await edit.leave(confirm.call), LeaveDecision.proceed);
      expect(confirm.asked.single.title, 'Finalize shift');
      expect(await reads.shiftsOf(fixtureEmployment), hasLength(1));
    },
  );

  test('Cancel keeps the new values unsaved; Discard drops them', () async {
    final edit = open()..edit(_defaults.copyWith(end: const LocalTime(17, 0)));
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.cancel]).call),
      SaveResult.cancelled,
    );
    expect(edit.dirty, isTrue);
    expect(
      await edit.undo(ScriptedConfirm([ConfirmAnswer.revert]).call),
      SaveResult.reverted,
    );
    expect(edit.draft, _defaults);
    expect(await reads.shiftsOf(fixtureEmployment), isEmpty);
  });

  test('a draft shift is revised and finalized at its revision', () async {
    final edit = open(await draftShift());
    expect(edit.draft.start, const LocalTime(7, 0));
    edit.edit(edit.draft.copyWith(end: const LocalTime(16, 0)));
    final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(await edit.save(confirm.call), SaveResult.committed);
    expect(confirm.asked.single.revert, 'Revert');
    expect(edit.baseline!.shift.state, ShiftState.finalized);
    expect(edit.baseline!.shift.endUtc, DateTime.utc(2026, 10, 20, 13));
  });

  test('an open draft starts as a zero-length shift that cannot save until '
      'its end is set', () async {
    final edit = open(await draftShift(withoutEnd: true));
    expect(edit.draft.end, edit.draft.start);
    expect(adapter.validate(edit.draft), {'end': ShiftProblems.endAfterStart});
    edit.edit(edit.draft.copyWith(end: const LocalTime(15, 0)));
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.committed,
    );
    expect(edit.baseline!.shift.endUtc, DateTime.utc(2026, 10, 20, 12));
  });

  test('a draft finalized elsewhere meanwhile is stale, not refused as '
      'unfinalizable', () async {
    final record = await draftShift();
    final edit = open(record)
      ..edit(_defaults.copyWith(end: const LocalTime(16, 0)));
    await fixture.shifts.finalizeShift(
      record.shift.id,
      expected: record.shift.revision,
    );
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.stale,
    );
    expect(edit.phase, EditPhase.stale);
  });

  test(
    'a draft ending in the repeated autumn hour saves with its fold',
    () async {
      // Vilnius goes back from 04:00 to 03:00 on 2026-10-25: 01:30Z is the
      // second 03:30.
      final id = fixture.ids.shiftId();
      await ShiftDao(fixture.database).insert(
        WorkShift(
          id: id,
          employmentId: fixtureEmployment,
          agreementId: null,
          state: ShiftState.draft,
          startUtc: DateTime.utc(2026, 10, 24, 16),
          endUtc: DateTime.utc(2026, 10, 25, 1, 30),
          timezoneId: 'Europe/Vilnius',
          localStartDate: const LocalDate(2026, 10, 24),
          note: null,
          voidReason: null,
          replacementShiftId: null,
          replacedShiftId: null,
          createdAtUtc: fixture.clock.value,
          updatedAtUtc: fixture.clock.value,
          revision: const Revision(0),
        ),
      );
      final edit = open(await reads.shift(id));
      expect(edit.draft.endFold, FoldChoice.later);
      edit.edit(
        edit.draft.copyWith(note: () => 'Night before the clock change'),
      );
      expect(
        await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
        SaveResult.committed,
      );
      expect(edit.baseline!.shift.endUtc, DateTime.utc(2026, 10, 25, 1, 30));
    },
  );

  test('a draft revised elsewhere meanwhile is stale', () async {
    final record = await draftShift();
    final edit = open(record)
      ..edit(_defaults.copyWith(end: const LocalTime(16, 0)));
    await ShiftDao(fixture.database).reviseDraft(
      record.shift.revisedFacts(
        startUtc: record.shift.startUtc,
        endUtc: DateTime.utc(2026, 10, 20, 11),
        timezoneId: record.shift.timezoneId,
        localStartDate: _day,
        note: 'changed elsewhere',
      ),
      expected: const Revision(0),
    );
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.stale,
    );
    expect(edit.phase, EditPhase.stale);
    await edit.reload();
    expect(edit.baseline!.shift.note, 'changed elsewhere');
  });

  test('times out of order are refused before any write', () async {
    final edit = open()
      ..edit(_defaults.copyWith(end: const LocalTime(7, 0), breaks: const []));
    expect(edit.issues, {'end': ShiftProblems.endAfterStart});
    final confirm = ScriptedConfirm();
    expect(await edit.save(confirm.call), SaveResult.invalid);
    expect(confirm.asked, isEmpty);
    expect(await reads.shiftsOf(fixtureEmployment), isEmpty);
  });

  test('a break outside the shift is refused on that break', () {
    final edit = open()
      ..edit(
        _defaults.copyWith(
          breaks: const [
            BreakValues(
              startDate: _day,
              start: LocalTime(15, 45),
              endDate: _day,
              end: LocalTime(16, 15),
            ),
          ],
        ),
      );
    expect(edit.issues, {'breaks.0': ShiftProblems.breakInside});
  });

  test('breaks are checked in start order; an overlap is reported on the '
      "break's own index", () async {
    BreakValues at(LocalTime start, LocalTime end) =>
        BreakValues(startDate: _day, start: start, endDate: _day, end: end);
    final later = at(const LocalTime(13, 0), const LocalTime(13, 30));
    expect(
      adapter.validate(
        _defaults.copyWith(
          breaks: [later, at(const LocalTime(12, 0), const LocalTime(12, 30))],
        ),
      ),
      isEmpty,
    );
    expect(
      adapter.validate(
        _defaults.copyWith(
          breaks: [later, at(const LocalTime(12, 0), const LocalTime(13, 15))],
        ),
      ),
      {'breaks.0': ShiftProblems.breakInside},
    );
    final edit = open()
      ..edit(
        _defaults.copyWith(
          breaks: [later, at(const LocalTime(12, 0), const LocalTime(12, 30))],
        ),
      );
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.committed,
    );
    expect(edit.baseline!.breaks, hasLength(2));
  });

  test('a date no agreement covers is refused by the command', () async {
    const august = LocalDate(2026, 8, 20);
    final edit = open()
      ..edit(
        _defaults.copyWith(
          startDate: august,
          endDate: august,
          breaks: const [],
        ),
      );
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.invalid,
    );
    expect(edit.problem, ShiftProblems.cannotFinalize);
    expect(edit.dirty, isTrue);
  });

  test('a wall-clock time that does not exist is refused', () async {
    // Clocks in Vilnius jump from 03:00 to 04:00 on 2027-03-28.
    const springForward = LocalDate(2027, 3, 28);
    final edit = open()
      ..edit(
        _defaults.copyWith(
          startDate: springForward,
          start: const LocalTime(3, 30),
          endDate: springForward,
          breaks: const [],
        ),
      );
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.invalid,
    );
    expect(edit.issues, {'localTime': ShiftProblems.localTime});
  });

  test(
    'a finalized shift is read-only, and a save of it writes nothing',
    () async {
      final edit = open()
        ..edit(_defaults.copyWith(end: const LocalTime(17, 0)));
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      final finalized = edit.baseline!;
      expect(shiftReadOnlyReason(finalized.shift), ShiftProblems.finalized);
      final again = open(finalized)
        ..edit(_defaults.copyWith(end: const LocalTime(18, 0)));
      final confirm = ScriptedConfirm();
      expect(await again.save(confirm.call), SaveResult.invalid);
      expect(confirm.asked, isEmpty);
      expect(again.problem, ShiftProblems.finalized);
      expect(
        (await reads.shift(finalized.shift.id))!.shift.revision,
        finalized.shift.revision,
      );
    },
  );

  test('Reload and check after an uncertain create finds the shift', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final edit = RecordEditSession(adapter: _ThrowsAfterWrite(adapter))
      ..edit(_defaults.copyWith(end: const LocalTime(17, 0)));
    addTearDown(edit.dispose);
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call),
      SaveResult.uncertain,
    );
    await edit.check();
    expect(edit.phase, EditPhase.committed);
    expect(edit.baseline!.shift.state, ShiftState.finalized);
    expect(await reads.shiftsOf(fixtureEmployment), hasLength(1));
  });

  test(
    'read back finds a saved shift whose note the service trimmed',
    () async {
      final values = _defaults.copyWith(note: () => '  late start ');
      await adapter.submit(null, values);
      final found = await adapter.readBack(null, values);
      expect((found as ReadFound<ShiftRecord>).saved, isTrue);
      expect(found.value.shift.note, 'late start');
    },
  );

  test(
    'read back of a new shift the command refused finds it not created',
    () async {
      const august = LocalDate(2026, 8, 20);
      final refused = _defaults.copyWith(
        startDate: august,
        endDate: august,
        breaks: const [],
      );
      await adapter.submit(null, refused);
      expect(
        await adapter.readBack(null, refused),
        isA<ReadNotSaved<Object?>>(),
      );
    },
  );
}
