import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

import '../../support/fake_record_adapter.dart';

const _saved = SavedShift(end: 19, breaks: [12], revision: 3);

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

  group('drafts and undo', () {
    test('a saved record starts idle from its draft', () {
      final edit = session();
      expect(edit.draft, const ShiftDraft(end: 19, breaks: [12]));
      expect(edit.phase, EditPhase.idle);
      expect(edit.dirty, isFalse);
      expect(edit.isNew, isFalse);
    });

    test('a new record starts from the defaults and is not dirty', () {
      final edit = session(baseline: null);
      expect(edit.draft, adapter.defaults);
      expect(edit.isNew, isTrue);
      expect(edit.dirty, isFalse);
    });

    test('an edit is taken and makes the record dirty; editing back is '
        'clean', () {
      final edit = session();
      expect(edit.edit(const ShiftDraft(end: 20, breaks: [12])), isNull);
      expect(edit.phase, EditPhase.dirty);
      expect(edit.dirty, isTrue);
      expect(edit.edit(const ShiftDraft(end: 19, breaks: [12])), isNull);
      expect(edit.phase, EditPhase.idle);
      expect(edit.dirty, isFalse);
    });

    test('a session is settled only while nothing is pending', () {
      final edit = session();
      expect(edit.settled, isTrue);
      edit.edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(edit.settled, isFalse);
      edit.edit(const ShiftDraft(end: 19, breaks: [12]));
      expect(edit.settled, isTrue);
    });

    test('a field left with a bad value is rejected; the draft is kept', () {
      final edit = session();
      final problem = edit.edit(
        const ShiftDraft(end: 5, breaks: [12]),
        field: 'end',
      );
      expect(problem, endProblem);
      expect(edit.draft, const ShiftDraft(end: 19, breaks: [12]));
      expect(edit.phase, EditPhase.idle);
    });

    test('a parent edit that strands a child is taken with the child '
        'marked', () {
      final edit = session();
      expect(
        edit.edit(const ShiftDraft(end: 11, breaks: [12]), field: 'end'),
        isNull,
      );
      expect(edit.draft.end, 11);
      expect(edit.issues, {'breaks.0': breakProblem});
    });

    test('undo puts an existing record back without asking', () async {
      final confirm = ScriptedConfirm();
      final edit = session()..edit(const ShiftDraft(end: 25, breaks: [3]));
      expect(await edit.undo(confirm.call), SaveResult.reverted);
      expect(edit.draft, const ShiftDraft(end: 19, breaks: [12]));
      expect(edit.issues, isEmpty);
      expect(edit.phase, EditPhase.idle);
      expect(confirm.asked, isEmpty);
    });

    test('listeners hear every change', () {
      final edit = session();
      var heard = 0;
      edit.addListener(() => heard++);
      edit.edit(const ShiftDraft(end: 20, breaks: [12]));
      edit.edit(const ShiftDraft(end: 21, breaks: [12]));
      expect(heard, 2);
    });
  });

  group('save', () {
    test('a clean record writes nothing', () async {
      expect(await session().save(ScriptedConfirm().call), SaveResult.clean);
      expect(adapter.submits, isEmpty);
    });

    test('the whole record is validated and nothing is written when it is '
        'invalid', () async {
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [25]));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
      expect(adapter.submits, isEmpty);
      expect(edit.issues, {'breaks.0': breakProblem});
      expect(edit.problem, EditProblems.invalid);
      expect(edit.phase, EditPhase.failed);
    });

    test('without a guard it submits once and commits: baseline, draft and '
        'phase follow the saved object', () async {
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
      expect(
        adapter.submits.single.draft,
        const ShiftDraft(end: 20, breaks: [12]),
      );
      expect(
        edit.baseline,
        const SavedShift(end: 20, breaks: [12], revision: 4),
      );
      expect(edit.dirty, isFalse);
      expect(edit.phase, EditPhase.committed);
    });

    test('a guard asks before any write; Cancel keeps the draft and writes '
        'nothing', () async {
      adapter.guardRequest = finalizeRequest;
      final confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(await edit.save(confirm.call), SaveResult.cancelled);
      expect(confirm.asked.single, same(finalizeRequest));
      expect(adapter.submits, isEmpty);
      expect(edit.draft.end, 20);
      expect(edit.phase, EditPhase.dirty);
    });

    test(
      'Revert in the guard drops the pending values and writes nothing',
      () async {
        adapter.guardRequest = finalizeRequest;
        final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
        final result = await edit.save(
          ScriptedConfirm([ConfirmAnswer.revert]).call,
        );
        expect(result, SaveResult.reverted);
        expect(adapter.submits, isEmpty);
        expect(edit.draft.end, 19);
        expect(edit.phase, EditPhase.idle);
      },
    );

    test('proceeding passes the request consent to the command', () async {
      adapter.guardRequest = const ConfirmRequest(
        title: 'Reprice',
        message: 'Reprices 3 shifts.',
        proceed: 'Save and reprice',
        revert: 'Revert',
        consent: 'impact-1',
      );
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      await edit.save(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      expect(adapter.submits.single.consent, 'impact-1');
    });

    test(
      'a changed impact asks again and submits only the fresh consent',
      () async {
        adapter
          ..guardRequest = const ConfirmRequest(
            title: 'Reprice',
            message: 'Reprices 3 shifts.',
            proceed: 'Save and reprice',
            consent: 'impact-1',
          )
          ..results.add(
            const Reconfirm(
              ConfirmRequest(
                title: 'Reprice again',
                message: 'Now reprices 4 shifts.',
                proceed: 'Save and reprice',
                consent: 'impact-2',
              ),
            ),
          );
        final confirm = ScriptedConfirm([
          ConfirmAnswer.proceed,
          ConfirmAnswer.proceed,
        ]);
        final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
        expect(await edit.save(confirm.call), SaveResult.committed);
        expect(confirm.asked.map((request) => request.title), [
          'Reprice',
          'Reprice again',
        ]);
        expect(adapter.submits.map((submit) => submit.consent), [
          'impact-1',
          'impact-2',
        ]);
      },
    );

    test(
      'cancelling the fresh request keeps the draft and writes no more',
      () async {
        adapter
          ..guardRequest = const ConfirmRequest(
            title: 'Reprice',
            message: 'Reprices 3 shifts.',
            proceed: 'Save and reprice',
            consent: 'impact-1',
          )
          ..results.add(
            const Reconfirm(
              ConfirmRequest(
                title: 'Reprice again',
                message: 'Now reprices 4 shifts.',
                proceed: 'Save and reprice',
                consent: 'impact-2',
              ),
            ),
          );
        final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
        final result = await edit.save(
          ScriptedConfirm([ConfirmAnswer.proceed, ConfirmAnswer.cancel]).call,
        );
        expect(result, SaveResult.cancelled);
        expect(adapter.submits, hasLength(1));
        expect(edit.draft.end, 20);
      },
    );

    test(
      'Invalid marks the fields the command named and keeps the draft',
      () async {
        adapter.results.add(
          const Submitted(
            Invalid({
              'end': [FieldIssue(FieldIssueCode.conflict)],
            }),
          ),
        );
        final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
        expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
        expect(edit.issues, {'end': 'The command refused end.'});
        expect(edit.problem, 'The command refused end.');
        expect(edit.phase, EditPhase.failed);
        expect(edit.draft.end, 20);
      },
    );

    test("a command's words stay until their own field is edited", () async {
      adapter.results.add(
        const Submitted(
          Invalid({
            'end': [FieldIssue(FieldIssueCode.conflict)],
          }),
        ),
      );
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
      expect(
        edit.edit(const ShiftDraft(end: 20, breaks: [13]), field: 'breaks'),
        isNull,
      );
      expect(edit.issues, {'end': 'The command refused end.'});
      expect(edit.problem, EditProblems.invalid);
      expect(
        edit.edit(const ShiftDraft(end: 21, breaks: [13]), field: 'end'),
        isNull,
      );
      expect(edit.issues, isEmpty);
      expect(edit.problem, isNull);
    });

    test(
      'Stale keeps the draft and refuses further saves until reload',
      () async {
        adapter.results.add(const Submitted(Stale()));
        final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
        expect(await edit.save(ScriptedConfirm().call), SaveResult.stale);
        expect(edit.phase, EditPhase.stale);
        expect(edit.problem, EditProblems.stale);
        expect(edit.edit(const ShiftDraft(end: 21, breaks: [12])), isNull);
        expect(edit.phase, EditPhase.stale, reason: 'keep editing, unsent');
        expect(await edit.save(ScriptedConfirm().call), SaveResult.stale);
        expect(adapter.submits, hasLength(1));
      },
    );

    test('Missing keeps the draft for inspection and refuses saves', () async {
      adapter.results.add(const Submitted(Missing()));
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.missing);
      expect(edit.gone, isTrue);
      expect(edit.problem, EditProblems.missing);
      expect(edit.draft.end, 20);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.missing);
      expect(adapter.submits, hasLength(1));
    });

    test('Unavailable keeps the draft; an explicit Save tries again', () async {
      adapter.results.add(
        const Submitted(Unavailable(SafeFailureCode.storageUnavailable)),
      );
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.unavailable);
      expect(edit.problem, EditProblems.unavailable);
      expect(edit.draft.end, 20);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.committed);
      expect(adapter.submits, hasLength(2));
    });

    test('Uncertain freezes the record: no edit, undo or save until it is '
        'checked', () async {
      adapter.results.add(
        const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
      );
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      expect(await edit.save(ScriptedConfirm().call), SaveResult.uncertain);
      expect(edit.phase, EditPhase.uncertain);
      expect(edit.frozen, isTrue);
      expect(
        edit.edit(const ShiftDraft(end: 21, breaks: [12])),
        EditProblems.checkFirst,
      );
      expect(await edit.undo(ScriptedConfirm().call), SaveResult.uncertain);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.uncertain);
      expect(adapter.submits, hasLength(1), reason: 'no automatic retry');
      expect(edit.draft.end, 20);
    });

    test('one save at a time: a second Save joins the first and editing is '
        'frozen meanwhile', () async {
      final held = Completer<SubmitResult<SavedShift>>();
      adapter.results.add(held.future);
      final edit = session()..edit(const ShiftDraft(end: 20, breaks: [12]));
      final first = edit.save(ScriptedConfirm().call);
      final second = edit.save(ScriptedConfirm().call);
      await pumpEventQueue();
      expect(edit.phase, EditPhase.saving);
      expect(edit.frozen, isTrue);
      expect(
        edit.edit(const ShiftDraft(end: 22, breaks: [12])),
        EditProblems.busy,
      );
      held.complete(
        const Submitted(
          Committed(SavedShift(end: 20, breaks: [12], revision: 4)),
        ),
      );
      expect(await first, SaveResult.committed);
      expect(await second, SaveResult.committed);
      expect(adapter.submits, hasLength(1));
    });

    test('a command that throws may have written: the save is uncertain, '
        'frozen and not sent again', () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      adapter.throwOnSubmit = StateError('bug');
      const entered = ShiftDraft(end: 20, breaks: [12]);
      final edit = session()..edit(entered);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.uncertain);
      expect(reported.single.exception, isA<StateError>());
      expect(edit.phase, EditPhase.uncertain);
      expect(edit.problem, EditProblems.uncertain);
      expect(edit.busy, isFalse);
      expect(edit.frozen, isTrue);
      expect(edit.draft, entered);
      expect(await edit.save(ScriptedConfirm().call), SaveResult.uncertain);
      expect(adapter.submits, hasLength(1));
      await edit.check();
      expect(adapter.readBacks, [entered]);
    });
  });
  group('saving an unchanged record', () {
    test('a plain Save of a clean record submits nothing', () async {
      final edit = session();
      expect(
        await edit.save((_) async => ConfirmAnswer.proceed),
        SaveResult.clean,
      );
      expect(adapter.submits, isEmpty);
    });

    test('Save with unchanged asks the guard and submits the stored values '
        'once', () async {
      adapter.guardRequest = const ConfirmRequest(
        title: 'Finalize',
        message: 'Finalize it?',
        proceed: 'Finalize',
        revert: null,
      );
      adapter.results.add(const Submitted(Committed(_saved)));
      final asked = <ConfirmRequest>[];
      final edit = session();
      expect(
        await edit.save((request) async {
          asked.add(request);
          return ConfirmAnswer.proceed;
        }, unchanged: true),
        SaveResult.committed,
      );
      expect(asked.single.title, 'Finalize');
      expect(adapter.submits.single.draft, edit.draft);
    });

    test('cancelling its window leaves the clean record idle', () async {
      adapter.guardRequest = const ConfirmRequest(
        title: 'Finalize',
        message: 'Finalize it?',
        proceed: 'Finalize',
        revert: null,
      );
      final edit = session();
      expect(
        await edit.save((_) async => ConfirmAnswer.cancel, unchanged: true),
        SaveResult.cancelled,
      );
      expect(edit.phase, EditPhase.idle);
      expect(adapter.submits, isEmpty);
    });
  });
  test('Save on a new record that still holds its defaults creates it; '
      'leaving it creates nothing', () async {
    adapter.results.add(const Submitted(Committed(_saved)));
    final edit = session(baseline: null);
    expect(edit.dirty, isFalse);
    expect(
      await edit.save((_) async => ConfirmAnswer.proceed),
      SaveResult.committed,
    );
    expect(adapter.submits.single.draft, adapter.defaults);
  });
}
