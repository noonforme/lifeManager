import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/workbench/inspector_pane.dart';
import '../../../shared/workbench/lifeos_frame.dart';
import '../../../shared/workbench/operational_state.dart';
import '../../../shared/workbench/system_rail.dart';
import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/shift.dart';
import 'correction_confirmation.dart';
import 'employment_agreement_forms.dart';
import 'period_payslip_forms.dart';
import 'shift_forms.dart';
import 'work_controller.dart' hide SetPayPeriodState;
import 'work_inspector.dart';
import 'work_register.dart';
import 'work_route_state.dart';

final class WorkScreen extends StatefulWidget {
  const WorkScreen({
    required this.state,
    required this.onSelect,
    required this.onPrimaryAction,
    required this.onCreateEmployment,
    required this.onCreateAgreement,
    required this.onNavigate,
    this.onStartBreak,
    this.onEndBreak,
    this.onEndShift,
    this.onFinalize,
    this.onStartShift,
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
    this.onReviseDraft,
    this.timezones,
    super.key,
  });

  final AsyncValue<WorkViewState> state;
  final ValueChanged<WorkRecordRef> onSelect;
  final VoidCallback onPrimaryAction;
  final SubmitEmployment onCreateEmployment;
  final SubmitAgreement onCreateAgreement;
  final ValueChanged<String> onNavigate;
  final MutateShift? onStartBreak;
  final Future<MutationOutcome<WorkShift>> Function(
    WorkShift shift,
    ShiftBreak value,
  )?
  onEndBreak;
  final MutateShift? onEndShift;
  final Future<MutationOutcome<WorkShift>> Function(
    WorkShift shift,
    int overtimeMinutes,
  )?
  onFinalize;
  final Future<MutationOutcome<WorkShift>> Function(EmploymentId employment)?
  onStartShift;
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
  final Future<MutationOutcome<WorkShift>> Function(
    WorkShift draft,
    ManualShiftDraft value,
  )?
  onReviseDraft;
  final TimezoneService? timezones;

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

final class _WorkScreenState extends State<WorkScreen> {
  bool _showRegister = false;
  MutationOutcome<WorkShift>? _startFailure;
  MutationOutcome<PayPeriod>? _periodFailure;
  bool _creatingPeriod = false;
  PayPeriodId? _payslipPeriod;
  MutationOutcome<WorkShift>? _reviseFailure;

  void _clearStartFailure() => setState(() => _startFailure = null);

  void _clearReviseFailure() => setState(() => _reviseFailure = null);

  Future<MutationOutcome<WorkShift>> _reviseDraft(
    WorkShift draft,
    ManualShiftDraft value,
  ) async {
    final outcome = await widget.onReviseDraft!(draft, value);
    if (!mounted) return outcome;
    setState(() {
      _reviseFailure =
          outcome is Committed<WorkShift> || outcome is Invalid<WorkShift>
          ? null
          : outcome;
    });
    return outcome;
  }

  void _clearPeriodFailure() => setState(() => _periodFailure = null);

  void _openPayslip(PayPeriodId period) =>
      setState(() => _payslipPeriod = period);

  Future<MutationOutcome<PayPeriod>> _createPeriod(PayPeriodDraft draft) async {
    final outcome = await widget.onCreatePayPeriod!(draft);
    if (mounted && outcome is Committed<PayPeriod>) {
      setState(() => _creatingPeriod = false);
    }
    return outcome;
  }

  Future<MutationOutcome<PayPeriod>> _setPeriodState(
    PayPeriod period,
    PayPeriodState state,
  ) async {
    final outcome = await widget.onSetPeriodState!(period, state);
    if (!mounted) return outcome;
    setState(() {
      _periodFailure = outcome is Committed<PayPeriod> ? null : outcome;
    });
    return outcome;
  }

  Future<void> _startShift(EmploymentId employment) async {
    final start = widget.onStartShift;
    if (start == null) return;
    final outcome = await start(employment);
    if (!mounted) return;
    setState(() {
      _startFailure = outcome is Committed<WorkShift> ? null : outcome;
    });
  }

