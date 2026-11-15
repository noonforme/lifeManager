import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../edit_session/leave_coordinator.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/agreement_fields.dart';
import '../work_edit/work_records.dart';
import 'agreement_action.dart';
import 'agreement_commands.dart';
import 'work_location.dart';

/// What the Agreements sheet's status line says when nothing else does.
abstract final class AgreementsNotices {
  static const ready = 'Ready.';
  static const loading = 'Loading pay agreements…';
  static const unreadable =
      'Pay agreements could not be read from local storage. Try again.';
  static const empty =
      'No pay agreement yet. Add pay agreement… sets up the first one.';
  static const newAgreement =
      'New pay agreement: enter when it starts and its hourly rate, then '
      'Save.';
  static const opening = 'Opening the agreement…';
  static const gone = 'This pay agreement no longer exists.';
  static const ended = 'Agreement ended.';
  static String changed(PayAgreement value) =>
      'Terms changed: version ${value.version} starts on '
      '${value.effectiveStart}.';
}

/// Why an agreement command does not apply, for its greyed key and menu
/// row (spec 4.9).
abstract final class AgreementsCommandWords {
  static const selectFirst = 'Select a stored pay agreement first.';
  static const undoDropsNew = 'Undo drops a new agreement.';
  static const actionOpen =
      'Finish or cancel the action in the property column first.';
  static const busy = 'Wait for the current command to finish.';
  static const changeNeedsDays =
      'It has no day after its start to change from.';
  static const inUse =
      'Finished shifts or confirmed leave use it. End agreement… or Change '
      'terms from… instead.';
}

/// The row id of an agreement being added.
const newAgreementId = 'new';

/// The new shell's Agreements sheet for one employment (spec 4.2, 4.9):
/// every version of its pay agreements with what each paid, the selected
/// version, and its edit through the existing `AgreementAdapter` (a
/// correction with the repricing guard once it is in use). Every change of
/// selection goes through [coordinator], so a pending edit is saved,
/// discarded or kept first; one session exists at a time. It holds no
/// widgets: `AgreementsSheetPart` renders it in the Work shell.
final class AgreementsSheetController extends ChangeNotifier {
  AgreementsSheetController({
    required this.work,
    required this.reads,
    required this.employmentId,
    required this.today,
    required this._confirm,
    required this.coordinator,
  });

  final ProductionWorkProviders work;
  final WorkReads reads;
  final EmploymentId employmentId;
  final LocalDate today;
  final Confirm _confirm;

  /// Guards every change of selection, shared with the whole shell.
  final LeaveCoordinator coordinator;

  List<AgreementRow> _rows = const [];
  bool _loaded = false;
  bool _failed = false;
  StreamSubscription<List<AgreementRow>>? _feed;
  final _ready = Completer<void>();

  String? _selectedId;
  AgreementSession? _session;
  AgreementAction? _action;
  String? _notice;
  bool _disposed = false;

  /// A command that runs outside the session; closing waits for it.
  Future<void>? _command;

  /// Counts openings: a read that finishes after a later one is dropped.
  int _opening = 0;

  /// The versions by start, with what each paid.
  List<AgreementRow> get rows => _rows;
  bool get loaded => _loaded;

  /// Whether the versions could not be read; [rows] are the last read.
  bool get failed => _failed;

  /// Completes once the rows are first read, the read fails, or the sheet
  /// is disposed.
  Future<void> get ready => _ready.future;

  /// The selected version's id, [newAgreementId] while one is added.
  String? get selectedId => _selectedId;

  /// The selected stored version as listed; null for none or the new one.
  AgreementRow? get selectedRow =>
      _rows.where((row) => row.agreement.id.value == _selectedId).firstOrNull;

  /// The selected version's edit.
  AgreementSession? get session => _session;

  /// The open Change terms or End agreement panel; while it is open the
  /// selected version has no edit.
  AgreementAction? get action => _action;

