import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/data/work_history.dart' show scheduleRecordId;
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/schedule.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../edit_session/leave_coordinator.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/schedule_edit.dart';
import '../work_edit/schedule_fields.dart';
import '../work_edit/schedule_preview.dart';
import '../work_edit/work_records.dart';
import 'employments_sheet_controller.dart' show EmploymentsWords;
import 'schedule_commands.dart';
import 'work_location.dart';

/// What the Schedules sheet's status line says when nothing else does.
abstract final class SchedulesNotices {
  static const ready = 'Ready.';
  static const loading = 'Loading schedules…';
  static const unreadable =
      'Schedules could not be read from local storage. Try again.';
  static const empty =
      'No schedule yet. New schedule… describes your rotation once.';
  static const newSchedule =
      'New schedule: name it, add shift types and the cycle. Save stores all '
      'of it at once.';
  static const opening = 'Opening the schedule…';
  static const gone = 'This schedule no longer exists.';
  static const deleted = 'Schedule deleted.';
  static const changeNothing =
      'Nothing is changed yet: change the From date, the cycle or a shift '
      'type, then press Change schedule.';
  static String changed(WorkSchedule value) =>
      'Schedule changed: version ${value.version} starts on '
      '${value.inUseFrom}.';
}

/// Why a schedule command or edit does not apply, for its greyed key, menu
/// row or refused cell (spec 4.9).
abstract final class SchedulesCommandWords {
  static const selectFirst = 'Select a stored schedule first.';
  static const busy = 'Wait for the current command to finish.';
  static const used =
      'Confirmed days use this version. Change schedule from… starts a new '
      'one.';
  static const earlier =
      'An earlier version is read-only; change the latest one.';
  static const notUsed = 'No confirmed day uses it: edit it and Save.';
  static const changeOpen = 'Finish or cancel Change schedule first.';
  static const deleteUsed =
      'Confirmed days use this schedule. Change it from a date instead.';
  static const deleteNew = 'Undo drops a new schedule.';
  static const discardChange =
      'Discard the new version you entered? The schedule is not changed.';
}

/// The row id of a schedule being added.
const newScheduleId = 'new';

/// The row id of block [index] of the cycle.
String blockRowId(int index) => 'block:$index';

/// The new shell's Schedules sheet for one employment (spec 4.2, 4.9):
/// every version of its schedules with the days confirmed from each, the
/// selected version, and its one edit session holding the fields, shift
/// types, breaks and cycle together. Only the latest version no confirmed
/// day uses is edited in place. Every change of selection goes through
/// [coordinator]. It holds no widgets: `SchedulesSheetPart` renders it.
final class SchedulesSheetController extends ChangeNotifier {
  SchedulesSheetController({
    required this.work,
    required this.reads,
    required this.employmentId,
    required this.today,
    required this._confirm,
    required this.coordinator,
    this._archived = false,
  });

  final ProductionWorkProviders work;
  final WorkReads reads;
  final EmploymentId employmentId;
  final LocalDate today;
  final Confirm _confirm;

  /// Guards every change of selection, shared with the whole shell.
  final LeaveCoordinator coordinator;

  /// The employment is archived: everything is read-only. The shell
  /// keeps it current as the employment changes.
  bool get archived => _archived;
  bool _archived;
  set archived(bool value) {
    if (value == _archived) return;
    _archived = value;
    _notify();
  }

  List<ScheduleRow> _rows = const [];
  bool _loaded = false;
  bool _failed = false;
  StreamSubscription<List<ScheduleRow>>? _feed;
  final _ready = Completer<void>();

  String? _selectedId;
  ScheduleSession? _session;

  /// While Change schedule from… is open: what holds the owner instead of
  /// the session, so leaving asks to discard and never saves.
  _ChangeGuard? _guard;
  bool _showingTypes = false;
  ShiftTypeId? _selectedType;
  String? _selectedBlock;
  String? _selectedBreak;
  PlanInputs? _planInputs;
  bool _planFailed = false;
  StreamSubscription<PlanInputs>? _plan;
  LocalDate? _previewFirst;
  String? _notice;
  bool _disposed = false;

  /// A command that runs outside the session; closing waits for it.
  Future<void>? _command;

  /// Counts openings: a read that finishes after a later one is dropped.
  int _opening = 0;

