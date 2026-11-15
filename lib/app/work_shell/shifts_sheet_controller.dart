import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/application/planned_leave_pay.dart';
import '../../features/work/application/work_templates.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/schedule.dart';
import '../../features/work/domain/shift.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../edit_session/leave_coordinator.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/extra_day_edit.dart';
import '../work_edit/leave_day_edit.dart';
import '../work_edit/planned_day_edit.dart';
import '../work_edit/shift_edit.dart';
import '../work_edit/work_preview.dart';
import '../work_edit/work_records.dart';
import 'confirm_days_action.dart';
import 'day_action.dart';
import 'day_commands.dart';
import 'employments_sheet_controller.dart' show EmploymentsWords;
import 'shifts_action.dart';
import 'shifts_edit.dart';
import 'shifts_rows.dart';
import 'work_location.dart' show WorkSheetKind;

/// What the Shifts sheet's status line says when nothing else does.
abstract final class ShiftsNotices {
  static const ready = 'Ready.';
  static const loading = 'Loading shifts…';
  static const unreadable =
      'Shifts could not be read from local storage. Try again.';
  static const gone = 'This record is no longer in the sheet.';
  static const offDay = 'No shift is planned on this day.';
  static const opening = 'Opening the record…';
  static const notPlanned =
      'This day is not an editable planned day; review it in its plan.';
  static const corrected =
      'Shift corrected: the original is Void. Change the replacement draft, '
      'then Save to finalize it.';
  static const voided =
      'Shift voided. It stays in the history and is no longer paid.';
  static const needsReview =
      'This change no longer fits the schedule on this date. It is ignored '
      'until you remove it with Remove change.';
  static const restored = 'Change removed: the day follows its schedule again.';
  static const restoredOff =
      'Change removed: the schedule plans no work on this day.';
  static const reviewChanged =
      'This day changed since you selected it; it is shown as it is now.';
  static const removeNotDone =
      'The change was not removed. Try again when ready.';
  static const leaveDay =
      'This day is leave. Restore shift brings the planned shift back.';
  static const cancelledDay =
      'This shift is cancelled. Restore shift brings it back.';
  static const leaveTaken = 'Confirmed leave is corrected on the Leave sheet.';
  static const removeUnknown =
      'It is not known whether the change was removed; the day is shown as '
      'it is now.';
}

/// Why a record command does not apply to the selected row, for its greyed
/// toolbar key and menu row (spec 4.9).
abstract final class ShiftsCommandWords {
  static const correctOnlyFinalized = 'Correct applies to a finalized shift.';
  static const voidOnlyStored =
      'Void applies to a stored shift that is not void yet.';
  static const removeOnlyReview =
      'Remove change applies to a day marked Needs review.';
  static const actionOpen =
      'Finish or cancel the action in the property column first.';
  static const busy = 'Wait for the current command to finish.';
  static const addElsewhere = 'Add shifts on the Shifts or Calendar sheet.';
  static const dayOnlyPlanned =
      'This applies to a planned day not yet confirmed; an extra shift is '
      'removed with Remove extra shift.';
}

/// The new shell's Shifts sheet for one employment and month (spec 3, 4.2):
/// the merged planned and stored rows, the selected row, and the edit of
/// that row through its `RecordEditSession`. Every change of selection,
/// including a new row, goes through [coordinator], so a pending edit is
/// saved, discarded or kept first; only one session exists at a time. It
/// holds no widgets: `ShiftsSheetPart` renders it in the Work shell.
final class ShiftsSheetController extends ChangeNotifier {
  ShiftsSheetController({
    required this.work,
    required this.reads,
    required this.employmentId,
    LocalDate? month,
    LocalDate? from,
    LocalDate? to,
    required this.today,
    required this.timezoneId,
    required Confirm confirm,
    Future<ShiftRecord?> Function(ShiftId)? readShift,
    Future<MutationOutcome<ConfirmedDay>> Function(EmploymentId, LocalDate)?
    confirmDay,
    LeaveCoordinator? coordinator,
    this._archived = false,
    this.kind = WorkSheetKind.shifts,
  }) : assert((month == null) != (from == null || to == null)),
       from = from ?? month!.firstOfMonth,
       to = to ?? month!.lastOfMonth,
       _confirm = confirm,
       _readShift = readShift ?? reads.shift,
       _confirmCommand = confirmDay ?? work.plans.confirm,
       coordinator = coordinator ?? LeaveCoordinator(confirm: confirm);

  final ProductionWorkProviders work;
  final WorkReads reads;
  final Future<ShiftRecord?> Function(ShiftId) _readShift;

  /// Confirms one day (`DayPlanService.confirm`); tests may script it.
  final Future<MutationOutcome<ConfirmedDay>> Function(EmploymentId, LocalDate)
  _confirmCommand;
  final EmploymentId employmentId;

  /// Which view of the rows the shell shows: Shifts, Calendar or To
  /// confirm (plan 4d-2).
  final WorkSheetKind kind;

  /// The first and last days the sheet shows.
  final LocalDate from;
  final LocalDate to;

  /// Whether the sheet shows exactly one calendar month.
  bool get wholeMonth => from == from.firstOfMonth && to == from.lastOfMonth;

  /// The first day of the month [from] lies in.
  LocalDate get month => from.firstOfMonth;
  final LocalDate today;

  /// The zone a new manual shift is entered in.
  final String timezoneId;
  final Confirm _confirm;

  /// The employment is archived: its rows are listed and nothing changes
  /// (bead 9pk.4.14). The shell keeps it current as the employment changes.
  bool get archived => _archived;
  bool _archived;
  set archived(bool value) {
    if (value == _archived) return;
    _archived = value;
    _notify();
  }

  /// Why New shift and Add ▾'s rows do not apply; null when they do.
  String? get addBlocked => _archived
      ? EmploymentsWords.archivedReadOnly
      : kind == WorkSheetKind.toConfirm
      ? ShiftsCommandWords.addElsewhere
      : null;

  /// Guards every change of selection, and the application's close. The
  /// Work shell passes its own, shared by every sheet it shows.
  final LeaveCoordinator coordinator;

  List<ShiftsRow> _rows = const [];
  List<ShiftSheetRow> _stored = const [];
  List<PlannedShiftRow> _planned = const [];
  List<NeedsReview> _review = const [];
  List<OffDay> _off = const [];
  List<LeaveRow> _leave = const [];
  List<CancelledPlan> _cancelled = const [];
  List<LeaveSheetRow> _taken = const [];

  /// The register from three months before the sheet's month: what
  /// planned leave is priced from.
  List<ShiftSheetRow> _pastShifts = const [];
  List<LeaveSheetRow> _pastLeave = const [];

  /// The plan inputs the day feed read last: which agreements cover which
  /// days.
  PlanInputs? _feedInputs;
  bool _storedLoaded = false;
  bool _plannedLoaded = false;
  bool _reviewLoaded = false;
  bool _failed = false;
  StreamSubscription<Object?>? _storedFeed;
  StreamSubscription<Object?>? _plannedFeed;
  StreamSubscription<Object?>? _reviewFeed;
  bool _removing = false;
  bool _confirming = false;
  final _ready = Completer<void>();

