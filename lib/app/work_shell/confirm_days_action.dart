import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay.dart';
import '../../ui/ui.dart' show eraBoxDate;
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import 'basis_total.dart';

/// What a day to confirm is, for the panel's words.
enum ConfirmDayKind { planned, changed, extra, vacation, sick }

/// One past day Confirm worked days lists (plan 4d-2): its paid time and
/// planned pay for the totals, and whether an agreement lets it be
/// confirmed at all.
@immutable
final class ConfirmDayChoice {
  const ConfirmDayChoice({
    required this.date,
    required this.kind,
    required this.paidSeconds,
    required this.pay,
    required this.eligible,
    this.basis,
  });

  final LocalDate date;
  final ConfirmDayKind kind;
  final int paidSeconds;

  /// Planned pay; null when it is not known (no agreement, or a leave
  /// day's months before not read yet).
  final Money? pay;

  /// The basis [pay] is on.
  final RateBasis? basis;

  /// False for a day no pay agreement covers: listed, never ticked.
  final bool eligible;
}

/// How confirming one day ended.
enum ConfirmDayResult { confirmed, notDone, unknown }

/// One day's result and the words that say it.
@immutable
final class ConfirmDayOutcome {
  const ConfirmDayOutcome(this.result, this.words);

  final ConfirmDayResult result;
  final String words;
}

enum ConfirmDaysPhase { picking, running, results }

/// The words of Confirm worked days (plan 4d-2, Task 5; mockup screens 2B,
/// "Bulk results" and "Bulk confirmation window").
abstract final class ConfirmDaysWords {
  static const title = 'Confirm worked days';

  static String days(int n) => n == 1 ? '1 day' : '$n days';

  static String confirmLabel(int n) => 'Confirm ${days(n)}';
  static String retryLabel(int n) => 'Retry ${days(n)}';
  static const check = 'Reload and check';

  static String picking(int n) =>
      'Confirm worked days: untick any day you did not work as planned, '
      'then press ${confirmLabel(n)}.';
  static const intro =
      'Tick the days you worked as planned. Each day is confirmed on its '
      'own: its pay becomes final, and a mistake is put right with '
      'Correct… or Void….';
  static String changed(LocalDate date) =>
      '${eraBoxDate(date)} is changed from its plan. It is confirmed as '
      'changed.';
  static String extra(LocalDate date) =>
      '${eraBoxDate(date)} is an extra shift. It is confirmed as one.';
  static String leave(LocalDate date, LeaveType type) =>
      '${eraBoxDate(date)} is '
      '${type == LeaveType.sick ? 'sick leave' : 'vacation'}. It is '
      'confirmed as a leave day.';
  static String withoutAgreement(int n, LocalDate first, LocalDate last) =>
      n == 1
      ? "1 day, ${eraBoxDate(first)}, can't be confirmed yet."
      : "$n days, ${eraBoxDate(first)} to ${eraBoxDate(last)}, can't be "
            'confirmed yet.';
  static String windowMessage(
    int n,
    LocalDate first,
    LocalDate last,
    BasisTotal pay,
  ) => n == 1
      ? 'Confirm 1 day, ${eraBoxDate(first)}? Its pay, ${pay.words}, '
            'becomes final.'
      : 'Confirm $n days, ${eraBoxDate(first)} to ${eraBoxDate(last)}? '
            'Their pay, ${pay.words}, becomes final. Each day is '
            'confirmed on its own; if one fails, the others still count.';

  static const confirmed = 'Confirmed';
  static const already = 'Confirmed already, elsewhere';
  static const noAgreement = 'Not done: no pay agreement covers it';
  static const notPlanned = 'Not done: it is no longer a planned day';
  static const unavailable = 'Not done: storage unavailable';
  static const unknown = 'May have gone through: Reload and check';
  static const checkedNotDone = 'Not done: it was not confirmed';

  static String summary(int done, int total) => switch (done) {
    0 => '0 of ${days(total)} confirmed.',
    1 => '1 of ${days(total)} confirmed. Its pay is final.',
    _ => '$done of ${days(total)} confirmed. Their pay is final.',
  };
  static String notKnown(List<LocalDate> dates) =>
      '${dates.map(eraBoxDate).join(', ')} '
      '${dates.length == 1 ? 'is' : 'are'} not known: Reload and check.';
  static String notDone(List<LocalDate> dates) =>
      '${dates.map(eraBoxDate).join(', ')} '
      '${dates.length == 1 ? 'was' : 'were'} not done.';
  static String allDone(int n) =>
      'Confirmed ${days(n)}. Their pay is final; Correct… or Void… changes '
      'a day.';
  static const discardTicks = 'Discard your ticks? Nothing is confirmed.';
  static String closeLeft(int done, int left) =>
      '${days(done)} ${done == 1 ? 'is' : 'are'} confirmed and stay '
      'confirmed; $left ${left == 1 ? 'was' : 'were'} not and stay to '
      'confirm. Close the results?';
  static const noDays = 'No past day waits to be confirmed.';
  static const extendHint =
      'Extend pay agreement… on their group row widens the agreement to '
      'them.';
}