  /// The versions by in-use-from, with the days confirmed from each.
  List<ScheduleRow> get rows => _rows;
  bool get loaded => _loaded;

  /// Whether the versions could not be read; [rows] are the last read.
  bool get failed => _failed;

  /// Completes once the rows are first read, the read fails, or the sheet
  /// is disposed.
  Future<void> get ready => _ready.future;

  /// The selected version's row id, [newScheduleId] while one is added.
  String? get selectedId => _selectedId;

  /// The selected stored version as listed; null for none or a new one.
  ScheduleRow? get selectedRow =>
      _rows.where((row) => row.rowId == _selectedId).firstOrNull;

  /// The selected version's edit.
  ScheduleSession? get session => _session;

  /// What the last change of selection or command found.
  String? get notice => _notice;

  /// Whether Change schedule from… is open: the session makes the next
  /// version.
  bool get versioning => _guard != null;

  /// Why Change schedule did nothing: its press found nothing changed.
  /// The panel shows it while the session stays clean.
  String? get changeProblem => _changeProblem;
  String? _changeProblem;

  /// Whether the middle grid shows the selected schedule's shift types.
  bool get showingTypes => _showingTypes;

  /// The shift type selected in the types view.
  ShiftTypeId? get selectedType => _selectedType;

  /// The selected row of the Cycle grid (`block:<index>`).
  String? get selectedBlock => _selectedBlock;

  /// The selected row of the Breaks grid (`break:<index>`).
  String? get selectedBreak => _selectedBreak;

  /// The employment's plan inputs for the Preview, once read.
  PlanInputs? get planInputs => _planInputs;

  /// Whether the plan inputs could not be read: the Preview says so.
  bool get planFailed => _planFailed;

  /// The first month the Preview shows.
  LocalDate get previewFirst {
    if (_previewFirst case final first?) return first;
    final session = _session;
    return session == null
        ? today.firstOfMonth
        : previewStart(session.draft, today);
  }

  /// Moves the Preview by [months] months.
  void stepPreview(int months) {
    var first = previewFirst;
    for (var i = 0; i < months.abs(); i++) {
      first = months > 0
          ? first.lastOfMonth.addDays(1)
          : first.addDays(-1).firstOfMonth;
    }
    _previewFirst = first;
    _notify();
  }

  /// Selects row [id] of the Cycle grid.
  void selectBlock(String? id) {
    _selectedBlock = id;
    _notify();
  }

  /// Selects row [id] of the Breaks grid.
  void selectBreak(String? id) {
    _selectedBreak = id;
    _notify();
  }

  /// [rows], and while Change schedule from… is open the pending next
  /// version after the changed one, which shows the end it will get.
  List<ScheduleRow> get displayRows {
    final session = _session;
    final from = session?.draft.versionFrom;
    if (!versioning || session == null || from == null) return _rows;
    final current = session.baseline!.value;
    final until = from.addDays(-1);
    return [
      for (final row in _rows)
        if (row.schedule.id == current.id &&
            row.schedule.version == current.version) ...[
          ScheduleRow(
            schedule: WorkSchedule(
              id: current.id,
              employmentId: current.employmentId,
              name: current.name,
              timezoneId: current.timezoneId,
              version: current.version,
              cycleStart: current.cycleStart,
              inUseFrom: current.inUseFrom,
              inUseUntil:
                  current.inUseUntil != null &&
                      current.inUseUntil!.compareTo(until) < 0
                  ? current.inUseUntil
                  : until,
              shiftTypes: current.shiftTypes,
              blocks: current.blocks,
              createdAtUtc: current.createdAtUtc,
              revision: current.revision,
              usedByConfirmedDay: true,
            ),
            confirmedDays: row.confirmedDays,
            lastConfirmed: row.lastConfirmed,
            latest: false,
          ),
          ScheduleRow(
            schedule: session.draft.asSchedule(
              employmentId: employmentId,
              id: current.id,
              version: current.version + 1,
            ),
            confirmedDays: 0,
            lastConfirmed: null,
            latest: true,
          ),
        ] else
          row,
    ];
  }

  /// Why [value] cannot be the new version's start, by the same rules a
  /// save checks; null when it can (or no Change schedule is open).
  String? versionFromProblem(Object? value) {
    final session = _session;
    if (session == null || !versioning) return null;
    if (value is! LocalDate) return ScheduleProblems.versionFromRequired;
    return session.adapter.validate(
      session.draft.copyWith(versionFrom: () => value),
    )[ScheduleField.versionFrom];
  }

