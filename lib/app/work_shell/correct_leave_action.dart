import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/leave.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';

/// Correct leave's existing service boundary, with a known replacement
/// identity so a lost response can be checked without repeating the write.
typedef CorrectLeave = Future<MutationOutcome<LeaveRecord>> Function(
  LeaveRecordId id, {
  required Revision expected,
  required LeaveType leaveType,
  required LocalDate? illnessStartedOn,
  required String reason,
  LeaveRecordId? replacementId,
});

enum CorrectLeavePhase { input, running, uncertain, blocked, completed }

abstract final class CorrectLeaveWords {
  static const title = 'Correct leave';
  static const primary = 'Void and replace';
  static const check = 'Reload and check';
  static const explanation =
      'The confirmed record stays in History as Void and leaves the totals. '
      'A confirmed replacement on the same date uses the new leave details.';
  static const reason = 'Enter why the leave is corrected.';
  static const illness =
      'Illness started on must be on or before the leave day.';
  static const unavailable =
      'Not done: local storage is unavailable. Try again.';
  static const stale =
      'This leave changed since the action opened. Cancel, then open it again.';
  static const missing =
      'This leave no longer exists. Cancel to return to the sheet.';
  static const refused =
      'This leave cannot be corrected. Cancel and reload the record.';
  static const uncertain =
      'This may have gone through. Reload and check before you do anything else.';
  static const unknown =
      'It is still not known whether this went through. Reload and check again.';
  static const notDone =
      'It did not go through, and nothing changed. Try again when ready.';
  static const discard = 'Discard what you entered? The leave is not changed.';
}