  /// Why a command on the selected version does not apply: none
  /// selected, a panel open, a command running; null when it does.
  String? get _commandBlocked {
    if (_action != null) return AgreementsCommandWords.actionOpen;
    if (_command != null || (_session?.frozen ?? false)) {
      return AgreementsCommandWords.busy;
    }
    return selectedRow == null ? AgreementsCommandWords.selectFirst : null;
  }

  /// Why Change terms from… does not apply; null when it does.
  String? get changeBlocked {
    if (_commandBlocked case final reason?) return reason;
    final value = selectedRow!.agreement;
    return value.effectiveEnd == value.effectiveStart
        ? AgreementsCommandWords.changeNeedsDays
        : null;
  }

  /// Why End agreement… does not apply; null when it does.
  String? get endBlocked => _commandBlocked;

  /// Why Remove agreement… does not apply; null when it does. A new
  /// version is dropped by Undo instead.
  String? get removeBlocked {
    if (_session?.isNew ?? false) return AgreementsCommandWords.undoDropsNew;
    if (_commandBlocked case final reason?) return reason;
    return selectedRow!.inUse ? AgreementsCommandWords.inUse : null;
  }

  /// What the last change of selection or command found.
  String? get notice => _notice;

  /// The place this sheet shows: the stored version selected, or none.
  WorkLocation get place => WorkLocation.agreements(
    employmentId,
    // An open Change terms or End panel holds its version.
    agreement: _session?.baseline?.value.id ?? _action?.row.agreement.id,
  );

