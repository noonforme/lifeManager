import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../features/work/application/shift_lifecycle_service.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/shift.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../work_edit/work_records.dart';

/// The record actions a stored shift runs in an action panel (spec 4.2,
/// 4.4): Correct voids a finalized shift and replaces it with a draft; Void
/// removes a draft or finalized shift with no replacement.
enum ShiftsActionKind { correct, voidShift }

/// Where a [ShiftsAction] stands.
enum ShiftsActionPhase {
  /// The owner enters the reason.
  input,

  /// The command, or its check, runs.
  running,

  /// The command committed; the controller is opening its saved record.
  opening,

  /// Opening failed after commit. The primary key retries only the reads.
  committed,

  /// The command may have gone through; Reload and check settles it.
  uncertain,

  /// The shift changed or went away; only Cancel is left.
  blocked,
}

/// Words of the Correct and Void panels.
abstract final class ShiftsActionWords {
  static const correctTitle = 'Correct shift';
  static const voidTitle = 'Void shift';
  static const correctPrimary = 'Void and replace';
  static const voidPrimary = 'Void shift';
  static const check = 'Reload and check';
  static const openFailed =
      'The shift was saved, but it could not be opened. Reload and check '
      'to open the saved record.';
  static const correctExplain =
      'The shift stays in the history as Void and leaves the totals. A '
      'replacement draft with the same times opens; saving it finalizes it.';
  static const voidExplain =
      'The shift stays in the history as Void and leaves the totals. '
      'Nothing replaces it.';
  static const correctHint =
      'Correct: give the reason, then press Void and replace. Nothing '
      'changes before that.';
  static const voidHint =
      'Void: give the reason, then press Void shift. Nothing changes before '
      'that.';
  static const correctReason = 'Explain why this correction is needed.';
  static const voidReason = 'Explain why this shift is voided.';
  static const stale =
      'This shift changed since the action opened. Cancel, then open it '
      'again on the current shift.';
  static const missing =
      'This shift no longer exists. Cancel to return to the sheet.';
  static const alreadyVoid = 'This shift is already void.';
  static const refused = 'This shift cannot be changed this way.';
  static const unavailable =
      'Not done: local storage is unavailable. Try again.';
  static const uncertain =
      'This may have gone through. Reload and check before you do anything '
      'else.';
  static const unknown =
      'It is still not known whether this went through. Reload and check '
      'again.';
  static const notDone =
      'It did not go through, and nothing changed. Try again when ready.';
  static const discard =
      'Discard the reason you entered? The shift is not changed.';
}

/// An open Correct or Void panel on one stored shift: the reason the owner
/// enters, the command through `ShiftLifecycleService` with the revision
/// the panel opened on, every outcome kept distinct (spec 9), and the leave
/// guard (spec 4.4: leaving asks first when a reason was entered). It holds
/// no widgets; the harness renders it in an `ActionPanel`.
final class ShiftsAction extends ChangeNotifier implements LeaveParticipant {
  ShiftsAction({
    required this.kind,
    required this.shift,
    required this.lifecycle,
    required this.reads,
    required this.newShiftId,
    this.onCheck,
    Future<ShiftRecord?> Function(ShiftId)? readShift,
  }) : _readShift = readShift ?? reads.shift;

  final ShiftsActionKind kind;

  /// The shift as read when the panel opened; the command expects its
  /// revision.
  final WorkShift shift;
  final ShiftLifecycleService lifecycle;
  final WorkReads reads;
  final Future<ShiftRecord?> Function(ShiftId) _readShift;

  /// The id a correction's replacement draft gets.
  final ShiftId Function() newShiftId;

  /// Reload and check as the panel's primary key runs it, offered when the
  /// owner quits before checking; null runs [submit].
  final Future<void> Function()? onCheck;

  /// Whether a Reload and check could not tell the result.
  bool _unresolved = false;

  String _reason = '';
  String? _reasonError;
  String? _error;
  ShiftsActionPhase _phase = ShiftsActionPhase.input;

  /// What the last command sent, for Reload and check.
  ShiftId? _sentReplacement;
  String? _sentReason;
  WorkShift? _completed;
  bool _disposed = false;

  String get reason => _reason;
  String? get reasonError => _reasonError;

