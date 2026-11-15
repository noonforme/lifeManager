import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

import '../../support/fake_record_adapter.dart';

const _saved = SavedShift(end: 19, breaks: [12], revision: 3);
const _edited = ShiftDraft(end: 20, breaks: [12]);

/// The plan's Review Focus: conditions the spec implies that the main
/// suites do not reach.
void main() {
  late FakeShiftAdapter adapter;
  late List<FlutterErrorDetails> reported;

  setUp(() {
    adapter = FakeShiftAdapter();
    reported = [];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
  });

  test(
    'a session left while its command runs settles without an error',
    () async {
      final held = Completer<SubmitResult<SavedShift>>();
      adapter.results.add(held.future);
      final edit = RecordEditSession(adapter: adapter, baseline: _saved)
        ..edit(_edited);
      final saving = edit.save(ScriptedConfirm().call);
      await pumpEventQueue();
      edit.dispose();
      held.complete(
        const Submitted(
          Committed(SavedShift(end: 20, breaks: [12], revision: 4)),
        ),
      );
      expect(await saving, SaveResult.committed);
      expect(reported, isEmpty);
      expect(adapter.submits, hasLength(1));
    },
  );

  test('reload cannot silently discard an ordinary dirty draft', () async {
    adapter.readBackResult = const ReadFound(_saved, saved: false);
    final edit = RecordEditSession(adapter: adapter, baseline: _saved)
      ..edit(_edited);
    addTearDown(edit.dispose);
    await edit.reload();
    expect(edit.draft, _edited);
    expect(adapter.readBacks, [null]);
    expect(edit.phase, EditPhase.dirty);
  });

  test('leaving during read-back stays with a visible busy message', () async {
    adapter.results.add(const Submitted(Stale()));
    final edit = RecordEditSession(adapter: adapter, baseline: _saved)
      ..edit(_edited);
    addTearDown(edit.dispose);
    await edit.save(ScriptedConfirm().call);
    final read = Completer<ReadBack<SavedShift>>();
    adapter.heldReadBack = read.future;
    final reloading = edit.reload();
    expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.stay);
    expect(edit.problem, EditProblems.busy);
    read.complete(const ReadFound(_saved, saved: false));
    await reloading;
    expect(edit.busy, isFalse);
    expect(edit.problem, isNull);
    expect(adapter.submits, hasLength(1));
  });

  test(
    'a stale reload that throws retains the draft and reports failure',
    () async {
      adapter.results.add(const Submitted(Stale()));
      final edit = RecordEditSession(adapter: adapter, baseline: _saved)
        ..edit(_edited);
      addTearDown(edit.dispose);
      await edit.save(ScriptedConfirm().call);
      adapter.throwOnReadBack = StateError('read failed');
      await edit.reload();
      expect(edit.draft, _edited);
      expect(edit.phase, EditPhase.stale);
      expect(edit.problem, EditProblems.unreadable);
      expect(edit.busy, isFalse);
      expect(reported, hasLength(1));
    },
  );

  test(
    'invalid new-record Undo and native quit share one discard window',
    () async {
      final edit = RecordEditSession(adapter: adapter)
        ..edit(const ShiftDraft(end: 6));
      addTearDown(edit.dispose);
      final answer = Completer<ConfirmAnswer>();
      final confirm = ScriptedConfirm()..hold = answer;
      final undoing = edit.undo(confirm.call);
      final quitting = edit.leave(confirm.call, kind: LeaveKind.quit);
      expect(confirm.asked, hasLength(1));
      answer.complete(ConfirmAnswer.cancel);
      expect(await undoing, SaveResult.cancelled);
      expect(await quitting, LeaveDecision.stay);
      expect(edit.dirty, isTrue);
      expect(edit.busy, isFalse);
      expect(adapter.submits, isEmpty);
    },
  );

  test(
    'cancelling a retried save clears its previous failure message',
    () async {
      adapter.results.add(
        const Submitted(Unavailable(SafeFailureCode.storageUnavailable)),
      );
      final edit = RecordEditSession(adapter: adapter, baseline: _saved)
        ..edit(_edited);
      addTearDown(edit.dispose);
      await edit.save(ScriptedConfirm().call);
      expect(edit.problem, EditProblems.unavailable);
      adapter.guardRequest = finalizeRequest;
      expect(
        await edit.save(ScriptedConfirm([ConfirmAnswer.cancel]).call),
        SaveResult.cancelled,
      );
      expect(edit.problem, isNull);
      expect(edit.draft, _edited);
      expect(adapter.submits, hasLength(1));
    },
  );

  test('a draft type without value equality is refused at once', () {
    expect(
      () => RecordEditSession(adapter: _NoEquality(), baseline: 1),
      throwsAssertionError,
    );
  });

  test('a guard that throws writes nothing and keeps the draft', () async {
    adapter.throwOnGuard = StateError('preview failed');
    final edit = RecordEditSession(adapter: adapter, baseline: _saved)
      ..edit(_edited);
    addTearDown(edit.dispose);
    expect(await edit.save(ScriptedConfirm().call), SaveResult.unavailable);
    expect(adapter.submits, isEmpty);
    expect(edit.draft, _edited);
    expect(edit.busy, isFalse);
    expect(reported.single.exception, isA<StateError>());
  });

  test('a read-back that throws leaves an uncertain save uncertain', () async {
    adapter.results.add(
      const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
    );
    final edit = RecordEditSession(adapter: adapter, baseline: _saved)
      ..edit(_edited);
    addTearDown(edit.dispose);
    await edit.save(ScriptedConfirm().call);
    adapter.throwOnReadBack = StateError('read failed');
    await edit.check();
    expect(edit.phase, EditPhase.uncertain);
    expect(edit.problem, EditProblems.unknown);
    expect(edit.busy, isFalse);
    expect(reported, hasLength(1));
  });
}

/// A draft without `==`: two drafts of the same values differ.
final class _Draft {}

final class _NoEquality implements RecordEditAdapter<int, _Draft> {
  @override
  _Draft draftOf(int? saved) => _Draft();

  @override
  Map<String, String> validate(_Draft draft) => const {};

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) =>
      const {};

  @override
  Future<ConfirmRequest?> guard(int? baseline, _Draft draft) async => null;

  @override
  Future<SubmitResult<int>> submit(
    int? baseline,
    _Draft draft, {
    Object? consent,
  }) async => const Submitted(Committed(1));

  @override
  Future<ReadBack<int>> readBack(int? baseline, _Draft? submitted) async =>
      const ReadUnknown();
}