  /// Starts reading the versions.
  void start() {
    _feed = reads
        .watchAgreements(employmentId)
        .listen(
          (rows) {
            _rows = rows;
            _loaded = true;
            _failed = false;
            _markReady();
            _notify();
          },
          onError: (Object error, StackTrace stack) {
            _failed = true;
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'agreements sheet',
              ),
            );
            _markReady();
            _notify();
          },
        );
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Shows the version [id], or none, without asking the current edit:
  /// the shell has let it go already.
  Future<void> show(AgreementId? id) async {
    if (_disposed) return;
    final ticket = ++_opening;
    if (id == null) {
      _replace(null, null);
      _notify();
      return;
    }
    _replace(id.value, null);
    _notice = AgreementsNotices.opening;
    _notify();
    final AgreementRecord? record;
    try {
      record = await reads.agreement(employmentId, id);
    } on Object {
      if (_disposed || ticket != _opening) return;
      _replace(null, null);
      _notice = AgreementsNotices.unreadable;
      _notify();
      return;
    }
    if (_disposed || ticket != _opening) return;
    if (record == null) {
      _replace(null, null);
      _notice = AgreementsNotices.gone;
    } else {
      _replace(id.value, _sessionOf(record));
    }
    _notify();
  }

  /// Selects the version [id] once the current edit lets go.
  Future<bool> select(AgreementId id) async {
    if (id.value == _selectedId && _session != null) return true;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    await show(id);
    return true;
  }

  /// Add pay agreement… (spec 4.3): a new version, selected, its terms
  /// those of the latest one, from the day after it ends. Saving it is
  /// its first write.
  Future<bool> addAgreement() async {
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    ++_opening;
    _replace(newAgreementId, _sessionOf(null));
    _notify();
    return true;
  }

  /// Save (spec 4.2). A new version, once stored, stays selected under its
  /// id.
  Future<SaveResult?> save() async {
    final session = _session;
    if (session == null) return null;
    final result = await session.save(_confirm);
    if (_disposed || !identical(session, _session)) return result;
    if (session.baseline case final saved?) {
      _selectedId = saved.value.id.value;
    }
    _notify();
    return result;
  }

  /// Undo (spec 4.2, 4.3): an untouched or discarded new version leaves.
  Future<SaveResult?> undo() async {
    final session = _session;
    if (session == null) return null;
    final result = await session.undo(_confirm);
    if (_disposed || !identical(session, _session)) return result;
    if (session.isNew &&
        (result == SaveResult.reverted || result == SaveResult.clean)) {
      _replace(null, null);
    }
    _notify();
    return result;
  }

  /// Reload record, or Reload and check after an uncertain save (spec 9).
  Future<void> reload() async {
    final session = _session;
    if (session == null) return;
    if (session.phase == EditPhase.uncertain) {
      await session.check();
    } else {
      await session.reload();
    }
    if (_disposed || !identical(session, _session)) return;
    if (session.baseline case final saved?) {
      _selectedId = saved.value.id.value;
    }
    _notify();
  }

  /// Discard and return to sheet (spec 9): the open version no longer
  /// exists, so its pending values are dropped and none is selected.
  Future<void> discardAndReturn() async {
    if (!(_session?.gone ?? false) || _disposed) return;
    ++_opening;
    _replace(null, null);
    _notify();
  }

  /// Takes [value] for [field] of row [rowId] into the selected version's
  /// pending terms; returns the problem that keeps it in its editor.
  String? editField(String rowId, String field, Object? value) {
    final session = _session;
    if (session == null || rowId != _selectedId) {
      return AgreementProblems.notEditable;
    }
    final result = withAgreementField(session.draft.terms, field, value);
    if (result.problem case final problem?) return problem;
    return session.edit(AgreementValues(result.terms!), field: field);
  }

  /// Opens the [kind] panel on the selected version (spec 4.4). A pending
  /// edit is resolved first, as for leaving the record; the panel then
  /// replaces the edit, on the version as stored now. Returns whether it
  /// opened.
  Future<bool> openAction(AgreementActionKind kind) async {
    final blocked = switch (kind) {
      AgreementActionKind.changeTerms => changeBlocked,
      AgreementActionKind.end => endBlocked,
    };
    final selected = selectedRow;
    if (blocked != null || selected == null) return false;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final List<AgreementRow> fresh;
    try {
      fresh = await reads.agreementRows(employmentId);
    } on Object {
      if (ticket == _opening && !_disposed) {
        _notice = AgreementsNotices.unreadable;
        _notify();
      }
      return false;
    }
    if (_disposed || ticket != _opening) return false;
    final row = fresh
        .where((value) => value.agreement.id == selected.agreement.id)
        .firstOrNull;
    if (row == null) {
      await show(null);
      _notice = AgreementsNotices.gone;
      _notify();
      return false;
    }
    _replace(row.agreement.id.value, null);
    final action = _action = AgreementAction(
      kind: kind,
      row: row,
      service: work.agreement,
      reads: reads,
      clock: work.clock,
      today: today,
      onCheck: submitAction,
    );
    coordinator.add(action);
    action.addListener(_notify);
    _notify();
    return true;
  }

  /// The open panel's primary key: runs its command, or checks one whose
  /// result was not known. Once it went through, the panel closes and the
  /// version it produced is selected: the new one, or the one ended.
  Future<void> submitAction() => tracked(() async {
    final action = _action;
    if (action == null) return;
    final produced = await action.submit();
    if (produced == null || !identical(action, _action) || _disposed) return;
    _closeAction();
    await show(produced.id);
    _notice = switch (action.kind) {
      AgreementActionKind.changeTerms => AgreementsNotices.changed(produced),
      AgreementActionKind.end => AgreementsNotices.ended,
    };
    _notify();
  });

  /// The panel's Cancel: once it lets go (input entered asks first), the
  /// version opens again as it is.
  Future<void> cancelAction() async {
    final action = _action;
    if (action == null) return;
    if (await action.leave(_confirm) == LeaveDecision.stay) return;
    if (!identical(action, _action) || _disposed) return;
    final id = action.row.agreement.id;
    _closeAction();
    await show(id);
  }

  void _closeAction() {
    final action = _action;
    if (action == null) return;
    action.removeListener(_notify);
    coordinator.remove(action);
    action.dispose();
    _action = null;
  }

  /// Remove agreement… (spec 4.3, 4.7): once a pending edit is resolved,
  /// asks, then deletes the selected unused version through
  /// `AgreementService.deleteAgreement` and selects none. A result that is
  /// not known is settled at once by reading the versions again.
  Future<void> remove() => tracked(() async {
    if (removeBlocked != null) return;
    final id = selectedRow!.agreement.id;
    if (!await coordinator.navigate(() {}) || _disposed) return;
    // Letting go may have saved a pending edit: remove the version as it
    // is stored now, with its revision.
    final AgreementRecord? fresh;
    try {
      fresh = await reads.agreement(employmentId, id);
    } on Object {
      _notice = AgreementCommandWords.unavailable;
      _notify();
      return;
    }
    if (_disposed) return;
    if (fresh == null) {
      await show(null);
      _notice = AgreementsNotices.gone;
      _notify();
      return;
    }
    final value = fresh.value;
    if (value.usedByFinalizedShift) {
      _notice = AgreementCommandWords.inUse;
      _notify();
      return;
    }
    if (await _confirm(removeAgreementRequest(value)) !=
            ConfirmAnswer.proceed ||
        _disposed) {
      return;
    }
    final command = DeleteAgreementCommand(
      agreementId: value.id,
      employmentId: employmentId,
      expectedRevision: value.revision,
    );
    String notice;
    var gone = false;
    try {
      final outcome = await work.agreement.deleteAgreement(command);
      gone = outcome is Committed;
      notice = switch (outcome) {
        Committed() => AgreementCommandWords.removed,
        Invalid() => AgreementCommandWords.inUse,
        Stale() => AgreementCommandWords.stale,
        Missing() => AgreementCommandWords.missing,
        Unavailable() => AgreementCommandWords.unavailable,
        Uncertain() => await _settleRemoval(value.id),
      };
    } on Object {
      notice = await _settleRemoval(value.id);
    }
    if (_disposed) return;
    if (gone || notice == AgreementCommandWords.removed) {
      await show(null);
    } else {
      await show(value.id);
    }
    _notice = notice;
    _notify();
  });

  /// Whether a removal whose answer was lost went through.
  Future<String> _settleRemoval(AgreementId id) async {
    try {
      final still = await reads.agreement(employmentId, id);
      return still == null
          ? AgreementCommandWords.removed
          : AgreementCommandWords.notRemoved;
    } on Object {
      return AgreementCommandWords.removeUnknown;
    }
  }

  /// Waits for a command that runs, for the window's close (spec 4.8).
  Future<void> settled() async {
    for (var running = _command; running != null; running = _command) {
      await running;
    }
  }

  /// Runs [body] as the sheet's one command; closing waits for it.
  Future<void> tracked(Future<void> Function() body) async {
    final running = body();
    _command = running;
    try {
      await running;
    } finally {
      if (identical(_command, running)) _command = null;
    }
  }

  /// What a new version starts with: the latest one's terms from the day
  /// after it ends, else this month with no rate.
  AgreementTerms _defaults() {
    final latest = _rows.lastOrNull?.agreement;
    if (latest == null) {
      return AgreementTerms(
        effectiveStart: today.firstOfMonth,
        effectiveEnd: null,
        hourlyRateMicroEur: 0,
        basis: const GrossBasis(),
        label: null,
        note: null,
      );
    }
    return AgreementTerms.of(
      latest,
      effectiveStart: latest.effectiveEnd?.addDays(1) ?? today.firstOfMonth,
      effectiveEnd: () => null,
    );
  }

  AgreementSession _sessionOf(AgreementRecord? record) => AgreementSession(
    adapter: AgreementAdapter(
      employmentId: employmentId,
      defaults: _defaults(),
      service: work.agreement,
      preview: work.workRepository,
      reads: reads,
      clock: work.clock,
    ),
    baseline: record,
    onCheck: reload,
  );

  /// Selects row [rowId] with [session] as its edit.
  void _replace(String? rowId, AgreementSession? session) {
    _close();
    _notice = null;
    _selectedId = rowId;
    if (session != null) {
      coordinator.add(session);
      session.addListener(_notify);
      _session = session;
    }
  }

  void _close() {
    _closeAction();
    final session = _session;
    if (session == null) return;
    session.removeListener(_notify);
    coordinator.remove(session);
    session.dispose();
    _session = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_opening;
    unawaited(_feed?.cancel());
    _markReady();
    _close();
    super.dispose();
  }
}