  /// A record command that runs outside an edit session (a panel's
  /// command, Remove change); closing waits for it (spec 4.8).
  Future<void>? _command;

  String? _selectedId;
  ShiftsEdit? _edit;
  ShiftsAction? _action;
  DayAction? _dayAction;
  String? _readOnlyReason;
  String? _notice;
  PlanInputs? _inputs;
  bool _disposed = false;

  /// Counts openings: a record read that finishes after a later selection
  /// is dropped.
  int _opening = 0;

  /// The sheet's stored and planned rows by start.
  List<ShiftsRow> get rows => _rows;

  /// The Calendar's day before its first (bead 9pk.4.21): read so a night
  /// that runs into the 1st shows its morning there, but not one of the
  /// sheet's rows. Empty on the other sheets.
  List<ShiftsRow> get eve => _eve;
  List<ShiftsRow> _eve = const [];

  /// The first day the feeds read: the day before [from] on Calendar.
  LocalDate get _feedFrom =>
      kind == WorkSheetKind.calendar ? from.addDays(-1) : from;

  bool get loaded => _storedLoaded && _plannedLoaded && _reviewLoaded;

  /// Whether a feed of the rows could not be read.
  bool get failed => _failed;

  /// Completes once the rows are first [loaded], a feed [failed], or the
  /// sheet is disposed.
  Future<void> get ready => _ready.future;

  /// The selected row's id, [newRowId] while a new shift is entered.
  String? get selectedId => _selectedId;

  /// The selected row as the sheet lists it; null for the new row.
  ShiftsRow? get selectedRow => _rowById(_selectedId);

  /// The selected record's edit; null when it is read-only or none is
  /// selected.
  ShiftsEdit? get edit => _edit;

  /// Why the selected row has no edit.
  String? get readOnlyReason => _readOnlyReason;

  /// Why Finalize does not apply; null on a stored draft with no pending
  /// change (plan 4d-1, call 9).
  String? get finalizeBlocked {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    final edit = _edit;
    if (edit != null && edit.frozen) return ShiftsCommandWords.busy;
    if (edit case StoredEdit(:final session)
        when !edit.isNew && session.baseline?.shift.state == ShiftState.draft) {
      return edit.dirty ? DayCommandWords.finalizeChanged : null;
    }
    return DayCommandWords.finalizeOnlyDraft;
  }

  /// Finalize: finalizes the selected draft as it is stored, after the same
  /// window Save asks on a draft.
  Future<SaveResult?> finalize() async {
    final edit = _edit;
    // The key's flush took a value typed into an open editor: Save
    // finalizes the changed draft.
    if (finalizeBlocked == DayCommandWords.finalizeChanged) return save();
    if (finalizeBlocked != null || edit == null) return null;
    final result = await edit.session.save(_confirm, unchanged: true);
    _settled(edit, result);
    return result;
  }

