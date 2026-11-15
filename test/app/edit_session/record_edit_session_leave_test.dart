import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

import '../../support/fake_record_adapter.dart';

const _saved = SavedShift(end: 19, breaks: [12], revision: 3);
const _edited = ShiftDraft(end: 20, breaks: [12]);

void main() {
  late FakeShiftAdapter adapter;

  RecordEditSession<SavedShift, ShiftDraft> session({
    SavedShift? baseline = _saved,
  }) {
    final value = RecordEditSession(adapter: adapter, baseline: baseline);
    addTearDown(value.dispose);
    return value;
  }

  setUp(() => adapter = FakeShiftAdapter());

  group('leaving', () {
    test('a clean record lets go without asking or writing', () async {
      final confirm = ScriptedConfirm();
      expect(await session().leave(confirm.call), LeaveDecision.proceed);
      expect(confirm.asked, isEmpty);
      expect(adapter.submits, isEmpty);
    });

    test('a new record holding only defaults creates nothing', () async {
      final confirm = ScriptedConfirm();
      final edit = session(baseline: null);
      expect(await edit.leave(confirm.call), LeaveDecision.proceed);
      expect(confirm.asked, isEmpty);
      expect(adapter.submits, isEmpty);
    });

    test(
      'a dirty record without a guard saves on leaving, then lets go',
      () async {
        final confirm = ScriptedConfirm();
        final edit = session()..edit(_edited);
        expect(await edit.leave(confirm.call), LeaveDecision.proceed);
        expect(confirm.asked, isEmpty);
        expect(adapter.submits.single.draft, _edited);
        expect(edit.phase, EditPhase.committed);
      },
    );

    test('a guarded record asks; proceed saves and lets go', () async {
      adapter.guardRequest = finalizeRequest;
      final edit = session()..edit(_edited);
      final decision = await edit.leave(
        ScriptedConfirm([ConfirmAnswer.proceed]).call,
      );
      expect(decision, LeaveDecision.proceed);
      expect(adapter.submits, hasLength(1));
    });

    test('Revert lets go and writes nothing', () async {
      adapter.guardRequest = finalizeRequest;
      final edit = session()..edit(_edited);
      final decision = await edit.leave(
        ScriptedConfirm([ConfirmAnswer.revert]).call,
      );
      expect(decision, LeaveDecision.proceed);
      expect(adapter.submits, isEmpty);
      expect(edit.draft, adapter.draftOf(_saved));
    });

    test('Cancel stays with the draft and writes nothing', () async {
      adapter.guardRequest = finalizeRequest;
      final edit = session()..edit(_edited);
      final decision = await edit.leave(
        ScriptedConfirm([ConfirmAnswer.cancel]).call,
      );
      expect(decision, LeaveDecision.stay);
      expect(adapter.submits, isEmpty);
      expect(edit.draft, _edited);
    });

    test(
      'a new record with entered values asks Save, Discard or Cancel',
      () async {
        final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
        final edit = session(baseline: null)..edit(_edited);
        expect(await edit.leave(confirm.call), LeaveDecision.proceed);
        expect(confirm.asked.single, same(newRecordRequest));
        expect(adapter.submits.single.draft, _edited);
        expect(edit.isNew, isFalse);
      },
    );

    test("a new record's lifecycle window replaces the Save window", () async {
      adapter.guardRequest = finalizeRequest;
      final confirm = ScriptedConfirm([ConfirmAnswer.revert]);
      final edit = session(baseline: null)..edit(_edited);
      expect(await edit.leave(confirm.call), LeaveDecision.proceed);
      expect(confirm.asked.single, same(finalizeRequest), reason: 'asked once');
      expect(adapter.submits, isEmpty);
    });

    test(
      'invalid values keep the owner on the record when navigating',
      () async {
        final confirm = ScriptedConfirm();
        final edit = session()..edit(const ShiftDraft(end: 20, breaks: [25]));
        expect(await edit.leave(confirm.call), LeaveDecision.stay);
        expect(confirm.asked, isEmpty);
        expect(adapter.submits, isEmpty);
        expect(edit.issues, {'breaks.0': breakProblem});
        expect(edit.problem, EditProblems.invalid);
      },
    );

    test('quitting with invalid values offers Discard and quit or Keep '
        'editing', () async {
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [25]));
      final keep = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(
        await edit.leave(keep.call, kind: LeaveKind.quit),
        LeaveDecision.stay,
      );
      expect(keep.asked.single.proceed, isNull);
      expect(keep.asked.single.revert, 'Discard and quit');
      expect(keep.asked.single.cancel, 'Keep editing');
      expect(edit.dirty, isTrue);
      final discard = ScriptedConfirm([ConfirmAnswer.revert]);
      expect(
        await edit.leave(discard.call, kind: LeaveKind.quit),
        LeaveDecision.proceed,
      );
      expect(edit.dirty, isFalse);
      expect(adapter.submits, isEmpty);
    });

    test('a stale record offers to discard its pending values', () async {
      adapter.results.add(const Submitted(Stale()));
      final edit = session()..edit(_edited);
      await edit.save(ScriptedConfirm().call);
      final confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(await edit.leave(confirm.call), LeaveDecision.stay);
      expect(confirm.asked.single.message, startsWith(EditProblems.stale));
      expect(
        await edit.leave(ScriptedConfirm([ConfirmAnswer.revert]).call),
        LeaveDecision.proceed,
      );
      expect(adapter.submits, hasLength(1));
    });

    test('a failed save keeps the owner on the record', () async {
      adapter.results.add(
        const Submitted(Unavailable(SafeFailureCode.storageUnavailable)),
      );
      final edit = session()..edit(_edited);
      expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.stay);
      expect(edit.draft, _edited);
      expect(edit.problem, EditProblems.unavailable);
    });

    test('an uncertain save keeps the owner: navigating asks nothing; '
        'quitting asks to check first', () async {
      adapter.results.add(
        const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
      );
      final edit = session()..edit(_edited);
      await edit.save(ScriptedConfirm().call);
      final quiet = ScriptedConfirm();
      expect(await edit.leave(quiet.call), LeaveDecision.stay);
      expect(quiet.asked, isEmpty);
      final confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(
        await edit.leave(confirm.call, kind: LeaveKind.quit),
        LeaveDecision.stay,
      );
      expect(confirm.asked.single, same(uncheckedQuitRequest));
      expect(adapter.readBacks, isEmpty);
      expect(adapter.submits, hasLength(1));
    });

    test('Reload and check from the quit window checks the save and '
        'stays', () async {
      adapter.results.add(
        const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
      );
      final edit = session()..edit(_edited);
      await edit.save(ScriptedConfirm().call);
      adapter.readBackResult = const ReadFound(
        SavedShift(end: 20, breaks: [12], revision: 4),
        saved: true,
      );
      expect(
        await edit.leave(
          ScriptedConfirm([ConfirmAnswer.proceed]).call,
          kind: LeaveKind.quit,
        ),
        LeaveDecision.stay,
      );
      expect(adapter.readBacks, hasLength(1));
      expect(edit.phase, EditPhase.committed);
      expect(adapter.submits, hasLength(1));
    });

    test('after a check that could not tell, quitting offers Quit anyway: '
        'Keep checking stays, Quit anyway lets go', () async {
      adapter.results.add(
        const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
      );
      final edit = session()..edit(_edited);
      await edit.save(ScriptedConfirm().call);
      await edit.check();
      expect(edit.unresolved, isTrue);
      final keep = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(
        await edit.leave(keep.call, kind: LeaveKind.quit),
        LeaveDecision.stay,
      );
      expect(keep.asked.single, same(unresolvedQuitRequest));
      expect(
        await edit.leave(
          ScriptedConfirm([ConfirmAnswer.proceed]).call,
          kind: LeaveKind.quit,
        ),
        LeaveDecision.proceed,
      );
      // Navigating still never lets go of an unknown result.
      expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.stay);
      expect(adapter.submits, hasLength(1));
    });

    test('a leave during a save waits for it: committed lets go', () async {
      final held = Completer<SubmitResult<SavedShift>>();
      adapter.results.add(held.future);
      final edit = session()..edit(_edited);
      final saving = edit.save(ScriptedConfirm().call);
      final leaving = edit.leave(ScriptedConfirm().call);
      held.complete(
        const Submitted(
          Committed(SavedShift(end: 20, breaks: [12], revision: 4)),
        ),
      );
      expect(await saving, SaveResult.committed);
      expect(await leaving, LeaveDecision.proceed);
      expect(adapter.submits, hasLength(1));
    });

    test(
      'a leave during a save that fails stays and sends nothing more',
      () async {
        final held = Completer<SubmitResult<SavedShift>>();
        adapter.results.add(held.future);
        final edit = session()..edit(_edited);
        final saving = edit.save(ScriptedConfirm().call);
        final leaving = edit.leave(ScriptedConfirm().call);
        held.complete(
          const Submitted(Unavailable(SafeFailureCode.storageUnavailable)),
        );
        await saving;
        expect(await leaving, LeaveDecision.stay);
        expect(adapter.submits, hasLength(1));
      },
    );
  });

  group('undo on a new record', () {
    test('with entered values it asks Save, Discard or Cancel', () async {
      final confirm = ScriptedConfirm([ConfirmAnswer.revert]);
      final edit = session(baseline: null)..edit(_edited);
      expect(await edit.undo(confirm.call), SaveResult.reverted);
      expect(confirm.asked.single, same(newRecordRequest));
      expect(edit.draft, adapter.defaults);
      expect(adapter.submits, isEmpty);
    });

    test('Save in that window saves the new record', () async {
      final edit = session(baseline: null)..edit(_edited);
      final result = await edit.undo(
        ScriptedConfirm([ConfirmAnswer.proceed]).call,
      );
      expect(result, SaveResult.committed);
      expect(adapter.submits, hasLength(1));
    });

    test('invalid entered values can be discarded but not saved', () async {
      final confirm = ScriptedConfirm([ConfirmAnswer.revert]);
      final edit = session(baseline: null)
        ..edit(const ShiftDraft(end: 20, breaks: [25]));
      expect(await edit.undo(confirm.call), SaveResult.reverted);
      expect(confirm.asked.single.proceed, isNull);
      expect(confirm.asked.single.revert, 'Discard');
      expect(edit.draft, adapter.defaults);
    });
  });
}
