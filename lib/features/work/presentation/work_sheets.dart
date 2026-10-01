import 'package:flutter/widgets.dart';

import '../../../core/explain/explanation.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/workbench/data_register.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/reconciliation.dart';
import '../domain/shift.dart';
import 'employment_agreement_forms.dart' show formatClock, formatHours;
import 'work_explanations.dart';
import 'work_formats.dart';
import 'work_route_state.dart';

/// The Work sheets on Register v2 (shell spec 7.2). Each derived cell
/// carries the explanation of the result that produced it.

String workRowId(WorkRecordRef record) =>
    '${record.kind.name}:${record.id.value}';

/// "Running", "On break", "Draft", "Finalized" or "Void".
String shiftStateLabel(ShiftState state) => switch (state) {
  ShiftState.running => 'Running',
  ShiftState.onBreak => 'On break',
  ShiftState.draft => 'Draft',
  ShiftState.finalized => 'Finalized',
  ShiftState.voided => 'Void',
};

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String periodName(PayPeriod period) =>
    period.label ?? '${period.start} – ${period.end}';

final class ShiftsSheet extends StatelessWidget {
  const ShiftsSheet({
    required this.rows,
    required this.timezones,
    required this.selectedId,
    required this.onOpen,
    required this.showVoid,
    this.onAddManualShift,
    super.key,
  });

  final List<ShiftSheetRow> rows;
  final TimezoneService timezones;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final bool showVoid;
  final VoidCallback? onAddManualShift;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in rows)
        if (showVoid || row.shift.state != ShiftState.voided) row,
    ];
    String clock(DateTime? utc, String zone) => utc == null
        ? ''
        : timezones.localTimeAt(utc, zone).toString().substring(0, 5);
    String group(ShiftSheetRow row) {
      if (row.period case final period?) return periodName(period);
      final date = row.shift.localStartDate;
      return '${_months[date.month - 1]} ${date.year}';
    }

    final lines = <RegisterLine<ShiftSheetRow>>[];
    String? current;
    for (final row in visible) {
      final name = group(row);
      if (name != current) {
        current = name;
        lines.add(GroupLine(label: name));
      }
      lines.add(
        RowLine(
          row,
          state: switch (row.shift.state) {
            ShiftState.running || ShiftState.onBreak => RowState.running,
            ShiftState.draft => RowState.draft,
            ShiftState.voided => RowState.voided,
            ShiftState.finalized => RowState.normal,
          },
        ),
      );
    }
    if (onAddManualShift case final add?) {
      lines.add(EntryLine(hint: 'Add a manual shift', onOpen: add));
    }

    String premium(ShiftSheetRow row, int Function(ExpectedPay pay) pick) {
      final pay = row.pay;
      return pay == null ? '' : formatDuration(pick(pay));
    }

    Explanation? premiumExplain(ShiftSheetRow row, PremiumHours which) =>
        switch ((row.facts, row.pay)) {
          (final facts?, final pay?) => explainPremiumHours(facts, pay, which),
          _ => null,
        };

    return DataRegister<ShiftSheetRow>(
      label: 'Shifts',
      lines: lines,
      rowId: (row) => workRowId(_shiftRef(row)),
      rowLabel: (row) =>
          'Shift on ${row.shift.localStartDate}, '
          '${shiftStateLabel(row.shift.state)}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(_shiftRef(row)),
      columns: [
        RegisterColumn(
          key: 'date',
          label: 'Date',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.shift.localStartDate.toString(),
        ),
        RegisterColumn(
          key: 'start',
          label: 'Start',
          kind: ColumnKind.time,
          width: 64,
          value: (row) => clock(row.shift.startUtc, row.shift.timezoneId),
        ),
        RegisterColumn(
          key: 'end',
          label: 'End',
          kind: ColumnKind.time,
          width: 64,
          value: (row) => clock(row.shift.endUtc, row.shift.timezoneId),
        ),
        RegisterColumn(
          key: 'break',
          label: 'Break',
          kind: ColumnKind.duration,
          width: 64,
          optional: true,
          value: (row) =>
              row.breakSeconds == 0 ? '' : formatDuration(row.breakSeconds),
        ),
        RegisterColumn(
          key: 'paid',
          label: 'Paid',
          kind: ColumnKind.duration,
          width: 64,
          value: (row) =>
              row.paidSeconds == null ? '' : formatDuration(row.paidSeconds!),
          explain: (row) =>
              row.facts == null ? null : explainPaidTime(row.facts!, timezones),
        ),
        RegisterColumn(
          key: 'night',
          label: 'Night',
          kind: ColumnKind.derived,
          width: 64,
          optional: true,
          value: (row) => premium(row, (pay) => pay.nightPaidSeconds),
          explain: (row) => premiumExplain(row, PremiumHours.night),
        ),
        RegisterColumn(
          key: 'holiday',
          label: 'Holiday',
          kind: ColumnKind.derived,
          width: 72,
          optional: true,
          value: (row) => premium(row, (pay) => pay.holidayPaidSeconds),
          explain: (row) => premiumExplain(row, PremiumHours.holiday),
        ),
        RegisterColumn(
          key: 'overtime',
          label: 'OT',
          kind: ColumnKind.derived,
          width: 56,
          optional: true,
          value: (row) => premium(row, (pay) => pay.overtimePaidSeconds),
          explain: (row) => premiumExplain(row, PremiumHours.overtime),
        ),
        RegisterColumn(
          key: 'pay',
          label: 'Est. pay',
          kind: ColumnKind.money,
          width: 112,
          value: (row) => row.pay == null ? '' : formatMoney(row.pay!.amount),
          explain: (row) => switch ((row.facts, row.pay)) {
            (final facts?, final pay?) => explainExpectedPay(facts, pay),
            _ => null,
          },
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 96,
          value: (row) => shiftStateLabel(row.shift.state),
        ),
      ],
    );
  }
}

