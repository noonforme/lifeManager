import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/workbench/inspector_pane.dart';
import '../../../shared/workbench/lifeos_frame.dart';
import '../../../shared/workbench/operational_state.dart';
import '../../../shared/workbench/system_rail.dart';
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
    super.key,
  });

  final AsyncValue<WorkViewState> state;
  final ValueChanged<WorkRecordRef> onSelect;
  final VoidCallback onPrimaryAction;
  final SubmitEmployment onCreateEmployment;
  final SubmitAgreement onCreateAgreement;
  final ValueChanged<String> onNavigate;

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
      WorkInspectorRecord(:final record) => WorkInspector.fromRecord(
        projection: record,
      ),
    };
  }
}

WorkRecordRef? _selectedRecord(AsyncValue<WorkViewState> state) {
  final value = switch (state) {
    AsyncData(:final value) => value,
    AsyncLoading() || AsyncError() => null,
  };
  return value is WorkReady ? value.route.record : null;
}