/// Confirm worked days (plan 4d-2, owner pick 2B; umbrella 4.4, 9): the
/// days ticked on the To confirm sheet, confirmed one by one after a
/// single confirmation window, each day's result kept until the panel
/// closes. A day known to be confirmed is never sent again; a day whose
/// result is not known blocks Retry until Reload and check reads it back.
final class ConfirmDaysAction extends ChangeNotifier
    implements LeaveParticipant {
  ConfirmDaysAction({
    required this.employmentId,
    required List<ConfirmDayChoice> days,
    required this._confirm,
    required this._confirmedDates,
  }) : days = _oldestFirst(days) {
    _eligible.addAll([
      for (final day in this.days)
        if (day.eligible) day.date,
    ]);
    _ticked.addAll(_eligible);
  }

  static List<ConfirmDayChoice> _oldestFirst(List<ConfirmDayChoice> days) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(sorted);
  }

  final EmploymentId employmentId;

  /// Every day listed, oldest first.
  final List<ConfirmDayChoice> days;
  final Future<MutationOutcome<Object?>> Function(EmploymentId, LocalDate)
  _confirm;
  final Future<Set<LocalDate>> Function() _confirmedDates;

  final _ticked = <LocalDate>{};

  /// The days an agreement covers: those listed so at the start, and any
  /// an Extend pay agreement… covered since.
  final _eligible = <LocalDate>{};
  final _results = <LocalDate, ConfirmDayOutcome>{};
  ConfirmDaysPhase _phase = ConfirmDaysPhase.picking;
  bool _busy = false;
  bool _unresolved = false;
  bool _disposed = false;

  Set<LocalDate> get ticked => Set.unmodifiable(_ticked);
  Map<LocalDate, ConfirmDayOutcome> get results => Map.unmodifiable(_results);
  ConfirmDaysPhase get phase => _phase;

  /// A confirmation or a check is running.
  bool get busy => _busy;

  /// A Reload and check could not tell whether a day went through.
  bool get unresolved => _unresolved;

  ConfirmDayChoice? _choice(LocalDate date) =>
      days.where((day) => day.date == date).firstOrNull;

  /// Whether an agreement covers [date], so it may be confirmed.
  bool isEligible(LocalDate date) => _eligible.contains(date);

  /// The listed days an agreement covers now (the sheet's live rows): a
  /// day covered since the panel opened becomes tickable, and while the
  /// days are still being picked it is ticked, as it would have been.
  void refreshEligible(Set<LocalDate> covered) {
    var changed = false;
    for (final day in days) {
      if (_eligible.contains(day.date) || !covered.contains(day.date)) {
        continue;
      }
      _eligible.add(day.date);
      if (_phase == ConfirmDaysPhase.picking) _ticked.add(day.date);
      changed = true;
    }
    if (changed) _notify();
  }

  /// Whether [date] may be ticked: an agreement covers it, and it is not
  /// confirmed or waiting on Reload and check.
  bool canTick(LocalDate date) =>
      _eligible.contains(date) &&
      _choice(date) != null &&
      _results[date]?.result != ConfirmDayResult.confirmed &&
      _results[date]?.result != ConfirmDayResult.unknown;

  void toggle(LocalDate date) {
    if (_busy || !canTick(date)) return;
    if (!_ticked.remove(date)) _ticked.add(date);
    _notify();
  }

  /// The ticked days still to send, oldest first.
  List<ConfirmDayChoice> get _toSend => [
    for (final day in days)
      if (_ticked.contains(day.date) && canTick(day.date)) day,
  ];

  int get tickedPaidSeconds =>
      _toSend.fold(0, (sum, day) => sum + day.paidSeconds);

  /// The ticked days' estimated pay, per basis.
  BasisTotal get tickedPay =>
      BasisTotal([for (final day in _toSend) (day.pay, day.basis)]);

  /// Ticked days not confirmed: not sent yet, not done or not known.
  int get left => [
    for (final date in _ticked)
      if (_results[date]?.result != ConfirmDayResult.confirmed) date,
  ].length;

  bool get hasUnknown =>
      _results.values.any((value) => value.result == ConfirmDayResult.unknown);

  /// Every day sent is confirmed and none is left.
  bool get allDone => _results.isNotEmpty && left == 0 && !hasUnknown;

  int get confirmedCount => _results.values
      .where((value) => value.result == ConfirmDayResult.confirmed)
      .length;

  /// The panel's primary key (plan 4d-2, call 8).
  String get primaryLabel => switch (_phase) {
    ConfirmDaysPhase.picking => ConfirmDaysWords.confirmLabel(_toSend.length),
    _ when hasUnknown => ConfirmDaysWords.check,
    _ => ConfirmDaysWords.retryLabel(_toSend.length),
  };

  /// Asks once in the bulk window, then confirms each ticked day still to
  /// send, oldest first, one at a time. Returns false when nothing could
  /// be sent or the owner cancelled.
  Future<bool> run(Confirm confirm) async {
    final sending = _toSend;
    if (_busy || hasUnknown || sending.isEmpty) return false;
    final answer = await confirm(
      ConfirmRequest(
        title: ConfirmDaysWords.title,
        message: ConfirmDaysWords.windowMessage(
          sending.length,
          sending.first.date,
          sending.last.date,
          tickedPay,
        ),
        proceed: ConfirmDaysWords.confirmLabel(sending.length),
      ),
    );
    if (answer != ConfirmAnswer.proceed || _disposed) return false;
    _busy = true;
    _phase = ConfirmDaysPhase.running;
    _notify();
    for (final day in sending) {
      ConfirmDayOutcome outcome;
      try {
        outcome = _outcomeOf(await _confirm(employmentId, day.date));
      } on Object {
        // Whether it was written is not known.
        outcome = const ConfirmDayOutcome(
          ConfirmDayResult.unknown,
          ConfirmDaysWords.unknown,
        );
      }
      _results[day.date] = outcome;
      if (outcome.result == ConfirmDayResult.confirmed) {
        _ticked.remove(day.date);
      }
      _notify();
    }
    _busy = false;
    _phase = ConfirmDaysPhase.results;
    _notify();
    return true;
  }

  static ConfirmDayOutcome _outcomeOf(MutationOutcome<Object?> outcome) =>
      switch (outcome) {
        Committed() => const ConfirmDayOutcome(
          ConfirmDayResult.confirmed,
          ConfirmDaysWords.confirmed,
        ),
        // Confirmed already: by another window, or before the sheet knew.
        Stale() => const ConfirmDayOutcome(
          ConfirmDayResult.confirmed,
          ConfirmDaysWords.already,
        ),
        Invalid(:final fields) when fields.containsKey('agreement') =>
          const ConfirmDayOutcome(
            ConfirmDayResult.notDone,
            ConfirmDaysWords.noAgreement,
          ),
        Invalid() || Missing() => const ConfirmDayOutcome(
          ConfirmDayResult.notDone,
          ConfirmDaysWords.notPlanned,
        ),
        Unavailable() => const ConfirmDayOutcome(
          ConfirmDayResult.notDone,
          ConfirmDaysWords.unavailable,
        ),
        Uncertain() => const ConfirmDayOutcome(
          ConfirmDayResult.unknown,
          ConfirmDaysWords.unknown,
        ),
      };

  /// Reload and check (umbrella 9): reads which days are confirmed now. A
  /// day not known becomes confirmed or not done; when the read fails it
  /// stays not known and [unresolved] says so.
  Future<void> check() async {
    if (_busy || !hasUnknown) return;
    _busy = true;
    _notify();
    try {
      final confirmed = await _confirmedDates();
      for (final MapEntry<LocalDate, ConfirmDayOutcome>(key: date, :value) in [
        ..._results.entries,
      ]) {
        if (value.result != ConfirmDayResult.unknown) continue;
        if (confirmed.contains(date)) {
          _results[date] = const ConfirmDayOutcome(
            ConfirmDayResult.confirmed,
            ConfirmDaysWords.confirmed,
          );
          _ticked.remove(date);
        } else {
          _results[date] = const ConfirmDayOutcome(
            ConfirmDayResult.notDone,
            ConfirmDaysWords.checkedNotDone,
          );
        }
      }
      _unresolved = false;
    } on Object {
      _unresolved = true;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (_busy) return LeaveDecision.stay;
    if (hasUnknown) {
      return kind == LeaveKind.quit
          ? leaveUncertain(confirm, unresolved: _unresolved, check: check)
          : LeaveDecision.stay;
    }
    if (_phase == ConfirmDaysPhase.picking) {
      if (setEquals(_ticked, _eligible)) return LeaveDecision.proceed;
      final answer = await confirm(
        ConfirmRequest(
          title: ConfirmDaysWords.title,
          message: ConfirmDaysWords.discardTicks,
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
    if (left == 0) return LeaveDecision.proceed;
    final answer = await confirm(
      ConfirmRequest(
        title: ConfirmDaysWords.title,
        message: ConfirmDaysWords.closeLeft(confirmedCount, left),
        proceed: kind == LeaveKind.quit ? 'Quit' : 'Close',
        cancel: 'Keep open',
        warning: false,
      ),
    );
    return answer == ConfirmAnswer.proceed
        ? LeaveDecision.proceed
        : LeaveDecision.stay;
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