WorkRecordRef _shiftRef(ShiftSheetRow row) =>
    WorkRecordRef(kind: WorkRecordKind.shift, id: row.shift.id);

final class PeriodsSheet extends StatelessWidget {
  const PeriodsSheet({
    required this.rows,
    required this.selectedId,
    required this.onOpen,
    this.onNewPeriod,
    super.key,
  });

  final List<PeriodSheetRow> rows;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final VoidCallback? onNewPeriod;

  @override
  Widget build(BuildContext context) {
    WorkRecordRef ref(PeriodSheetRow row) =>
        WorkRecordRef(kind: WorkRecordKind.payPeriod, id: row.period.id);
    final lines = <RegisterLine<PeriodSheetRow>>[];
    int? year;
    for (final row in rows) {
      if (row.period.start.year != year) {
        year = row.period.start.year;
        lines.add(GroupLine(label: '$year'));
      }
      lines.add(RowLine(row));
    }
    if (onNewPeriod case final add?) {
      lines.add(EntryLine(hint: 'Add a pay period', onOpen: add));
    }
    String money(
      PeriodSheetRow row,
      Money? Function(ReconciliationGroup group) pick,
    ) {
      final group = row.group;
      if (group == null) return row.groups.isEmpty ? '' : 'Mixed basis';
      final value = pick(group);
      return value == null ? '' : formatMoney(value);
    }

    return DataRegister<PeriodSheetRow>(
      label: 'Pay periods',
      lines: lines,
      rowId: (row) => workRowId(ref(row)),
      rowLabel: (row) => 'Pay period ${periodName(row.period)}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(ref(row)),
      columns: [
        RegisterColumn(
          key: 'start',
          label: 'Start',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.period.start.toString(),
        ),
        RegisterColumn(
          key: 'end',
          label: 'End',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.period.end.toString(),
        ),
        RegisterColumn(
          key: 'shifts',
          label: 'Shifts',
          kind: ColumnKind.quantity,
          width: 64,
          value: (row) => '${row.shiftCount}',
        ),
        RegisterColumn(
          key: 'expected',
          label: 'Expected',
          kind: ColumnKind.money,
          width: 112,
          value: (row) => money(row, (group) => group.expected),
          explain: (row) =>
              row.group == null ? null : explainPeriodExpected(row.group!),
        ),
        RegisterColumn(
          key: 'paid',
          label: 'Paid',
          kind: ColumnKind.money,
          width: 112,
          value: (row) => money(row, (group) => group.paid),
          explain: (row) =>
              row.group == null ? null : explainPeriodPaid(row.group!),
        ),
        RegisterColumn(
          key: 'difference',
          label: 'Difference',
          kind: ColumnKind.money,
          width: 112,
          value: (row) => money(row, (group) => group.difference),
          explain: (row) =>
              row.group == null ? null : explainDifference(row.group!),
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 88,
          value: (row) =>
              row.period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open',
        ),
      ],
    );
  }
}

final class PayslipsSheet extends StatelessWidget {
  const PayslipsSheet({
    required this.payslips,
    required this.periods,
    required this.selectedId,
    required this.onOpen,
    required this.showVoid,
    this.onRecordPayslip,
    super.key,
  });

  final List<Payslip> payslips;
  final List<PeriodSheetRow> periods;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final bool showVoid;

  /// Records a payslip in the selected pay period, when one is selected.
  final VoidCallback? onRecordPayslip;

