import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/domain/ids.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../edit_session/leave_coordinator.dart';
import '../production_work_providers.dart';
import 'correct_leave_action.dart';
import 'employments_sheet_controller.dart' show EmploymentsWords;
import 'shifts_filter.dart';
import 'shifts_lines.dart' show leaveTypeWord;
import 'work_location.dart';

abstract final class LeaveSheetWords {
  static const ready = 'Ready.';
  static const loading = 'Loading leave…';
  static const unreadable =
      'Leave could not be read from local storage. Try again.';
  static const empty =
      'No confirmed leave in this period. Mark a planned day as leave on Shifts or Calendar, then confirm it.';
  static const readOnly =
      'Confirmed leave is read-only. Use Correct… to void and replace it.';
  static const voided =
      'This leave is Void and leaves the totals. Follow its replacement to see the current leave.';

  /// The status bar's short forms of [readOnly] and [voided].
  static const readOnlyStatus = 'Read-only: use Correct… to change it.';
  static const voidedStatus = 'Void: its replacement is the current leave.';
  static const corrected =
      'Leave corrected. The original is Void; its confirmed replacement is selected.';
}

/// The priced leave projection stays live; a correction owns its fixed
/// original separately. All row/scope/sheet moves share the shell guard.
final class LeaveSheetController extends ChangeNotifier {
  LeaveSheetController({
    required this.work,
    required this.employmentId,
    required this.from,
    required this.to,
    required this.coordinator,
    required this._confirm,
    this._archived = false,
  });
  final ProductionWorkProviders work;
  final EmploymentId employmentId;
  final LocalDate from;
  final LocalDate to;
  final LeaveCoordinator coordinator;
  final Confirm _confirm;
  bool _archived;
  bool get archived => _archived;
  set archived(bool value) {
    if (_archived == value) return;
    _archived = value;
    _notify();
  }

  List<LeaveSheetRow> _rows = const [];
  List<LeaveSheetRow> get rows => _rows;
  LeaveRecordId? _selected;
  LeaveRecordId? get selectedId => _selected;

  /// The replacement the last Correct… selected, until another is: the
  /// shell widens its filter so it shows.
  LeaveRecordId? get corrected => _corrected;
  LeaveRecordId? _corrected;
  LeaveSheetRow? get selectedRow =>
      _rows.where((row) => row.record.id == _selected).firstOrNull;
  CorrectLeaveAction? _action;
  CorrectLeaveAction? get action => _action;
  bool _loaded = false;
  bool get loaded => _loaded;
  bool _failed = false;
  bool get failed => _failed;
  String? _notice;
  String? get notice => _notice;
  StreamSubscription<WorkRegisterProjection>? _feed;
  final _ready = Completer<void>();
  Completer<void>? _loadDone;
  Future<void> get ready => _ready.future;
  Future<void>? _command;
  bool _disposed = false;
  int _opening = 0;

  /// Whether [filter] shows [row]; an open correction keeps its original
  /// shown whatever the filter.
  bool admits(LeaveSheetRow row, ShiftsFilter filter) =>
      _action?.original.id == row.record.id ||
      (filter.type == null ||
              filter.type == leaveTypeWord(row.record.leaveType)) &&
          switch (filter.status) {
            ShiftsStatusFilter.all => true,
            ShiftsStatusFilter.voided => !row.record.isEffective,
            _ => row.record.isEffective,
          };

  String? get correctBlocked => _archived
      ? EmploymentsWords.archivedReadOnly
      : _action != null
      ? 'Finish or cancel the action in the property column first.'
      : selectedRow == null
      ? 'Select confirmed leave first.'
      : !selectedRow!.record.isEffective
      ? LeaveSheetWords.voided
      : null;

  void start() {
    _loadDone = Completer<void>();
    _feed = work.workRepository
        .watchRegister(
          WorkScope(
            employmentId: employmentId,
            temporal: DateRangeScope(start: from, end: to),
          ),
        )
        .listen(
          (value) {
            _rows = value.leaveSheet;
            _loaded = true;
            _failed = false;
            _markReady();
            _notify();
          },
          onError: (Object error, StackTrace stack) {
            _failed = true;
            _markReady();
            _notify();
          },
        );
  }

  Future<void>? _reloading;
  Future<void> reload() =>
      _reloading ??= _reload().whenComplete(() => _reloading = null);

  Future<void> _reload() async {
    await _feed?.cancel();
    if (_disposed) return;
    _notice = null;
    start();
    await _loadDone!.future;
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
    if (_loadDone case final load? when !load.isCompleted) load.complete();
  }

  WorkLocation get place =>
      WorkLocation.leave(employmentId, from: from, to: to, leave: _selected);

  /// The shell has resolved the previous record before calling this.
  void show(LeaveRecordId? id) {
    ++_opening;
    _closeAction();
    // The shell has checked this identity already. The projection can
    // still be catching up with a confirmation, so an absent row here
    // must not turn a resolved record into a missing record.
    _selected = id;
    _corrected = null;
    _notice = _failed ? LeaveSheetWords.unreadable : null;
    _notify();
  }

  Future<bool> select(LeaveRecordId id) async {
    if (id == _selected) return true;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    show(id);
    return true;
  }

  Future<bool> openCorrect() async {
    if (correctBlocked != null) return false;
    final id = _selected!;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    try {
      final original = await work.plans.repository.leaveById(id);
      if (_disposed || ticket != _opening || correctBlocked != null) {
        return false;
      }
      if (original == null ||
          original.employmentId != employmentId ||
          !original.isEffective) {
        _notice = original == null
            ? CorrectLeaveWords.missing
            : CorrectLeaveWords.stale;
        _notify();
        return false;
      }
      final action = _action = CorrectLeaveAction(
        original: original,
        service: work.plans,
        onCheck: submitAction,
      );
      action.addListener(_notify);
      coordinator.add(action);
      _notify();
      return true;
    } on Object {
      if (!_disposed && ticket == _opening) {
        _notice = LeaveSheetWords.unreadable;
        _notify();
      }
      return false;
    }
  }

  /// The result is already a complete saved record. Selecting it requires
  /// no fallible reopen; live prices arrive from the register afterwards.
  Future<void> submitAction() async {
    if (_command != null ||
        _archived && _action?.phase == CorrectLeavePhase.input) {
      return;
    }
    final running = _submit();
    _command = running;
    try {
      await running;
    } finally {
      if (identical(_command, running)) _command = null;
    }
  }

  Future<void> _submit() async {
    final action = _action;
    if (action == null) return;
    final produced = await action.submit();
    if (_disposed || !identical(action, _action) || produced == null) return;
    if (!_rows.any((row) => row.record.id == produced.id)) {
      _rows = [..._rows, LeaveSheetRow(record: produced, pay: null)];
    }
    _selected = produced.id;
    _corrected = produced.id;
    _closeAction();
    _notice = LeaveSheetWords.corrected;
    _notify();
  }

  Future<void> cancelAction() async {
    final action = _action;
    if (action == null || await action.leave(_confirm) == LeaveDecision.stay) {
      return;
    }
    if (_disposed || !identical(action, _action)) return;
    _closeAction();
    _notify();
  }

  Future<void> settled() async {
    for (var running = _command; running != null; running = _command) {
      await running;
    }
  }

  void _closeAction() {
    final action = _action;
    if (action == null) return;
    action.removeListener(_notify);
    coordinator.remove(action);
    action.dispose();
    _action = null;
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
    _closeAction();
    super.dispose();
  }
}
