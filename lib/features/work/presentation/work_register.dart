import 'package:flutter/material.dart';

import '../../../shared/workbench/data_register.dart';
import '../../../shared/workbench/lifeos_theme.dart';
import '../../../shared/workbench/operational_state.dart';
import '../data/daos/payslip_dao.dart';
import '../data/daos/shift_dao.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import 'work_route_state.dart';

final class WorkRegister extends StatelessWidget {
  const WorkRegister({
    required this.projection,
    required this.selectedRecord,
    required this.onSelect,
    required this.onPrimaryAction,
    this.onOpenEmployment,
    this.onNewPeriod,
    super.key,
  });

  final WorkRegisterProjection? projection;
  final WorkRecordRef? selectedRecord;
  final ValueChanged<WorkRecordRef> onSelect;
  final VoidCallback onPrimaryAction;
  final ValueChanged<EmploymentId>? onOpenEmployment;
  final VoidCallback? onNewPeriod;

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
              onPressed: onPrimaryAction,
              child: const Text('Create employment'),
            ),
          ],
        ),
      );
    }
    if (value.scope.employmentId == null) {
      return OperationalState(
        kind: OperationalStateKind.empty,
        title: 'Create an employment to begin.',
        message: 'An employment anchors agreements, shifts, and pay evidence.',
        action: FilledButton(
          onPressed: onPrimaryAction,
          child: const Text('Create employment'),
        ),
      );
    }

    final rows = <_WorkRow>[
      for (final period in value.periodRows) _WorkRow.period(period),
      for (final shift in value.shiftRows) _WorkRow.shift(shift),
      for (final payslip in value.payslipRows) _WorkRow.payslip(payslip),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          projection: value,
          onPrimaryAction: onPrimaryAction,
          onNewPeriod: onNewPeriod,
        ),
        _Summary(projection: value),
        Expanded(
          child: rows.isEmpty
              ? const OperationalState(
                  kind: OperationalStateKind.empty,
                  title: 'No Work records in this scope',
                  message: 'Add a shift or change the explicit scope.',
                )
              : DataRegister<_WorkRow>(
                  label: 'Work rows',
                  rows: rows,
                  columns: [
                    RegisterColumn(
                      label: 'Date',
                      width: 150,
                      value: (row) => row.date,
                    ),
                    RegisterColumn(
                      label: 'Record',
                      width: 150,
                      value: (row) => row.kindLabel,
                    ),
                    RegisterColumn(
                      label: 'Status',
                      width: 140,
                      value: (row) => row.status,
                    ),
                    RegisterColumn(
                      label: 'Duration / amount',
                      width: 190,
                      value: (row) => row.value,
                      numeric: true,
                    ),
                  ],
                  rowId: (row) => row.routeValue,
                  rowLabel: (row) => row.semanticLabel,
                  selectedId: selectedRecord == null
                      ? null
                      : _routeValue(selectedRecord!),
                  onSelect: (row) => onSelect(row.record),
                ),
        ),
      ],
    );
  }
}

final class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.projection,
    required this.onPrimaryAction,
    required this.onNewPeriod,
  });

  final WorkRegisterProjection projection;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onNewPeriod;

  @override
  Widget build(BuildContext context) {
    final scope = projection.scope.temporal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Control(label: 'Employment', detail: projection.employment?.name),
          _Control(
            label: 'Scope',
            detail: switch (scope) {
              PayPeriodScope() => 'Pay period',
              DateRangeScope(:final start, :final end) => '$start – $end',
              null => 'All records',
            },
          ),
          const _Control(label: 'Status', detail: 'Effective'),
          FilledButton.icon(
            onPressed: onPrimaryAction,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add shift'),
          ),
          if (onNewPeriod != null)
            OutlinedButton(
              onPressed: onNewPeriod,
              child: const Text('New pay period'),
            ),
        ],
      ),
    );
  }
}

final class _Control extends StatelessWidget {
  const _Control({required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (detail != null) ...[const Text(': '), Text(detail!)],
        ],
      ),
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
      decoration: const BoxDecoration(
        color: LifeOSColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: LifeOSColors.boundary),
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

final class _WorkRow {
  const _WorkRow({
    required this.record,
    required this.date,
    required this.kindLabel,
    required this.status,
    required this.value,
    required this.semanticLabel,
  });

  factory _WorkRow.shift(ShiftRegisterRow row) {
    final duration = row.endUtc == null
        ? '—'
        : _duration(row.endUtc!.difference(row.startUtc));
    return _WorkRow(
      record: WorkRecordRef(kind: WorkRecordKind.shift, id: row.id),
      date: row.localStartDate,
      kindLabel: 'Shift',
      status: row.state.name,
      value: duration,
      semanticLabel: 'Shift on ${row.localStartDate}',
    );
  }

  factory _WorkRow.period(PayPeriod period) => _WorkRow(
    record: WorkRecordRef(kind: WorkRecordKind.payPeriod, id: period.id),
    date: period.start.toString(),
    kindLabel: 'Pay period',
    status: period.state == PayPeriodState.reviewed ? 'reviewed' : 'open',
    value: '${period.start} – ${period.end}',
    semanticLabel: 'Pay period from ${period.start} to ${period.end}',
  );

  factory _WorkRow.payslip(PayslipRegisterRow row) => _WorkRow(
    record: WorkRecordRef(kind: WorkRecordKind.payslip, id: row.id),
    date: row.issuedDate,
    kindLabel: 'Payslip',
    status: row.state.name,
    value: _money(row.amount),
    semanticLabel: 'Payslip issued ${row.issuedDate}',
  );

  final WorkRecordRef record;
  final String date;
  final String kindLabel;
  final String status;
  final String value;
  final String semanticLabel;

  String get routeValue => _routeValue(record);
}

String _routeValue(WorkRecordRef record) =>
    '${record.kind.name}:${record.id.value}';

String _duration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '$hours:${minutes.toString().padLeft(2, '0')}';
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
