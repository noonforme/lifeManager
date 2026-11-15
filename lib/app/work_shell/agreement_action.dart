import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/app_clock.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/agreement_service.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/facts.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/agreement_fields.dart';
import '../work_edit/work_records.dart';

/// The actions an agreement version runs in an action panel (spec 4.9):
/// Change terms from… starts the next version on a date; End agreement…
/// sets its last day.
enum AgreementActionKind { changeTerms, end }

/// Where an [AgreementAction] stands.
enum AgreementActionPhase {
  /// The owner enters the date and terms.
  input,

  /// The command, or its check, runs.
  running,

  /// The command may have gone through; Reload and check settles it.
  uncertain,

  /// The version changed or went away; only Cancel is left.
  blocked,
}

/// Words of the Change terms and End agreement panels.
abstract final class AgreementActionWords {
  static const changeTitle = 'Change terms';
  static const endTitle = 'End agreement';
  static const changePrimary = 'Change terms';
  static const endPrimary = 'End agreement';
  static const check = 'Reload and check';
  static const fromLabel = 'From';
  static const lastDayLabel = 'Last day';

  static String changeExplain(PayAgreement value) =>
      'Version ${value.version} ends the day before From. The new version '
      'runs ${switch (value.effectiveEnd) {
        final end? => 'to ${_day(end)}',
        null => 'with no end',
      }}. Overtime, night, holiday and leave pay carry over; change them on '
      'the new version afterwards.';
  static const endExplain =
      'It pays up to and including the last day. Days after it are paid by '
      'no agreement until another covers them.';
  static const changeHint =
      'Change terms: pick From and the new rate, then press Change terms. '
      'Nothing changes before that.';
  static const endHint =
      'End agreement: pick its last day, then press End agreement. Nothing '
      'changes before that.';

  static String fromRange(LocalDate start, LocalDate? end) =>
      'Pick a day after it starts, ${_day(start)}'
      '${end == null ? '.' : ', and on or before it ends, ${_day(end)}.'}';
  static String paidUntil(LocalDate last) =>
      'It paid days up to ${_day(last)} under these terms. Pick a '
      'later day.';
  static const paidLater =
      'It paid days on or after this day under these terms. Pick a later '
      'day.';
  static String lastBeforeStart(LocalDate start) =>
      'The last day must be on or after its start, ${_day(start)}.';
  static String endPaidUntil(LocalDate last) =>
      'It paid days up to ${_day(last)}. Pick that day or a later one.';
  static const endPaidLater = 'It paid days after this day. Pick a later one.';
  static const stale =
      'This agreement changed since the action opened. Cancel, then open it '
      'again.';
  static const missing =
      'This agreement no longer exists. Cancel to return to the sheet.';
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
      'Discard what you entered? The agreement is not changed.';
}

/// An open Change terms or End agreement panel on one stored version: the
/// date and terms the owner enters, the command through
/// `AgreementService` with the revision the panel opened on, every outcome
/// kept distinct (spec 9), and the leave guard (spec 4.4). It holds no
/// widgets; the Agreements part renders it in an `ActionPanel`.
final class AgreementAction extends ChangeNotifier implements LeaveParticipant {
  AgreementAction({
    required this.kind,
    required this.row,
    required this.service,
    required this.reads,
    required this.clock,
    required LocalDate today,
    this.onCheck,
  }) : date = _defaultDate(kind, row, today),
       rate = row.agreement.hourlyRateMicroEur,
       basis = row.agreement.basis,
       label = row.agreement.label,
       note = row.agreement.note {
    _opened = _values;
  }

  final AgreementActionKind kind;

  /// The version as read when the panel opened; the command expects its
  /// revision.
  final AgreementRow row;
  final AgreementService service;
  final WorkReads reads;
  final AppClock clock;

  /// Reload and check as the shell runs it when the owner quits first.
  final Future<void> Function()? onCheck;

  /// From, or the last day.
  LocalDate date;

  /// The new version's rate, basis, label and note (Change terms only).
  int rate;
  RateBasis basis;
  String? label;
  String? note;

  late final Object _opened;
  Map<String, String> _errors = const {};
  String? _error;
  AgreementActionPhase _phase = AgreementActionPhase.input;
  bool _unresolved = false;
  DateTime? _sentAt;
  LocalDate? _sentDate;
  bool _disposed = false;

  /// Why the service refused a value, by field (`date` or an
  /// `AgreementField`).
  Map<String, String> get errors => _errors;

  /// Why the last command did not go through, when no field says so.
  String? get error => _error;
  AgreementActionPhase get phase => _phase;
  bool get busy => _phase == AgreementActionPhase.running;
  bool get canSubmit =>
      _phase == AgreementActionPhase.input ||
      _phase == AgreementActionPhase.uncertain;

