import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/day_action.dart';
import 'package:lifeos/app/work_shell/day_commands.dart';
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const _monday = LocalDate(2026, 10, 5);

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedConfirm confirm;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    confirm = ScriptedConfirm();
  });

  tearDown(() => fixture.dispose());

  /// Waits until [condition] holds, letting the database's streams run.
  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<ShiftsSheetController> open({
    Future<ShiftRecord?> Function(ShiftId)? readShift,
  }) async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      readShift: readShift,
      employmentId: fixtureEmployment,
      month: ShiftsSheetFixture.month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      // Each test may script its own answers after the sheet opens.
      confirm: (request) => confirm.call(request),
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  /// A correction's replacement draft of a finalized shift on the 20th.
  Future<WorkShift> replacementDraft() async {
    final original = await fixture.finishShift(20);
    final outcome = await fixture.work.shifts.correctShift(
      CorrectShiftCommand(
        originalId: original.id,
        replacementId: fixture.schedule.ids.shiftId(),
        expectedRevision: original.revision,
        voidReason: 'Wrong end',
      ),
    );
    return (outcome as Committed<WorkShift>).value;
  }

  test('Correct applies only to a finalized shift; it commits and selects '
      'the replacement draft, ready to edit', () async {
    final stored = await fixture.finishShift(20);
    final sheet = await open();
    await sheet.select(plannedRowId(_monday));
    expect(sheet.correctBlocked, ShiftsCommandWords.correctOnlyFinalized);
    expect(sheet.voidBlocked, ShiftsCommandWords.voidOnlyStored);

    await sheet.select(storedRowId(stored));
    expect(sheet.correctBlocked, isNull);
    expect(sheet.voidBlocked, isNull);
    expect(await sheet.openAction(ShiftsActionKind.correct), isTrue);
    final action = sheet.action!;
    expect(action.shift.id, stored.id);
    expect(sheet.edit, isNull);
    expect(sheet.correctBlocked, ShiftsCommandWords.actionOpen);

    action.setReason('Wrong end');
    await sheet.submitAction();
    expect(sheet.action, isNull);
    final edit = sheet.edit! as StoredEdit;
    final replacement = edit.session.baseline!.shift;
    expect(replacement.state, ShiftState.draft);
    expect(replacement.replacedShiftId, stored.id);
    expect(sheet.selectedId, storedRowId(replacement));
    expect(sheet.notice, ShiftsNotices.corrected);
    expect(
      sheet.editField(
        sheet.selectedId!,
        ShiftsField.end,
        const LocalTime(17, 0),
      ),
      isNull,
    );
    expect(sheet.edit!.dirty, isTrue);
    expect(sheet.notice, ShiftsNotices.corrected, reason: 'until it moves');
  });

  test('Void selects the void shift, read-only, with its notice', () async {
    final stored = await fixture.finishShift(20);
    final sheet = await open();
    await sheet.select(storedRowId(stored));
    await sheet.openAction(ShiftsActionKind.voidShift);
    sheet.action!.setReason('Not worked');
    await sheet.submitAction();
    expect(sheet.action, isNull);
    expect(sheet.edit, isNull);
    expect(sheet.selectedId, storedRowId(stored));
    expect(sheet.readOnlyReason, ShiftProblems.voided);
    expect(sheet.notice, ShiftsNotices.voided);
    await until(() => sheet.voidBlocked != null);
    expect(sheet.voidBlocked, ShiftsCommandWords.voidOnlyStored);
  });

  test(
    'a committed correction stays locked while the replacement read waits',
    () async {
      final stored = await fixture.finishShift(20);
      final release = Completer<void>();
      var delayReads = false;
      var followReads = 0;
      final sheet = await open(
        readShift: (id) async {
          if (delayReads) {
            followReads++;
            await release.future;
          }
          return fixture.reads.shift(id);
        },
      );
      await sheet.select(storedRowId(stored));
      await sheet.openAction(ShiftsActionKind.correct);
      sheet.action!.setReason('Wrong end');
      delayReads = true;
      final submitting = sheet.submitAction();
      try {
        await until(() => followReads == 1);
        expect(sheet.action!.busy, isTrue);
        expect(sheet.action!.canSubmit, isFalse);
        expect(await sheet.select(plannedRowId(_monday)), isFalse);
        await sheet.submitAction();
        expect(followReads, 1);
      } finally {
        release.complete();
        await submitting;
      }
      expect(sheet.action, isNull);
      expect(sheet.edit, isA<StoredEdit>());
      expect(sheet.notice, ShiftsNotices.corrected);
    },
  );

  test('a failed post-commit read retries opening the saved draft without writing again', () async {
    final stored = await fixture.finishShift(20);
    var failReads = false;
    final sheet = await open(
      readShift: (id) async {
        if (failReads) throw StateError('read unavailable');
        return fixture.reads.shift(id);
      },
    );
    await sheet.select(storedRowId(stored));
    await sheet.openAction(ShiftsActionKind.correct);
    sheet.action!.setReason('Wrong end');
    failReads = true;
    await sheet.submitAction();
    expect(sheet.action, isNotNull);
    expect(sheet.action!.busy, isFalse);
    expect(sheet.action!.primaryLabel, ShiftsActionWords.check);
    expect(sheet.action!.reason, 'Wrong end');
    expect(sheet.action!.notice, contains('saved'));
    final saved = await fixture.reads.shiftsOf(fixtureEmployment);
    expect(saved, hasLength(2));
    final replacement = saved.singleWhere(
      (shift) => shift.state == ShiftState.draft,
    );
    failReads = false;
    await sheet.submitAction();
    expect(sheet.action, isNull);
    expect(sheet.selectedId, storedRowId(replacement));
    expect(sheet.edit, isA<StoredEdit>());
    expect(sheet.notice, ShiftsNotices.corrected);
    expect(
      (await fixture.reads.shiftsOf(fixtureEmployment))
          .map((shift) => shift.id)
          .toSet(),
      saved.map((shift) => shift.id).toSet(),
    );
  });

  test('Void on a draft resolves its pending edit first; Cancel brings the '
      'edit back', () async {
    final draft = await replacementDraft();
    final sheet = await open();
    await sheet.select(storedRowId(draft));
    sheet.editField(
      storedRowId(draft),
      ShiftsField.end,
      const LocalTime(17, 0),
    );

    confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
    expect(await sheet.openAction(ShiftsActionKind.voidShift), isFalse);
    expect(confirm.asked.single.title, 'Finalize shift');
    expect(sheet.action, isNull);
    expect(sheet.edit!.dirty, isTrue);

    confirm = ScriptedConfirm([ConfirmAnswer.revert]);
    expect(await sheet.openAction(ShiftsActionKind.voidShift), isTrue);
    expect(sheet.edit, isNull);
    expect(sheet.readOnlyReason, ShiftsCommandWords.actionOpen);

    await sheet.cancelAction();
    expect(confirm.asked, hasLength(1), reason: 'nothing entered: no ask');
    expect(sheet.action, isNull);
    expect(sheet.edit, isA<StoredEdit>());
    expect(sheet.edit!.dirty, isFalse);
    expect(sheet.selectedId, storedRowId(draft));
  });

  test(
    'a panel with a reason entered asks before the selection moves',
    () async {
      final stored = await fixture.finishShift(20);
      final sheet = await open();
      await sheet.select(storedRowId(stored));
      await sheet.openAction(ShiftsActionKind.voidShift);
      sheet.action!.setReason('Not worked');

      confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(await sheet.select(plannedRowId(_monday)), isFalse);
      expect(confirm.asked.single.revert, 'Discard');
      expect(sheet.action, isNotNull);
      expect(sheet.selectedId, storedRowId(stored));

      confirm = ScriptedConfirm([ConfirmAnswer.revert]);
      expect(await sheet.select(plannedRowId(_monday)), isTrue);
      expect(sheet.action, isNull);
      expect(sheet.edit, isA<PlannedEdit>());
      final now = (await fixture.reads.shift(stored.id))!.shift;
      expect(now.state, ShiftState.finalized, reason: 'nothing was voided');
    },
  );
  group('day panels', () {
    const night = LocalDate(2026, 10, 11);

    test('Cancel shift… opens a panel; Cancel shift stores it and selects '
        'the cancelled day', () async {
      final sheet = await open();
      final id = plannedRowId(night);
      await sheet.select(id);
      expect(sheet.cancelBlocked, isNull);
      expect(await sheet.openDayAction(DayActionKind.cancel), isTrue);
      final action = sheet.dayAction!;
      expect(sheet.edit, isNull);
      action
        ..setReason(CancelReason.dayOff)
        ..setNote('Asked for it');
      await sheet.submitDayAction();
      expect(sheet.dayAction, isNull);
      expect(sheet.selectedId, id);
      expect(sheet.notice, DayActionWords.cancelled(night));
      await until(() => sheet.selectedRow is CancelledRow);
    });

    test('Mark as leave… on a day with a pending time change saves the '
        'change first', () async {
      final sheet = await open();
      final id = plannedRowId(night);
      await sheet.select(id);
      sheet.editField(id, ShiftsField.end, const LocalTime(6, 0));
      expect(await sheet.openDayAction(DayActionKind.leave), isTrue);
      final saved = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).exceptions.single;
      expect(saved, isA<ChangedDay>());
      expect(sheet.dayAction!.exception?.id, saved.id);
      sheet.dayAction!.setLeaveType(LeaveType.sick);
      await sheet.submitDayAction();
      expect(sheet.notice, DayActionWords.markedLeave(night, LeaveType.sick));
    });

    test('while a day panel is open the other commands wait for it', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(night));
      await sheet.openDayAction(DayActionKind.cancel);
      expect(sheet.confirmBlocked, ShiftsCommandWords.actionOpen);
      expect(sheet.correctBlocked, ShiftsCommandWords.actionOpen);
      expect(sheet.voidBlocked, ShiftsCommandWords.actionOpen);
      expect(sheet.restoreBlocked, ShiftsCommandWords.actionOpen);
      expect(sheet.leaveBlocked, ShiftsCommandWords.actionOpen);
    });

    test('Cancel closes the panel and opens the day again', () async {
      final sheet = await open();
      final id = plannedRowId(night);
      await sheet.select(id);
      await sheet.openDayAction(DayActionKind.cancel);
      await sheet.cancelDayAction();
      expect(sheet.dayAction, isNull);
      expect(sheet.edit, isA<PlannedEdit>());
    });

    test(
      'the panels apply to planned days, not to extra or other days',
      () async {
        await fixture.work.plans.addExtra(
          fixtureEmployment,
          const LocalDate(2026, 10, 9),
          start: const LocalTime(8, 0),
          end: const LocalTime(14, 0),
          endDayOffset: 0,
          breaks: const [],
          shiftTypeId: null,
          countsAsOvertime: false,
        );
        final sheet = await open();
        await until(
          () => sheet.rows.any(
            (row) => row is PlannedRow && row.planned.day.isExtra,
          ),
        );
        await sheet.select(plannedRowId(const LocalDate(2026, 10, 9)));
        expect(sheet.cancelBlocked, ShiftsCommandWords.dayOnlyPlanned);
        expect(sheet.leaveBlocked, ShiftsCommandWords.dayOnlyPlanned);
        await sheet.select('off:2026-10-08');
        expect(sheet.cancelBlocked, ShiftsCommandWords.dayOnlyPlanned);
      },
    );
  });
  test('a panel opened on a day confirmed elsewhere shows what was made '
      'and says so', () async {
    final sheet = await open();
    await sheet.select(plannedRowId(const LocalDate(2026, 10, 11)));
    await fixture.work.plans.confirm(
      fixtureEmployment,
      const LocalDate(2026, 10, 11),
    );
    expect(await sheet.openDayAction(DayActionKind.cancel), isFalse);
    expect(sheet.dayAction, isNull);
    expect(sheet.selectedId, startsWith('shift:'));
    expect(sheet.notice, DayCommandWords.alreadyConfirmed);
  });
}
