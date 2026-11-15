import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/edit_session/window_close_guard.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

import '../../support/fake_record_adapter.dart';

const _saved = SavedShift(end: 19, breaks: [12], revision: 3);
const _edited = ShiftDraft(end: 20, breaks: [12]);

final class _Window implements WindowCloseApi {
  var destroyed = 0;

  @override
  Future<void> interceptClose(Future<void> Function() onCloseRequested) async {}

  @override
  Future<void> releaseClose(Future<void> Function() onCloseRequested) async {}

  @override
  Future<void> destroy() async => destroyed++;
}

/// Closing the application with a record open (database shell spec 4.8,
/// 10): the session, the coordinator and the window guard together.
void main() {
  late FakeShiftAdapter adapter;
  late _Window window;

  ({
    RecordEditSession<SavedShift, ShiftDraft> session,
    WindowCloseGuard guard,
    ScriptedConfirm confirm,
  })
  open(List<ConfirmAnswer> answers, {SavedShift? baseline = _saved}) {
    final confirm = ScriptedConfirm(answers);
    final session = RecordEditSession(adapter: adapter, baseline: baseline);
    addTearDown(session.dispose);
    final coordinator = LeaveCoordinator(confirm: confirm.call)..add(session);
    return (
      session: session,
      guard: WindowCloseGuard(api: window, mayClose: coordinator.quit),
      confirm: confirm,
    );
  }

  setUp(() {
    adapter = FakeShiftAdapter();
    window = _Window();
  });

  test('a clean record closes at once', () async {
    final app = open([]);
    await app.guard.requestClose();
    expect(window.destroyed, 1);
    expect(app.confirm.asked, isEmpty);
  });

  test('a valid planned-day edit is saved, then the window closes', () async {
    final app = open([]);
    app.session.edit(_edited);
    await app.guard.requestClose();
    expect(adapter.submits.single.draft, _edited);
    expect(window.destroyed, 1);
  });

  test(
    'a finalizing edit asks; Cancel leaves the window and the draft',
    () async {
      adapter.guardRequest = finalizeRequest;
      final app = open([ConfirmAnswer.cancel]);
      app.session.edit(_edited);
      await app.guard.requestClose();
      expect(window.destroyed, 0);
      expect(app.session.draft, _edited);
      expect(adapter.submits, isEmpty);
    },
  );

  test('an invalid edit offers Discard and quit; Keep editing stays', () async {
    final app = open([ConfirmAnswer.cancel, ConfirmAnswer.revert]);
    app.session.edit(const ShiftDraft(end: 20, breaks: [25]));
    await app.guard.requestClose();
    expect(window.destroyed, 0);
    expect(app.session.dirty, isTrue);
    await app.guard.requestClose();
    expect(window.destroyed, 1);
    expect(adapter.submits, isEmpty);
  });

  test('a new row with values asks Save, Discard or Cancel', () async {
    final app = open([ConfirmAnswer.revert], baseline: null);
    app.session.edit(_edited);
    await app.guard.requestClose();
    expect(app.confirm.asked.single, same(newRecordRequest));
    expect(window.destroyed, 1);
    expect(adapter.submits, isEmpty);
  });

  test('a close during a save waits for its result before deciding', () async {
    final held = Completer<SubmitResult<SavedShift>>();
    adapter.results.add(held.future);
    final app = open([]);
    app.session.edit(_edited);
    final saving = app.session.save(app.confirm.call);
    final closing = app.guard.requestClose();
    final again = app.guard.requestClose();
    await pumpEventQueue();
    expect(window.destroyed, 0);
    held.complete(
      const Submitted(
        Committed(SavedShift(end: 20, breaks: [12], revision: 4)),
      ),
    );
    await Future.wait([saving, closing, again]);
    expect(window.destroyed, 1);
    expect(adapter.submits, hasLength(1));
  });

  for (final (name, outcome) in <(String, MutationOutcome<SavedShift>)>[
    ('Unavailable', const Unavailable(SafeFailureCode.storageUnavailable)),
    ('Invalid', const Invalid({'end': []})),
  ]) {
    test('a save that ends $name keeps the window and the draft', () async {
      adapter.results.add(Submitted(outcome));
      final app = open([]);
      app.session.edit(_edited);
      await app.guard.requestClose();
      expect(window.destroyed, 0);
      expect(app.session.draft, _edited);
      expect(adapter.submits, hasLength(1));
    });
  }

  test('a save that ends Uncertain keeps the window and the draft; closing '
      'again asks to check first, and Keep editing stays', () async {
    adapter.results.add(
      const Submitted(Uncertain(SafeFailureCode.commitOutcomeUnknown)),
    );
    final app = open([ConfirmAnswer.cancel]);
    app.session.edit(_edited);
    // The close saves first; the save's result is not known.
    await app.guard.requestClose();
    expect(app.confirm.asked, isEmpty);
    expect(window.destroyed, 0);
    // Closing again asks to check it first.
    await app.guard.requestClose();
    expect(app.confirm.asked.single.proceed, 'Reload and check');
    expect(window.destroyed, 0);
    expect(app.session.draft, _edited);
    expect(adapter.submits, hasLength(1));
  });

  for (final (name, outcome) in <(String, MutationOutcome<SavedShift>)>[
    ('Stale', const Stale()),
    ('Missing', const Missing()),
  ]) {
    test(
      'after $name, quitting offers to discard; Keep editing stays',
      () async {
        adapter.results.add(Submitted(outcome));
        final app = open([ConfirmAnswer.cancel]);
        app.session.edit(_edited);
        await app.session.save(app.confirm.call);
        await app.guard.requestClose();
        expect(app.confirm.asked.single.revert, 'Discard and quit');
        expect(window.destroyed, 0);
        expect(app.session.draft, _edited);
      },
    );
  }
}