  /// The row id of the pending next version, while versioning.
  String? get pendingVersionId {
    final current = _session?.baseline?.value;
    if (!versioning || current == null) return null;
    return '${current.id.value}@${current.version + 1}';
  }

  /// The place this sheet shows: the stored version selected, or none.
  WorkLocation get place {
    final saved = _session?.baseline?.value;
    return WorkLocation.schedules(
      employmentId,
      schedule: saved?.id,
      version: saved?.version,
    );
  }

  /// Why the selected version's values cannot be changed now; null when
  /// they can.
  String? get editBlocked {
    if (archived) return EmploymentsWords.archivedReadOnly;
    final session = _session;
    if (session == null) return SchedulesCommandWords.selectFirst;
    if (session.isNew || versioning) return null;
    final row = selectedRow;
    if (row != null && !row.latest) return SchedulesCommandWords.earlier;
    if (session.baseline!.value.usedByConfirmedDay) {
      return SchedulesCommandWords.used;
    }
    return null;
  }

  /// Why Change schedule from… does not apply; null when it does.
  String? get changeBlocked {
    if (archived) return EmploymentsWords.archivedReadOnly;
    if (_command != null || (_session?.frozen ?? false)) {
      return SchedulesCommandWords.busy;
    }
    if (versioning) return SchedulesCommandWords.changeOpen;
    final row = selectedRow;
    if (row == null) return SchedulesCommandWords.selectFirst;
    if (!row.latest) return SchedulesCommandWords.earlier;
    return row.used ? null : SchedulesCommandWords.notUsed;
  }

  /// Why Delete schedule… does not apply; null when it does.
  String? get deleteBlocked {
    if (archived) return EmploymentsWords.archivedReadOnly;
    if (_command != null || (_session?.frozen ?? false)) {
      return SchedulesCommandWords.busy;
    }
    if (versioning) return SchedulesCommandWords.changeOpen;
    if (_selectedId == newScheduleId) return SchedulesCommandWords.deleteNew;
    final row = selectedRow;
    if (row == null) return SchedulesCommandWords.selectFirst;
    final used = _rows.any(
      (other) => other.schedule.id == row.schedule.id && other.used,
    );
    return used ? SchedulesCommandWords.deleteUsed : null;
  }

