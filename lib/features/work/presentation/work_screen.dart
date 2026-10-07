import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/shell/shell_frame.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/shell/task_pane.dart';
import '../../../shared/shell/working_group_box.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../application/work_templates.dart';
import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/schedule.dart';
import '../domain/shift.dart';
import 'confirm_days_dialog.dart';
import 'correction_confirmation.dart';
import 'day_sheet_host.dart';
import 'employment_agreement_forms.dart';
import 'leave_sheet.dart';
import 'period_payslip_forms.dart';
import 'record_history_panel.dart';
import 'remove_shift_dialog.dart';
import 'schedule_sheet_host.dart';
import 'shift_forms.dart';
import 'work_controller.dart' hide SetPayPeriodState;
import 'work_inspector.dart';
import 'work_plan_view.dart';
import 'work_record_names.dart';
import 'work_register.dart';
import 'work_route_state.dart';
import 'work_tasks.dart';
import 'work_views.dart';

final class WorkScreen extends StatefulWidget {
  const WorkScreen({
    required this.state,
    required this.onSelect,
    required this.onPrimaryAction,
    required this.onCreateEmployment,
    required this.onCreateAgreement,
    required this.onNavigate,
    this.onFinalize,
    this.onOpenManualShift,
    this.onSaveManualShift,
    this.systemTimezoneId,
    this.onCreatePayPeriod,
    this.onSetPeriodState,
    this.onRecordPayslip,
    this.onOpenCorrection,
    this.onCancelCorrection,
    this.onCorrectShift,
    this.onCorrectPayslip,
    this.onRemoveShift,
    this.onReviseDraft,
    this.timezones,
    this.onUpdateEmployment,
    this.onDeleteEmployment,
    this.onUpdateAgreement,
    this.today,
    this.lastShiftTemplate,
    this.onSaveView,
    this.schedules = const [],
    this.onOpenProperties,
    this.onCloseDialog,
    super.key,
  });

  final AsyncValue<WorkViewState> state;
  final ValueChanged<WorkRecordRef> onSelect;
  final VoidCallback onPrimaryAction;
  final SubmitEmployment onCreateEmployment;
  final SubmitAgreement onCreateAgreement;
  final ValueChanged<String> onNavigate;
  final MutateShift? onFinalize;
  final ValueChanged<EmploymentId>? onOpenManualShift;
  final SubmitManualShift? onSaveManualShift;
  final String? systemTimezoneId;
  final SubmitPayPeriod? onCreatePayPeriod;
  final SetPayPeriodState? onSetPeriodState;
  final SubmitPayslip? onRecordPayslip;
  final VoidCallback? onOpenCorrection;
  final VoidCallback? onCancelCorrection;
  final Future<MutationOutcome<WorkShift>> Function(
    WorkShift original,
    String reason,
  )?
  onCorrectShift;
  final Future<MutationOutcome<Payslip>> Function(
    Payslip original,
    String reason,
  )?
  onCorrectPayslip;

  /// Voids a draft or finalized shift with the owner's reason and no
  /// replacement ("Remove this shift…").
  final Future<MutationOutcome<WorkShift>> Function(
    WorkShift shift,
    String reason,
  )?
  onRemoveShift;
  final Future<MutationOutcome<WorkShift>> Function(
    WorkShift draft,
    ManualShiftDraft value,
  )?
  onReviseDraft;
  final TimezoneService? timezones;
  final Future<MutationOutcome<Employment>> Function(
    Employment current,
    EmploymentDraft value,
  )?
  onUpdateEmployment;
  final DeleteEmployment? onDeleteEmployment;
  final Future<MutationOutcome<PayAgreement>> Function(
    PayAgreement current,
    AgreementDraft value,
  )?
  onUpdateAgreement;

  /// Today's local date for new agreements; the device date when null.
  final LocalDate? today;

  /// The selected employment's schedule versions; they choose the default
  /// sheet and name a schedule's dialog.
  final List<WorkSchedule> schedules;

  /// The selected employment's last finalized shift, for "from last time".
  final ShiftTemplate? lastShiftTemplate;

  /// Saves the sheet on the desk, with its filters, as a named view.
  final ValueChanged<WorkRouteState>? onSaveView;

  /// Opens a record's Properties sheet (route `mode=properties`).
  final ValueChanged<WorkRecordRef>? onOpenProperties;

  /// Closes whatever dialog the route opened (back to `mode=inspect`).
  final VoidCallback? onCloseDialog;

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

final class _WorkScreenState extends State<WorkScreen> {
  LocalDate get _today => widget.today ?? _deviceToday();

