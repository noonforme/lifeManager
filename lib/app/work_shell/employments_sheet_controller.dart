import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/employment.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave_coordinator.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/agreement_fields.dart';
import '../work_edit/employment_edit.dart';
import '../work_edit/work_records.dart';
import 'work_location.dart';

export '../work_edit/agreement_fields.dart' show AgreementField;

/// An employment's edit session.
typedef EmploymentSession =
    RecordEditSession<EmploymentRecord, EmploymentValues>;

/// What the Employments sheet says (spec 4.9).
abstract final class EmploymentsNotices {
  static const ready = 'Ready.';
  static const empty =
      'No employment yet. Add employment… starts the first one.';
  static const onlyEnded =
      'Every employment is archived. Add employment… starts another.';
  static const gone = 'This employment no longer exists.';
  static const opening = 'Opening the employment…';
  static const noAgreement =
      'No pay agreement yet: shifts show no pay. Set up pay agreement… '
      'adds one.';
  static const newEmployment =
      'New employment: enter its name, then Save. Nothing is stored before '
      'that.';
  static const newAgreement =
      'New pay agreement: enter when it starts and its hourly rate, then '
      'Save.';
  static const agreementSaved =
      'Pay agreement saved. Agreements holds it; New schedule… comes next.';
}

/// Why an employment command does not apply, and what it did (spec 4.9).
abstract final class EmploymentsCommandWords {
  static const selectFirst = 'Select a saved employment first.';
  static const archived = 'It is archived already.';
  static const hasHistory = 'Work is recorded for it; archive it instead.';
  static const busy = 'Wait for the current command to finish.';
  static const archivedDone =
      'Employment archived. It is under Ended employments.';
  static const deleted = 'Employment deleted.';
  static const stale =
      'This employment changed meanwhile; nothing was done. Try again.';
  static const missing = 'This employment no longer exists.';
  static const unavailable =
      'Not done: local storage is unavailable. Try again.';
  static const notArchived = 'It was not archived. Try again when ready.';
  static const notDeleted = 'It was not deleted. Try again when ready.';
  static const unknown =
      'It is not known whether this went through; the employment is shown '
      'as it is now.';
}

/// Archive employment… (spec 4.7): it cannot be taken back in LifeOS.
ConfirmRequest archiveEmploymentRequest(
  Employment employment, {
  required int daysToConfirm,
}) => ConfirmRequest(
  title: 'Archive employment',
  message: [
    'Archive ${employment.name}? It moves to Ended employments and becomes '
        'read-only; its records stay. LifeOS cannot make it active again.',
    if (daysToConfirm == 1) 'It still has 1 day to confirm.',
    if (daysToConfirm > 1) 'It still has $daysToConfirm days to confirm.',
  ].join(' '),
  proceed: 'Archive',
);

/// Delete employment… (spec 4.7: deleting a record asks first).
ConfirmRequest deleteEmploymentRequest(
  Employment employment, {
  required int agreements,
}) => ConfirmRequest(
  title: 'Delete employment',
  message:
      'Delete ${employment.name}? Nothing is recorded for it'
      '${switch (agreements) {
        0 => '',
        1 => '; its 1 pay agreement goes with it',
        final n => '; its $n pay agreements go with it',
      }}. '
      "This can't be undone.",
  proceed: 'Delete',
);

/// The Work overview's Employments sheet (spec 4.9): every employment, the
/// selected one's properties, and its inline setup: Add employment…, then
/// Set up pay agreement…. One edit exists at a time, the employment's or
/// an agreement's, and every change of it goes through [coordinator]. It
/// holds no widgets: `WorkShell` renders it.
final class EmploymentsSheetController extends ChangeNotifier {
  EmploymentsSheetController({
    required this.work,
    required this.reads,
    required this.today,
    required this.confirm,
    required this.coordinator,
  });

  final ProductionWorkProviders work;
  final WorkReads reads;
  final LocalDate today;
  final Confirm confirm;
  final LeaveCoordinator coordinator;

  EmploymentId? _selected;
  EmploymentSession? _employment;
  AgreementSession? _agreement;
  List<PayAgreement> _agreements = const [];
  String? _notice;
  bool _disposed = false;

  /// Counts openings: a read that finishes after a later one is dropped.
  int _opening = 0;

  /// The selected employment; null on the overview or while a new one is
  /// entered.
  EmploymentId? get selected => _selected;

  /// The employment's edit: the selected one's, or a new one's.
  EmploymentSession? get employment => _employment;

  /// The pay agreement's edit, in the employment's property column.
  AgreementSession? get agreement => _agreement;

  /// The selected employment's pay agreements, by version.
  List<PayAgreement> get agreements => _agreements;

  /// What the last change of selection found.
  String? get notice => _notice;