/// An inline correction is an action, never an editable confirmed record.
/// Its original revision remains fixed while live sheet facts refresh.
final class CorrectLeaveAction extends ChangeNotifier
    implements LeaveParticipant {
  CorrectLeaveAction({
    required this.original,
    required DayPlanService service,
    CorrectLeave? correct,
    Future<LeaveRecord?> Function(LeaveRecordId)? read,
    this.onCheck,
  }) : _correct = correct ?? service.correctLeave,
       _read = read ?? service.repository.leaveById,
       _newId = service.ids.leaveRecordId,
       _type = original.leaveType,
       _illness = original.illnessStartedOn;

  final LeaveRecord original;
  final CorrectLeave _correct;
  final Future<LeaveRecord?> Function(LeaveRecordId) _read;
  final LeaveRecordId Function() _newId;
  final Future<void> Function()? onCheck;
  LeaveType _type;
  LocalDate? _illness;
  String _reason = '';
  final Map<String, String> _errors = {};
  String? _error;
  CorrectLeavePhase _phase = CorrectLeavePhase.input;
  LeaveRecordId? _sentId;
  LeaveRecord? _completed;
  bool _unresolved = false;
  bool _disposed = false;

  LeaveType get type => _type;
  LocalDate? get illness => _illness;
  String get reason => _reason;
  Map<String, String> get errors => Map.unmodifiable(_errors);
  String? get error => _error;
  CorrectLeavePhase get phase => _phase;
  bool get busy => _phase == CorrectLeavePhase.running;
  bool get canSubmit =>
      _phase == CorrectLeavePhase.input ||
      _phase == CorrectLeavePhase.uncertain;
  String get primaryLabel => _phase == CorrectLeavePhase.uncertain
      ? CorrectLeaveWords.check
      : CorrectLeaveWords.primary;
  bool get dirty =>
      _type != original.leaveType ||
      _illness != original.illnessStartedOn ||
      _reason.trim().isNotEmpty;
  String get notice =>
      _error ??
      _errors.values.firstOrNull ??
      (_phase == CorrectLeavePhase.uncertain
          ? CorrectLeaveWords.uncertain
          : 'Correct leave: enter the replacement details and reason, then press Void and replace.');

  /// Returns a field problem without replacing any accepted input.
  String? set(String field, Object? value) {
    if (_phase != CorrectLeavePhase.input) {
      return 'Wait for the current action.';
    }
    switch (field) {
      case 'type':
        if (value is! LeaveType) return 'Choose Vacation or Sick.';
        _type = value;
        if (value == LeaveType.vacation) _illness = null;
        _errors.remove('illness');
      case 'illness':
        if (value != null && value is! LocalDate) {
          return CorrectLeaveWords.illness;
        }
        if (value is LocalDate && value.compareTo(original.date) > 0) {
          return CorrectLeaveWords.illness;
        }
        _illness = value as LocalDate?;
      case 'reason':
        _reason = value?.toString() ?? '';
      default:
        return 'This field cannot be changed.';
    }
    _errors.remove(field);
    _error = null;
    _notify();
    return null;
  }

  Future<LeaveRecord?> submit() async {
    if (_phase == CorrectLeavePhase.uncertain) return _check();
    if (_phase != CorrectLeavePhase.input) return null;
    _errors.clear();
    if (_reason.trim().isEmpty) _errors['reason'] = CorrectLeaveWords.reason;
    if (_type == LeaveType.sick &&
        _illness != null &&
        _illness!.compareTo(original.date) > 0) {
      _errors['illness'] = CorrectLeaveWords.illness;
    }
    if (_errors.isNotEmpty) {
      _notify();
      return null;
    }
    _error = null;
    _sentId = _newId();
    _enter(CorrectLeavePhase.running);
    final MutationOutcome<LeaveRecord> outcome;
    try {
      outcome = await _correct(
        original.id,
        expected: original.revision,
        leaveType: _type,
        illnessStartedOn: _type == LeaveType.sick ? _illness : null,
        reason: _reason.trim(),
        replacementId: _sentId,
      );
    } on Object {
      // A thrown response can follow a successful commit. Never retry it
      // until a read has established what happened.
      _unresolved = false;
      _enter(CorrectLeavePhase.uncertain);
      return null;
    }
    switch (outcome) {
      case Committed(:final value):
        return _done(value);
      case Invalid(:final fields):
        if (fields.containsKey('reason')) {
          _errors['reason'] = CorrectLeaveWords.reason;
        }
        if (fields.containsKey('illnessStartedOn')) {
          _errors['illness'] = CorrectLeaveWords.illness;
        }
        if (_errors.isEmpty) {
          _error = CorrectLeaveWords.refused;
          _enter(CorrectLeavePhase.blocked);
        } else {
          _enter(CorrectLeavePhase.input);
        }
      case Stale():
        _error = CorrectLeaveWords.stale;
        _enter(CorrectLeavePhase.blocked);
      case Missing():
        _error = CorrectLeaveWords.missing;
        _enter(CorrectLeavePhase.blocked);
      case Unavailable():
        _error = CorrectLeaveWords.unavailable;
        _enter(CorrectLeavePhase.input);
      case Uncertain():
        _unresolved = false;
        _enter(CorrectLeavePhase.uncertain);
    }
    return null;
  }

  Future<LeaveRecord?> _check() async {
    _error = null;
    _enter(CorrectLeavePhase.running);
    try {
      final now = await _read(original.id);
      if (now == null) return _unknown();
      if (!now.isEffective && now.replacementId == _sentId) {
        final replacement = await _read(_sentId!);
        if (replacement == null || replacement.replacedId != original.id) {
          return _unknown();
        }
        return _done(replacement);
      }
      if (now.isEffective && now.revision == original.revision) {
        _error = CorrectLeaveWords.notDone;
        _enter(CorrectLeavePhase.input);
      } else {
        _error = CorrectLeaveWords.stale;
        _enter(CorrectLeavePhase.blocked);
      }
    } on Object {
      return _unknown();
    }
    return null;
  }

  LeaveRecord? _unknown() {
    _unresolved = true;
    _error = CorrectLeaveWords.unknown;
    _enter(CorrectLeavePhase.uncertain);
    return null;
  }

  LeaveRecord _done(LeaveRecord value) {
    _completed = value;
    _enter(CorrectLeavePhase.completed);
    return value;
  }

  LeaveRecord? get completed => _completed;

  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (busy) return LeaveDecision.stay;
    if (_phase == CorrectLeavePhase.uncertain) {
      return kind == LeaveKind.quit
          ? leaveUncertain(
              confirm,
              unresolved: _unresolved,
              check:
                  onCheck ??
                  () async {
                    await submit();
                  },
            )
          : LeaveDecision.stay;
    }
    if (!dirty || _phase != CorrectLeavePhase.input) {
      return LeaveDecision.proceed;
    }
    return await confirm(
              ConfirmRequest(
                title: CorrectLeaveWords.title,
                message: CorrectLeaveWords.discard,
                proceed: null,
                revert: kind == LeaveKind.quit
                    ? 'Discard input and quit'
                    : 'Discard',
                cancel: 'Keep editing',
                warning: false,
              ),
            ) ==
            ConfirmAnswer.revert
        ? LeaveDecision.proceed
        : LeaveDecision.stay;
  }

  void _enter(CorrectLeavePhase value) {
    _phase = value;
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
}
