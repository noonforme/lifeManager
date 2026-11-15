import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay_period.dart';
import '../../features/work/domain/payslip.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../edit_session/leave_coordinator.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/pay_edit.dart';
import '../work_edit/work_records.dart';
import 'employments_sheet_controller.dart' show EmploymentsWords;
import 'pay_action.dart';

typedef PaySession = RecordEditSession<PayRecord, PayValues>;

/// One of the two pay sheets. Persisted facts and reconciliation stay live;
/// the one pending creation or action has its own immutable baseline.
final class PaySheetController extends ChangeNotifier {
  PaySheetController({
    required this.kind,
    required this.work,
    required this.reads,
    required this.employmentId,
    required this.today,
    required this.coordinator,
    required this._confirm,
    this._archived = false,
  });
  final PayKind kind;
  final ProductionWorkProviders work;
  final WorkReads reads;
  final EmploymentId employmentId;
  final LocalDate today;
  final LeaveCoordinator coordinator;
  final Confirm _confirm;
  bool _archived;
  bool get archived => _archived;
  set archived(bool value) {
    if (_archived == value) return;
    _archived = value;
    _notify();
  }

  WorkRegisterProjection? register;
  List<PeriodSheetRow> get periods => register?.periodSheet ?? const [];
  List<Payslip> get payslips => register?.payslipSheet ?? const [];
  List<PayRecord> get records => kind == PayKind.periods
      ? [for (final row in periods) PayRecord.period(row.period)]
      : [for (final row in payslips) PayRecord.payslip(row)];
  WorkRecordId? get recordId => selectedId == null || selectedId == 'new'
      ? null
      : kind == PayKind.periods
      ? PayPeriodId(selectedId!)
      : PayslipId(selectedId!);
  PayRecord? get selected =>
      (_justSaved?.id.value == selectedId ? _justSaved : null) ??
      records.where((row) => row.id.value == selectedId).firstOrNull ??
      (session?.baseline?.id.value == selectedId ? session?.baseline : null);
  String? selectedId;
  PaySession? session;
  PayAction? action;
  PayRecord? _justSaved;
  bool loaded = false, failed = false, _disposed = false;
  String? notice;
  StreamSubscription<WorkRegisterProjection>? _feed;
  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  Completer<void>? _load;
  Future<void>? _command, _reloading;
  int _opening = 0;
  String? get createBlocked => archived
      ? EmploymentsWords.archivedReadOnly
      : action != null
      ? 'Finish or cancel the current action first.'
      : null;
  String? get actionBlocked => archived
      ? EmploymentsWords.archivedReadOnly
      : action != null
      ? 'Finish or cancel the current action first.'
      : session?.isNew == true
      ? 'Save or discard the new record first.'
      : selected == null
      ? 'Select a saved record first.'
      : null;
  void start() {
    _load = Completer<void>();
    _feed = work.workRepository
        .watchRegister(WorkScope(employmentId: employmentId, temporal: null))
        .listen(
          (value) {
            register = value;
            loaded = true;
            failed = false;
            if (_justSaved case final saved?
                when records.any(
                  (row) =>
                      row.id == saved.id &&
                      row.revision.value >= saved.revision.value,
                )) {
              _justSaved = null;
            }
            _markReady();
            _notify();
          },
          onError: (Object error, StackTrace stack) {
            failed = true;
            _markReady();
            _notify();
          },
        );
  }

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
    if (_load case final load? when !load.isCompleted) load.complete();
  }

  Future<void> refresh() =>
      _reloading ??= _refresh().whenComplete(() => _reloading = null);
  Future<void> _refresh() async {
    await _feed?.cancel();
    if (_disposed) return;
    start();
    await _load!.future;
  }

  void show(WorkRecordId? id) {
    ++_opening;
    _close();
    selectedId = id?.value;
    _justSaved = null;
    notice = null;
    _notify();
  }

  Future<bool> select(WorkRecordId id) async {
    if (id.value == selectedId) return true;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    show(id);
    return true;
  }

  Future<bool> add({PayPeriodId? period}) async {
    if (createBlocked != null ||
        !await coordinator.navigate(() {}) ||
        _disposed) {
      return false;
    }
    if (kind == PayKind.payslips && periods.isEmpty) {
      notice = 'Create a pay period before recording a payslip.';
      _notify();
      return false;
    }
    ++_opening;
    _close();
    selectedId = 'new';
    _justSaved = null;
    notice = null;
    final last = periods.lastOrNull?.period;
    final start = last == null ? today.firstOfMonth : last.end.addDays(1);
    final defaults = PayValues(
      start: start,
      end: start.lastOfMonth,
      issued: today,
      period:
          period ??
          (last?.state == PayPeriodState.open
              ? last?.id
              : periods
                        .where((row) => row.period.state == PayPeriodState.open)
                        .lastOrNull
                        ?.period
                        .id ??
                    last?.id),
    );
    session = PaySession(
      adapter: PayAdapter(
        kind: kind,
        work: work,
        reads: reads,
        employment: employmentId,
        defaults: defaults,
      ),
      onCheck: reload,
    );
    coordinator.add(session!);
    session!.addListener(_followSession);
    _notify();
    return true;
  }

  void _followSession() {
    if (session?.baseline case final saved?) {
      selectedId = saved.id.value;
      _justSaved = saved;
    }
    _notify();
  }

  String? set(String field, Object? value) {
    final edit = session;
    if (archived || edit == null || !edit.isNew) {
      return 'Saved facts are read-only.';
    }
    try {
      return edit.edit(edit.draft.withField(field, value), field: field);
    } on Object {
      return 'Check this value.';
    }
  }

  Future<void> save() async {
    if (archived) return;
    await session?.save(_confirm);
  }

  Future<void> undo() async {
    final edit = session;
    if (edit == null) return;
    final result = await edit.undo(_confirm);
    if (edit.isNew &&
        (result == SaveResult.clean || result == SaveResult.reverted) &&
        !_disposed) {
      show(null);
    }
  }

  Future<void> reload() async {
    final edit = session;
    if (edit == null) {
      await refresh();
      return;
    }
    if (edit.phase == EditPhase.uncertain) {
      await edit.check();
    } else {
      await edit.reload();
    }
  }

  Future<void> discardMissing() async {
    if (session?.gone == true) show(null);
  }

  Future<bool> openAction(PayActionKind kind) async {
    if (actionBlocked != null) return false;
    final chosen = selected!;
    if (kind == PayActionKind.correct && chosen.payslip?.isEffective != true) {
      return false;
    }
    if (kind != PayActionKind.correct && chosen.period == null) return false;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final PayRecord? fresh;
    try {
      fresh = chosen.period != null
          ? switch (await reads.period(chosen.period!.id)) {
              final value? => PayRecord.period(value),
              _ => null,
            }
          : switch (await reads.payslip(chosen.payslip!.id)) {
              final value? => PayRecord.payslip(value),
              _ => null,
            };
    } on Object {
      notice = 'The record could not be read. Try again.';
      _notify();
      return false;
    }
    if (_disposed || ticket != _opening || archived) return false;
    if (fresh == null) {
      notice = 'This record no longer exists.';
      _notify();
      return false;
    }
    if (fresh.payslip?.isEffective == false) {
      notice = 'This payslip is already Void.';
      _notify();
      return false;
    }
    if (fresh.period case final period?) {
      final desired = kind == PayActionKind.review
          ? PayPeriodState.reviewed
          : PayPeriodState.open;
      if (period.state == desired) {
        _justSaved = fresh;
        notice = 'This period is already ${desired.name}.';
        _notify();
        return false;
      }
    }
    _close();
    action = PayAction(
      kind: kind,
      original: fresh,
      work: work,
      reads: reads,
      onCheck: submitAction,
    );
    coordinator.add(action!);
    action!.addListener(_notify);
    _notify();
    if (kind != PayActionKind.correct) await submitAction();
    return true;
  }

  Future<void> submitAction() async {
    if (_command != null || archived && action?.phase == PayActionPhase.input) {
      return;
    }
    final running = _submitAction();
    _command = running;
    try {
      await running;
    } finally {
      if (identical(_command, running)) _command = null;
    }
  }

  Future<void> _submitAction() async {
    final open = action;
    if (open == null) return;
    final saved = await open.submit();
    if (_disposed || !identical(open, action) || saved == null) return;
    _closeAction();
    selectedId = saved.id.value;
    _justSaved = saved;
    notice = switch (open.kind) {
      PayActionKind.review => PayActionWords.reviewed,
      PayActionKind.reopen => PayActionWords.reopened,
      PayActionKind.correct => PayActionWords.corrected,
    };
    _notify();
  }

  Future<void> cancelAction() async {
    final open = action;
    if (open == null ||
        await open.leave(_confirm) == LeaveDecision.stay ||
        _disposed) {
      return;
    }
    if (identical(open, action)) {
      _closeAction();
      _notify();
    }
  }

  Future<void> settled() async {
    for (var running = _command; running != null; running = _command) {
      await running;
    }
  }

  void _closeAction() {
    final open = action;
    if (open == null) return;
    coordinator.remove(open);
    open.removeListener(_notify);
    open.dispose();
    action = null;
  }

  void _close() {
    _closeAction();
    final edit = session;
    if (edit == null) return;
    coordinator.remove(edit);
    edit.removeListener(_followSession);
    edit.dispose();
    session = null;
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