  /// The session whose Save, Undo and Reload the keys run.
  RecordEditSession<Object?, Object?>? get session =>
      (_agreement ?? _employment) as RecordEditSession<Object?, Object?>?;

  /// The place this sheet shows: the overview or an employment. A new
  /// agreement set up inline has no place of its own (spec 4.5).
  WorkLocation get place => switch (_selected) {
    null => const WorkLocation.overview(),
    final id => WorkLocation.employment(id),
  };

  /// Shows [employment], or none, without asking the current edit: the
  /// shell has let it go already.
  Future<void> show(EmploymentId? employment) async {
    if (_disposed) return;
    final ticket = ++_opening;
    if (employment == null) {
      _replace(null, null);
      _notify();
      return;
    }
    // The last edit is let go and [employment] is the selection while it
    // is read, so choosing the last one again opens it again.
    _replace(employment, null);
    _agreements = const [];
    _notice = EmploymentsNotices.opening;
    _notify();
    final record = await reads.employment(employment);
    if (_disposed || ticket != _opening) return;
    final agreements = await reads.agreementsOf(employment);
    if (_disposed || ticket != _opening) return;
    if (record == null) {
      _replace(null, null);
      _notice = EmploymentsNotices.gone;
      _notify();
      return;
    }
    _agreements = agreements;
    _replace(employment, null, record: record);
    _notice = agreements.isEmpty ? EmploymentsNotices.noAgreement : null;
    _notify();
  }

  /// Whether the current edit let go. A value that reached the session
  /// while it was letting go (typed during the window) is asked about
  /// again rather than dropped (bead 9pk.3.3.7 item 10).
  Future<bool> _letGo() async {
    for (var round = 0; round < 3; round++) {
      if (!await coordinator.navigate(() {}) || _disposed) return false;
      if (!(session?.dirty ?? false)) return true;
    }
    return false;
  }

  /// Selects [employment] once the current edit lets go.
  Future<bool> select(EmploymentId employment) async {
    if (employment == _selected && _agreement == null) return true;
    if (!await _letGo()) return false;
    await show(employment);
    return true;
  }

  /// Add employment… (spec 4.9): a new employment in the property column,
  /// once the current edit lets go. Saving it is its first write.
  Future<bool> addEmployment() async {
    if (!await _letGo()) return false;
    ++_opening;
    _replace(null, null);
    _employment = _join(
      EmploymentSession(adapter: _employmentAdapter(), onCheck: reload),
    );
    _notify();
    return true;
  }

  /// Set up pay agreement… (spec 4.9): a new agreement of the selected
  /// employment in its property column, once the current edit lets go.
  Future<bool> setUpAgreement() async {
    final employment = _selected;
    if (employment == null) return false;
    if (!await _letGo()) return false;
    ++_opening;
    _replace(employment, _agreementSession(employment, null));
    _notify();
    return true;
  }

  /// Back from an agreement to its employment, once the agreement lets go.
  Future<bool> closeAgreement() async {
    final employment = _selected;
    if (employment == null || _agreement == null) return false;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    await show(employment);
    return true;
  }

  /// The selected stored employment, as last read.
  Employment? get _stored =>
      _agreement == null ? _employment?.baseline?.value : null;

  /// Whether a command runs.
  bool _busy = false;

  /// Why Archive employment… does not apply; null when it does.
  String? get archiveBlocked {
    final stored = _stored;
    if (stored == null) return EmploymentsCommandWords.selectFirst;
    if (_busy || (session?.frozen ?? false)) {
      return EmploymentsCommandWords.busy;
    }
    return stored.status == EmploymentStatus.archived
        ? EmploymentsCommandWords.archived
        : null;
  }

  /// Why Delete employment… does not apply, given whether work is
  /// recorded for it ([hasHistory], from the employments' summaries).
  String? deleteBlocked({required bool hasHistory}) {
    if (_stored == null) return EmploymentsCommandWords.selectFirst;
    if (_busy || (session?.frozen ?? false)) {
      return EmploymentsCommandWords.busy;
    }
    return hasHistory ? EmploymentsCommandWords.hasHistory : null;
  }

  /// Archive employment… (spec 4.9): once the edit lets go, asks (naming
  /// its [daysToConfirm]), archives it through
  /// `EmploymentService.archiveEmployment` and shows it read-only.
  Future<void> archive({required int daysToConfirm}) async {
    if (archiveBlocked != null) return;
    final id = _selected!;
    if (!await _letGo()) return;
    final current = (await _read(id))?.value;
    if (_disposed || current == null) return;
    if (await confirm(
              archiveEmploymentRequest(current, daysToConfirm: daysToConfirm),
            ) !=
            ConfirmAnswer.proceed ||
        _disposed) {
      return;
    }
    final notice = await _run(
      () => work.employment.archiveEmployment(
        ArchiveEmploymentCommand(
          employmentId: id,
          expectedRevision: current.revision,
        ),
      ),
      done: EmploymentsCommandWords.archivedDone,
      settle: (now) => now?.value.status == EmploymentStatus.archived,
      notDone: EmploymentsCommandWords.notArchived,
      id: id,
    );
    if (_disposed) return;
    await show(id);
    _notice = notice;
    _notify();
  }