  MutationOutcome<PayPeriod>? _periodFailure;
  bool _creatingPeriod = false;
  PayPeriodId? _payslipPeriod;
  MutationOutcome<WorkShift>? _reviseFailure;

  void _clearReviseFailure() => setState(() => _reviseFailure = null);

  Future<MutationOutcome<WorkShift>> _reviseDraft(
    WorkShift draft,
    ManualShiftDraft value,
  ) async {
    final outcome = await _saved(
      widget.onReviseDraft!(draft, value),
      'Shift saved.',
    );
    if (!mounted) return outcome;
    setState(() {
      _reviseFailure =
          outcome is Committed<WorkShift> || outcome is Invalid<WorkShift>
          ? null
          : outcome;
    });
    return outcome;
  }

  void _closeDialog() {
    setState(() {
      _creatingPeriod = false;
      _payslipPeriod = null;
      _periodFailure = null;
      _reviseFailure = null;
    });
    widget.onCloseDialog?.call();
  }

  /// Passes a mutation through and, when it committed, says so in the
  /// status bar.
  Future<MutationOutcome<T>> _saved<T>(
    Future<MutationOutcome<T>> pending,
    String notice,
  ) async {
    final outcome = await pending;
    if (outcome is Committed<T> && mounted) {
      StatusNoticeScope.read(context)?.value = notice;
    }
    return outcome;
  }

  void _clearPeriodFailure() => setState(() => _periodFailure = null);

  /// "Remove this shift…", from the task pane or the shift's sheet; null
  /// when [shift] is void or removal is not wired.
  VoidCallback? _removal(WorkShift shift) {
    final remove = widget.onRemoveShift;
    if (remove == null || shift.state == ShiftState.voided) return null;
    return () => askRemoveShift(
      context,
      shift: shift,
      onRemove: (reason) => _saved(remove(shift, reason), 'Shift removed.'),
    );
  }

  void _openPayslip(PayPeriodId period) =>
      setState(() => _payslipPeriod = period);

  Future<MutationOutcome<PayPeriod>> _createPeriod(PayPeriodDraft draft) async {
    final outcome = await _saved(
      widget.onCreatePayPeriod!(draft),
      'Pay period created.',
    );
    if (mounted && outcome is Committed<PayPeriod>) {
      setState(() => _creatingPeriod = false);
    }
    return outcome;
  }

  Future<MutationOutcome<PayPeriod>> _setPeriodState(
    PayPeriod period,
    PayPeriodState state,
  ) async {
    final outcome = await _saved(
      widget.onSetPeriodState!(period, state),
      state == PayPeriodState.reviewed
          ? 'Period marked reviewed.'
          : 'Period reopened.',
    );
    if (!mounted) return outcome;
    setState(() {
      _periodFailure = outcome is Committed<PayPeriod> ? null : outcome;
    });
    return outcome;
  }

