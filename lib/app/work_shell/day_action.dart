import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/planner.dart';
import '../../ui/ui.dart' show eraBoxDate;
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import 'shifts_action.dart' show ShiftsActionWords;
import 'shifts_lines.dart' show leaveTypeWord;

/// The day actions that run in an action panel (plan 4d-1, call 6): Cancel
/// shift… and Mark as leave… on a planned day not yet confirmed.
enum DayActionKind { cancel, leave }

/// Where a [DayAction] stands.
enum DayActionPhase {
  /// The owner enters the fields.
  input,

  /// The command, or its check, runs.
  running,

  /// The change is stored; the sheet opens the day as it is now.
  opening,

  /// The change is stored but the day could not be opened; Reload and
  /// check opens it without sending the command again.
  committed,

  /// The command may have gone through; Reload and check settles it.
  uncertain,

  /// The day changed or went away; only Cancel is left.
  blocked,
}

/// The panel's field ids, as `ActionField`s and [DayAction.fieldError]
/// name them.
abstract final class DayActionField {
  static const reason = 'reason';
  static const note = 'note';
  static const leaveType = 'leaveType';
  static const illness = 'illnessStartedOn';
}

/// Words of the Cancel shift and Mark as leave panels.
abstract final class DayActionWords {
  static const cancelTitle = 'Cancel shift';
  static const leaveTitle = 'Mark as leave';
  static const cancelHint =
      'Cancel shift: choose why, then press Cancel shift. Nothing changes '
      'before that.';
  static const leaveHint =
      'Mark as leave: choose the leave, then press Mark as leave. Nothing '
      'changes before that.';
  static const illnessNote =
      'Illness is marked as sick leave, not cancelled: use Mark as leave….';
  static const illnessHelp = 'Leave it blank to count from the first sick day.';
  static const illness = 'The illness must start on or before this day.';
  static const changed =
      'This day changed since the action opened. Cancel, then open it again.';
  static const discard = 'Discard what you entered? The day is not changed.';
  static const openFailed =
      'The day was changed, but it could not be opened. Reload and check '
      'to open it.';
  static String cancelled(LocalDate date) =>
      '${eraBoxDate(date)} is cancelled. Restore shift brings it back.';
  static String markedLeave(LocalDate date, LeaveType type) =>
      '${eraBoxDate(date)} is ${leaveTypeWord(type).toLowerCase()} now. '
      'Restore shift brings the shift back.';
}

/// Sends what [DayAction] holds: `DayPlanService.cancelDay` or `markLeave`.
typedef DayActionSend = Future<MutationOutcome<DayException>> Function(
  DayAction action,
);

/// An open Cancel shift or Mark as leave panel on one planned day: the
/// fields the owner enters, the command through `DayPlanService` with the
/// revision of the day's change as the panel opened, every outcome kept
/// distinct (spec 9), and the leave guard (spec 4.4). It holds no widgets.
final class DayAction extends ChangeNotifier implements LeaveParticipant {
  DayAction({
    required this.kind,
    required this.employmentId,
    required this.day,
    required this.exception,
    required this.plans,
    this._send,
    this._readExceptions,
    this.onCheck,
  });

  final DayActionKind kind;
  final EmploymentId employmentId;

  /// The planned shift the action replaces.
  final PlannedShift day;

  /// The day's change as the panel opened; the command expects its
  /// revision.
  final DayException? exception;
  final DayPlanService plans;
  final DayActionSend? _send;
  final Future<List<DayException>> Function()? _readExceptions;

  /// Reload and check as the primary key runs it, offered on quit.
  final Future<void> Function()? onCheck;

  LocalDate get date => day.date;

  CancelReason _reason = CancelReason.swapped;
  String _note = '';
  LeaveType _leaveType = LeaveType.vacation;
  LocalDate? _illness;
  final _fieldErrors = <String, String>{};
  String? _error;
  DayActionPhase _phase = DayActionPhase.input;
  bool _unresolved = false;
  bool _disposed = false;

  CancelReason get reason => _reason;
  String get note => _note;
  LeaveType get leaveType => _leaveType;
  LocalDate? get illnessStartedOn => _illness;
  String? get error => _error;
  DayActionPhase get phase => _phase;
  bool get busy =>
      _phase == DayActionPhase.running || _phase == DayActionPhase.opening;

  /// Whether the primary key acts: it runs the command, checks one whose
  /// result is not known, or opens again a day whose change is stored.
  bool get canSubmit =>
      _phase == DayActionPhase.input ||
      _phase == DayActionPhase.uncertain ||
      _phase == DayActionPhase.committed;

  /// [field]'s problem, shown in its row.
  String? fieldError(String field) => _fieldErrors[field];

  /// Whether anything differs from what the panel opened with.
  bool get entered =>
      _reason != CancelReason.swapped ||
      _note.trim().isNotEmpty ||
      _leaveType != LeaveType.vacation ||
      _illness != null;

  String get title => switch (kind) {
    DayActionKind.cancel => DayActionWords.cancelTitle,
    DayActionKind.leave => DayActionWords.leaveTitle,
  };

  String get primaryLabel =>
      _phase == DayActionPhase.uncertain || _phase == DayActionPhase.committed
      ? ShiftsActionWords.check
      : title;

  /// What the status line says while the panel is open.
  String get notice =>
      _error ??
      _fieldErrors.values.firstOrNull ??
      switch ((_phase, kind)) {
        (DayActionPhase.uncertain, _) => ShiftsActionWords.uncertain,
        (_, DayActionKind.cancel) => DayActionWords.cancelHint,
        (_, DayActionKind.leave) => DayActionWords.leaveHint,
      };

  void setReason(CancelReason value) => _input(() => _reason = value);

