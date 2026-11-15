import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/shift_lifecycle_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/scripted_lifecycle.dart';
import '../../support/shifts_sheet_fixture.dart';

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedLifecycle storage;
  late WorkShift shift;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    storage = ScriptedLifecycle(fixture.schedule.shifts);
    shift = await fixture.finishShift(20);
  });

  tearDown(() => fixture.dispose());

  ShiftsAction action(ShiftsActionKind kind) {
    final value = ShiftsAction(
      kind: kind,
      shift: shift,
      lifecycle: ShiftLifecycleService(
        storage,
        idFactory: fixture.schedule.ids,
        clock: fixture.schedule.clock,
      ),
      reads: fixture.reads,
      newShiftId: fixture.schedule.ids.shiftId,
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<WorkShift> stored(WorkShift value) async =>
      (await fixture.reads.shift(value.id))!.shift;

  test('Correct needs a reason, then voids the shift and returns its '
      'replacement draft', () async {
    final correct = action(ShiftsActionKind.correct);
    expect(await correct.submit(), isNull);
    expect(correct.reasonError, ShiftsActionWords.correctReason);
    expect(storage.commits, 0, reason: 'no write without a reason');

    correct.setReason('  Wrong end time  ');
    expect(correct.reasonError, isNull);
    final replacement = (await correct.submit())!;
    expect(replacement.state, ShiftState.draft);
    expect(replacement.replacedShiftId, shift.id);
    final original = await stored(shift);
    expect(original.state, ShiftState.voided);
    expect(original.voidReason, 'Wrong end time');
    expect(original.replacementShiftId, replacement.id);
  });

  test('Void removes the shift with its reason and no replacement', () async {
    final remove = action(ShiftsActionKind.voidShift)..setReason('Not worked');
    final voided = (await remove.submit())!;
    expect(voided.id, shift.id);
    final now = await stored(shift);
    expect(now.state, ShiftState.voided);
    expect(now.voidReason, 'Not worked');
    expect(now.replacementShiftId, isNull);
  });

  test(
    'a committed action cannot write again while its record opens',
    () async {
      final correct = action(ShiftsActionKind.correct)..setReason('Wrong end');
      final replacement = await correct.submit();
      expect(replacement, isNotNull);
      expect(correct.busy, isTrue);
      expect(correct.canSubmit, isFalse);
      expect(await correct.submit(), isNull);
      expect(storage.commits, 1);
      expect(await correct.leave(ScriptedConfirm().call), LeaveDecision.stay);
    },
  );

  test('a shift changed since the panel opened is Stale: only Cancel is '
      'left, and it asks nothing', () async {
    final correct = action(ShiftsActionKind.correct)..setReason('Late');
    // Another window voids it meanwhile.
    await fixture.work.shifts.voidShift(
      VoidShiftCommand(
        id: shift.id,
        expectedRevision: shift.revision,
        voidReason: 'Elsewhere',
      ),
    );
    expect(await correct.submit(), isNull);
    expect(correct.error, ShiftsActionWords.stale);
    expect(correct.phase, ShiftsActionPhase.blocked);
    expect(correct.canSubmit, isFalse);
    final confirm = ScriptedConfirm();
    expect(await correct.leave(confirm.call), LeaveDecision.proceed);
    expect(confirm.asked, isEmpty);
  });

  test('Unavailable keeps the reason for another try', () async {
    storage.next = (
      write: false,
      report: const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable),
    );
    final remove = action(ShiftsActionKind.voidShift)..setReason('Not worked');
    expect(await remove.submit(), isNull);
    expect(remove.error, ShiftsActionWords.unavailable);
    expect(remove.phase, ShiftsActionPhase.input);
    expect(remove.reason, 'Not worked');
    expect((await remove.submit())?.state, ShiftState.voided);
  });

  test('an uncertain correction that went through is found by Reload and '
      'check, and holds the owner until then', () async {
    storage.next = (
      write: true,
      report: const Uncertain<WorkShift>(SafeFailureCode.commitOutcomeUnknown),
    );
    final correct = action(ShiftsActionKind.correct)..setReason('Late');
    expect(await correct.submit(), isNull);
    expect(correct.phase, ShiftsActionPhase.uncertain);
    expect(correct.primaryLabel, ShiftsActionWords.check);
    expect(correct.notice, ShiftsActionWords.uncertain);
    expect(
      await correct.leave(ScriptedConfirm().call),
      LeaveDecision.stay,
      reason: 'an unresolved outcome is never left (spec 9)',
    );
    correct.setReason('changed');
    expect(correct.reason, 'Late', reason: 'the sent reason stays');

    final replacement = (await correct.submit())!;
    expect(storage.commits, 1, reason: 'the check never writes again');
    expect(replacement.replacedShiftId, shift.id);
    expect((await stored(shift)).replacementShiftId, replacement.id);
  });

  test('an uncertain void that did not go through says so and keeps the '
      'reason to try again', () async {
    storage.next = (
      write: false,
      report: const Uncertain<WorkShift>(SafeFailureCode.commitOutcomeUnknown),
    );
    final remove = action(ShiftsActionKind.voidShift)..setReason('Not worked');
    expect(await remove.submit(), isNull);
    expect(await remove.submit(), isNull);
    expect(remove.error, ShiftsActionWords.notDone);
    expect(remove.phase, ShiftsActionPhase.input);
    expect((await stored(shift)).state, ShiftState.finalized);
    expect((await remove.submit())?.state, ShiftState.voided);
    expect(storage.commits, 2);
  });

  test('leaving with a reason entered asks Discard or Keep editing; with '
      'none it goes at once', () async {
    final correct = action(ShiftsActionKind.correct);
    final confirm = ScriptedConfirm([
      ConfirmAnswer.cancel,
      ConfirmAnswer.revert,
      ConfirmAnswer.cancel,
    ]);
    expect(await correct.leave(confirm.call), LeaveDecision.proceed);
    expect(confirm.asked, isEmpty);

    correct.setReason('Late');
    expect(await correct.leave(confirm.call), LeaveDecision.stay);
    expect(confirm.asked.last.revert, 'Discard');
    expect(confirm.asked.last.cancel, 'Keep editing');
    expect(confirm.asked.last.proceed, isNull);
    expect(await correct.leave(confirm.call), LeaveDecision.proceed);
    expect(
      await correct.leave(confirm.call, kind: LeaveKind.quit),
      LeaveDecision.stay,
    );
    expect(confirm.asked.last.revert, 'Discard input and quit');
  });

  test('quitting an uncertain correction asks to check it first; after a '
      'check that could not tell, Quit anyway lets go', () async {
    storage.next = (
      write: false,
      report: const Uncertain<WorkShift>(SafeFailureCode.commitOutcomeUnknown),
    );
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    // Explicit failed read-back; no closed executor or database lifecycle trick.
    final correct = ShiftsAction(
      kind: ShiftsActionKind.correct,
      shift: shift,
      lifecycle: ShiftLifecycleService(
        storage,
        idFactory: fixture.schedule.ids,
        clock: fixture.schedule.clock,
      ),
      reads: fixture.reads,
      readShift: (_) => Future.error(StateError('Synthetic read-back failure')),
      newShiftId: fixture.schedule.ids.shiftId,
    )..setReason('Wrong end');
    addTearDown(correct.dispose);
    expect(await correct.submit(), isNull);
    expect(correct.phase, ShiftsActionPhase.uncertain);

    final first = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(
      await correct.leave(first.call, kind: LeaveKind.quit),
      LeaveDecision.stay,
    );
    expect(first.asked.single, same(uncheckedQuitRequest));
    expect(correct.error, ShiftsActionWords.unknown);

    final second = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(
      await correct.leave(second.call, kind: LeaveKind.quit),
      LeaveDecision.proceed,
    );
    expect(second.asked.single, same(unresolvedQuitRequest));
    expect(
      await correct.leave(ScriptedConfirm().call),
      LeaveDecision.stay,
      reason: 'navigating never leaves an unknown result',
    );
    expect(storage.commits, 1);
  });
}