  /// Why the last command did not go through.
  String? get error => _error;
  ShiftsActionPhase get phase => _phase;
  bool get busy =>
      _phase == ShiftsActionPhase.running ||
      _phase == ShiftsActionPhase.opening;

  /// Whether the primary key acts: it runs the command, checks an unknown
  /// result, or retries opening a record whose commit is already known.
  bool get canSubmit =>
      _phase == ShiftsActionPhase.input ||
      _phase == ShiftsActionPhase.committed ||
      _phase == ShiftsActionPhase.uncertain;

  String get title => switch (kind) {
    ShiftsActionKind.correct => ShiftsActionWords.correctTitle,
    ShiftsActionKind.voidShift => ShiftsActionWords.voidTitle,
  };

  String get primaryLabel =>
      _phase == ShiftsActionPhase.uncertain ||
          _phase == ShiftsActionPhase.committed
      ? ShiftsActionWords.check
      : switch (kind) {
          ShiftsActionKind.correct => ShiftsActionWords.correctPrimary,
          ShiftsActionKind.voidShift => ShiftsActionWords.voidPrimary,
        };

  String get explanation => switch (kind) {
    ShiftsActionKind.correct => ShiftsActionWords.correctExplain,
    ShiftsActionKind.voidShift => ShiftsActionWords.voidExplain,
  };

  /// What the status line says while the panel is open.
  String get notice =>
      _error ??
      _reasonError ??
      switch ((_phase, kind)) {
        (ShiftsActionPhase.uncertain, _) => ShiftsActionWords.uncertain,
        (_, ShiftsActionKind.correct) => ShiftsActionWords.correctHint,
        (_, ShiftsActionKind.voidShift) => ShiftsActionWords.voidHint,
      };

  /// Takes the reason the owner typed; it is fixed once sent.
  void setReason(String value) {
    if (_phase != ShiftsActionPhase.input) return;
    _reason = value;
    _reasonError = null;
    _notify();
  }

  /// Runs the action, checks an uncertain outcome, or resumes opening a
  /// known commit without writing again. Returns the shift it produced: the
  /// replacement draft, or the void shift. Null otherwise; [error] or
  /// [reasonError] then says why.
  Future<WorkShift?> submit() => switch (_phase) {
    ShiftsActionPhase.input => _run(),
    ShiftsActionPhase.uncertain => _check(),
    ShiftsActionPhase.committed => Future<WorkShift?>.value(_resumeOpening()),
    ShiftsActionPhase.running ||
    ShiftsActionPhase.opening ||
    ShiftsActionPhase.blocked => Future<WorkShift?>.value(),
  };

  Future<WorkShift?> _run() async {
    final reason = _reason.trim();
    if (reason.isEmpty) {
      _reasonError = _reasonWords;
      _notify();
      return null;
    }
    _error = null;
    _sentReason = reason;
    _enter(ShiftsActionPhase.running);
    final MutationOutcome<WorkShift> outcome;
    try {
      outcome = switch (kind) {
        ShiftsActionKind.correct => await lifecycle.correctShift(
          CorrectShiftCommand(
            originalId: shift.id,
            replacementId: _sentReplacement = newShiftId(),
            expectedRevision: shift.revision,
            voidReason: reason,
          ),
        ),
        ShiftsActionKind.voidShift => await lifecycle.voidShift(
          VoidShiftCommand(
            id: shift.id,
            expectedRevision: shift.revision,
            voidReason: reason,
          ),
        ),
      };
    } on Object catch (error, stack) {
      _report(error, stack);
      _error = ShiftsActionWords.unavailable;
      _enter(ShiftsActionPhase.input);
      return null;
    }
    switch (outcome) {
      case Committed(:final value):
        return _committed(value);
      case Invalid(:final fields) when fields.containsKey('voidReason'):
        _reasonError = _reasonWords;
        _enter(ShiftsActionPhase.input);
      case Invalid(:final fields) when fields.containsKey('state'):
        _error = ShiftsActionWords.alreadyVoid;
        _enter(ShiftsActionPhase.blocked);
      case Invalid():
        _error = ShiftsActionWords.refused;
        _enter(ShiftsActionPhase.blocked);
      case Stale():
        _error = ShiftsActionWords.stale;
        _enter(ShiftsActionPhase.blocked);
      case Missing():
        _error = ShiftsActionWords.missing;
        _enter(ShiftsActionPhase.blocked);
      case Unavailable():
        _error = ShiftsActionWords.unavailable;
        _enter(ShiftsActionPhase.input);
      case Uncertain():
        _unresolved = false;
        _enter(ShiftsActionPhase.uncertain);
    }
    return null;
  }