  @override
  void didUpdateWidget(covariant WorkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRecord = _selectedRecord(oldWidget.state);
    final newRecord = _selectedRecord(widget.state);
    if (oldRecord?.id != newRecord?.id) {
      _periodFailure = null;
      _creatingPeriod = false;
      _payslipPeriod = null;
    }
    if (_routeMode(oldWidget.state) != _routeMode(widget.state)) {
      _reviseFailure = null;
      _creatingPeriod = false;
    }
    // A dialog the task pane opened belongs to the location it was opened
    // at; when the route moves (Back, Forward, a link), it closes, so a new
    // pay period can never be saved against another employment.
    final oldRoute = _routeUri(oldWidget.state);
    final newRoute = _routeUri(widget.state);
    if (oldRoute != null && newRoute != null && oldRoute != newRoute) {
      _creatingPeriod = false;
      _payslipPeriod = null;
      _periodFailure = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _current(widget.state);
    return ShellFrame(
      desk: _RegisterLandmark(child: _register(ready)),
      dialog: ready is WorkReady && _dialogOpen(ready)
          ? ShellDialog(
              title: _dialogTitle(ready),
              kind: _dialogKind(ready),
              size: _dialogSize(ready),
              fitHeight: _fitsContent(ready),
              onClose: _closeDialog,
              child: _inspector(ready),
            )
          : null,
      tasks: _taskGroups(ready),
      details: _details(ready),
    );
  }

  List<Widget> _taskGroups(WorkViewState? state) {
    if (state is! WorkReady) return const [];
    final route = state.route;
    if (route.employmentId == null) return const [];
    final register = state.register;
    final employment = register.employment;
    final selected = _selected(state);
    final ref = route.record;
    final shownRoute = route.copyWith(
      sheet: route.sheet ?? defaultSheetFor(widget.schedules, _today),
    );
    final open = widget.onOpenProperties;
    final period = selected is PayPeriodRecordProjection
        ? selected.period
        : null;
    final plannedDay = _plannedDay(state);
    return workTaskGroups(
      WorkTaskContext(
        selected: selected,
        plannedDay: plannedDay,
        dayConfirmable:
            plannedDay != null && plannedDay.day.date.compareTo(_today) <= 0,
        onOpenDay: () =>
            _go(route.copyWith(mode: WorkInspectorMode.properties)),
        onConfirmDays: widget.schedules.isEmpty
            ? null
            : () => _go(route.copyWith(confirming: true)),
        onAddShift: widget.onPrimaryAction,
        onNewPeriod: widget.onCreatePayPeriod == null
            ? null
            : () => setState(() => _creatingPeriod = true),
        onRecordPayslip:
            widget.onRecordPayslip == null || register.period == null
            ? null
            : () => setState(() => _payslipPeriod = register.period!.id),
        // Calendar and Schedules are not saved as views; no link, not a dead
        // one.
        onSaveView:
            widget.onSaveView == null || workViewShape(shownRoute) == null
            ? null
            : () => widget.onSaveView!(shownRoute),
        onProperties: ref == null || open == null ? null : () => open(ref),
        onEmploymentProperties: employment == null || open == null
            ? null
            : () => open(
                WorkRecordRef(
                  kind: WorkRecordKind.employment,
                  id: employment.id,
                ),
              ),
        onNewSchedule: register.hasAgreement
            ? () => _go(route.copyWith(adding: () => WorkAddKind.schedule))
            : null,
        onSetUpAgreement: employment == null || register.hasAgreement
            ? null
            : () => _go(route.copyWith(adding: () => WorkAddKind.agreement)),
        // Finalizing happens on the shift's Properties sheet.
        onFinalize: ref == null || open == null ? null : () => open(ref),
        onCorrect: widget.onOpenCorrection,
        onRemove: selected is ShiftRecordProjection
            ? _removal(selected.shift)
            : null,
        onMarkReviewed: period == null || widget.onSetPeriodState == null
            ? null
            : () => _setPeriodState(period, PayPeriodState.reviewed),
        onReopen: period == null || widget.onSetPeriodState == null
            ? null
            : () => _setPeriodState(period, PayPeriodState.open),
        onRecordPayslipForPeriod:
            period == null || widget.onRecordPayslip == null
            ? null
            : () => setState(() => _payslipPeriod = period.id),
      ),
    );
  }

  Widget? _details(WorkViewState? state) {
    if (state is! WorkReady) return null;
    final chrome = ShellChrome.maybeOf(context);
    final selected = _selected(state);
    final register = state.register;
    final Widget scope = register.employment == null
        ? const SizedBox.shrink()
        : register.hasAgreement
        ? WorkDetails(
            projection: register,
            listsPlanned:
                (state.route.sheet ??
                    defaultSheetFor(widget.schedules, _today)) ==
                WorkSheet.shifts,
          )
        : const TaskDetails(lines: [Text('No pay agreement yet.')]);
    // The selected record leads; the scope's totals stay under it, so a
    // period's expected and paid figures never leave the pane.
    final plannedDay = _plannedDay(state);
    final Widget? summary = selected != null
        ? RecordSummary(record: selected, timezones: widget.timezones)
        : plannedDay != null
        ? PlannedDaySummary(
            row: plannedDay,
            timezones: widget.timezones ?? IanaTimezoneService(),
          )
        : null;
    final Widget fallback = summary == null
        ? scope
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 8), scope],
          );
    return WorkingDetails(
      onNavigate: (route) => chrome?.onNavigate(route.toString()),
      fallback: fallback,
    );
  }

  Widget _register(WorkViewState? state) {
    // A refresh keeps showing the previous register, so opening a record
    // does not tear the list down (and with it the cell selection).
    if (widget.state.isLoading && !widget.state.hasValue) {
      return const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Loading Work records',
        message: 'Reading the current local register.',
      );
    }
    if (widget.state.hasError) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Work records unavailable',
        message: 'Reload Work to inspect the current records.',
      );
    }
    return switch (state) {
      WorkInvalidScope() => const OperationalState(
        kind: OperationalStateKind.invalidScope,
        title: 'Invalid Work scope',
        message: 'Choose a valid period or explicit date range.',
      ),
      WorkReady(:final register, :final route) => WorkRegister(
        today: _today,
        defaultSheet: defaultSheetFor(widget.schedules, _today),
        projection: register,
        selectedRecord: route.record,
        onSelect: widget.onSelect,
        onPrimaryAction: widget.onPrimaryAction,
        onOpenEmployment: (id) => widget.onNavigate(
          workRouteUri(
            WorkRouteState(
              employmentId: id,
              scope: null,
              record: null,
              mode: WorkInspectorMode.inspect,
            ),
          ).toString(),
        ),
        onAllEmployments: () => _go(
          const WorkRouteState(
            employmentId: null,
            scope: null,
            record: null,
            mode: WorkInspectorMode.inspect,
          ),
        ),
        onCreateEmployment: () => _go(
          const WorkRouteState(
            employmentId: null,
            scope: null,
            record: null,
            mode: WorkInspectorMode.create,
          ),
        ),
        route: route,
        onRoute: _go,
        onProperties: widget.onOpenProperties,
        timezones: widget.timezones,
      ),
      null => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Work records unavailable',
        message: 'Reload Work to inspect the current records.',
      ),
    };
  }

  Widget _inspector(WorkViewState? state) {
    if (state is! WorkReady) {
      return const OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Select a Work record',
        message: 'The selected record will remain beside the register.',
      );
    }
    final route = state.route;
    final employmentId = route.employmentId;
    if (route.day case final day?
        when employmentId != null && route.record == null) {
      return DaySheetHost(
        key: ValueKey(('day-sheet', day)),
        employmentId: employmentId,
        date: day,
        today: _today,
      );
    }
    if (route.confirming && employmentId != null) {
      return ConfirmDaysHost(employmentId: employmentId);
    }
    if (route.record
        case WorkRecordRef(
          kind: WorkRecordKind.schedule,
          id: final ScheduleId id,
        )
        when employmentId != null &&
            route.mode == WorkInspectorMode.properties) {
      return ScheduleSheetHost(
        key: ValueKey(('schedule-sheet', id)),
        employmentId: employmentId,
        employmentName: state.register.employment?.name ?? 'Employment',
        scheduleId: id,
        today: _today,
        defaultTimezoneId: widget.systemTimezoneId ?? '',
        onCreated: () {},
        onDeleted: _closeDialog,
      );
    }
    if (route.record == null && employmentId != null) {
      final added = _added(route.adding, state.register, employmentId);
      if (added != null) return added;
    }
    if (_creatingPeriod && employmentId != null) {
      return PeriodInspector.create(
        key: ValueKey(('create-period', employmentId)),
        employmentId: employmentId,
        onSubmit: _createPeriod,
        today: _today,
      );
    }
    final recordPayslip = widget.onRecordPayslip;
    if (_payslipPeriod case final periodId? when recordPayslip != null) {
      return PayslipInspector.create(
        periodId: periodId,
        onSubmit: (value) => _saved(recordPayslip(value), 'Payslip recorded.'),
        today: _today,
      );
    }
    if (_settingUpAgreement(state)) {
      final employment = state.register.employment!;
      return AgreementForm(
        key: ValueKey(employment.id),
        employmentId: employment.id,
        today: widget.today,
        onSubmit: (value) =>
            _saved(widget.onCreateAgreement(value), 'Pay agreement saved.'),
      );
    }
    if (route.mode == WorkInspectorMode.create && route.record == null) {
      final employment = route.employmentId;
      if (employment != null) {
        final open = widget.onOpenManualShift;
        return ShiftCreateInspector(
          onAddManualShift: open == null ? null : () => open(employment),
        );
      }
      return EmploymentForm(
        onSubmit: (value) =>
            _saved(widget.onCreateEmployment(value), 'Employment saved.'),
      );
    }
    final save = widget.onSaveManualShift;
    if (route.mode == WorkInspectorMode.edit &&
        route.record == null &&
        route.employmentId != null &&
        save != null) {
      final template = route.fromLast ? widget.lastShiftTemplate : null;
      return ShiftEditInspector(
        key: ValueKey(('manual-shift', template != null)),
        employmentId: route.employmentId!,
        today: _today,
        initialTimezoneId: widget.systemTimezoneId,
        title: template == null
            ? 'Manual shift'
            : 'Manual shift from last time',
        prefill: template == null
            ? null
            : ShiftFormPrefill.fromTemplate(template, _today),
        onSubmit: (value) => _saved(save(value), 'Shift saved.'),
      );
    }
    return switch (state.inspector) {
      WorkInspectorEmpty() => const OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Select a Work record',
        message: 'The selected record will remain beside the register.',
      ),
      WorkInspectorUnavailable() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Work record unavailable',
        message: 'The requested record is not available in this scope.',
      ),
      WorkInspectorRecord(:final record)
          when route.mode == WorkInspectorMode.correct =>
        _correction(record),
      WorkInspectorRecord(
        record: EmploymentRecordProjection(:final employment),
      ) =>
        _employmentSheet(state.register, employment),
      WorkInspectorRecord(record: LeaveRecordProjection(:final leave)) =>
        LeavePropertiesHost(
          key: ValueKey(('leave', leave.id, leave.revision)),
          leave: leave,
          pay: state.register.leaveSheet
              .where((row) => row.record.id == leave.id)
              .firstOrNull
              ?.pay,
          today: _today,
        ),
      WorkInspectorRecord(record: final AgreementRecordProjection record) =>
        _agreement(record),
      WorkInspectorRecord(:final record) => _recordInspector(
        record,
        state.register,
      ),
    };
  }
}