  /// Starts reading the versions.
  void start() {
    _feed = reads
        .watchSchedules(employmentId)
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
                library: 'schedules sheet',
              ),
            );
            _markReady();
            _notify();
          },
        );
    _watchPlan();
  }

  /// Starts reading the plan inputs the Preview prices with; a failure
  /// leaves the Preview without them (it says so).
  void _watchPlan() {
    _plan = work.plans
        .watchInputs(employmentId)
        .listen(
          (inputs) {
            _planInputs = inputs;
            _planFailed = false;
            _notify();
          },
          onError: (Object error, StackTrace stack) {
            _planFailed = true;
            _notify();
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'schedules sheet',
              ),
            );
          },
        );
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Shows version [version] of schedule [id] (its latest when null), or
  /// none, without asking the current edit: the shell has let it go.
  Future<void> show(ScheduleId? id, {int? version}) async {
    if (_disposed) return;
    final ticket = ++_opening;
    if (id == null) {
      _replace(null, null);
      _notify();
      return;
    }
    _replace(null, null);
    _notice = SchedulesNotices.opening;
    _notify();
    final ScheduleRecord? record;
    try {
      record = await reads.schedule(employmentId, id, version: version);
    } on Object {
      if (_disposed || ticket != _opening) return;
      _replace(null, null);
      _notice = SchedulesNotices.unreadable;
      _notify();
      return;
    }
    if (_disposed || ticket != _opening) return;
    if (record == null) {
      _replace(null, null);
      _notice = SchedulesNotices.gone;
    } else {
      _replace(scheduleRecordId(record.value), _sessionOf(record));
    }
    _notify();
  }

  /// Selects the version of row [rowId] once the current edit lets go.
  Future<bool> select(String rowId) async {
    if (rowId == _selectedId && _session != null) return true;
    final at = rowId.lastIndexOf('@');
    final version = at < 0 ? null : int.tryParse(rowId.substring(at + 1));
    if (version == null) return false;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    await show(ScheduleId(rowId.substring(0, at)), version: version);
    return true;
  }

  /// New schedule… (spec 4.3): an empty schedule from today in the current
  /// timezone, selected. Saving it is its first write.
  Future<bool> addSchedule() async {
    if (archived) return false;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    ++_opening;
    _replace(newScheduleId, _sessionOf(null));
    _notify();
    return true;
  }

  /// Save (spec 4.2). A new schedule, once stored, stays selected.
  Future<SaveResult?> save() async {
    final session = _session;
    if (session == null) return null;
    _changeProblem = null;
    final result = await session.save(_confirm);
    if (versioning && result == SaveResult.clean) {
      // A version identical to the one it replaces is no change.
      _changeProblem = SchedulesNotices.changeNothing;
      _notify();
      return result;
    }
    if (_disposed || !identical(session, _session)) return result;
    if (versioning && result == SaveResult.committed) {
      final made = session.baseline!.value;
      await show(made.id, version: made.version);
      _notice = SchedulesNotices.changed(made);
      _notify();
      return result;
    }
    if (session.baseline case final saved?) {
      _selectedId = scheduleRecordId(saved.value);
    }
    _notify();
    return result;
  }

  /// Undo (spec 4.2, 4.3): an untouched or discarded new schedule leaves.
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
    final checking = session.phase == EditPhase.uncertain;
    final from = session.baseline?.value;
    if (checking) {
      await session.check();
    } else {
      await session.reload();
    }
    if (_disposed || !identical(session, _session)) return;
    // A new version a check found: the panel closes on it, as after Save.
    final made = session.baseline?.value;
    if (versioning &&
        checking &&
        made != null &&
        from != null &&
        made.version == from.version + 1) {
      await show(made.id, version: made.version);
      _notice = SchedulesNotices.changed(made);
      _notify();
      return;
    }
    if (session.baseline case final saved?) {
      _selectedId = scheduleRecordId(saved.value);
    }
    _notify();
  }

  /// Discard and return to sheet (spec 9): the open schedule no longer
  /// exists, so its pending values are dropped and none is selected.
  Future<void> discardAndReturn() async {
    if (!(_session?.gone ?? false) || _disposed) return;
    ++_opening;
    _replace(null, null);
    _notify();
  }

  /// Applies [edit] to the pending values under issue key [field] (null:
  /// the whole schedule, never refused by another value's problem).
  String? _edit(
    ScheduleEdit Function(ScheduleValues values) edit,
    String? field,
  ) {
    if (editBlocked case final reason?) return reason;
    final session = _session!;
    final result = edit(session.draft);
    if (result.problem case final problem?) return problem;
    return session.edit(result.values!, field: field);
  }

  /// [field] of the schedule itself takes [value].
  String? editField(String field, Object? value) =>
      _edit((v) => withScheduleField(v, field, value), field);

  /// [field] of block [index] takes [value].
  String? editBlock(int index, String field, Object? value) => _edit(
    (v) => withBlockField(v, index, field, value),
    blockKey(index, field),
  );

  /// A new block of one Off day, last.
  String? addBlock() => _edit(withNewBlock, null);

  /// Removes block [index].
  String? removeBlock(int index) => _edit((v) => withoutBlock(v, index), null);

  /// Moves the block of row [rowId] to [toIndex] (a drag).
  String? moveBlock(String rowId, int toIndex) {
    final from = rowId.startsWith('block:')
        ? int.tryParse(rowId.substring(6))
        : null;
    if (from == null) return ScheduleProblems.notEditable;
    final problem = _edit((v) => withBlockMoved(v, from, toIndex), null);
    // The selection stays on its block wherever the move puts it.
    final selected = _selectedBlock == null
        ? null
        : int.tryParse(_selectedBlock!.substring(6));
    if (problem == null && selected != null) {
      final now = selected == from
          ? toIndex
          : from < selected && toIndex >= selected
          ? selected - 1
          : from > selected && toIndex <= selected
          ? selected + 1
          : selected;
      _selectedBlock = blockRowId(now);
      _notify();
    }
    return problem;
  }

  /// [field] of shift type [id] takes [value].
  String? editType(ShiftTypeId id, String field, Object? value) =>
      _edit((v) => withTypeField(v, id, field, value), typeKey(id, field));

  /// A new shift type, last, selected.
  String? addType() {
    final problem = _edit(withNewType, null);
    if (problem == null) {
      _selectedType = _session!.draft.types.last.id;
      _notify();
    }
    return problem;
  }

  /// Removes shift type [id], unless the cycle uses it.
  String? removeType(ShiftTypeId id) {
    final problem = _edit((v) => withoutType(v, id), null);
    if (problem == null && _selectedType == id) {
      _selectedType = _session!.draft.types.firstOrNull?.id;
      _notify();
    }
    return problem;
  }

  /// Shows the selected schedule's shift types in the middle grid, or its
  /// versions again. The part flushes the open editor first.
  void showTypes(bool on) {
    if (on && _session == null) return;
    _showingTypes = on;
    _selectedType = on ? _session!.draft.types.firstOrNull?.id : null;
    _selectedBreak = null;
    _notify();
  }

  /// Selects shift type [id] in the types view.
  void selectType(ShiftTypeId? id) {
    if (!_showingTypes) return;
    _selectedType = id;
    _selectedBreak = null;
    _notify();
  }

  /// Change schedule from… (spec 4.2, owner pick 3B): once a pending edit
  /// is resolved, a session that makes the next version of the selected
  /// used one, from the latest of today, the day after its start and the
  /// day after its last confirmed day. Returns whether it opened.
  Future<bool> changeFrom() async {
    if (changeBlocked != null) return false;
    final id = selectedRow!.schedule.id;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final List<ScheduleRow> fresh;
    try {
      fresh = await reads.scheduleRows(employmentId);
    } on Object {
      if (ticket == _opening && !_disposed) {
        _notice = SchedulesNotices.unreadable;
        _notify();
      }
      return false;
    }
    if (_disposed || ticket != _opening) return false;
    final row = fresh
        .where((value) => value.schedule.id == id && value.latest)
        .firstOrNull;
    if (row == null) {
      await show(null);
      _notice = SchedulesNotices.gone;
      _notify();
      return false;
    }
    final value = row.schedule;
    var from = today;
    for (final after in [value.inUseFrom, ?row.lastConfirmed]) {
      final next = after.addDays(1);
      if (next.compareTo(from) > 0) from = next;
    }
    final session = ScheduleSession(
      adapter: ScheduleAdapter(
        employmentId: employmentId,
        defaults: ScheduleValues.of(value).copyWith(versionFrom: () => from),
        service: work.schedules,
        reads: reads,
        clock: work.clock,
        versioning: true,
        versionStart: value.inUseFrom,
        lastConfirmed: row.lastConfirmed,
      ),
      baseline: ScheduleRecord(value),
      onCheck: reload,
    );
    _replace(row.rowId, session, guard: _ChangeGuard(session));
    _notify();
    return true;
  }

  /// The Change schedule panel's Cancel: once it lets go (input entered
  /// asks first), the changed version shows again as stored.
  Future<void> cancelChange() async {
    final guard = _guard;
    final session = _session;
    if (guard == null || session == null) return;
    if (await guard.leave(_confirm) == LeaveDecision.stay) return;
    if (!identical(session, _session) || _disposed) return;
    final value = session.baseline!.value;
    await show(value.id, version: value.version);
  }

  /// [field] of break [index] of type [id] takes [value].
  String? editBreak(ShiftTypeId id, int index, String field, Object? value) =>
      _edit(
        (v) => withBreakField(v, id, index, field, value),
        breakKey(id, index, field),
      );

  /// A new break of type [id].
  String? addBreak(ShiftTypeId id) => _edit((v) => withNewBreak(v, id), null);

  /// Removes break [index] of type [id].
  String? removeBreak(ShiftTypeId id, int index) =>
      _edit((v) => withoutBreak(v, id, index), null);

  /// Delete schedule… (spec 4.3, 4.7): once a pending edit is resolved,
  /// asks, then deletes every version of the selected schedule through
  /// `ScheduleService.delete` and selects none. A result that is not known
  /// is settled at once by reading again.
  Future<void> delete() => tracked(() async {
    if (deleteBlocked != null) return;
    final id = selectedRow!.schedule.id;
    if (!await coordinator.navigate(() {}) || _disposed) return;
    // Letting go may have saved a pending edit: delete the schedule as it
    // is stored now, with its latest revision.
    final ScheduleRecord? fresh;
    try {
      fresh = await reads.schedule(employmentId, id);
    } on Object {
      _notice = ScheduleCommandWords.unavailable;
      _notify();
      return;
    }
    if (_disposed) return;
    if (fresh == null) {
      await show(null);
      _notice = SchedulesNotices.gone;
      _notify();
      return;
    }
    final value = fresh.value;
    if (value.usedByConfirmedDay) {
      _notice = ScheduleCommandWords.inUse;
      _notify();
      return;
    }
    if (await _confirm(deleteScheduleRequest(value)) != ConfirmAnswer.proceed ||
        _disposed) {
      return;
    }
    String notice;
    try {
      final outcome = await work.schedules.delete(
        value.id,
        expected: value.revision,
      );
      notice = switch (outcome) {
        Committed() => SchedulesNotices.deleted,
        Invalid() => ScheduleCommandWords.inUse,
        Stale() => ScheduleCommandWords.stale,
        Missing() => ScheduleCommandWords.missing,
        Unavailable() => ScheduleCommandWords.unavailable,
        Uncertain() => await _settleDeletion(value.id),
      };
    } on Object {
      notice = await _settleDeletion(value.id);
    }
    if (_disposed) return;
    if (notice == SchedulesNotices.deleted) {
      await show(null);
    } else {
      await show(value.id, version: value.version);
    }
    _notice = notice;
    _notify();
  });

  /// Whether a deletion whose answer was lost went through.
  Future<String> _settleDeletion(ScheduleId id) async {
    try {
      final still = await reads.schedule(employmentId, id);
      return still == null
          ? SchedulesNotices.deleted
          : ScheduleCommandWords.notDeleted;
    } on Object {
      return ScheduleCommandWords.deleteUnknown;
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

  /// What a new schedule starts with: no name, types or blocks, today in
  /// the current timezone.
  ScheduleValues _defaults() => ScheduleValues(
    name: '',
    timezoneId: work.currentTimezoneId() ?? 'UTC',
    cycleStart: today,
    inUseFrom: today,
    inUseUntil: null,
    types: const [],
    blocks: const [],
  );

  ScheduleSession _sessionOf(ScheduleRecord? record) => ScheduleSession(
    adapter: ScheduleAdapter(
      employmentId: employmentId,
      defaults: _defaults(),
      service: work.schedules,
      reads: reads,
      clock: work.clock,
    ),
    baseline: record,
    onCheck: reload,
  );

  /// Selects row [rowId] with [session] as its edit; [guard] holds the
  /// owner in its place while Change schedule from… is open.
  void _replace(
    String? rowId,
    ScheduleSession? session, {
    _ChangeGuard? guard,
  }) {
    _close();
    _notice = null;
    _changeProblem = null;
    _selectedId = rowId;
    _showingTypes = false;
    _selectedType = null;
    _selectedBlock = null;
    _selectedBreak = null;
    _previewFirst = null;
    if (session != null) {
      coordinator.add(guard ?? session);
      session.addListener(_notify);
      _session = session;
      _guard = guard;
    }
  }

  void _close() {
    final session = _session;
    if (session == null) return;
    session.removeListener(_notify);
    coordinator.remove(_guard ?? session);
    session.dispose();
    _session = null;
    _guard = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_opening;
    unawaited(_feed?.cancel());
    unawaited(_plan?.cancel());
    _markReady();
    _close();
    super.dispose();
  }
}

/// Holds the owner on an open Change schedule from… panel (spec 4.4): the
/// new version is made only by its own key, so leaving with input asks to
/// discard it and never saves it; an uncertain or running save decides as
/// the session does.
final class _ChangeGuard implements LeaveParticipant {
  _ChangeGuard(this.session);

  final ScheduleSession session;

  /// An open panel holds the owner.
  @override
  bool get settled => false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (session.busy || session.phase == EditPhase.uncertain) {
      return session.leave(confirm, kind: kind);
    }
    if (!session.dirty) return LeaveDecision.proceed;
    final answer = await confirm(
      ConfirmRequest(
        title: 'Change schedule',
        message: SchedulesCommandWords.discardChange,
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
}