  String get title => switch (kind) {
    AgreementActionKind.changeTerms => AgreementActionWords.changeTitle,
    AgreementActionKind.end => AgreementActionWords.endTitle,
  };

  String get primaryLabel => _phase == AgreementActionPhase.uncertain
      ? AgreementActionWords.check
      : switch (kind) {
          AgreementActionKind.changeTerms => AgreementActionWords.changePrimary,
          AgreementActionKind.end => AgreementActionWords.endPrimary,
        };

  String get explanation => switch (kind) {
    AgreementActionKind.changeTerms => AgreementActionWords.changeExplain(
      row.agreement,
    ),
    AgreementActionKind.end => AgreementActionWords.endExplain,
  };

  /// What the status line says while the panel is open.
  String get notice =>
      _error ??
      _errors.values.firstOrNull ??
      switch ((_phase, kind)) {
        (AgreementActionPhase.uncertain, _) => AgreementActionWords.uncertain,
        (_, AgreementActionKind.changeTerms) => AgreementActionWords.changeHint,
        (_, AgreementActionKind.end) => AgreementActionWords.endHint,
      };

  /// Takes [value] for [field]; returns the problem that keeps it in its
  /// editor. Values are fixed once sent.
  String? set(String field, Object? value) {
    if (_phase != AgreementActionPhase.input) {
      return AgreementProblems.notEditable;
    }
    if (field == 'date') {
      if (value is! LocalDate) return AgreementProblems.startRequired;
      date = value;
    } else {
      if (kind != AgreementActionKind.changeTerms) {
        return AgreementProblems.notEditable;
      }
      final result = withAgreementField(_terms, field, value);
      if (result.problem case final problem?) return problem;
      final terms = result.terms!;
      rate = terms.hourlyRateMicroEur;
      basis = terms.basis;
      label = terms.label;
      note = terms.note;
    }
    _errors = {
      for (final MapEntry(:key, :value) in _errors.entries)
        if (key != field) key: value,
    };
    _error = null;
    _notify();
    return null;
  }

  /// Runs the action, or checks an uncertain one. Returns the version it
  /// produced (the new one, or the one ended); null otherwise, and
  /// [errors] or [error] say why.
  Future<PayAgreement?> submit() => switch (_phase) {
    AgreementActionPhase.input => _run(),
    AgreementActionPhase.uncertain => _check(),
    _ => Future<PayAgreement?>.value(),
  };

  /// The new version's terms: this version's, with the panel's values.
  AgreementTerms get _terms =>
      AgreementTerms.of(row.agreement, effectiveStart: date).change(
        hourlyRateMicroEur: rate,
        basis: basis,
        label: () => label,
        note: () => note,
      );

  Future<PayAgreement?> _run() async {
    final current = row.agreement;
    _error = null;
    _errors = const {};
    _sentAt = clock.nowUtc();
    _sentDate = date;
    _enter(AgreementActionPhase.running);
    final MutationOutcome<PayAgreement> outcome;
    try {
      outcome = switch (kind) {
        AgreementActionKind.changeTerms => await service.changeAgreementTerms(
          ChangeAgreementTermsCommand(
            agreementId: current.id,
            employmentId: current.employmentId,
            expectedRevision: current.revision,
            from: date,
            terms: _terms,
          ),
        ),
        AgreementActionKind.end => await service.closeAgreement(
          CloseAgreementCommand(
            agreementId: current.id,
            employmentId: current.employmentId,
            end: date,
            expectedRevision: current.revision,
          ),
        ),
      };
    } on Object catch (error, stack) {
      // A write that throws may have committed: only a check can tell.
      _report(error, stack);
      _unresolved = false;
      _enter(AgreementActionPhase.uncertain);
      return null;
    }
    switch (outcome) {
      case Committed(:final value):
        return value;
      case Invalid(:final fields):
        _errors = _describe(fields);
        if (_errors.isEmpty) _error = AgreementProblems.terms;
        _enter(AgreementActionPhase.input);
      case Stale():
        _error = AgreementActionWords.stale;
        _enter(AgreementActionPhase.blocked);
      case Missing():
        _error = AgreementActionWords.missing;
        _enter(AgreementActionPhase.blocked);
      case Unavailable():
        _error = AgreementActionWords.unavailable;
        _enter(AgreementActionPhase.input);
      case Uncertain():
        _unresolved = false;
        _enter(AgreementActionPhase.uncertain);
    }
    return null;
  }