LocalDate _deviceToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

extension on _WorkScreenState {
  /// The create form a route's `add=` opens (shell spec 6.7).
  Widget? _added(
    WorkAddKind? adding,
    WorkRegisterProjection register,
    EmploymentId employmentId,
  ) {
    switch (adding) {
      case WorkAddKind.payPeriod when widget.onCreatePayPeriod != null:
        return PeriodInspector.create(
          key: ValueKey(('create-period', employmentId)),
          employmentId: employmentId,
          onSubmit: _createPeriod,
          today: _today,
        );
      case WorkAddKind.payslip when widget.onRecordPayslip != null:
        final period =
            register.period ??
            register.periodSheet.map((row) => row.period).lastOrNull;
        if (period == null) {
          return const OperationalState(
            kind: OperationalStateKind.empty,
            title: 'No pay period yet',
            message: 'Add a pay period first, then record its payslip.',
          );
        }
        return PayslipInspector.create(
          key: ValueKey(('add-payslip', period.id)),
          periodId: period.id,
          onSubmit: (value) =>
              _saved(widget.onRecordPayslip!(value), 'Payslip recorded.'),
          today: _today,
        );
      case WorkAddKind.agreement:
        return AgreementForm(
          key: ValueKey(('add-agreement', employmentId)),
          employmentId: employmentId,
          today: widget.today,
          onSubmit: (value) =>
              _saved(widget.onCreateAgreement(value), 'Pay agreement saved.'),
        );
      case WorkAddKind.schedule:
        return ScheduleSheetHost(
          key: ValueKey(('add-schedule', employmentId)),
          employmentId: employmentId,
          employmentName: register.employment?.name ?? 'Employment',
          scheduleId: null,
          today: _today,
          defaultTimezoneId: widget.systemTimezoneId ?? '',
          onCreated: () => _go(
            WorkRouteState(
              employmentId: employmentId,
              scope: null,
              record: null,
              mode: WorkInspectorMode.inspect,
              sheet: WorkSheet.calendar,
            ),
          ),
          onDeleted: () {},
        );
      case WorkAddKind.extraShift || WorkAddKind.leave:
        return AddDayHost(
          key: ValueKey(('add-day', adding, employmentId)),
          employmentId: employmentId,
          kind: adding == WorkAddKind.extraShift
              ? AddDayKind.extraShift
              : AddDayKind.leave,
          today: _today,
        );
      case WorkAddKind.payPeriod || WorkAddKind.payslip || null:
        return null;
    }
  }