  /// Why Add extra shift does not apply; null when an Off day is
  /// selected.
  String? get extraBlocked {
    if (addBlocked case final blocked?) return blocked;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_removing || _confirming || (_edit?.frozen ?? false)) {
      return ShiftsCommandWords.busy;
    }
    return selectedRow is OffRow ? null : DayCommandWords.extraOnlyOff;
  }

  /// Add extra shift (plan 4d-1, call 8): a new, unsaved extra shift on
  /// the selected Off day, from the first shift type of the schedule in
  /// use that day, once the current record lets go. Saving it is its first
  /// write; left untouched it creates nothing.
  Future<bool> addExtra() async {
    if (extraBlocked != null) return false;
    final date = selectedRow!.date;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final inputs = await work.plans.repository.planInputs(employmentId);
    if (ticket != _opening || _disposed) return false;
    final types =
        inputs.schedules
            .where((value) => value.isInUseOn(date))
            .firstOrNull
            ?.shiftTypes ??
        const <ShiftType>[];
    final first = types.firstOrNull;
    final defaults = first == null
        ? const PlannedDayValues(
            start: LocalTime(8, 0),
            end: LocalTime(16, 0),
            endDayOffset: 0,
          )
        : PlannedDayValues(
            start: first.start,
            end: first.end,
            endDayOffset: first.endDayOffset,
            breaks: first.breaks,
            shiftTypeId: first.id,
          );
    _replace(
      PlannedEdit(
        RecordEditSession(
          adapter: ExtraDayAdapter(
            plans: work.plans,
            employmentId: employmentId,
            date: date,
            defaults: defaults,
          ),
          onCheck: reload,
        ),
        typeChoices: types,
        newDate: date,
      ),
      newExtraRowId,
    );
    _inputs = inputs;
    _notify();
    return true;
  }

  /// The open Correct or Void panel; while it is open the selected record
  /// has no edit.
  ShiftsAction? get action => _action;

  /// The open Cancel shift or Mark as leave panel; while it is open the
  /// selected day has no edit.
  DayAction? get dayAction => _dayAction;

  /// The open Confirm worked days panel, To confirm only (plan 4d-2);
  /// while it is open the grid picks days and no record has an edit.
  ConfirmDaysAction? get confirmDays => _confirmDays;
  ConfirmDaysAction? _confirmDays;

  /// Whether a panel holds the property column.
  bool get _panelOpen =>
      _action != null || _dayAction != null || _confirmDays != null;

  /// Why Confirm worked days… does not apply here and now; null when it
  /// may open (the shell also greys it while no day waits).
  String? get confirmDaysBlocked {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_removing || _confirming || (_edit?.frozen ?? false)) {
      return ShiftsCommandWords.busy;
    }
    return null;
  }

  /// Opens Confirm worked days on To confirm (plan 4d-2, owner pick 2B)
  /// once the current record lets go: every past day to confirm ticked,
  /// those no agreement covers listed and never ticked. Returns whether it
  /// opened.
  Future<bool> openConfirmDays() async {
    if (kind != WorkSheetKind.toConfirm || confirmDaysBlocked != null) {
      return false;
    }
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final days = <ConfirmDayChoice>[
      for (final row in _rows)
        if (row.date.compareTo(today) < 0)
          ?switch (row) {
            PlannedRow(:final planned) => ConfirmDayChoice(
              date: row.date,
              kind: planned.day.isExtra
                  ? ConfirmDayKind.extra
                  : planned.day.changed
                  ? ConfirmDayKind.changed
                  : ConfirmDayKind.planned,
              paidSeconds: planned.day.paidSeconds,
              pay: planned.pay?.amount,
              basis: planned.pay?.basis,
              eligible: !planned.withoutAgreement,
            ),
            LeaveRow(:final day, :final withoutAgreement, :final pay) =>
              ConfirmDayChoice(
                date: row.date,
                kind: day.leaveType == LeaveType.sick
                    ? ConfirmDayKind.sick
                    : ConfirmDayKind.vacation,
                paidSeconds: day.paidMinutes * 60,
                pay: pay?.amount,
                basis: pay?.basis,
                eligible: !withoutAgreement,
              ),
            _ => null,
          },
    ];
    ++_opening;
    _replace(null, _selectedId, reason: ShiftsCommandWords.actionOpen);
    final action = _confirmDays = ConfirmDaysAction(
      employmentId: employmentId,
      days: days,
      confirm: _confirmCommand,
      confirmedDates: () async =>
          (await work.plans.repository.planInputs(employmentId)).confirmedDates,
    );
    coordinator.add(action);
    action.addListener(_notify);
    _notify();
    return true;
  }

  /// The panel's primary key: confirms the ticked days, or Retry, or
  /// Reload and check while a day is not known. A full success closes the
  /// panel (plan 4d-2, call 8); a selected day it confirmed is selected as
  /// what confirming made, as a single Confirm does.
  Future<void> runConfirmDays() => _tracked(() async {
    final action = _confirmDays;
    if (action == null) return;
    if (action.hasUnknown) {
      await action.check();
    } else {
      await action.run(_confirm);
    }
    if (!identical(action, _confirmDays) || !action.allDone) return;
    final done = action.confirmedCount;
    final id = _selectedId;
    final made = [
      for (final MapEntry(:key, :value) in action.results.entries)
        if (value.result == ConfirmDayResult.confirmed &&
            plannedRowId(key) == id)
          key,
    ].firstOrNull;
    _closeAction();
    if (made != null) {
      await _showConfirmedOr(made, ++_opening);
    } else if (id != null && _rowById(id) != null) {
      await _open(id);
    } else {
      _selectedId = null;
      _readOnlyReason = null;
    }
    _notice = ConfirmDaysWords.allDone(done);
    _notify();
  });

  /// Reload and check of a day whose result is not known.
  Future<void> checkConfirmDays() =>
      _tracked(() async => _confirmDays?.check());

  /// Cancel or Close: leaves the panel once it lets go (asking about
  /// changed ticks or days left).
  Future<void> closeConfirmDays() async {
    final action = _confirmDays;
    if (action == null) return;
    if (await action.leave(_confirm) == LeaveDecision.stay) return;
    if (!identical(action, _confirmDays)) return;
    final id = _selectedId;
    _closeAction();
    if (id == null || _rowById(id) == null) {
      _selectedId = null;
      _readOnlyReason = null;
      _notify();
    } else {
      await _open(id);
    }
  }

  /// Why Cancel shift… does not apply to the selected row; null when it
  /// does: a planned day (not an extra one) not yet confirmed.
  String? get cancelBlocked => _dayActionBlocked;

  /// Why Mark as leave… does not apply to the selected row; null when it
  /// does.
  String? get leaveBlocked => _dayActionBlocked;

  String? get _dayActionBlocked {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_removing || _confirming || (_edit?.frozen ?? false)) {
      return ShiftsCommandWords.busy;
    }
    return switch (selectedRow) {
      PlannedRow(:final planned) when !planned.day.isExtra => null,
      _ => ShiftsCommandWords.dayOnlyPlanned,
    };
  }

  /// What the last record command did, until the selection next changes.
  String? get notice => _notice;

  /// Why Correct does not apply to the selected row; null when it does.
  String? get correctBlocked => _blocked(
    (shift) => shift.state == ShiftState.finalized,
    ShiftsCommandWords.correctOnlyFinalized,
  );

  /// Why Void does not apply to the selected row; null when it does.
  String? get voidBlocked => _blocked(
    (shift) => shift.state != ShiftState.voided,
    ShiftsCommandWords.voidOnlyStored,
  );

  /// Why Remove change does not apply to the selected row; null when it
  /// does.
  String? get removeChangeBlocked {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_removing) return ShiftsCommandWords.busy;
    return selectedRow is ReviewRow
        ? null
        : ShiftsCommandWords.removeOnlyReview;
  }

  /// Why Confirm does not apply to the selected row; null when it does: a
  /// planned day or leave on or before today that an agreement covers.
  String? get confirmBlocked {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_removing || _confirming || (_edit?.frozen ?? false)) {
      return ShiftsCommandWords.busy;
    }
    final (date, withoutAgreement) = switch (selectedRow) {
      PlannedRow(:final planned) => (
        planned.day.date,
        planned.withoutAgreement,
      ),
      LeaveRow(:final day, :final withoutAgreement) => (
        day.date,
        withoutAgreement,
      ),
      _ => (null, false),
    };
    if (date == null || date.compareTo(today) > 0) {
      return DayCommandWords.confirmOnly;
    }
    return withoutAgreement ? DayCommandWords.noAgreement : null;
  }

  String? _blocked(bool Function(WorkShift shift) applies, String otherwise) {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_edit?.frozen ?? false) return ShiftsCommandWords.busy;
    return switch (selectedRow) {
      StoredRow(:final shift) when applies(shift) => null,
      _ => otherwise,
    };
  }

  /// The derived values of the selected record's pending values.
  WorkPreview? get preview => switch (_edit) {
    PlannedEdit(:final session, :final date) when _inputs != null =>
      switch (session.baseline) {
        final record? => previewPlannedDay(
          record,
          session.draft,
          inputs: _inputs!,
          zoneClocks: work.plans.zoneClocks,
        ),
        null => previewNewExtra(
          employmentId,
          date,
          session.draft,
          inputs: _inputs!,
          zoneClocks: work.plans.zoneClocks,
        ),
      },
    StoredEdit(:final session) when _inputs != null => previewShift(
      session.draft,
      employmentId: employmentId,
      agreements: _inputs!.agreements,
      timezones: work.timezones,
      zoneClocks: work.plans.zoneClocks,
      schedule: session.baseline?.shift.schedule,
    ),
    _ => null,
  };

  /// The pay agreement that pays [date], from the plan inputs read for the
  /// selected record; null when none or several apply.
  PayAgreement? agreementFor(LocalDate date) {
    final inputs = _inputs;
    if (inputs == null) return null;
    return switch (resolveAgreement(
      employmentId: employmentId,
      localStartDate: date,
      agreements: inputs.agreements,
    )) {
      ResolvedAgreement(:final agreement) => agreement,
      _ => null,
    };
  }

  /// Whether a single pay agreement covers [date], as the day feed last
  /// read the agreements; false before it has read them.
  bool agreementCovers(LocalDate date) {
    final inputs = _feedInputs;
    if (inputs == null) return false;
    return resolveAgreement(
      employmentId: employmentId,
      localStartDate: date,
      agreements: inputs.agreements,
    ) is ResolvedAgreement;
  }

  /// The cycle's own plan for [date], before any change to that day; null
  /// when the cycle plans no work on it.
  PlannedShift? cyclePlanOf(LocalDate date) {
    final inputs = _inputs;
    if (inputs == null) return null;
    final day = planDays(
      from: date,
      to: date,
      schedules: inputs.schedules,
      exceptions: [
        for (final value in inputs.exceptions)
          if (value.date != date) value,
      ],
      confirmedDates: const {},
      zoneClocks: work.plans.zoneClocks,
    ).firstOrNull;
    return day is PlannedShift ? day : null;
  }

  /// Starts following the sheet's rows.
  void start() {
    final scope = WorkScope(
      employmentId: employmentId,
      temporal: DateRangeScope(start: _feedFrom, end: to),
    );
    // Leave is priced from the three months before its own (bead
    // 9pk.4.19), so the register is read from that far back; only the
    // sheet's own days become rows.
    final history = WorkScope(
      employmentId: employmentId,
      temporal: DateRangeScope(start: from.firstOfMonth.addMonths(-3), end: to),
    );
    _storedFeed = work.workRepository.watchRegister(history).listen((value) {
      unawaited(_readFromLast());
      _pastShifts = value.shiftSheet;
      _pastLeave = value.leaveSheet;
      _stored = [
        for (final row in value.shiftSheet)
          if (row.shift.localStartDate.compareTo(_feedFrom) >= 0) row,
      ];
      _taken = [
        for (final row in value.leaveSheet)
          if (row.record.isEffective &&
              row.record.date.compareTo(_feedFrom) >= 0 &&
              row.record.date.compareTo(to) <= 0)
            row,
      ];
      _storedLoaded = true;
      _merge();
    }, onError: _feedFailed);
    _plannedFeed = work.workRepository.watchPlannedShifts(scope).listen((
      value,
    ) {
      _planned = value;
      _plannedLoaded = true;
      _merge();
    }, onError: _feedFailed);
    // The days whose change no longer fits: the planned feed leaves them
    // out, as they plan nothing until the change is removed.
    _reviewFeed = work.plans.watchInputs(employmentId).listen((inputs) {
      final days = planDays(
        from: _feedFrom,
        to: to,
        schedules: inputs.schedules,
        exceptions: inputs.exceptions,
        confirmedDates: inputs.confirmedDates,
        zoneClocks: work.plans.zoneClocks,
      );
      _review = [
        for (final day in days)
          if (day is NeedsReview) day,
      ];
      // Off days are rows too, listed while Off days is ticked.
      _off = [
        for (final day in days)
          if (day is OffDay) day,
      ];
      _leave = [
        for (final day in days)
          if (day is PlannedLeave)
            LeaveRow(
              day,
              withoutAgreement: lacksAgreement(
                day,
                employmentId: employmentId,
                agreements: inputs.agreements,
              ),
            ),
      ];
      _cancelled = [
        for (final day in days)
          if (day is CancelledPlan) day,
      ];
      _feedInputs = inputs;
      _reviewLoaded = true;
      _merge();
    }, onError: _feedFailed);
  }

  /// A feed that could not be read: the sheet says so instead of loading.
  void _feedFailed(Object error, StackTrace stack) {
    if (_disposed) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'shifts sheet',
      ),
    );
    _failed = true;
    if (!_ready.isCompleted) _ready.complete();
    _notify();
  }

  /// [rows] with what each would pay once confirmed, when its agreement
  /// and the months before it are known.
  List<LeaveRow> _priced(List<LeaveRow> rows) {
    final inputs = _feedInputs;
    if (inputs == null || !_storedLoaded) return rows;
    return [
      for (final row in rows)
        LeaveRow(
          row.day,
          withoutAgreement: row.withoutAgreement,
          pay: plannedLeavePay(
            row.day,
            employmentId: employmentId,
            agreements: inputs.agreements,
            shifts: _pastShifts,
            leave: _pastLeave,
          ),
        ),
    ];
  }

  void _merge() {
    final merged = mergeShiftsRows(
      stored: _stored,
      planned: _planned,
      review: _review,
      off: _off,
      leave: _priced(_leave),
      cancelled: _cancelled,
      taken: _taken,
    );
    _rows = [
      for (final row in merged)
        if (row.date.compareTo(from) >= 0) row,
    ];
    _eve = [
      for (final row in merged)
        if (row.date.compareTo(from) < 0) row,
    ];
    // Days an Extend pay agreement… covered become tickable.
    _confirmDays?.refreshEligible({
      for (final row in _rows)
        if (row.date.compareTo(today) < 0)
          if (row case PlannedRow(:final planned)
              when !planned.withoutAgreement)
            row.date
          else if (row case LeaveRow(withoutAgreement: false))
            row.date,
    });
    if (loaded && !_ready.isCompleted) _ready.complete();
    _notify();
  }

  /// The name of schedule [id] as the day feed read it last; null before
  /// the first read.
  String? scheduleName(ScheduleId id) =>
      _feedInputs?.schedules.where((value) => value.id == id).firstOrNull?.name;

  /// The row [date] selects on Calendar and To confirm (plan 4d-2, call
  /// 2): its plan row, else a stored shift that is not void, else confirmed
  /// leave, else a void shift, else its Off row; null when the sheet has
  /// none on that date.
  String? rowIdOn(LocalDate date) {
    final on = [
      for (final row in _rows)
        if (row.date == date) row,
    ];
    int rank(ShiftsRow row) => switch (row) {
      PlannedRow() || LeaveRow() || CancelledRow() || ReviewRow() => 0,
      StoredRow(:final shift) when shift.state != ShiftState.voided => 1,
      LeaveTakenRow() => 2,
      StoredRow() => 3,
      OffRow() => 4,
    };
    ShiftsRow? best;
    for (final row in on) {
      if (best == null || rank(row) < rank(best)) best = row;
    }
    return best?.id;
  }

  /// The shift types of every schedule version the day feed read, each
  /// version's in its order, without repeats: the calendar's tones.
  List<String> get shiftTypeNames => [
    ...{
      for (final schedule in _feedInputs?.schedules ?? const <WorkSchedule>[])
        for (final type in schedule.shiftTypes) type.name,
    },
  ];

  ShiftsRow? _rowById(String? id) =>
      _rows.where((row) => row.id == id).firstOrNull;

  /// Selects row [id] once the current record lets go (spec 4.2): a
  /// pending edit is saved under the save matrix, or discarded, or keeps
  /// the selection. Returns whether the selection moved.
  Future<bool> select(String id) async {
    if (id == _selectedId) return true;
    String? target;
    if (!await coordinator.navigate(() => target = id)) return false;
    await _open(target!);
    return true;
  }

  /// Selects row [id], or none, without asking the current record: the
  /// Work shell has already let it go through [coordinator] (Back,
  /// Forward, a followed link, a restored route).
  Future<void> show(String? id) async {
    if (id == _selectedId) return;
    if (id == null) {
      ++_opening;
      _replace(null, null);
      _notify();
      return;
    }
    await _open(id);
  }

  /// Waits for a record command that runs outside an edit session; an
  /// edit session's save is waited for by its own leave guard.
  Future<void> settled() async {
    for (var running = _command; running != null; running = _command) {
      await running;
    }
  }

  /// Runs [body] as the sheet's command for [settled].
  Future<T> _tracked<T>(Future<T> Function() body) async {
    final done = Completer<void>();
    _command = done.future;
    try {
      return await body();
    } finally {
      if (identical(_command, done.future)) _command = null;
      done.complete();
    }
  }

  /// The last finalized shift's shape, for Manual shift from last time;
  /// null when there is none (or it could not be read).
  ShiftTemplate? _fromLast;

  /// Why Manual shift from last time does not apply; null when a finalized
  /// shift can be copied.
  String? get fromLastBlocked {
    if (addBlocked case final blocked?) return blocked;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_edit?.frozen ?? false) return ShiftsCommandWords.busy;
    return _fromLast == null ? DayCommandWords.noLastShift : null;
  }

  /// Reads the employment's last finalized shift as a template.
  Future<void> _readFromLast() async {
    try {
      final last = (await reads.shiftsOf(employmentId))
          .where((shift) => shift.state == ShiftState.finalized)
          .fold<WorkShift?>(
            null,
            (latest, shift) =>
                latest == null || shift.startUtc.isAfter(latest.startUtc)
                ? shift
                : latest,
          );
      final record = last == null ? null : await _readShift(last.id);
      if (_disposed) return;
      _fromLast = record == null
          ? null
          : shiftTemplateFromLast([
              (shift: record.shift, breaks: record.breaks),
            ], work.timezones);
      _notify();
    } on Object {
      _fromLast = null;
    }
  }

  /// Adds a new manual shift once the current record lets go (spec 4.3,
  /// bead 9pk.4.3). Its date is the selected row's, else today when the
  /// sheet shows it, else the sheet's first day. Its times and breaks are
  /// that day's plan, else 08:00 to 16:00; with [fromLast], the last
  /// finalized shift's. Saving it is its first write.
  Future<bool> addShift({bool fromLast = false}) async {
    if (addBlocked != null || (fromLast && fromLastBlocked != null)) {
      return false;
    }
    final date = _newShiftDate();
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final defaults = fromLast && _fromLast != null
        ? _fromTemplate(_fromLast!, date)
        : _plannedValues(date) ??
              ShiftValues(
                startDate: date,
                start: const LocalTime(8, 0),
                endDate: date,
                end: const LocalTime(16, 0),
                timezoneId: timezoneId,
              );
    final adapter = _shiftAdapter(defaults: defaults);
    _replace(
      StoredEdit(RecordEditSession(adapter: adapter, onCheck: reload)),
      newRowId,
    );
    final inputs = await work.plans.repository.planInputs(employmentId);
    if (ticket == _opening) _inputs = inputs;
    _notify();
    return true;
  }

  LocalDate _newShiftDate() {
    bool inside(LocalDate date) =>
        date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
    final selected = selectedRow?.date;
    if (selected != null && inside(selected)) return selected;
    return inside(today) ? today : from;
  }

  /// [date]'s planned shift as a new shift's values, in its own zone; null
  /// when the day plans no shift.
  ShiftValues? _plannedValues(LocalDate date) {
    final inputs = _feedInputs;
    if (inputs == null) return null;
    final day = planDays(
      from: date,
      to: date,
      schedules: inputs.schedules,
      exceptions: inputs.exceptions,
      confirmedDates: const {},
      zoneClocks: work.plans.zoneClocks,
    ).firstOrNull;
    if (day is! PlannedShift) return null;
    final zone = day.timezoneId;
    final zones = work.timezones;
    LocalTime at(DateTime utc) {
      final time = zones.localTimeAt(utc, zone);
      return LocalTime(time.hour, time.minute);
    }

    return ShiftValues(
      startDate: zones.localDateAt(day.startUtc, zone),
      start: at(day.startUtc),
      endDate: zones.localDateAt(day.endUtc, zone),
      end: at(day.endUtc),
      timezoneId: zone,
      breaks: [
        for (final item in day.breaks)
          BreakValues(
            startDate: zones.localDateAt(item.start, zone),
            start: at(item.start),
            endDate: zones.localDateAt(item.end, zone),
            end: at(item.end),
          ),
      ],
    );
  }

  /// [template] placed on [date].
  ShiftValues _fromTemplate(ShiftTemplate template, LocalDate date) =>
      ShiftValues(
        startDate: date,
        start: template.start,
        endDate: ShiftTemplate.shift(date, template.endDayOffset),
        end: template.end,
        timezoneId: template.timezoneId,
        breaks: [
          for (final item in template.breaks)
            BreakValues(
              startDate: ShiftTemplate.shift(date, item.startDayOffset),
              start: item.start,
              endDate: ShiftTemplate.shift(date, item.endDayOffset),
              end: item.end,
            ),
        ],
      );

  /// Save (spec 4.2).
  Future<SaveResult?> save() async {
    final edit = _edit;
    if (edit == null) return null;
    final result = await edit.save(_confirm);
    _settled(edit, result);
    return result;
  }

  /// Undo (spec 4.2, 4.3).
  Future<SaveResult?> undo() async {
    final edit = _edit;
    if (edit == null) return null;
    final result = await edit.undo(_confirm);
    // An untouched or discarded new row leaves the sheet.
    if (edit.isNew &&
        identical(edit, _edit) &&
        (result == SaveResult.reverted || result == SaveResult.clean)) {
      _close();
      _selectedId = null;
      _notify();
    } else {
      _settled(edit, result);
    }
    return result;
  }

  /// Reload record, or Reload and check after an uncertain save (spec 9),
  /// from the toolbar or the quit window.
  Future<void> reload() async {
    final edit = _edit;
    if (edit == null) return;
    await edit.reload();
    _settled(edit, null);
  }

  /// Discard and return to sheet (spec 9): the selected record no longer
  /// exists, so its pending values are dropped and nothing is selected.
  Future<void> discardAndReturn() async {
    if (!(_edit?.session.gone ?? false)) return;
    ++_opening;
    _replace(null, null);
    _notify();
  }

  /// Takes [value] for [field] of row [rowId] into the selected record's
  /// pending values; returns the problem that keeps it in its editor.
  String? editField(String rowId, String field, Object? value) {
    final edit = _edit;
    if (rowId != _selectedId || edit == null) {
      return ShiftsEditProblems.notEditable;
    }
    return edit.set(field, value);
  }

  /// Opens the [kind] panel on the selected stored shift (spec 4.2, 4.4).
  /// A pending edit is resolved first, as for leaving the record; the
  /// panel then replaces the record's edit, on the shift as stored now.
  /// Returns whether it opened.
  Future<bool> openAction(ShiftsActionKind kind) async {
    final blocked = switch (kind) {
      ShiftsActionKind.correct => correctBlocked,
      ShiftsActionKind.voidShift => voidBlocked,
    };
    final row = selectedRow;
    if (blocked != null || row is! StoredRow) return false;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final record = await _readShift(row.shift.id);
    if (ticket != _opening) return false;
    final state = record?.shift.state;
    final fits = switch (kind) {
      ShiftsActionKind.correct => state == ShiftState.finalized,
      ShiftsActionKind.voidShift => state != null && state != ShiftState.voided,
    };
    if (record == null || !fits) {
      // It changed meanwhile: show it as it is now.
      await _openShift(row.shift.id, ticket);
      await _readInputs(ticket);
      return false;
    }
    final action = ShiftsAction(
      kind: kind,
      shift: record.shift,
      lifecycle: work.shifts,
      reads: reads,
      newShiftId: work.shiftIds.shiftId,
      onCheck: submitAction,
    );
    _replace(
      null,
      row.id,
      reason:
          shiftReadOnlyReason(record.shift) ?? ShiftsCommandWords.actionOpen,
    );
    _action = action;
    coordinator.add(action);
    action.addListener(_notify);
    await _readInputs(ticket);
    return true;
  }

  /// Opens the [kind] panel on the selected planned day (plan 4d-1, call
  /// 6). A pending edit is resolved first; the panel then opens on the day
  /// as stored now. Returns whether it opened.
  Future<bool> openDayAction(DayActionKind kind) async {
    if (_dayActionBlocked != null) return false;
    final id = _selectedId!;
    final date = selectedRow!.date;
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final ticket = ++_opening;
    final record = await readPlannedDay(work.plans, employmentId, date);
    if (ticket != _opening || _disposed) return false;
    if (record == null) {
      // It changed meanwhile: show it as it is now, confirmed included.
      await _showConfirmedOr(date, ticket);
      return false;
    }
    final action = DayAction(
      kind: kind,
      employmentId: employmentId,
      day: record.day,
      exception: record.exception,
      plans: work.plans,
      onCheck: submitDayAction,
    );
    _replace(null, id, reason: ShiftsCommandWords.actionOpen);
    _dayAction = action;
    coordinator.add(action);
    action.addListener(_notify);
    await _readInputs(ticket);
    return true;
  }

  /// The day panel's primary key: runs its command, or checks one whose
  /// result was not known. Once stored, the day is selected as it now is.
  Future<void> submitDayAction() => _tracked(_submitDayAction);

  Future<void> _submitDayAction() async {
    final action = _dayAction;
    if (action == null) return;
    if (!await action.submit() || !identical(action, _dayAction)) return;
    final ticket = ++_opening;
    try {
      await _openDay(action.date, ticket);
    } on Object {
      if (ticket == _opening && identical(action, _dayAction)) {
        action.openingFailed();
      }
      return;
    }
    if (ticket != _opening) return;
    _notice = switch (action.kind) {
      DayActionKind.cancel => DayActionWords.cancelled(action.date),
      DayActionKind.leave => DayActionWords.markedLeave(
        action.date,
        action.leaveType,
      ),
    };
    _notify();
  }

  /// The day panel's Cancel: once it lets go (input asks first), the day
  /// opens again as it was.
  Future<void> cancelDayAction() async {
    final action = _dayAction;
    if (action == null) return;
    if (await action.leave(_confirm) == LeaveDecision.stay) return;
    if (!identical(action, _dayAction)) return;
    final id = _selectedId;
    _closeAction();
    if (id == null) {
      _notify();
    } else {
      await _open(id);
    }
  }

  /// Selects what confirming [date] made, saying it is already confirmed;
  /// else the day as the plan holds it now.
  Future<void> _showConfirmedOr(LocalDate date, int ticket) async {
    ConfirmedDay? made;
    try {
      made = await confirmedOn(work.plans, reads, employmentId, date);
    } on Object {
      made = null;
    }
    if (ticket != _opening || _disposed) return;
    switch (made) {
      case ConfirmedShift(:final shift):
        _replace(
          null,
          shiftRowId(shift.id),
          reason: shiftReadOnlyReason(shift),
        );
      case ConfirmedLeave(:final leave):
        _replace(null, leaveRowId(leave.id), reason: ShiftsNotices.leaveTaken);
      case null:
        return _openDay(date, ticket);
    }
    _notice = DayCommandWords.alreadyConfirmed;
    await _readInputs(ticket);
  }

  /// Selects the day on [date] as the plan holds it now, whatever the rows
  /// say yet: a planned day ready to edit, or its row read-only with why.
  Future<void> _openDay(LocalDate date, int ticket) async {
    final inputs = await work.plans.repository.planInputs(employmentId);
    if (ticket != _opening) return;
    final day = planDays(
      from: date,
      to: date,
      schedules: inputs.schedules,
      exceptions: inputs.exceptions,
      confirmedDates: inputs.confirmedDates,
      zoneClocks: work.plans.zoneClocks,
    ).firstOrNull;
    final id = plannedRowId(date);
    switch (day) {
      case PlannedShift():
        final record = await readPlannedDay(work.plans, employmentId, date);
        if (ticket != _opening) return;
        _replace(
          record == null ? null : _plannedEdit(record),
          id,
          reason: record == null ? ShiftsNotices.notPlanned : null,
        );
      case PlannedLeave():
        final record = await readLeaveDay(work.plans, employmentId, date);
        if (ticket != _opening) return;
        _replace(
          record == null ? null : _leaveEdit(record),
          id,
          reason: record == null ? ShiftsNotices.leaveDay : null,
        );
      case CancelledPlan():
        _replace(null, id, reason: ShiftsNotices.cancelledDay);
      case NeedsReview():
        _replace(null, id, reason: ShiftsNotices.needsReview);
      case OffDay() || null:
        _replace(null, null);
    }
    _inputs = inputs;
    _notify();
  }

  /// The open panel's primary key: runs its command, or checks one whose
  /// result was not known. Once it commits, a correction selects its
  /// replacement draft, ready to edit, and a void its read-only void shift.
  Future<void> submitAction() => _tracked(_submitAction);

  Future<void> _submitAction() async {
    final action = _action;
    if (action == null) return;
    final produced = await action.submit();
    if (produced == null || !identical(action, _action)) return;
    final ticket = ++_opening;
    try {
      // Keep the panel locked until all reads needed to open the saved
      // record succeed. Retrying this step must never repeat its command.
      final record = await _readShift(produced.id);
      final inputs = await work.plans.repository.planInputs(employmentId);
      if (ticket != _opening || !identical(action, _action)) return;
      _showShift(produced.id, record);
      _inputs = inputs;
      _notice = record == null
          ? ShiftsNotices.gone
          : switch (action.kind) {
              ShiftsActionKind.correct => ShiftsNotices.corrected,
              ShiftsActionKind.voidShift => ShiftsNotices.voided,
            };
      _notify();
    } on Object {
      if (ticket == _opening && identical(action, _action)) {
        action.openingFailed();
      }
    }
  }

  /// The panel's Cancel: once the panel lets go (a reason entered asks
  /// first), the record opens again as it was.
  Future<void> cancelAction() async {
    final action = _action;
    if (action == null) return;
    if (await action.leave(_confirm) == LeaveDecision.stay) return;
    if (!identical(action, _action)) return;
    final id = _selectedId;
    _closeAction();
    if (id == null) {
      _notify();
    } else {
      await _open(id);
    }
  }

  /// Remove change (owner decision 2026-10-13): drops the change of the
  /// selected Needs review day through `DayPlanService.removeException`,
  /// so the day follows its schedule again, then opens the day as it is
  /// now: a planned day ready to edit, or no selection when the schedule
  /// plans no work on it. Nothing is asked: the change is already ignored,
  /// so removing it changes no pay.
  Future<void> removeChange() => _tracked(_removeChange);

  Future<void> _removeChange() async {
    final row = selectedRow;
    if (removeChangeBlocked != null || row is! ReviewRow) return;
    await _removeException(
      row,
      row.exception,
      done: ShiftsNotices.restored,
      doneOff: ShiftsNotices.restoredOff,
      kept: ShiftsNotices.needsReview,
    );
  }

  /// The change of the selected day that Restore shift removes: a changed,
  /// extra, cancelled or leave day not yet confirmed.
  DayException? get _restorable {
    final row = selectedRow;
    final applies = switch (row) {
      PlannedRow(:final planned) => planned.day.changed || planned.day.isExtra,
      CancelledRow() || LeaveRow() => true,
      _ => false,
    };
    if (!applies) return null;
    return _feedInputs?.exceptions
        .where((value) => value.date == row!.date)
        .firstOrNull;
  }

  /// Why Restore shift does not apply to the selected row; null when it
  /// does.
  String? get restoreBlocked {
    if (_archived) return EmploymentsWords.archivedReadOnly;
    if (_panelOpen) return ShiftsCommandWords.actionOpen;
    if (_removing || _confirming || (_edit?.frozen ?? false)) {
      return ShiftsCommandWords.busy;
    }
    return _restorable == null ? DayCommandWords.restoreOnly : null;
  }

  /// Restore shift's words: on an extra day, the old day sheet's
  /// Remove extra shift.
  String get restoreLabel => switch (selectedRow) {
    PlannedRow(:final planned) when planned.day.isExtra => 'Remove extra shift',
    _ => 'Restore shift',
  };

  /// Restore shift (plan 4d-1, call 5): removes the selected day's change
  /// through `DayPlanService.removeException`, after its pending edit is
  /// resolved, so the day follows its schedule again. Nothing is asked: no
  /// pay is final yet.
  Future<void> restoreShift() => _tracked(_restore);

  Future<void> _restore() async {
    if (restoreBlocked != null) return;
    if (!await coordinator.navigate(() {}) || _disposed) return;
    final row = selectedRow;
    // The change as the owner last saw it: an open edit's session holds the
    // revision its own save just made; other days show the sheet's.
    final exception = switch (_edit) {
      PlannedEdit(:final session) => session.baseline?.exception,
      LeaveEdit(:final record) => record.exception,
      _ => _restorable,
    };
    if (row == null || exception == null) return;
    await _removeException(
      row,
      exception,
      done: DayCommandWords.restored,
      doneOff: DayCommandWords.extraRemoved,
      kept: null,
    );
  }

  /// Removes [exception] of [row]'s day, then opens the day as it is now:
  /// a planned day ready to edit, no selection when the schedule plans no
  /// work on it, or [row] read-only with [kept] (null: the day's own
  /// reason) when the change stayed. Its notice is [done] or [doneOff]
  /// when removed, else why not.
  Future<void> _removeException(
    ShiftsRow row,
    DayException exception, {
    required String done,
    required String doneOff,
    required String? kept,
  }) async {
    final guard = _RemovalLeaveGuard(_command!);
    coordinator.add(guard);
    try {
      await _performRemoval(
        row,
        exception,
        done: done,
        doneOff: doneOff,
        kept: kept,
      );
    } finally {
      guard.active = false;
      coordinator.remove(guard);
      _removing = false;
      _notify();
    }
  }

  Future<void> _performRemoval(
    ShiftsRow row,
    DayException exception, {
    required String done,
    required String doneOff,
    required String? kept,
  }) async {
    final ticket = ++_opening;
    _removing = true;
    _notify();
    final outcome = await work.plans.removeException(
      exception.id,
      expected: exception.revision,
    );
    final removed = switch (outcome) {
      Committed() => true,
      Uncertain() => await _removedAfterAll(exception),
      _ => false,
    };
    _removing = false;
    if (ticket != _opening) return _notify();
    final record = await readPlannedDay(work.plans, employmentId, row.date);
    if (ticket != _opening) return _notify();
    if (record != null) {
      _replace(_plannedEdit(record), plannedRowId(row.date));
    } else if (removed == true) {
      _replace(null, null);
    } else {
      _replace(null, row.id, reason: kept ?? _reasonOf(row));
    }
    _notice = switch ((removed, outcome)) {
      (true, _) when record != null => done,
      (true, _) => doneOff,
      (null, _) => ShiftsNotices.removeUnknown,
      (_, Uncertain()) => ShiftsNotices.removeNotDone,
      (_, Invalid()) => PlannedDayProblems.confirmed,
      (_, Unavailable()) => ShiftsActionWords.unavailable,
      _ => ShiftsNotices.reviewChanged,
    };
    await _readInputs(ticket);
  }

  /// Why [row] is read-only when it opens without an edit.
  String? _reasonOf(ShiftsRow row) => switch (row) {
    LeaveRow() => ShiftsNotices.leaveDay,
    CancelledRow() => ShiftsNotices.cancelledDay,
    LeaveTakenRow() => ShiftsNotices.leaveTaken,
    ReviewRow() => ShiftsNotices.needsReview,
    OffRow() => ShiftsNotices.offDay,
    _ => null,
  };

  /// Confirm (owner pick 3B, 2026-10-20): confirms the selected day at
  /// once, after its pending change is resolved, then selects what it made
  /// (its finalized shift or confirmed leave) and says so. Nothing is
  /// asked; Correct… or Void… changes it later.
  Future<void> confirmDay() => _tracked(_confirmSelected);

  Future<void> _confirmSelected() async {
    if (confirmBlocked != null) return;
    final id = _selectedId!;
    if (!await coordinator.navigate(() {}) || _disposed) return;
    final row = _rowById(id);
    if (row is! PlannedRow && row is! LeaveRow) return;
    final date = row!.date;
    final ticket = ++_opening;
    _confirming = true;
    _notify();
    MutationOutcome<ConfirmedDay> outcome;
    try {
      outcome = await _confirmCommand(employmentId, date);
    } on Object {
      outcome = const Uncertain<ConfirmedDay>(
        SafeFailureCode.storageUnavailable,
      );
    }
    ConfirmedDay? made;
    String? words;
    switch (outcome) {
      case Committed(:final value):
        made = value;
      case Uncertain():
        try {
          made = await confirmedOn(work.plans, reads, employmentId, date);
          if (made == null) words = DayCommandWords.notDone;
        } on Object {
          words = DayCommandWords.unknown;
        }
      case Stale():
        words = DayCommandWords.alreadyConfirmed;
        try {
          made = await confirmedOn(work.plans, reads, employmentId, date);
        } on Object {
          made = null;
        }
      case Invalid(:final fields) when fields.containsKey('agreement'):
        words = DayCommandWords.noAgreement;
      case Unavailable():
        words = ShiftsActionWords.unavailable;
      case Invalid() || Missing():
        words = ShiftsNotices.reviewChanged;
    }
    _confirming = false;
    if (ticket != _opening || _disposed) return _notify();
    switch (made) {
      case ConfirmedShift(:final shift):
        _replace(
          null,
          shiftRowId(shift.id),
          reason: shiftReadOnlyReason(shift),
        );
        words ??= DayCommandWords.confirmed(date);
      case ConfirmedLeave(:final leave):
        _replace(null, leaveRowId(leave.id), reason: ShiftsNotices.leaveTaken);
        words ??= DayCommandWords.confirmedLeave(date);
      case null:
        await _open(id);
        if (ticket + 1 != _opening) return;
    }
    _notice = words;
    await _readInputs(ticket);
  }

  /// After an uncertain Remove change: whether the change is gone (true),
  /// still there unchanged (false), or neither can be told (null).
  Future<bool?> _removedAfterAll(DayException exception) async {
    try {
      final now = (await work.plans.repository.planInputs(employmentId))
          .exceptions
          .where((value) => value.id == exception.id)
          .firstOrNull;
      if (now == null) return true;
      return now.revision == exception.revision ? false : null;
    } on Object {
      return null;
    }
  }

  /// A shift that committed is finalized now (spec 4.2): it is selected
  /// under its stored id and read-only, so its session ends.
  void _settled(ShiftsEdit edit, SaveResult? result) {
    if (!identical(edit, _edit)) return;
    // A new extra shift, once stored, is its planned day.
    if (edit case PlannedEdit(:final session, :final date)
        when _selectedId == newExtraRowId && session.baseline != null) {
      _selectedId = plannedRowId(date);
    }
    if (edit case StoredEdit(:final session)) {
      if (session.baseline case final saved?) {
        final reason = shiftReadOnlyReason(saved.shift);
        if (reason != null) {
          _replace(null, storedRowId(saved.shift), reason: reason);
        } else if (_selectedId == newRowId) {
          _selectedId = storedRowId(saved.shift);
        }
      }
    }
    _notify();
  }

  Future<void> _open(String id) async {
    final ticket = ++_opening;
    final row = _rowById(id);
    if (_archived && row != null) {
      _replace(null, id, reason: EmploymentsWords.archivedReadOnly);
      await _readInputs(ticket);
      return;
    }
    if (row is PlannedRow || row is StoredRow || row is LeaveRow) {
      // The last record is let go and [id] is the selection while it is
      // read, so choosing the last one again opens it again.
      _replace(null, id, reason: ShiftsNotices.opening);
      _notify();
    }
    switch (row) {
      case PlannedRow(:final date):
        final record = await readPlannedDay(work.plans, employmentId, date);
        if (ticket != _opening) return;
        if (record == null) {
          _replace(null, id, reason: ShiftsNotices.notPlanned);
        } else {
          _replace(_plannedEdit(record), id);
        }
      case ReviewRow():
        _replace(null, id, reason: ShiftsNotices.needsReview);
      case OffRow():
        _replace(null, id, reason: ShiftsNotices.offDay);
      case LeaveRow(:final date):
        final record = await readLeaveDay(work.plans, employmentId, date);
        if (ticket != _opening) return;
        _replace(
          record == null ? null : _leaveEdit(record),
          id,
          reason: record == null ? ShiftsNotices.leaveDay : null,
        );
      case CancelledRow():
        _replace(null, id, reason: ShiftsNotices.cancelledDay);
      case LeaveTakenRow():
        _replace(null, id, reason: ShiftsNotices.leaveTaken);
      case StoredRow(:final shift):
        await _openShift(shift.id, ticket);
      case null:
        _replace(null, null);
    }
    await _readInputs(ticket);
  }

  PlannedEdit _plannedEdit(PlannedDayRecord record) => PlannedEdit(
    RecordEditSession(
      adapter: PlannedDayAdapter(work.plans),
      baseline: record,
      onCheck: reload,
    ),
    typeChoices: _typesOf(record.day),
  );

  LeaveEdit _leaveEdit(LeaveDayRecord record) => LeaveEdit(
    RecordEditSession(
      adapter: LeaveDayAdapter(work.plans, date: record.date),
      baseline: record,
      onCheck: reload,
    ),
  );

  /// The shift types of the schedule version that planned [day].
  List<ShiftType> _typesOf(PlannedShift day) =>
      _feedInputs?.schedules
          .where(
            (value) =>
                value.id == day.scheduleId &&
                value.version == day.scheduleVersion,
          )
          .firstOrNull
          ?.shiftTypes ??
      const [];

  /// Selects the stored shift [id] as stored now: a draft with its edit, a
  /// finalized or void shift read-only. It need not be in the rows yet: a
  /// correction's replacement is selected before the sheet lists it.
  Future<void> _openShift(ShiftId id, int ticket) async {
    final record = await _readShift(id);
    if (ticket != _opening) return;
    _showShift(id, record);
  }

  void _showShift(ShiftId id, ShiftRecord? record) {
    final reason = record == null
        ? ShiftsNotices.gone
        : shiftReadOnlyReason(record.shift);
    if (record == null || reason != null) {
      _replace(null, shiftRowId(id), reason: reason);
    } else {
      _replace(
        StoredEdit(
          RecordEditSession(
            adapter: _shiftAdapter(defaults: null),
            baseline: record,
            onCheck: reload,
          ),
        ),
        shiftRowId(id),
      );
    }
  }

  /// Reads the plan inputs for the selected record: read-only records show
  /// their plan and pay too (subform tabs).
  Future<void> _readInputs(int ticket) async {
    if (_selectedId != null) {
      final inputs = await work.plans.repository.planInputs(employmentId);
      if (ticket == _opening) _inputs = inputs;
    }
    _notify();
  }

  ShiftAdapter _shiftAdapter({required ShiftValues? defaults}) => ShiftAdapter(
    employmentId: employmentId,
    // A stored shift never uses its defaults; any value will do.
    defaults:
        defaults ??
        ShiftValues(
          startDate: today,
          start: const LocalTime(8, 0),
          endDate: today,
          end: const LocalTime(16, 0),
          timezoneId: timezoneId,
        ),
    create: work.manualShifts,
    revise: work.draftRevisions,
    reads: reads,
    timezones: work.timezones,
    clock: work.clock,
  );

  /// Selects row [id] with [edit]; a disposed sheet takes none, so a read
  /// that finishes late joins nothing to [coordinator].
  void _replace(ShiftsEdit? edit, String? id, {String? reason}) {
    if (_disposed) {
      edit?.dispose();
      return;
    }
    _close();
    _closeAction();
    _notice = null;
    _edit = edit;
    _selectedId = id;
    _readOnlyReason = reason;
    if (edit != null) {
      coordinator.add(edit.participant);
      edit.addListener(_notify);
    }
  }

  void _close() {
    _inputs = null;
    final edit = _edit;
    if (edit == null) return;
    edit.removeListener(_notify);
    coordinator.remove(edit.participant);
    edit.dispose();
    _edit = null;
  }

  void _closeAction() {
    final action = _action;
    if (action != null) {
      action.removeListener(_notify);
      coordinator.remove(action);
      action.dispose();
      _action = null;
    }
    final day = _dayAction;
    if (day != null) {
      day.removeListener(_notify);
      coordinator.remove(day);
      day.dispose();
      _dayAction = null;
    }
    final bulk = _confirmDays;
    if (bulk != null) {
      bulk.removeListener(_notify);
      coordinator.remove(bulk);
      bulk.dispose();
      _confirmDays = null;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // A read that finishes later is dropped, and a move waiting for the
    // rows goes on.
    ++_opening;
    if (!_ready.isCompleted) _ready.complete();
    unawaited(_storedFeed?.cancel());
    unawaited(_plannedFeed?.cancel());
    unawaited(_reviewFeed?.cancel());
    _close();
    _closeAction();
    super.dispose();
  }
}

/// Navigation stays on a removal whose completion notice belongs to this
/// record. Quit waits for the one tracked command instead of dropping it.
final class _RemovalLeaveGuard implements LeaveParticipant {
  _RemovalLeaveGuard(this.command);
  final Future<void> command;
  bool active = true;
  @override
  bool get settled => !active;
  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (!active) return LeaveDecision.proceed;
    if (kind == LeaveKind.navigate) return LeaveDecision.stay;
    await command;
    return LeaveDecision.proceed;
  }
}