  /// Delete employment… (spec 4.9): once the edit lets go, asks, deletes
  /// it with its agreements through `EmploymentService.deleteEmployment`
  /// and shows the overview. Greyed while work is recorded
  /// ([hasHistory]); the service refuses it then too.
  Future<void> delete({bool hasHistory = false}) async {
    if (deleteBlocked(hasHistory: hasHistory) != null) return;
    final id = _selected!;
    if (!await _letGo()) return;
    final current = (await _read(id))?.value;
    if (_disposed || current == null) return;
    final agreements = _agreements.length;
    if (await confirm(
              deleteEmploymentRequest(current, agreements: agreements),
            ) !=
            ConfirmAnswer.proceed ||
        _disposed) {
      return;
    }
    final notice = await _run(
      () => work.employment.deleteEmployment(
        DeleteEmploymentCommand(
          employmentId: id,
          expectedRevision: current.revision,
        ),
      ),
      done: EmploymentsCommandWords.deleted,
      settle: (now) => now == null,
      notDone: EmploymentsCommandWords.notDeleted,
      id: id,
    );
    if (_disposed) return;
    if (notice == EmploymentsCommandWords.deleted) {
      ++_opening;
      _replace(null, null);
    } else {
      await show(id);
    }
    _notice = notice;
    _notify();
  }

  Future<EmploymentRecord?> _read(EmploymentId id) async {
    try {
      return await reads.employment(id);
    } on Object {
      _notice = EmploymentsCommandWords.unavailable;
      _notify();
      return null;
    }
  }

  /// Runs [command]; returns the status line's words for its outcome. A
  /// result that is not known is settled at once by reading the
  /// employment again: [settle] says whether it went through.
  /// Archive or Delete as it runs: closing waits for it ([settled]).
  Future<String>? _command;

  /// Waits for an Archive or Delete that is running.
  Future<void> settled() async {
    for (var running = _command; running != null; running = _command) {
      await running;
    }
  }

  Future<String> _run(
    Future<MutationOutcome<Employment>> Function() command, {
    required String done,
    required bool Function(EmploymentRecord? now) settle,
    required String notDone,
    required EmploymentId id,
  }) async {
    final running = _command = _send(
      command,
      done: done,
      settle: settle,
      notDone: notDone,
      id: id,
    );
    try {
      return await running;
    } finally {
      if (identical(_command, running)) _command = null;
    }
  }

  Future<String> _send(
    Future<MutationOutcome<Employment>> Function() command, {
    required String done,
    required bool Function(EmploymentRecord? now) settle,
    required String notDone,
    required EmploymentId id,
  }) async {
    _busy = true;
    _notify();
    try {
      final outcome = await command();
      return switch (outcome) {
        Committed() => done,
        Invalid() => EmploymentsCommandWords.hasHistory,
        Stale() => EmploymentsCommandWords.stale,
        Missing() => EmploymentsCommandWords.missing,
        Unavailable() => EmploymentsCommandWords.unavailable,
        Uncertain() => await _settle(settle, done, notDone, id),
      };
    } on Object {
      return _settle(settle, done, notDone, id);
    } finally {
      _busy = false;
    }
  }

  Future<String> _settle(
    bool Function(EmploymentRecord? now) settle,
    String done,
    String notDone,
    EmploymentId id,
  ) async {
    try {
      return settle(await reads.employment(id)) ? done : notDone;
    } on Object {
      return EmploymentsCommandWords.unknown;
    }
  }

  /// Save (spec 4.2). A new employment or agreement, once stored, is
  /// selected under its id.
  Future<SaveResult?> save() async {
    final session = this.session;
    if (session == null) return null;
    final result = await session.save(confirm);
    if (_disposed) return result;
    await _settled(session);
    return result;
  }

  /// Undo (spec 4.2, 4.3): an untouched or discarded new record leaves.
  Future<SaveResult?> undo() async {
    final session = this.session;
    if (session == null) return null;
    final result = await session.undo(confirm);
    if (_disposed) return result;
    if (session.isNew &&
        identical(session, this.session) &&
        (result == SaveResult.reverted || result == SaveResult.clean)) {
      if (identical(session, _agreement)) {
        await show(_selected);
      } else {
        _replace(null, null);
      }
    } else {
      await _settled(session);
    }
    _notify();
    return result;
  }