  bool _dialogOpen(WorkReady state) {
    final route = state.route;
    return route.mode != WorkInspectorMode.inspect ||
        route.confirming ||
        route.adding != null ||
        _creatingPeriod ||
        _payslipPeriod != null ||
        _periodFailure != null ||
        _reviseFailure != null;
  }

  /// The planned day selected on the Shifts sheet: the route's day while
  /// no record is open, when the scope still plans it.
  PlannedShiftRow? _plannedDay(WorkReady state) {
    final route = state.route;
    final day = route.day;
    if (day == null || route.record != null) return null;
    return state.register.plannedShiftSheet
        .where((row) => row.day.date == day)
        .firstOrNull;
  }

  WorkRecordProjection? _selected(WorkReady state) => switch (state.inspector) {
    WorkInspectorRecord(:final record) => record,
    _ => null,
  };

  /// Setup's next step after a new employment: its pay agreement.
  bool _settingUpAgreement(WorkReady state) =>
      state.route.mode == WorkInspectorMode.create &&
      state.route.record == null &&
      state.register.employment != null &&
      !state.register.hasAgreement;

  // A failed revision shows above its form, so only a period failure is a
  // message box of its own.
  bool _failed() => _periodFailure != null;

  ShellDialogKind _dialogKind(WorkReady state) => _failed()
      ? ShellDialogKind.message
      : state.route.mode == WorkInspectorMode.properties
      ? ShellDialogKind.properties
      : ShellDialogKind.form;

