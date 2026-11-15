import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay_period.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../production_work_providers.dart';
import '../work_edit/pay_edit.dart';
import '../work_edit/work_records.dart';

enum PayActionKind { review, reopen, correct }

/// The pay actions' words.
abstract final class PayActionWords {
  static const reviewRefused =
      'This period cannot be marked reviewed as it is now. Reload record to '
      'see it.';
  static const reopenRefused =
      'This period cannot be reopened as it is now. Reload record to see it.';
  static const correctRefused =
      'This action is invalid. Check the replacement values and reason.';
  static const reviewed = 'Period marked reviewed.';
  static const reopened = 'Period reopened.';
  static const corrected = 'Payslip corrected. Its replacement is selected.';
}

enum PayActionPhase { input, running, uncertain, blocked, completed }

/// Explicit state changes and inline corrections keep their opening
/// revision. A live register refresh never substitutes another baseline.
final class PayAction extends ChangeNotifier implements LeaveParticipant {
  PayAction({
    required this.kind,
    required this.original,
    required this.work,
    required this.reads,
    this.onCheck,
  }) : _values = original.payslip == null
           ? null
           : PayValues.ofPayslip(original.payslip!);
  final PayActionKind kind;
  final PayRecord original;
  final ProductionWorkProviders work;
  final WorkReads reads;
  final Future<void> Function()? onCheck;
  PayValues? _values;
  String _reason = '';
  Map<String, String> _errors = {};
  String? _error;
  PayActionPhase _phase = PayActionPhase.input;

  /// The replacement values a correction enters; null for state changes.
  PayValues? get values => _values;
  String get reason => _reason;

  /// Field problems, by field key.
  Map<String, String> get errors => Map.unmodifiable(_errors);

  /// The action's own problem, shown in its panel.
  String? get error => _error;
  PayActionPhase get phase => _phase;
  PayslipId? _sent;
  bool _unresolved = false, _disposed = false;
  bool get busy => phase == PayActionPhase.running;
  bool get canSubmit =>
      _phase == PayActionPhase.input || phase == PayActionPhase.uncertain;
  String get title => switch (kind) {
    PayActionKind.review => 'Mark reviewed',
    PayActionKind.reopen => 'Reopen period',
    PayActionKind.correct => 'Correct payslip',
  };
  String get primary => phase == PayActionPhase.uncertain
      ? 'Reload and check'
      : kind == PayActionKind.correct
      ? 'Void and replace'
      : title;
  String get explanation => kind == PayActionKind.correct
      ? 'The original stays in History as Void and leaves the totals. A replacement in the same period records the corrected values.'
      : kind == PayActionKind.review
      ? 'Mark this period Reviewed. Its saved dates and money evidence stay as recorded.'
      : 'Reopen this period. Its saved dates and money evidence stay as recorded.';
  String get notice =>
      error ??
      errors.values.firstOrNull ??
      (phase == PayActionPhase.uncertain ? unknown : explanation);
  static const unknown =
      'This may have gone through. Reload and check before doing anything else.';
  static const stale =
      'This record changed. Cancel and reload it before trying again.';
  String? set(String field, Object? value) {
    if (phase != PayActionPhase.input) return 'Wait for the current action.';
    if (field == 'reason') {
      _reason = '${value ?? ''}';
    } else {
      if (values == null || field == 'period') {
        return 'The period cannot change in a correction.';
      }
      try {
        final changed = values!.withField(field, value);
        final problem = validatePay(PayKind.payslips, changed)[field];
        if (problem != null) return problem;
        _values = changed;
      } on Object {
        return 'Check this value.';
      }
    }
    _errors.remove(field);
    _error = null;
    _notify();
    return null;
  }