  /// Reload and check (spec 9): the shift's state and links say whether
  /// the command went through. A correction is the original voided with a
  /// link to the replacement this panel sent; a void is the original voided
  /// with no replacement and this panel's reason. The original unchanged
  /// means it did not; anything else is another change, so the panel is
  /// stale.
  Future<WorkShift?> _check() async {
    _error = null;
    _enter(ShiftsActionPhase.running);
    try {
      final now = (await _readShift(shift.id))?.shift;
      if (now == null) return _stillUnknown();
      final went = switch (kind) {
        ShiftsActionKind.correct =>
          now.state == ShiftState.voided &&
              now.replacementShiftId == _sentReplacement,
        ShiftsActionKind.voidShift =>
          now.state == ShiftState.voided &&
              now.replacementShiftId == null &&
              now.voidReason == _sentReason,
      };
      if (went) {
        final produced = switch (kind) {
          ShiftsActionKind.correct => (await _readShift(
            _sentReplacement!,
          ))?.shift,
          ShiftsActionKind.voidShift => now,
        };
        if (produced == null) return _stillUnknown();
        return _committed(produced);
      }
      if (now.revision == shift.revision) {
        _error = ShiftsActionWords.notDone;
        _enter(ShiftsActionPhase.input);
      } else {
        _error = ShiftsActionWords.stale;
        _enter(ShiftsActionPhase.blocked);
      }
      return null;
    } on Object catch (error, stack) {
      _report(error, stack);
      return _stillUnknown();
    }
  }

  WorkShift? _stillUnknown() {
    _error = ShiftsActionWords.unknown;
    _unresolved = true;
    _enter(ShiftsActionPhase.uncertain);
    return null;
  }

  WorkShift _committed(WorkShift value) {
    _completed = value;
    _enter(ShiftsActionPhase.opening);
    return value;
  }

  WorkShift? _resumeOpening() {
    _error = null;
    _enter(ShiftsActionPhase.opening);
    return _completed;
  }

  /// Retains a known commit when the controller cannot read its record.
  /// The next submit returns that same identity without a lifecycle write.
  void openingFailed() {
    if (_phase != ShiftsActionPhase.opening) return;
    _error = ShiftsActionWords.openFailed;
    _enter(ShiftsActionPhase.committed);
  }

  String get _reasonWords => switch (kind) {
    ShiftsActionKind.correct => ShiftsActionWords.correctReason,
    ShiftsActionKind.voidShift => ShiftsActionWords.voidReason,
  };

  /// Leaving drops the panel (spec 4.4): at once when nothing was entered
  /// or nothing can be done; after Discard when a reason was entered. A
  /// running command keeps the owner here, and so does one whose result is
  /// not known (spec 9), except that quitting offers Reload and check and,
  /// after a check that could not tell, Quit anyway (owner decision
  /// 2026-10-13).
  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (busy) return LeaveDecision.stay;
    if (_phase == ShiftsActionPhase.uncertain) {
      return kind == LeaveKind.quit
          ? leaveUncertain(
              confirm,
              unresolved: _unresolved,
              check: onCheck ?? () async => submit(),
            )
          : LeaveDecision.stay;
    }
    if (_phase == ShiftsActionPhase.blocked ||
        _phase == ShiftsActionPhase.committed ||
        _reason.trim().isEmpty) {
      return LeaveDecision.proceed;
    }
    final answer = await confirm(
      ConfirmRequest(
        title: title,
        message: ShiftsActionWords.discard,
        proceed: null,
        revert: kind == LeaveKind.quit ? 'Discard input and quit' : 'Discard',
        cancel: 'Keep editing',
        warning: false,
      ),
    );
    return answer == ConfirmAnswer.revert
        ? LeaveDecision.proceed
        : LeaveDecision.stay;
  }

  void _enter(ShiftsActionPhase phase) {
    _phase = phase;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
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
      library: 'shifts action',
    ),
  );
}
