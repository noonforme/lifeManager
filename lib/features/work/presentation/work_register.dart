import 'package:flutter/material.dart';

import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/task_pane.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
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
    this.timezones,
    super.key,
  });

  final WorkRegisterProjection? projection;
  final WorkRecordRef? selectedRecord;
  final ValueChanged<WorkRecordRef> onSelect;
  final VoidCallback onPrimaryAction;
  final ValueChanged<EmploymentId>? onOpenEmployment;
  final VoidCallback? onNewPeriod;

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
    final skin = LifeOSSkinScope.of(context);
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: skin.painters.toolbar(skin.tokens),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SheetPicker(
                sheet: route.sheet,
                onSheet: (sheet) => change(route.copyWith(sheet: sheet)),
              ),
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
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: skin.tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: sheet,
          ),
        ),
      ],
    );
  }
}

/// The Details group for a Work scope (spec 5.2): employment, period,
/// shift count and the reconciliation per basis, worded as the summary was.
final class WorkDetails extends StatelessWidget {
  const WorkDetails({required this.projection, super.key});

  final WorkRegisterProjection projection;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final figure = skin.typography.figure.copyWith(color: skin.tokens.ink);
    final period = projection.period;
    final groups = projection.reconciliation?.groups ?? const [];
    Widget pair(String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 6),
        Text(value, style: figure),
      ],
    );
    return TaskDetails(
      lines: [
        if (projection.employment case final employment?)
          Text(
            employment.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (period != null)
          Text('${period.start} – ${period.end}', style: figure),
        Text(
          projection.shiftSheet.length == 1
              ? '1 shift'
              : '${projection.shiftSheet.length} shifts',
        ),
        if (groups.isEmpty) pair('Paid evidence', _money(projection.paid)),
        for (final group in groups) ...[
          Text(
            '${_basis(group.basis)} · ${group.currency.value}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          pair(
            'Expected under recorded agreement',
            _optionalMoney(group.expected),
          ),
          pair('Paid evidence', _optionalMoney(group.paid)),
          if (group.difference case final difference?)
            pair('Difference', _money(difference)),
        ],
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