  Future<PayRecord?> submit() async {
    if (phase == PayActionPhase.uncertain) return _check();
    if (phase != PayActionPhase.input) return null;
    _errors = {
      if (values != null) ...validatePay(PayKind.payslips, values!),
      if (kind == PayActionKind.correct && reason.trim().isEmpty)
        'reason': 'Enter why the payslip is corrected.',
    };
    if (errors.isNotEmpty) {
      _notify();
      return null;
    }
    _error = null;
    _enter(PayActionPhase.running);
    try {
      if (kind == PayActionKind.correct) {
        _sent = work.evidenceIds.payslipId();
        final result = await work.payslips.correctPayslip(
          CorrectPayslipCommand(
            originalId: original.payslip!.id,
            replacementId: _sent!,
            expectedRevision: original.revision,
            voidReason: reason.trim(),
            replacement: values!.command(),
          ),
        );
        switch (result) {
          case Committed(:final value):
            _enter(PayActionPhase.completed);
            return PayRecord.payslip(value);
          default:
            _failed(result);
        }
      } else {
        final result = await work.periods.setState(
          SetPayPeriodStateCommand(
            id: original.period!.id,
            state: kind == PayActionKind.review
                ? PayPeriodState.reviewed
                : PayPeriodState.open,
            expectedRevision: original.revision,
          ),
        );
        switch (result) {
          case Committed(:final value):
            _enter(PayActionPhase.completed);
            return PayRecord.period(value);
          default:
            _failed(result);
        }
      }
    } on Object {
      _unresolved = false;
      _enter(PayActionPhase.uncertain);
    }
    return null;
  }

  void _failed<T>(MutationOutcome<T> result) {
    switch (result) {
      case Invalid():
        _error = switch (kind) {
          PayActionKind.review => PayActionWords.reviewRefused,
          PayActionKind.reopen => PayActionWords.reopenRefused,
          PayActionKind.correct => PayActionWords.correctRefused,
        };
        _enter(PayActionPhase.input);
      case Stale():
        _error = stale;
        _enter(PayActionPhase.blocked);
      case Missing():
        _error = 'This record no longer exists. Cancel to return to the sheet.';
        _enter(PayActionPhase.blocked);
      case Unavailable():
        _error = 'Not done: local storage is unavailable. Try again.';
        _enter(PayActionPhase.input);
      case Uncertain():
        _unresolved = false;
        _enter(PayActionPhase.uncertain);
      case Committed():
        break;
    }
  }

  Future<PayRecord?> _check() async {
    _error = null;
    _enter(PayActionPhase.running);
    try {
      if (kind == PayActionKind.correct) {
        final now = await reads.payslip(original.payslip!.id);
        if (now == null) return _unknown();
        if (!now.isEffective && now.replacementPayslipId == _sent) {
          final made = await reads.payslip(_sent!);
          if (made == null || made.replacedPayslipId != original.id) {
            return _unknown();
          }
          _enter(PayActionPhase.completed);
          return PayRecord.payslip(made);
        }
        if (now.revision != original.revision) return _changed();
      } else {
        final now = await reads.period(original.period!.id);
        if (now == null) return _unknown();
        final desired = kind == PayActionKind.review
            ? PayPeriodState.reviewed
            : PayPeriodState.open;
        if (now.state == desired && now.revision == original.revision.next()) {
          _enter(PayActionPhase.completed);
          return PayRecord.period(now);
        }
        if (now.revision != original.revision) return _changed();
      }
      _error =
          'It did not go through. Your input is kept; try again when ready.';
      _enter(PayActionPhase.input);
    } on Object {
      return _unknown();
    }
    return null;
  }

  PayRecord? _changed() {
    _error = stale;
    _enter(PayActionPhase.blocked);
    return null;
  }

  PayRecord? _unknown() {
    _unresolved = true;
    _error = 'The result is still not known. Reload and check again.';
    _enter(PayActionPhase.uncertain);
    return null;
  }

  bool get dirty =>
      values != null &&
      (reason.trim().isNotEmpty ||
          values != PayValues.ofPayslip(original.payslip!));

  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (busy) return LeaveDecision.stay;
    if (phase == PayActionPhase.uncertain) {
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
    if (!dirty || phase != PayActionPhase.input) return LeaveDecision.proceed;
    return await confirm(
              ConfirmRequest(
                title: title,
                message: 'Discard the correction you entered? The original is not changed.',
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

  void _enter(PayActionPhase value) {
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
