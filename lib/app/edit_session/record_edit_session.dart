import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import 'confirm.dart';
import 'leave.dart';
import 'record_edit_adapter.dart';

/// Where a [RecordEditSession] stands (database shell spec 6).
enum EditPhase {
  /// Nothing pending.
  idle,

  /// The draft differs from the saved values and was not submitted.
  dirty,

  /// A save is checking the complete draft.
  validating,

  /// A save waits for the owner's answer in a confirmation window.
  awaitingConfirmation,

  /// A save's command runs; editing is frozen.
  saving,

  /// The last save committed; the baseline is the saved object.
  committed,

  /// The last save or leave was refused (invalid values, a missing record,
  /// unavailable storage); the draft stays.
  failed,

  /// The record changed since it was read; the draft stays for inspection
  /// until Reload record or a discard.
  stale,

  /// The last save may have gone through; nothing is submitted, undone or
  /// left until Reload and check settles it.
  uncertain,
}

/// How a save or an undo ended.
enum SaveResult {
  /// Nothing was pending; nothing was written.
  clean,
  committed,

  /// The owner chose Revert or Discard; the pending values are gone.
  reverted,

  /// The owner chose Cancel; the pending values stay.
  cancelled,
  invalid,
  stale,
  missing,
  unavailable,
  uncertain,

  /// A read-back runs; nothing was done.
  busy,
}

/// What the session tells the owner, in the description pane and status
/// bar (spec 9).
abstract final class EditProblems {
  static const invalid =
      'Fix the marked values, or undo them, before leaving this record.';
  static const stale =
      'This record changed since you opened it. Reload it to see the '
      'current facts, which discards your pending values, or keep editing '
      'them.';
  static const missing =
      'This record no longer exists. Your pending values are kept to look '
      'at; discard them to return to the sheet.';
  static const unavailable =
      'Not saved: local storage is unavailable. Try again.';
  static const uncertain =
      'The save may have gone through. Reload and check before you do '
      'anything else.';
  static const unknown =
      'It is still not known whether the save went through. Reload and '
      'check again.';
  static const notSaved =
      'The save did not go through. Your values are still here; save again '
      'when ready.';
  static const unreadable = 'The record could not be read. Try again.';
  static const busy = 'Wait for the save to finish.';
  static const checkFirst = 'Reload and check the last save first.';
}

/// What a new record with entered values asks when it is left or undone
/// without a lifecycle window of its own (spec 4.3).
const newRecordRequest = ConfirmRequest(
  title: 'New record',
  message:
      'This new record is not saved yet. Save it, or discard what you '
      'entered?',
  proceed: 'Save',
  revert: 'Discard',
);

