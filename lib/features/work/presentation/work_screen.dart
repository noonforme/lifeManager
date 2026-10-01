import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../shared/workbench/inspector_pane.dart';
import '../../../shared/workbench/lifeos_frame.dart';
import '../../../shared/workbench/operational_state.dart';
import '../../../shared/workbench/system_rail.dart';
import '../data/projections/work_record_projection.dart';
import '../domain/shift.dart';
import 'employment_agreement_forms.dart';
import 'work_controller.dart';
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

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

final class _WorkScreenState extends State<WorkScreen> {
  bool _showRegister = false;

  @override
  void didUpdateWidget(covariant WorkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRecord = _selectedRecord(oldWidget.state);
    final newRecord = _selectedRecord(widget.state);
    if (oldRecord?.id != newRecord?.id) {
      _showRegister = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = switch (widget.state) {
      AsyncData(:final value) => value,
      AsyncLoading() || AsyncError() => null,
    };
    final routeRecord = ready is WorkReady ? ready.route.record : null;
    final inspectorActive = routeRecord != null && !_showRegister;
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
    if (state.route.mode == WorkInspectorMode.create &&
        state.route.record == null) {
      return WorkInspector(
        onCreateEmployment: widget.onCreateEmployment,
        onCreateAgreement: widget.onCreateAgreement,
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
      WorkInspectorRecord(:final record) => _recordInspector(record),
    };
  }
}

extension on _WorkScreenState {
  Widget _recordInspector(WorkRecordProjection record) {
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
