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

  Future<RecordEditSession<SavedShift, ShiftDraft>> after(
    MutationOutcome<SavedShift> outcome, {
    SavedShift? baseline = _saved,
    ShiftDraft draft = _edited,
  }) async {
    final edit = RecordEditSession(adapter: adapter, baseline: baseline);
    addTearDown(edit.dispose);
    adapter.results.add(Submitted(outcome));
    edit.edit(draft);
    await edit.save(ScriptedConfirm().call);
    return edit;
  }

  setUp(() => adapter = FakeShiftAdapter());

  group('Reload record after Stale', () {
    test('the current facts replace the baseline; pending values go', () async {
      final edit = await after(const Stale());
      const current = SavedShift(end: 21, breaks: [13], revision: 5);
      adapter.readBackResult = const ReadFound(current, saved: false);
      await edit.reload();
      expect(adapter.readBacks.single, isNull);
      expect(edit.baseline, current);
      expect(edit.draft, const ShiftDraft(end: 21, breaks: [13]));
      expect(edit.phase, EditPhase.idle);
      expect(edit.problem, isNull);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.clean);
    });

    test('a record found gone is marked missing', () async {
      final edit = await after(const Stale());
      adapter.readBackResult = const ReadGone();
      await edit.reload();
      expect(edit.gone, isTrue);
      expect(edit.problem, EditProblems.missing);
      expect(edit.draft, _edited);
    });

    test('an unreadable record keeps everything and says so', () async {
      final edit = await after(const Stale());
      adapter.readBackResult = const ReadUnknown();
      await edit.reload();
      expect(edit.phase, EditPhase.stale);
      expect(edit.problem, EditProblems.unreadable);
      expect(edit.draft, _edited);
    });
  });

  group('Missing', () {
    test('Undo discards the pending values so the sheet can be left', () async {
      final edit = await after(const Missing());
      expect(await edit.undo(ScriptedConfirm().call), SaveResult.reverted);
      expect(edit.dirty, isFalse);
      expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.proceed);
      expect(adapter.submits, hasLength(1));
    });
  });

  group('Reload and check after Uncertain', () {
    const unknown = Uncertain<SavedShift>(SafeFailureCode.commitOutcomeUnknown);

    test('found stored: the stored object becomes the baseline', () async {
      final edit = await after(unknown);
      const stored = SavedShift(end: 20, breaks: [12], revision: 4);
      adapter.readBackResult = const ReadFound(stored, saved: true);
      await edit.check();
      expect(adapter.readBacks.single, _edited, reason: 'the submitted draft');
      expect(edit.baseline, stored);
      expect(edit.dirty, isFalse);
      expect(edit.phase, EditPhase.committed);
      expect(edit.frozen, isFalse);
    });

    test('found not stored: the values stay for an explicit save; nothing '
        'is retried', () async {
      final edit = await after(unknown);
      adapter.readBackResult = const ReadFound(_saved, saved: false);
      await edit.check();
      expect(edit.draft, _edited);
      expect(edit.dirty, isTrue);
      expect(edit.phase, EditPhase.dirty);
      expect(edit.problem, EditProblems.notSaved);
      expect(adapter.submits, hasLength(1));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
      expect(adapter.submits, hasLength(2));
    });

    test('found not stored but changed meanwhile: the record is stale and '
        'the values are not saved over the current facts', () async {
      final edit = await after(unknown);
      const changed = SavedShift(end: 18, breaks: [12], revision: 4);
      adapter.readBackResult = const ReadFound(changed, saved: false);
      await edit.check();
      expect(edit.phase, EditPhase.stale);
      expect(edit.problem, EditProblems.stale);
      expect(edit.draft, _edited);
      expect(edit.frozen, isFalse);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.stale);
      expect(adapter.submits, hasLength(1));
    });

    test('a new record established not created keeps its values', () async {
      final edit = await after(unknown, baseline: null);
      adapter.readBackResult = const ReadNotSaved();
      await edit.check();
      expect(edit.isNew, isTrue);
      expect(edit.draft, _edited);
      expect(edit.phase, EditPhase.dirty);
      expect(edit.problem, EditProblems.notSaved);
    });

    test('still unknown: the record stays uncertain and frozen', () async {
      final edit = await after(unknown);
      adapter.readBackResult = const ReadUnknown();
      await edit.check();
      expect(edit.phase, EditPhase.uncertain);
      expect(edit.frozen, isTrue);
      expect(edit.problem, EditProblems.unknown);
    });

    test('gone: the record is marked missing', () async {
      final edit = await after(unknown);
      adapter.readBackResult = const ReadGone();
      await edit.check();
      expect(edit.gone, isTrue);
      expect(edit.phase, EditPhase.failed);
      expect(edit.problem, EditProblems.missing);
    });
  });

  test('check does nothing unless the last save is uncertain', () async {
    final edit = await after(const Stale());
    await edit.check();
    expect(adapter.readBacks, isEmpty);
    expect(edit.phase, EditPhase.stale);
  });

  test(
    'a fresh uncertain save requires a fresh check before Quit anyway',
    () async {
      adapter.results.add(
        const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
      );
      final edit = RecordEditSession(adapter: adapter, baseline: _saved)
        ..edit(_edited);
      addTearDown(edit.dispose);
      await edit.save(ScriptedConfirm().call);
      await edit.check();
      expect(edit.unresolved, isTrue);
      adapter.readBackResult = const ReadFound(_saved, saved: false);
      await edit.check();
      adapter.results.add(
        const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
      );
      await edit.save(ScriptedConfirm().call);
      expect(edit.unresolved, isFalse);
    },
  );

  test('a confirmation request is never reused after a reload', () async {
    adapter.guardRequest = const ConfirmRequest(
      title: 'Reprice',
      message: 'Reprices 3 shifts.',
      proceed: 'Save and reprice',
      consent: 'impact-1',
    );
    final edit = RecordEditSession(adapter: adapter, baseline: _saved);
    addTearDown(edit.dispose);
    adapter.results.add(const Submitted(Stale()));
    edit.edit(_edited);
    await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call);
    adapter.readBackResult = const ReadFound(_saved, saved: false);
    await edit.reload();
    edit.edit(_edited);
    final confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
    await edit.save(confirm.call);
    expect(confirm.asked, hasLength(1), reason: 'asked again after reload');
    expect(adapter.submits, hasLength(1));
  });
}