/// The pending edit of one record and its children (database shell spec
/// 4.2, 6): the draft, its validation, the guarded save through a
/// [RecordEditAdapter], every outcome kept distinct (spec 9), and the
/// leave guard for navigation and quitting. It holds no widgets; the shell
/// renders it and reports edits.
final class RecordEditSession<S, D> extends ChangeNotifier
    implements LeaveParticipant {
  RecordEditSession({required this.adapter, S? baseline, this.onCheck})
    : _baseline = baseline,
      _start = adapter.draftOf(baseline) {
    _draft = _start;
    // Without value equality every draft looks changed, and leaving would
    // save records nobody edited.
    assert(
      adapter.draftOf(baseline) == adapter.draftOf(baseline),
      'RecordEditSession needs a draft type with value equality, '
      'including collection contents.',
    );
  }

  final RecordEditAdapter<S, D> adapter;

  /// Reload and check as the sheet's key runs it, offered when the owner
  /// quits before checking, so the sheet settles after it; null runs
  /// [check].
  final Future<void> Function()? onCheck;

  S? _baseline;
  D _start;
  late D _draft;
  D? _submitted;
  EditPhase _phase = EditPhase.idle;
  Map<String, String> _issues = const {};

  /// The words the last command refused fields with; each stays until its
  /// own field is edited, since only the command can check it again.
  Map<String, String> _refused = const {};
  String? _problem;
  bool _gone = false;
  Future<SaveResult>? _saving;
  bool _reading = false;
  Future<LeaveDecision>? _discarding;
  bool _disposed = false;

  /// Whether a Reload and check could not tell the uncertain save's
  /// result.
  bool _unresolved = false;

  /// The saved object the draft started from; null for a new record.
  S? get baseline => _baseline;

  D get draft => _draft;
  EditPhase get phase => _phase;

  /// Problems by field key, from validation or the command.
  Map<String, String> get issues => _issues;

  /// The record-level message for the description pane and status bar.
  String? get problem => _problem;

  bool get isNew => _baseline == null;

  /// Whether the draft differs from the values it started from. A new
  /// record holding only its defaults is not dirty, so leaving it creates
  /// nothing (spec 4.3).
  bool get dirty => _draft != _start;

  /// Whether a save or a read-back runs.
  bool get busy => _saving != null || _reading || _discarding != null;

  @override
  bool get settled => _phase == EditPhase.idle && !dirty && !busy;

  /// Whether edits, undo and saves are refused: something runs, or the
  /// last save is uncertain.
  bool get frozen => busy || _phase == EditPhase.uncertain;

  /// Whether the record no longer exists.
  bool get gone => _gone;

  /// Whether the last save is uncertain and a Reload and check could not
  /// tell its result: quitting may then go anyway.
  bool get unresolved => _phase == EditPhase.uncertain && _unresolved;

  /// Takes [draft] as the pending value. When [field] names the field
  /// being left, a problem on that field rejects the edit: the draft stays
  /// as it was and the problem is returned for its editor (spec 4.2:
  /// validation runs when a field is left). Problems on other fields are
  /// kept in [issues]. Returns null when taken.
  String? edit(D draft, {String? field}) {
    if (busy) return EditProblems.busy;
    if (_phase == EditPhase.uncertain) return EditProblems.checkFirst;
    final found = adapter.validate(draft);
    if (field != null) {
      if (found[field] case final problem?) return problem;
    }
    _draft = draft;
    _refused = field == null
        ? const {}
        : {
            for (final MapEntry(:key, :value) in _refused.entries)
              if (key != field && !key.startsWith('$field.')) key: value,
          };
    _issues = {..._refused, ...found};
    if (_phase != EditPhase.stale && !_gone) {
      if (_phase == EditPhase.failed || _problem == EditProblems.invalid) {
        _problem = _issues.isEmpty ? null : EditProblems.invalid;
      }
      _phase = dirty ? EditPhase.dirty : EditPhase.idle;
    }
    notifyListeners();
    return null;
  }

  /// Undo (spec 4.2, 4.3). An existing record goes back to its saved
  /// values at once. A new record with entered values asks its lifecycle
  /// window or [newRecordRequest]: Save saves it, Discard drops the values,
  /// Cancel keeps them; invalid entered values can only be discarded.
  Future<SaveResult> undo(Confirm confirm) async {
    if (busy) return SaveResult.busy;
    if (_phase == EditPhase.uncertain) return SaveResult.uncertain;
    if (!dirty) {
      _revert();
      return SaveResult.clean;
    }
    if (!isNew || _gone || _phase == EditPhase.stale) {
      _revert();
      return SaveResult.reverted;
    }
    if (adapter.validate(_draft).isNotEmpty) {
      final decision = await _offerDiscard(confirm, LeaveKind.navigate);
      return decision == LeaveDecision.proceed
          ? SaveResult.reverted
          : SaveResult.cancelled;
    }
    return _run(() => _save(confirm, leaving: true));
  }

  /// Save (spec 4.2): validates the complete draft, asks the adapter's
  /// guard, then submits once. A Save while one runs returns that same
  /// save; no second command is issued. With [unchanged] a clean draft is
  /// submitted too (Finalize an unchanged draft, plan 4d-1 call 9).
  Future<SaveResult> save(Confirm confirm, {bool unchanged = false}) =>
      _run(() => _save(confirm, leaving: false, unchanged: unchanged));

  /// Reload record after Stale (spec 9): the record's current facts replace
  /// the baseline and the pending values are discarded. Outside Stale/Gone,
  /// a dirty draft is kept: reading may detect deletion or a conflicting
  /// revision, but does not silently replace pending values.
  Future<void> reload() async {
    if (busy || _phase == EditPhase.uncertain) return;
    _reading = true;
    notifyListeners();
    try {
      switch (await adapter.readBack(_baseline, null)) {
        case ReadFound(:final value):
          if (dirty && _phase != EditPhase.stale && !_gone) {
            if (value != _baseline) {
              _phase = EditPhase.stale;
              _problem = EditProblems.stale;
            }
          } else {
            _rebase(value);
            _phase = EditPhase.idle;
          }
        case ReadGone() || ReadNotSaved():
          _markGone();
        case ReadUnknown():
          _problem = EditProblems.unreadable;
      }
    } catch (error, stack) {
      _report(error, stack);
      _problem = EditProblems.unreadable;
    } finally {
      _reading = false;
      notifyListeners();
    }
  }

  /// Reload and check after Uncertain (spec 9): reads the record back to
  /// learn whether the submitted draft was stored. Nothing is retried; when
  /// it was not stored, the values stay for an explicit save.
  Future<void> check() async {
    if (busy || _phase != EditPhase.uncertain) return;
    _reading = true;
    notifyListeners();
    try {
      switch (await adapter.readBack(_baseline, _submitted)) {
        case ReadFound(:final value, saved: true):
          _rebase(value);
          _phase = EditPhase.committed;
        case ReadFound(:final value, saved: false) when value != _baseline:
          // The facts changed meanwhile: saving the draft over them would
          // be a force-overwrite; it waits for Reload record (spec 9).
          _submitted = null;
          _problem = EditProblems.stale;
          _phase = EditPhase.stale;
        case ReadFound(:final value, saved: false):
          final kept = _draft;
          _rebase(value);
          _draft = kept;
          _problem = EditProblems.notSaved;
          _phase = dirty ? EditPhase.dirty : EditPhase.idle;
        case ReadNotSaved():
          _submitted = null;
          _problem = EditProblems.notSaved;
          _phase = EditPhase.dirty;
        case ReadGone():
          _markGone();
        case ReadUnknown():
          _problem = EditProblems.unknown;
          _unresolved = true;
      }
    } catch (error, stack) {
      _report(error, stack);
      _problem = EditProblems.unknown;
      _unresolved = true;
    } finally {
      _reading = false;
      notifyListeners();
    }
  }

  /// The leave guard (spec 4.2, 4.8). A clean record lets go. A dirty one
  /// is saved under the save matrix: silently, or through the adapter's
  /// lifecycle window, or [newRecordRequest] for a new record. Invalid
  /// values keep the owner on the record; quitting offers to discard them.
  /// A stale or missing record offers to discard. An uncertain save keeps
  /// the owner; quitting offers Reload and check, and after a check that
  /// could not tell, Quit anyway (owner decision 2026-10-13). A leave
  /// during a save waits for that save and decides from its result,
  /// without a second command.
  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (_discarding case final running?) return running;
    if (_saving case final running?) return _decides(await running);
    if (_reading) {
      _problem = EditProblems.busy;
      notifyListeners();
      return LeaveDecision.stay;
    }
    if (_phase == EditPhase.uncertain) {
      return kind == LeaveKind.quit
          ? leaveUncertain(
              confirm,
              unresolved: _unresolved,
              check: onCheck ?? check,
            )
          : LeaveDecision.stay;
    }
    if (!dirty) return LeaveDecision.proceed;
    if (_gone || _phase == EditPhase.stale) return _offerDiscard(confirm, kind);
    final found = adapter.validate(_draft);
    if (found.isNotEmpty) {
      _issues = found;
      _problem = EditProblems.invalid;
      _enter(EditPhase.failed);
      return kind == LeaveKind.quit
          ? _offerDiscard(confirm, kind)
          : LeaveDecision.stay;
    }
    return _decides(await _run(() => _save(confirm, leaving: true)));
  }

  Future<SaveResult> _run(Future<SaveResult> Function() body) {
    if (_saving case final running?) return running;
    if (_reading || _discarding != null) return Future.value(SaveResult.busy);
    final done = Completer<SaveResult>();
    _saving = done.future;
    () async {
      SaveResult result;
      try {
        result = await body();
      } catch (error, stack) {
        _report(error, stack);
        _problem = EditProblems.unavailable;
        _phase = EditPhase.failed;
        result = SaveResult.unavailable;
      }
      _saving = null;
      notifyListeners();
      done.complete(result);
    }();
    return done.future;
  }

  Future<SaveResult> _save(
    Confirm confirm, {
    required bool leaving,
    bool unchanged = false,
  }) async {
    if (_gone) return SaveResult.missing;
    if (_phase == EditPhase.stale) return SaveResult.stale;
    if (_phase == EditPhase.uncertain) return SaveResult.uncertain;
    // A clean record has nothing to save, except a new one the owner saves
    // as it is (its defaults are its values; leaving it creates nothing,
    // spec 4.3) and an unchanged one saved on purpose (Finalize).
    if (!dirty && !(isNew ? !leaving : unchanged)) return SaveResult.clean;
    _enter(EditPhase.validating);
    final found = adapter.validate(_draft);
    if (found.isNotEmpty) {
      _issues = found;
      _problem = EditProblems.invalid;
      _enter(EditPhase.failed);
      return SaveResult.invalid;
    }
    var request =
        await adapter.guard(_baseline, _draft) ??
        (leaving && isNew ? newRecordRequest : null);
    while (true) {
      Object? consent;
      if (request != null) {
        assert(
          !isNew || !leaving || request.revert != null,
          'A new record lifecycle window must offer Discard when leaving.',
        );
        _enter(EditPhase.awaitingConfirmation);
        switch (await confirm(request)) {
          case ConfirmAnswer.cancel:
            // A clean record saved on purpose (Finalize) stays clean.
            _problem = null;
            _enter(dirty ? EditPhase.dirty : EditPhase.idle);
            return SaveResult.cancelled;
          case ConfirmAnswer.revert:
            _revert();
            return SaveResult.reverted;
          case ConfirmAnswer.proceed:
            consent = request.consent;
        }
      }
      // The command checks every field again.
      _refused = const {};
      final submitted = _submitted = _draft;
      _enter(EditPhase.saving);
      final SubmitResult<S> result;
      try {
        result = await adapter.submit(_baseline, submitted, consent: consent);
      } catch (error, stack) {
        // The command may have written before it threw: never claim it
        // failed or invite a second write (spec 9).
        _report(error, stack);
        return _apply(const Uncertain(SafeFailureCode.commitOutcomeUnknown));
      }
      switch (result) {
        case Reconfirm(request: final fresh):
          request = fresh;
        case Submitted(:final outcome):
          return _apply(outcome);
      }
    }
  }

  SaveResult _apply(MutationOutcome<S> outcome) {
    switch (outcome) {
      case Committed(:final value):
        _rebase(value);
        _enter(EditPhase.committed);
        return SaveResult.committed;
      case Invalid(:final fields):
        _issues = _refused = adapter.describe(fields);
        _problem = _issues.values.firstOrNull ?? EditProblems.invalid;
        _enter(EditPhase.failed);
        return SaveResult.invalid;
      case Stale():
        _problem = EditProblems.stale;
        _enter(EditPhase.stale);
        return SaveResult.stale;
      case Missing():
        _markGone();
        notifyListeners();
        return SaveResult.missing;
      case Unavailable():
        _problem = EditProblems.unavailable;
        _enter(EditPhase.failed);
        return SaveResult.unavailable;
      case Uncertain():
        _problem = EditProblems.uncertain;
        _unresolved = false;
        _enter(EditPhase.uncertain);
        return SaveResult.uncertain;
    }
  }

  Future<LeaveDecision> _offerDiscard(Confirm confirm, LeaveKind kind) {
    if (_discarding case final running?) return running;
    final done = Completer<LeaveDecision>();
    _discarding = done.future;
    () async {
      try {
        done.complete(await _askDiscard(confirm, kind));
      } catch (error, stack) {
        _report(error, stack);
        done.complete(LeaveDecision.stay);
      } finally {
        _discarding = null;
        notifyListeners();
      }
    }();
    return done.future;
  }

  Future<LeaveDecision> _askDiscard(Confirm confirm, LeaveKind kind) async {
    final quitting = kind == LeaveKind.quit;
    final reason = _gone || _phase == EditPhase.stale
        ? '$_problem Discard your pending values'
        : 'What you entered is not valid, so it cannot be saved. Discard it';
    final answer = await confirm(
      ConfirmRequest(
        title: 'Pending values',
        message: '$reason${quitting ? ' and quit' : ''}?',
        proceed: null,
        revert: quitting ? 'Discard and quit' : 'Discard',
        cancel: 'Keep editing',
      ),
    );
    if (answer != ConfirmAnswer.revert) return LeaveDecision.stay;
    _revert();
    return LeaveDecision.proceed;
  }

  LeaveDecision _decides(SaveResult result) => switch (result) {
    SaveResult.clean ||
    SaveResult.committed ||
    SaveResult.reverted => LeaveDecision.proceed,
    _ => LeaveDecision.stay,
  };

  void _revert() {
    _draft = _start;
    _issues = _refused = const {};
    if (!_gone && _phase != EditPhase.stale) {
      _problem = null;
      _phase = EditPhase.idle;
    }
    notifyListeners();
  }

  void _rebase(S value) {
    _baseline = value;
    _start = adapter.draftOf(value);
    _draft = _start;
    _submitted = null;
    _issues = _refused = const {};
    _problem = null;
    _gone = false;
  }

  void _markGone() {
    _gone = true;
    _problem = EditProblems.missing;
    _phase = EditPhase.failed;
  }

  void _enter(EditPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  /// A session left while its command runs (the record went off screen)
  /// still settles; it only stops telling listeners.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'record edit session',
    ),
  );
}