  /// A message box or the one-key Record work step fits its content.
  bool _fitsContent(WorkReady state) {
    final route = state.route;
    final recordWork =
        route.mode == WorkInspectorMode.create &&
        route.record == null &&
        route.employmentId != null &&
        route.adding == null &&
        !_creatingPeriod &&
        _payslipPeriod == null &&
        !_settingUpAgreement(state);
    return _failed() || recordWork;
  }

  Size _dialogSize(WorkReady state) {
    if (_failed()) return const Size(380, 260);
    if (state.route.confirming) return const Size(600, 480);
    if (state.route.adding == WorkAddKind.schedule ||
        state.route.record?.kind == WorkRecordKind.schedule) {
      return const Size(560, 620);
    }
    // As tall as a form: a sheet's General page holds the record's fields.
    if (state.route.mode == WorkInspectorMode.properties) {
      return const Size(440, 560);
    }
    final agreement =
        state.route.adding == WorkAddKind.agreement ||
        _settingUpAgreement(state) ||
        _selected(state) is AgreementRecordProjection;
    return agreement ? const Size(480, 600) : const Size(440, 560);
  }

  String _dialogTitle(WorkReady state) {
    final route = state.route;
    if (_failed()) return 'Work';
    if (route.day case final day? when route.record == null) {
      return spokenDate(day);
    }
    if (route.confirming) return 'Confirm worked days';
    if (_creatingPeriod || route.adding == WorkAddKind.payPeriod) {
      return 'New pay period';
    }
    if (_payslipPeriod != null || route.adding == WorkAddKind.payslip) {
      return 'Record payslip';
    }
    if (route.adding == WorkAddKind.agreement || _settingUpAgreement(state)) {
      return 'Pay agreement';
    }
    if (route.adding == WorkAddKind.schedule) return 'New schedule';
    if (route.adding == WorkAddKind.extraShift) return 'Extra shift';
    if (route.adding == WorkAddKind.leave) return 'Leave';
    if (route.record case WorkRecordRef(
      kind: WorkRecordKind.schedule,
      :final id,
    )) {
      final name = widget.schedules
          .where((value) => value.id == id)
          .map((value) => value.name)
          .firstOrNull;
      return '${name ?? 'Schedule'} Properties';
    }
    final record = _selected(state);
    return switch (route.mode) {
      WorkInspectorMode.create =>
        route.employmentId == null ? 'New employment' : 'Record work',
      // Only a new manual shift has an edit form; records open as sheets.
      WorkInspectorMode.edit =>
        route.fromLast && widget.lastShiftTemplate != null
            ? 'Manual shift from last time'
            : 'Manual shift',
      WorkInspectorMode.correct =>
        record is PayslipRecordProjection ? 'Correct payslip' : 'Correct shift',
      WorkInspectorMode.properties || WorkInspectorMode.inspect =>
        record == null ? 'Work record' : '${recordName(record)} Properties',
    };
  }

  void _go(WorkRouteState route) =>
      widget.onNavigate(workRouteUri(route).toString());

  /// The employment's property sheet: General, edited in place, and
  /// History.
  Widget _employmentSheet(
    WorkRegisterProjection register,
    Employment employment,
  ) {
    final agreement = register.currentAgreement;
    final delete = widget.onDeleteEmployment;
    final update = widget.onUpdateEmployment;
    return RecordTabs(
      key: ValueKey(('tabs', employment.id)),
      record: WorkRecordRef(kind: WorkRecordKind.employment, id: employment.id),
      details: EmploymentSheet(
        key: ValueKey(('employment', employment.id)),
        employment: employment,
        agreement: agreement,
        agreementInUse: register.agreementInUse,
        canDelete: register.canDeleteEmployment && delete != null,
        onSubmit: update == null
            ? (_) async => const Unavailable<Employment>(
                SafeFailureCode.storageUnavailable,
              )
            : (value) => _saved(update(employment, value), 'Employment saved.'),
        onDelete: delete != null
            ? (value) => _saved(delete(value), 'Employment deleted.')
            : (_) async => const Unavailable<Employment>(
                SafeFailureCode.storageUnavailable,
              ),
        // Opens the agreement's own property sheet.
        onViewAgreement: agreement == null
            ? null
            : () => _go(
                WorkRouteState(
                  employmentId: employment.id,
                  scope: null,
                  record: WorkRecordRef(
                    kind: WorkRecordKind.agreement,
                    id: agreement.id,
                  ),
                  mode: WorkInspectorMode.properties,
                ),
              ),
      ),
    );
  }