  /// The service's refusals in the panel's words.
  Map<String, String> _describe(Map<String, List<FieldIssue>> fields) {
    final current = row.agreement;
    final last = row.lastUse;
    String? words(String key, FieldIssueCode? code) => switch ((kind, key)) {
      (AgreementActionKind.changeTerms, 'from') =>
        code == FieldIssueCode.conflict
            ? (last == null
                  ? AgreementActionWords.paidLater
                  : AgreementActionWords.paidUntil(last))
            : AgreementActionWords.fromRange(
                current.effectiveStart,
                current.effectiveEnd,
              ),
      (AgreementActionKind.end, 'effectiveEnd') =>
        code == FieldIssueCode.conflict
            ? (last == null
                  ? AgreementActionWords.endPaidLater
                  : AgreementActionWords.endPaidUntil(last))
            : AgreementActionWords.lastBeforeStart(current.effectiveStart),
      (_, 'effectiveRange') => AgreementProblems.overlap,
      _ => null,
    };
    // Every refusal the panel names is about its date.
    final text = [
      for (final MapEntry(:key, :value) in fields.entries)
        ?words(key, value.firstOrNull?.code),
    ].firstOrNull;
    return {'date': ?text};
  }

  /// Reload and check (spec 9): the stored versions say whether the
  /// command went through. Change terms went when this version ends the
  /// day before the sent From and a version made since the send starts on
  /// it; End went when this version ends on the sent day at a new
  /// revision. This version unchanged means it did not; anything else is
  /// another change, so the panel is stale.
  Future<PayAgreement?> _check() async {
    final current = row.agreement;
    final sent = _sentDate ?? date;
    _error = null;
    _enter(AgreementActionPhase.running);
    try {
      final rows = await reads.agreementRows(current.employmentId);
      final now = rows
          .where((value) => value.agreement.id == current.id)
          .firstOrNull
          ?.agreement;
      if (now == null) {
        _error = AgreementActionWords.missing;
        _enter(AgreementActionPhase.blocked);
        return null;
      }
      final sentAt = _sentAt;
      final PayAgreement? produced = switch (kind) {
        AgreementActionKind.changeTerms
            when now.effectiveEnd == sent.addDays(-1) =>
          rows
              .map((value) => value.agreement)
              .where(
                (value) =>
                    value.effectiveStart == sent &&
                    sentAt != null &&
                    !value.createdAtUtc.isBefore(sentAt),
              )
              .firstOrNull,
        AgreementActionKind.end
            when now.effectiveEnd == sent && now.revision != current.revision =>
          now,
        _ => null,
      };
      if (produced != null) return produced;
      if (now.revision == current.revision) {
        _error = AgreementActionWords.notDone;
        _enter(AgreementActionPhase.input);
      } else {
        _error = AgreementActionWords.stale;
        _enter(AgreementActionPhase.blocked);
      }
      return null;
    } on Object catch (error, stack) {
      _report(error, stack);
      _error = AgreementActionWords.unknown;
      _unresolved = true;
      _enter(AgreementActionPhase.uncertain);
      return null;
    }
  }

  /// The values the owner can change, to tell whether anything was
  /// entered.
  Object get _values => (date, rate, basis, label, note);

  /// Leaving drops the panel (spec 4.4): at once when nothing was entered
  /// or nothing can be done; after Discard when something was entered. A
  /// running command keeps the owner here, and so does one whose result is
  /// not known, except that quitting offers Reload and check and, after a
  /// check that could not tell, Quit anyway (owner decision 2026-10-13).
  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (busy) return LeaveDecision.stay;
    if (_phase == AgreementActionPhase.uncertain) {
      return kind == LeaveKind.quit
          ? leaveUncertain(
              confirm,
              unresolved: _unresolved,
              check: onCheck ?? () async => submit(),
            )
          : LeaveDecision.stay;
    }
    if (_phase == AgreementActionPhase.blocked || _values == _opened) {
      return LeaveDecision.proceed;
    }
    final answer = await confirm(
      ConfirmRequest(
        title: title,
        message: AgreementActionWords.discard,
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

  void _enter(AgreementActionPhase phase) {
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
      library: 'agreement action',
    ),
  );
}

String _day(LocalDate date) => '$date';

/// Where a panel's date starts: Change terms on the first day it can
/// (after the start, after the last paid day, today at the earliest, never
/// past the end); End on its end, else today, never before its start.
LocalDate _defaultDate(
  AgreementActionKind kind,
  AgreementRow row,
  LocalDate today,
) {
  final value = row.agreement;
  LocalDate latest(LocalDate a, LocalDate b) => a.compareTo(b) >= 0 ? a : b;
  switch (kind) {
    case AgreementActionKind.changeTerms:
      var from = latest(today, value.effectiveStart.addDays(1));
      if (row.lastUse case final last?) from = latest(from, last.addDays(1));
      final end = value.effectiveEnd;
      return end != null && from.compareTo(end) > 0 ? end : from;
    case AgreementActionKind.end:
      return value.effectiveEnd ?? latest(today, value.effectiveStart);
  }
}