  @override
  void didUpdateWidget(covariant WorkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRecord = _selectedRecord(oldWidget.state);
    final newRecord = _selectedRecord(widget.state);
    if (oldRecord?.id != newRecord?.id) {
      _showRegister = false;
      _periodFailure = null;
      _creatingPeriod = false;
      _payslipPeriod = null;
    }
    if (_routeMode(oldWidget.state) != _routeMode(widget.state)) {
      _startFailure = null;
      _reviseFailure = null;
      _creatingPeriod = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = switch (widget.state) {
      AsyncData(:final value) => value,
      AsyncLoading() || AsyncError() => null,
    };
    final routeRecord = ready is WorkReady ? ready.route.record : null;
    final inspectorActive =
        (routeRecord != null || _creatingPeriod || _payslipPeriod != null) &&
        !_showRegister;
    return LifeOSFrame(
      rail: SystemRail(selectedPath: '/work', onNavigate: widget.onNavigate),
      register: _register(ready),
      inspector: InspectorPane(child: _inspector(ready)),
      inspectorIsActive: inspectorActive,
      onBackToRegister: () => setState(() => _showRegister = true),
    );
  }

  Widget _register(WorkViewState? state) {
    if (widget.state.isLoading) {
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
        projection: register,
        selectedRecord: route.record,
        onSelect: widget.onSelect,
        onPrimaryAction: widget.onPrimaryAction,
        onNewPeriod: widget.onCreatePayPeriod == null || route.employmentId == null
            ? null
            : () => setState(() {
                _creatingPeriod = true;
                _showRegister = false;
              }),
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
    if (_creatingPeriod && employmentId != null) {
      return PeriodInspector.create(
        employmentId: employmentId,
        onSubmit: _createPeriod,
      );
    }
    final recordPayslip = widget.onRecordPayslip;
    if (_payslipPeriod case final periodId? when recordPayslip != null) {
      return PayslipInspector.create(
        periodId: periodId,
        onSubmit: recordPayslip,
      );
    }
    if (route.mode == WorkInspectorMode.create && route.record == null) {
      if (_startFailure case final failure?) {
        return _startOutcome(failure);
      }
      final employment = route.employmentId;
      if (employment != null) {
        final open = widget.onOpenManualShift;
        return ShiftCreateInspector(
          onStartShift: () => _startShift(employment),
          onAddManualShift: open == null ? null : () => open(employment),
        );
      }
      return WorkInspector(
        onCreateEmployment: widget.onCreateEmployment,
        onCreateAgreement: widget.onCreateAgreement,
        onStartShift: _startShift,
        onAddManualShift: widget.onOpenManualShift,
      );
    }
    final save = widget.onSaveManualShift;
    if (route.mode == WorkInspectorMode.edit &&
        route.record == null &&
        route.employmentId != null &&
        save != null) {
      return ShiftEditInspector(
        employmentId: route.employmentId!,
        initialTimezoneId: widget.systemTimezoneId,
        onSubmit: save,
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
      WorkInspectorRecord(:final record)
          when route.mode == WorkInspectorMode.edit &&
              record is ShiftRecordProjection &&
              record.shift.state == ShiftState.draft &&
              record.shift.endUtc != null &&
              widget.onReviseDraft != null &&
              widget.timezones != null =>
        _revision(record),
      WorkInspectorRecord(:final record) => _recordInspector(
        record,
        state.register,
      ),
    };
  }
}

extension on _WorkScreenState {
  Widget _startOutcome(
    MutationOutcome<WorkShift> outcome, {
    VoidCallback? dismiss,
  }) {
    dismiss ??= _clearStartFailure;
    return switch (outcome) {
      Invalid<WorkShift>(:final fields) when fields.containsKey('timezoneId') =>
        _rejected(
          'The system timezone is unavailable. '
          'Set a known IANA timezone and try again.',
          dismiss,
        ),
      Invalid<WorkShift>() => _rejected(
        'The shift could not start. Review the employment and agreement.',
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

  Widget _revision(ShiftRecordProjection record) {
    if (_reviseFailure case final failure?) {
      return _startOutcome(failure, dismiss: _clearReviseFailure);
    }
    final shift = record.shift;
    return ShiftEditInspector(
      key: ValueKey(('revise', record.id, shift.revision)),
      employmentId: shift.employmentId,
      title: 'Revise replacement shift',
      prefill: ShiftFormPrefill.fromShift(
        shift,
        record.breaks,
        widget.timezones!,
      ),
      onSubmit: (value) => _reviseDraft(shift, value),
    );
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
          onConfirm: correctShift,
          onCancel: cancel,
        ),
      PayslipRecordProjection(:final payslip)
          when payslip.isEffective && correctPayslip != null =>
        CorrectionConfirmationInspector<Payslip>(
          key: ValueKey(('correct', record.id)),
          recordName: 'payslip',
          original: payslip,
          onConfirm: correctPayslip,
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
      return WorkInspector.fromRecord(
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
      );
    }
    final onEndBreak = widget.onEndBreak;
    final onFinalize = widget.onFinalize;
    final shift = record is ShiftRecordProjection ? record.shift : null;
    return WorkInspector.fromRecord(
      key: ValueKey(record.id),
      projection: record,
      onStartBreak: widget.onStartBreak,
      onEndBreak: onEndBreak == null || shift == null
          ? null
          : (value) => onEndBreak(shift, value),
      onEndShift: widget.onEndShift,
      onFinalize: onFinalize == null || shift == null
          ? null
          : (minutes) => onFinalize(shift, minutes),
      onCorrect: widget.onOpenCorrection,
    );
  }
}

WorkRecordRef? _selectedRecord(AsyncValue<WorkViewState> state) {
  final value = switch (state) {
    AsyncData(:final value) => value,
    AsyncLoading() || AsyncError() => null,
  };
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

WorkInspectorMode? _routeMode(AsyncValue<WorkViewState> state) {
  final value = switch (state) {
    AsyncData(:final value) => value,
    AsyncLoading() || AsyncError() => null,
  };
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onDismiss,
          child: Text(action),
        ),
      ],
    ),
  );
}