  @override
  Widget build(BuildContext context) {
    WorkRecordRef ref(Payslip value) =>
        WorkRecordRef(kind: WorkRecordKind.payslip, id: value.id);
    final periodById = {for (final row in periods) row.period.id: row.period};
    final lines = <RegisterLine<Payslip>>[];
    int? year;
    for (final payslip in payslips) {
      if (!showVoid && !payslip.isEffective) continue;
      if (payslip.issuedDate.year != year) {
        year = payslip.issuedDate.year;
        lines.add(GroupLine(label: '$year'));
      }
      lines.add(
        RowLine(
          payslip,
          state: payslip.isEffective ? RowState.normal : RowState.voided,
        ),
      );
    }
    if (onRecordPayslip case final add?) {
      lines.add(
        EntryLine(hint: 'Record a payslip for this period', onOpen: add),
      );
    }
    return DataRegister<Payslip>(
      label: 'Payslips',
      lines: lines,
      rowId: (value) => workRowId(ref(value)),
      rowLabel: (value) => 'Payslip issued ${value.issuedDate}',
      selectedId: selectedId,
      onOpen: (value) => onOpen(ref(value)),
      columns: [
        RegisterColumn(
          key: 'issued',
          label: 'Issued',
          kind: ColumnKind.date,
          width: 104,
          value: (value) => value.issuedDate.toString(),
        ),
        RegisterColumn(
          key: 'paidOn',
          label: 'Paid on',
          kind: ColumnKind.date,
          width: 104,
          optional: true,
          value: (value) => value.paidDate?.toString() ?? '',
        ),
        RegisterColumn(
          key: 'period',
          label: 'Period',
          kind: ColumnKind.text,
          width: 196,
          optional: true,
          value: (value) => switch (periodById[value.periodId]) {
            final period? => periodName(period),
            null => '',
          },
        ),
        RegisterColumn(
          key: 'basis',
          label: 'Basis',
          kind: ColumnKind.text,
          width: 64,
          value: (value) => value.basis is GrossBasis ? 'Gross' : 'Net',
        ),
        RegisterColumn(
          key: 'amount',
          label: 'Amount',
          kind: ColumnKind.money,
          width: 112,
          value: (value) => formatMoney(value.amount),
        ),
        RegisterColumn(
          key: 'reference',
          label: 'Reference',
          kind: ColumnKind.text,
          width: 120,
          optional: true,
          value: (value) => value.reference ?? '',
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 88,
          value: (value) => value.isEffective ? 'Effective' : 'Void',
        ),
      ],
    );
  }
}

final class AgreementsSheet extends StatelessWidget {
  const AgreementsSheet({
    required this.rows,
    required this.employmentName,
    required this.selectedId,
    required this.onOpen,
    super.key,
  });

  final List<AgreementSheetRow> rows;
  final String employmentName;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;

  @override
  Widget build(BuildContext context) {
    WorkRecordRef ref(AgreementSheetRow row) =>
        WorkRecordRef(kind: WorkRecordKind.agreement, id: row.agreement.id);
    return DataRegister<AgreementSheetRow>(
      label: 'Agreements',
      lines: [
        if (rows.isNotEmpty) GroupLine(label: employmentName),
        for (final row in rows) RowLine(row),
      ],
      rowId: (row) => workRowId(ref(row)),
      rowLabel: (row) => 'Agreement version ${row.agreement.version}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(ref(row)),
      columns: [
        RegisterColumn(
          key: 'version',
          label: 'Version',
          kind: ColumnKind.quantity,
          width: 64,
          value: (row) => 'v${row.agreement.version}',
        ),
        RegisterColumn(
          key: 'from',
          label: 'From',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.agreement.effectiveStart.toString(),
        ),
        RegisterColumn(
          key: 'to',
          label: 'To',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.agreement.effectiveEnd?.toString() ?? '',
        ),
        RegisterColumn(
          key: 'rate',
          label: 'Rate',
          kind: ColumnKind.money,
          width: 88,
          value: (row) => formatHourlyRate(row.agreement.hourlyRateMicroEur),
        ),
        RegisterColumn(
          key: 'basis',
          label: 'Basis',
          kind: ColumnKind.text,
          width: 64,
          value: (row) => row.agreement.basis is GrossBasis ? 'Gross' : 'Net',
        ),
        RegisterColumn(
          key: 'overtime',
          label: 'Overtime',
          kind: ColumnKind.text,
          width: 120,
          optional: true,
          value: (row) =>
              'after ${formatHours(row.agreement.overtimeThresholdMinutes)} h '
              '×${formatMultiplier(row.agreement.overtimeMultiplier)}',
        ),
        RegisterColumn(
          key: 'night',
          label: 'Night',
          kind: ColumnKind.text,
          width: 144,
          optional: true,
          value: (row) => row.agreement.nightEnabled
              ? '${formatClock(row.agreement.nightStartMinute)}–'
                    '${formatClock(row.agreement.nightEndMinute)} '
                    '×${formatMultiplier(row.agreement.nightMultiplier)}'
              : 'Off',
        ),
        RegisterColumn(
          key: 'holiday',
          label: 'Holiday',
          kind: ColumnKind.text,
          width: 80,
          optional: true,
          value: (row) => row.agreement.holidayCalendar == HolidayCalendar.none
              ? 'Off'
              : '×${formatMultiplier(row.agreement.holidayMultiplier)}',
        ),
        RegisterColumn(
          key: 'stacking',
          label: 'Stacking',
          kind: ColumnKind.text,
          width: 112,
          optional: true,
          value: (row) => switch (row.agreement.premiumStacking) {
            PremiumStacking.highest => 'Highest wins',
            PremiumStacking.additive => 'Add extras',
            PremiumStacking.multiplicative => 'Multiply',
          },
        ),
        RegisterColumn(
          key: 'inUse',
          label: 'In use',
          kind: ColumnKind.quantity,
          width: 64,
          value: (row) =>
              row.finishedShifts == 0 ? 'No' : '${row.finishedShifts}',
        ),
      ],
    );
  }
}