  /// The agreement's property sheet: Rate, Premiums, Leave, Notes and
  /// History, edited in place while no finished shift uses it.
  Widget _agreement(AgreementRecordProjection record) {
    final agreement = record.agreement;
    final update = widget.onUpdateAgreement;
    final shifts = record.finishedShifts;
    return AgreementForm(
      key: ValueKey(('agreement', agreement.id, agreement.revision)),
      employmentId: agreement.employmentId,
      initial: agreement,
      readOnly: record.inUse || update == null,
      lockedReason: record.inUse
          ? 'Used by $shifts finished ${shifts == 1 ? 'shift' : 'shifts'}, '
                'so these terms can no longer change.'
          : null,
      historyRecord: WorkRecordRef(
        kind: WorkRecordKind.agreement,
        id: agreement.id,
      ),
      onSubmit: update == null
          ? (_) async => const Unavailable<PayAgreement>(
              SafeFailureCode.storageUnavailable,
            )
          : (value) => _saved(update(agreement, value), 'Pay agreement saved.'),
    );
  }

  Widget _reviseOutcome(
    MutationOutcome<WorkShift> outcome, {
    required VoidCallback dismiss,
  }) {
    return switch (outcome) {
      Invalid<WorkShift>() => _rejected(
        'The shift was rejected. Review the shift and try again.',
        dismiss,
      ),
      Stale<WorkShift>() => StaleConflictInspector(
        draft: const SizedBox.shrink(),
        onReload: dismiss,
      ),
      Missing<WorkShift>() => const MissingRecordInspector(),
      Unavailable<WorkShift>(:final code) => UnavailableInspector(code: code),
      Uncertain<WorkShift>() => const UncertainOutcomeInspector(),
      Committed<WorkShift>() => const SizedBox.shrink(),
    };
  }

  Widget _periodOutcome(MutationOutcome<PayPeriod> outcome) {
    final dismiss = _clearPeriodFailure;
    return switch (outcome) {
      Invalid<PayPeriod>() => _rejected(
        'The period state could not change. Review the period and try again.',
        dismiss,
        action: 'Back to period',
      ),
      Stale<PayPeriod>() => StaleConflictInspector(
        draft: const SizedBox.shrink(),
        onReload: dismiss,
      ),
      Missing<PayPeriod>() => const MissingRecordInspector(),
      Unavailable<PayPeriod>(:final code) => UnavailableInspector(code: code),
      Uncertain<PayPeriod>() => const UncertainOutcomeInspector(),
      Committed<PayPeriod>() => const SizedBox.shrink(),
    };
  }

