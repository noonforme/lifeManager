import 'package:flutter/material.dart';

import '../../../core/time/timezone_service.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import 'work_route_state.dart';
import 'work_sheets.dart';
import 'work_toolbar_controls.dart';

final class WorkRegister extends StatelessWidget {
  const WorkRegister({
    required this.projection,
    required this.selectedRecord,
    required this.onSelect,
    required this.onPrimaryAction,
    this.onOpenEmployment,
    this.onNewPeriod,
    this.onAllEmployments,
    this.onCreateEmployment,
    this.route,
    this.onRoute,
    this.onAddManualShift,
    this.onRecordPayslip,
    this.onSaveView,
    this.timezones,
    super.key,
  });

  final WorkRegisterProjection? projection;
  final WorkRecordRef? selectedRecord;
  final ValueChanged<WorkRecordRef> onSelect;
  final VoidCallback onPrimaryAction;
  final ValueChanged<EmploymentId>? onOpenEmployment;
  final VoidCallback? onNewPeriod;

  /// Saves the sheet and its filters as a named view.
  final ValueChanged<WorkRouteState>? onSaveView;

  /// Clears the employment from the route.
  final VoidCallback? onAllEmployments;

  /// Opens the employment form in the inspector.
  final VoidCallback? onCreateEmployment;

  /// The current route; its sheet, scope and void filter shape the desk.
  final WorkRouteState? route;

  /// Applies a sheet, scope or filter change.
  final ValueChanged<WorkRouteState>? onRoute;

  final VoidCallback? onAddManualShift;

  /// Records a payslip in the given pay period.
  final ValueChanged<PayPeriodId>? onRecordPayslip;

  /// Reads shift times on their own wall clock.
  final TimezoneService? timezones;

  @override
  Widget build(BuildContext context) {
    final value = projection;
    if (value == null) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Work records unavailable',
        message: 'Reload Work to inspect the current records.',
      );
    }
    final open = onOpenEmployment;
    final create = onCreateEmployment ?? onPrimaryAction;
    if (value.scope.employmentId == null &&
        value.availableEmployments.isNotEmpty &&
        open != null) {
      return OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Choose an employment',
        message: 'Open an employment to continue, or create another one.',
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final employment in value.availableEmployments)
              OutlinedButton(
                onPressed: () => open(employment.id),
                child: Text(employment.name),
              ),
            FilledButton(
              onPressed: create,
              child: const Text('Create employment'),
            ),
          ],
        ),
      );
    }
    if (value.scope.employmentId == null) {
      return OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Work',
        message:
            'Track shifts, see what you should be paid, and compare it with '
            'your payslips. Start by adding where you work.',
        action: FilledButton(
          onPressed: create,
          child: const Text('Create employment'),
        ),
      );
    }

    final route =
        this.route ??
        WorkRouteState(
          employmentId: value.scope.employmentId,
          scope: value.scope.temporal,
          record: selectedRecord,
          mode: WorkInspectorMode.inspect,
        );
    void change(WorkRouteState next) => onRoute?.call(next);
    final selectedId = selectedRecord == null
        ? null
        : workRowId(selectedRecord!);
    final period = value.period;
    final recordPayslip = onRecordPayslip;
    final Widget sheet = switch (route.sheet) {
      WorkSheet.shifts => ShiftsSheet(
        rows: value.shiftSheet,
        timezones: timezones ?? IanaTimezoneService(),
        selectedId: selectedId,
        onOpen: onSelect,
        showVoid: route.showVoid,
        onAddManualShift: onAddManualShift,
      ),
      WorkSheet.periods => PeriodsSheet(
        rows: value.periodSheet,
        selectedId: selectedId,
        onOpen: onSelect,
        onNewPeriod: onNewPeriod,
      ),
      WorkSheet.payslips => PayslipsSheet(
        payslips: value.payslipSheet,
        periods: value.periodSheet,
        selectedId: selectedId,
        onOpen: onSelect,
        showVoid: route.showVoid,
        onRecordPayslip: period == null || recordPayslip == null
            ? null
            : () => recordPayslip(period.id),
      ),
      WorkSheet.agreements => AgreementsSheet(
        rows: value.agreementSheet,
        employmentName: value.employment?.name ?? 'Employment',
        selectedId: selectedId,
        onOpen: onSelect,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedTabs(
            labels: const ['Shifts', 'Pay periods', 'Payslips', 'Agreements'],
            selectedIndex: route.sheet.index,
            onSelected: (index) =>
                change(route.copyWith(sheet: WorkSheet.values[index])),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EmploymentSwitcher(
                current: value.employment?.id,
                currentName: value.employment?.name,
                employments: value.availableEmployments,
                onOpen: onOpenEmployment,
                onAll: onAllEmployments,
                onCreate: create,
              ),
              PeriodPicker(
                scope: route.scope,
                periods: [for (final row in value.periodSheet) row.period],
                onScope: (scope) => change(
                  route.copyWith(scope: () => scope, record: () => null),
                ),
              ),
              StateFilter(
                showVoid: route.showVoid,
                onChanged: (show) => change(route.copyWith(showVoid: show)),
              ),
              KeyButton(
                label: 'Add shift',
                kind: KeyKind.primary,
                onPressed: onPrimaryAction,
              ),
              if (onNewPeriod case final add?)
                KeyButton(label: 'New pay period', onPressed: add),
              if (onSaveView case final save?)
                KeyButton(label: 'Save view', onPressed: () => save(route)),
            ],
          ),
        ),
        if (value.reconciliation != null) _Summary(projection: value),
        Expanded(child: sheet),
      ],
    );
  }
}

final class _Summary extends StatelessWidget {
  const _Summary({required this.projection});

  final WorkRegisterProjection projection;

  @override
  Widget build(BuildContext context) {
    final groups = projection.reconciliation?.groups ?? const [];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: groups.isEmpty
            ? _SummaryValue(
                label: 'Paid evidence',
                value: _money(projection.paid),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < groups.length; index++) ...[
                    if (index > 0) const Divider(height: 17),
                    Text(
                      '${_basis(groups[index].basis)} · ${groups[index].currency.value}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 28,
                      runSpacing: 8,
                      children: [
                        _SummaryValue(
                          label: 'Expected under recorded agreement',
                          value: _optionalMoney(groups[index].expected),
                        ),
                        _SummaryValue(
                          label: 'Paid evidence',
                          value: _optionalMoney(groups[index].paid),
                        ),
                        if (groups[index].difference != null)
                          _SummaryValue(
                            label: 'Difference',
                            value: _money(groups[index].difference!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

final class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

String _basis(RateBasis? basis) => switch (basis) {
  GrossBasis() => 'Gross',
  NetBasis() => 'Net',
  null => 'Mixed basis',
};

String _optionalMoney(Money? money) =>
    money == null ? 'Not recorded' : _money(money);

String _money(Money money) {
  final negative = money.minorUnits < 0;
  final absolute = money.minorUnits.abs();
  final major = absolute ~/ 100;
  final minor = absolute.remainder(100).toString().padLeft(2, '0');
  return '${money.currency.value} ${negative ? '-' : ''}$major.$minor';
}