  /// Reload record, or Reload and check after an uncertain save (spec 9),
  /// from the toolbar or the quit window.
  Future<void> reload() async {
    final session = this.session;
    if (session == null) return;
    if (session.phase == EditPhase.uncertain) {
      await session.check();
    } else {
      await session.reload();
    }
    if (_disposed) return;
    await _settled(session);
  }

  /// Discard and return to sheet (spec 9): the open record no longer
  /// exists, so its pending values are dropped. A gone agreement returns
  /// to its employment, a gone employment to the overview.
  Future<void> discardAndReturn() async {
    final session = this.session;
    if (session == null || !session.gone || _disposed) return;
    if (identical(session, _agreement)) return show(_selected);
    ++_opening;
    _replace(null, null);
    _notify();
  }

  /// Takes [value] for the employment's [field]; returns the problem that
  /// keeps it in its editor.
  String? editEmployment(String field, Object? value) {
    final session = _employment;
    if (session == null) return EmploymentsWords.notEditable;
    if (session.baseline?.value.status == EmploymentStatus.archived) {
      return EmploymentsWords.archivedReadOnly;
    }
    final draft = session.draft;
    final text = '${value ?? ''}';
    final next = switch (field) {
      EmploymentField.name => EmploymentValues(
        name: text,
        legalLabel: draft.legalLabel,
      ),
      EmploymentField.legalLabel => EmploymentValues(
        name: draft.name,
        legalLabel: text.trim().isEmpty ? null : text,
      ),
      _ => null,
    };
    if (next == null) return EmploymentsWords.notEditable;
    return session.edit(next, field: field);
  }

  /// Takes [value] for the agreement's [field]; returns the problem that
  /// keeps it in its editor.
  String? editAgreement(String field, Object? value) {
    final session = _agreement;
    if (session == null) return EmploymentsWords.notEditable;
    final result = withAgreementField(session.draft.terms, field, value);
    if (result.problem case final problem?) return problem;
    return session.edit(AgreementValues(result.terms!), field: field);
  }

  Future<void> _settled(RecordEditSession<Object?, Object?> session) async {
    if (_disposed || !identical(session, this.session)) return;
    if (identical(session, _employment)) {
      if (_employment!.baseline case final saved? when _selected == null) {
        await show(saved.value.id);
        return;
      }
    } else if (_agreement?.baseline != null) {
      // The setup is done (3c-3 decision 3): the employment shows again,
      // and the Agreements sheet holds the agreement from now on.
      await show(_selected);
      if (_disposed) return;
      _notice = EmploymentsNotices.agreementSaved;
    }
    _notify();
  }

  EmploymentAdapter _employmentAdapter() => EmploymentAdapter(
    service: work.employment,
    reads: reads,
    clock: work.clock,
  );

  AgreementSession _agreementSession(
    EmploymentId employment,
    AgreementRecord? record,
  ) => AgreementSession(
    adapter: AgreementAdapter(
      employmentId: employment,
      defaults: AgreementTerms(
        effectiveStart: today.firstOfMonth,
        effectiveEnd: null,
        hourlyRateMicroEur: 0,
        basis: const GrossBasis(),
        label: null,
        note: null,
      ),
      service: work.agreement,
      preview: work.workRepository,
      reads: reads,
      clock: work.clock,
    ),
    baseline: record,
    onCheck: reload,
  );

  /// Selects [employment] with [agreement] as the edit, else the
  /// employment's own edit over [record].
  void _replace(
    EmploymentId? employment,
    AgreementSession? agreement, {
    EmploymentRecord? record,
  }) {
    _close();
    _notice = null;
    _selected = employment;
    if (employment == null) _agreements = const [];
    if (agreement != null) {
      _agreement = _join(agreement);
    } else if (record != null) {
      _employment = _join(
        EmploymentSession(
          adapter: _employmentAdapter(),
          baseline: record,
          onCheck: reload,
        ),
      );
    }
  }

  T _join<T extends RecordEditSession<Object?, Object?>>(T session) {
    coordinator.add(session);
    session.addListener(_notify);
    return session;
  }

  void _close() {
    for (final session in [_employment, _agreement]) {
      if (session == null) continue;
      session.removeListener(_notify);
      coordinator.remove(session);
      session.dispose();
    }
    _employment = null;
    _agreement = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_opening;
    _close();
    super.dispose();
  }
}

/// The employment's field keys.
abstract final class EmploymentField {
  static const name = 'name';
  static const legalLabel = 'legalLabel';
}

/// Words of the Employments sheet's fields.
abstract final class EmploymentsWords {
  static const notEditable = 'This value is not edited here.';
  static const unreadable = 'Employments could not be read';
  static const startRequired = 'Enter the first day it pays.';
  static const archivedReadOnly = 'An archived employment is read-only.';
}