  void setNote(String value) => _input(() => _note = value);

  /// Vacation has no illness start: choosing it clears the date.
  void setLeaveType(LeaveType value) => _input(() {
    _leaveType = value;
    if (value != LeaveType.sick) _illness = null;
    _fieldErrors.remove(DayActionField.illness);
  });

  void setIllnessStartedOn(LocalDate? value) => _input(() {
    _illness = _leaveType == LeaveType.sick ? value : null;
    _fieldErrors.remove(DayActionField.illness);
  });

  void _input(VoidCallback change) {
    if (_phase != DayActionPhase.input) return;
    change();
    _error = null;
    _notify();
  }

  /// Runs the action, checks an uncertain one, or opens again a day whose
  /// change is stored without sending it again. True once the change is
  /// known to be stored, and the panel then waits while the sheet opens
  /// the day; [error] or [fieldError] says why not otherwise.
  Future<bool> submit() => switch (_phase) {
    DayActionPhase.input => _run(),
    DayActionPhase.uncertain => _check(),
    DayActionPhase.committed => Future.value(_stored()),
    DayActionPhase.running ||
    DayActionPhase.opening ||
    DayActionPhase.blocked => Future.value(false),
  };

  bool _stored() {
    _error = null;
    _enter(DayActionPhase.opening);
    return true;
  }

  /// The sheet could not open the day after the change was stored: the
  /// panel keeps it, and Reload and check tries again.
  void openingFailed() {
    if (_phase != DayActionPhase.opening) return;
    _error = DayActionWords.openFailed;
    _enter(DayActionPhase.committed);
  }

  Future<bool> _run() async {
    if (_illness case final start? when start.compareTo(date) > 0) {
      _fieldErrors[DayActionField.illness] = DayActionWords.illness;
      _notify();
      return false;
    }
    _error = null;
    _enter(DayActionPhase.running);
    final MutationOutcome<DayException> outcome;
    try {
      outcome = await (_send ?? _sendToPlans)(this);
    } on Object catch (error, stack) {
      _report(error, stack);
      _error = ShiftsActionWords.unavailable;
      _enter(DayActionPhase.input);
      return false;
    }
    switch (outcome) {
      case Committed():
        return _stored();
      case Invalid(:final fields) when fields.containsKey('illnessStartedOn'):
        _fieldErrors[DayActionField.illness] = DayActionWords.illness;
        _enter(DayActionPhase.input);
      case Invalid() || Stale() || Missing():
        _error = DayActionWords.changed;
        _enter(DayActionPhase.blocked);
      case Unavailable():
        _error = ShiftsActionWords.unavailable;
        _enter(DayActionPhase.input);
      case Uncertain():
        _unresolved = false;
        _enter(DayActionPhase.uncertain);
    }
    return false;
  }

  Future<MutationOutcome<DayException>> _sendToPlans(DayAction action) =>
      switch (kind) {
        DayActionKind.cancel => plans.cancelDay(
          employmentId,
          date,
          reason: _reason,
          note: _note,
          expected: exception?.revision,
        ),
        DayActionKind.leave => plans.markLeave(
          employmentId,
          date,
          leaveType: _leaveType,
          illnessStartedOn: _illness,
          expected: exception?.revision,
        ),
      };

  /// Reload and check (spec 9): the day's change now says whether the
  /// command went through. What this panel sent means it did; the change
  /// as the panel opened means it did not; anything else is another change.
  Future<bool> _check() async {
    _error = null;
    _enter(DayActionPhase.running);
    try {
      final now = (await (_readExceptions ?? _readPlans)())
          .where((value) => value.date == date)
          .firstOrNull;
      if (_matchesSent(now)) return _stored();
      if (now?.id == exception?.id && now?.revision == exception?.revision) {
        _error = ShiftsActionWords.notDone;
        _enter(DayActionPhase.input);
      } else {
        _error = DayActionWords.changed;
        _enter(DayActionPhase.blocked);
      }
      return false;
    } on Object catch (error, stack) {
      _report(error, stack);
      _error = ShiftsActionWords.unknown;
      _unresolved = true;
      _enter(DayActionPhase.uncertain);
      return false;
    }
  }

  Future<List<DayException>> _readPlans() async =>
      (await plans.repository.planInputs(employmentId)).exceptions;

  bool _matchesSent(DayException? now) => switch ((kind, now)) {
    (DayActionKind.cancel, CancelledDay(:final reason, :final note)) =>
      reason == _reason && (note ?? '') == _note.trim(),
    (
      DayActionKind.leave,
      LeaveDay(:final leaveType, :final illnessStartedOn),
    ) =>
      leaveType == _leaveType && illnessStartedOn == _illness,
    _ => false,
  };

  /// Leaving drops the panel (spec 4.4): at once when nothing was entered
  /// or nothing can be done; after Discard when something was. A running
  /// command keeps the owner here, and so does one whose result is not
  /// known, except that quitting offers Reload and check.
  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (busy) return LeaveDecision.stay;
    if (_phase == DayActionPhase.uncertain) {
      return kind == LeaveKind.quit
          ? leaveUncertain(
              confirm,
              unresolved: _unresolved,
              check: onCheck ?? () async => submit(),
            )
          : LeaveDecision.stay;
    }
    if (_phase == DayActionPhase.blocked ||
        _phase == DayActionPhase.committed ||
        !entered) {
      return LeaveDecision.proceed;
    }
    final answer = await confirm(
      ConfirmRequest(
        title: title,
        message: DayActionWords.discard,
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

  void _enter(DayActionPhase phase) {
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
    FlutterErrorDetails(exception: error, stack: stack, library: 'day action'),
  );
}