  Widget _correction(WorkRecordProjection record) {
    final cancel = widget.onCancelCorrection ?? () {};
    final correctShift = widget.onCorrectShift;
    final correctPayslip = widget.onCorrectPayslip;
    return switch (record) {
      ShiftRecordProjection(:final shift)
          when shift.state == ShiftState.finalized && correctShift != null =>
        CorrectionConfirmationInspector<WorkShift>(
          key: ValueKey(('correct', record.id)),
          recordName: 'shift',
          original: shift,
          onConfirm: (original, reason) =>
              _saved(correctShift(original, reason), 'Shift corrected.'),
          onCancel: cancel,
        ),
      PayslipRecordProjection(:final payslip)
          when payslip.isEffective && correctPayslip != null =>
        CorrectionConfirmationInspector<Payslip>(
          key: ValueKey(('correct', record.id)),
          recordName: 'payslip',
          original: payslip,
          onConfirm: (original, reason) =>
              _saved(correctPayslip(original, reason), 'Payslip corrected.'),
          onCancel: cancel,
        ),
      _ => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Correction unavailable',
        message: 'Only finalized shifts and effective payslips are corrected.',
      ),
    };
  }

  Widget _recordInspector(
    WorkRecordProjection record,
    WorkRegisterProjection register,
  ) {
    if (record is PayPeriodRecordProjection) {
      if (_periodFailure case final failure?) {
        return _periodOutcome(failure);
      }
      return _tabs(
        WorkRecordKind.payPeriod,
        record,
        WorkInspector.fromRecord(
          key: ValueKey(record.id),
          projection: record,
          onSetPeriodState: widget.onSetPeriodState == null
              ? null
              : _setPeriodState,
          onRecordPayslip: widget.onRecordPayslip == null
              ? null
              : () => _openPayslip(record.period.id),
          reconciliation: register.period?.id == record.period.id
              ? register.reconciliation?.groups ?? const []
              : const [],
        ),
      );
    }
    final details = _tabs(
      record is PayslipRecordProjection
          ? WorkRecordKind.payslip
          : WorkRecordKind.shift,
      record,
      WorkInspector.fromRecord(
        key: ValueKey(record.id),
        projection: record,
        timezones: widget.timezones,
        shiftFields: record is ShiftRecordProjection
            ? _shiftFields(record)
            : null,
        onFinalize: widget.onFinalize == null
            ? null
            : (shift) => _saved(widget.onFinalize!(shift), 'Shift finalized.'),
        onCorrect: widget.onOpenCorrection,
        onRemove: record is ShiftRecordProjection
            ? _removal(record.shift)
            : null,
      ),
    );
    // A failed revision explains itself above the sheet, which keeps what
    // the owner changed; "Reload record" clears it.
    // The sheet keeps one place in the tree, so a failure appearing above
    // it never rebuilds the form and loses what was typed.
    final failure = _reviseFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: _reviseOutcome(failure, dismiss: _clearReviseFailure),
          ),
        Expanded(key: const ValueKey('record-sheet'), child: details),
      ],
    );
  }

  /// A shift's times on its sheet: editable while it is a draft that can
  /// be revised, greyed once finalized or void.
  Widget? _shiftFields(ShiftRecordProjection record) {
    final shift = record.shift;
    final zones = widget.timezones;
    if (zones == null || shift.endUtc == null) return null;
    final prefill = ShiftFormPrefill.fromShift(shift, record.breaks, zones);
    return switch (shift.state) {
      ShiftState.draft when widget.onReviseDraft != null => ShiftEditInspector(
        key: ValueKey(('revise', record.id, shift.revision)),
        employmentId: shift.employmentId,
        today: _today,
        title: 'Shift',
        prefill: prefill,
        onSubmit: (value) => _reviseDraft(shift, value),
      ),
      ShiftState.finalized || ShiftState.voided => ShiftEditInspector(
        key: ValueKey(('shift-fields', record.id, shift.revision)),
        employmentId: shift.employmentId,
        today: _today,
        title: 'Shift',
        prefill: prefill,
        readOnly: true,
        onSubmit: (_) async =>
            const Unavailable<WorkShift>(SafeFailureCode.storageUnavailable),
      ),
      _ => null,
    };
  }

  Widget _tabs(
    WorkRecordKind kind,
    WorkRecordProjection record,
    Widget details,
  ) => RecordTabs(
    key: ValueKey(('tabs', record.id)),
    record: WorkRecordRef(kind: kind, id: record.id),
    details: details,
  );
}

/// The state to show: the current value, or the previous one while a
/// refresh is loading. Nothing while loading for the first time or failed.
WorkViewState? _current(AsyncValue<WorkViewState> state) =>
    state.hasError ? null : state.value;

WorkRecordRef? _selectedRecord(AsyncValue<WorkViewState> state) {
  final value = _current(state);
  return value is WorkReady ? value.route.record : null;
}

Widget _rejected(
  String message,
  VoidCallback onDismiss, {
  String action = 'Back to Record work',
}) => ValidationFailureInspector(
  message: message,
  child: _Rejected(message: message, onDismiss: onDismiss, action: action),
);

/// The route a state was built from, to tell when the location moved.
String? _routeUri(AsyncValue<WorkViewState> state) {
  final value = _current(state);
  return value is WorkReady ? workRouteUri(value.route).toString() : null;
}

WorkInspectorMode? _routeMode(AsyncValue<WorkViewState> state) {
  final value = _current(state);
  return value is WorkReady ? value.route.mode : null;
}

final class _Rejected extends StatelessWidget {
  const _Rejected({
    required this.message,
    required this.onDismiss,
    required this.action,
  });

  final String message;
  final VoidCallback onDismiss;
  final String action;

  @override
  Widget build(BuildContext context) => InspectorPane(
    children: [
      InspectorText(message),
      InspectorActions(
        children: [KeyButton(label: action, onPressed: onDismiss)],
      ),
    ],
  );
}

/// Keeps the Work register a named landmark inside the shell's desk.
final class _RegisterLandmark extends StatelessWidget {
  const _RegisterLandmark({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Work register',
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: FocusTraversalGroup(child: child),
      ),
    );
  }
}
