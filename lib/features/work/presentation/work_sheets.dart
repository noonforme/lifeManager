import 'package:flutter/widgets.dart';

import '../../../core/explain/explanation.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../ui/ui.dart';
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
import 'work_plan_view.dart' show plannedShiftName;
import 'work_route_state.dart';

/// The Work sheets on Register v2 (shell spec 7.2). Each derived cell
/// carries the explanation of the result that produced it.

String workRowId(WorkRecordRef record) =>
    '${record.kind.name}:${record.id.value}';

/// "Draft", "Finalized" or "Void".
String shiftStateLabel(ShiftState state) => switch (state) {
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

/// The register id of the planned day on [date], such as "day:2026-10-06".
String plannedRowId(LocalDate date) => 'day:$date';

/// "No pay agreement" while no agreement covers the day; "To confirm" from
/// the day itself on, as its Properties offer Confirm; otherwise the
/// Calendar's words: "Planned", "Planned (changed)" or "Extra, planned".
String plannedStateLabel(PlannedShiftRow row) => row.withoutAgreement
    ? 'No pay agreement'
    : row.toConfirm
    ? 'To confirm'
    : row.day.isExtra
    ? 'Extra, planned'
    : row.day.changed
    ? 'Planned (changed)'
    : 'Planned';

/// One line of the Shifts sheet: a recorded shift, or a planned day that
/// is derived and not yet recorded.
sealed class _ShiftEntry {
  const _ShiftEntry();
}

final class _Recorded extends _ShiftEntry {
  const _Recorded(this.row);

  final ShiftSheetRow row;
}

final class _Planned extends _ShiftEntry {
  const _Planned(this.row);

  final PlannedShiftRow row;
}

final class ShiftsSheet extends StatelessWidget {
  const ShiftsSheet({
    required this.rows,
    required this.timezones,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    required this.showVoid,
    this.planned = const [],
    this.onOpenDay,
    this.onDayProperties,
    super.key,
  });

  final List<ShiftSheetRow> rows;
  final TimezoneService timezones;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;

  /// Opens the row's Properties (Enter, double-click, right-click).
  final ValueChanged<WorkRecordRef>? onProperties;
  final bool showVoid;

  /// Planned days in scope in start order, listed greyed among the shifts.
  /// They are not records: no Status filter hides them and no total counts
  /// them.
  final List<PlannedShiftRow> planned;

  /// Selects a planned row's day.
  final ValueChanged<LocalDate>? onOpenDay;

  /// Opens a planned row's day Properties, where it is confirmed.
  final ValueChanged<LocalDate>? onDayProperties;

  @override
  Widget build(BuildContext context) {
    final recorded = [
      for (final row in rows)
        if (showVoid || row.shift.state != ShiftState.voided) row,
    ];
    // The merge relies on both lists running by start: the register reads
    // shifts by start and the planner walks the dates in order. A planned
    // day then sits among the shifts by date, a recorded shift first on a
    // tie.
    assert(
      [
        for (var i = 1; i < planned.length; i++)
          !planned[i].day.startUtc.isBefore(planned[i - 1].day.startUtc),
      ].every((ordered) => ordered),
      'Planned rows must be in start order',
    );
    final visible = <_ShiftEntry>[];
    var next = 0;
    for (final row in recorded) {
      while (next < planned.length &&
          planned[next].day.startUtc.isBefore(row.shift.startUtc)) {
        visible.add(_Planned(planned[next++]));
      }
      visible.add(_Recorded(row));
    }
    visible.addAll([for (final row in planned.skip(next)) _Planned(row)]);

    String clock(DateTime? utc, String zone) => utc == null
        ? ''
        : timezones.localTimeAt(utc, zone).toString().substring(0, 5);
    String group(_ShiftEntry entry) {
      final (period, date) = switch (entry) {
        _Recorded(:final row) => (row.period, row.shift.localStartDate),
        _Planned(:final row) => (row.period, row.day.date),
      };
      if (period != null) return periodName(period);
      return '${_months[date.month - 1]} ${date.year}';
    }

    final lines = <RegisterLine<_ShiftEntry>>[];
    String? current;
    for (final entry in visible) {
      final name = group(entry);
      if (name != current) {
        current = name;
        lines.add(GroupLine(label: name));
      }
      lines.add(
        RowLine(
          entry,
          state: switch (entry) {
            _Planned() => RowState.planned,
            _Recorded(:final row) => switch (row.shift.state) {
              ShiftState.draft => RowState.draft,
              ShiftState.voided => RowState.voided,
              ShiftState.finalized => RowState.normal,
            },
          },
        ),
      );
    }

    String premium(_ShiftEntry entry, int Function(ExpectedPay pay) pick) {
      final pay = switch (entry) {
        _Recorded(:final row) => row.pay,
        _Planned(:final row) => row.pay,
      };
      return pay == null ? '' : formatDuration(pick(pay));
    }

    Explanation? premiumExplain(_ShiftEntry entry, PremiumHours which) =>
        switch (entry) {
          _Recorded(row: ShiftSheetRow(:final facts?, :final pay?)) =>
            explainPremiumHours(facts, pay, which),
          _ => null,
        };

    String typeName(_ShiftEntry entry) => switch (entry) {
      _Recorded(:final row) => row.typeName ?? '',
      _Planned(:final row) => plannedShiftName(row.day),
    };
    String id(_ShiftEntry entry) => switch (entry) {
      _Recorded(:final row) => workRowId(_shiftRef(row)),
      _Planned(:final row) => plannedRowId(row.day.date),
    };
    // Only a schedule names shifts, so without one the sheet is unchanged.
    final typed = visible.any((entry) => typeName(entry).isNotEmpty);
    final dayProperties = onDayProperties;
    final properties = onProperties;

    return DataRegister<_ShiftEntry>(
      label: 'Shifts',
      lines: lines,
      sortedColumn: 'date',
      rowId: id,
      rowLabel: (entry) => switch (entry) {
        _Recorded(:final row) =>
          'Shift on ${row.shift.localStartDate}, '
              '${shiftStateLabel(row.shift.state)}',
        _Planned(:final row) =>
          '${plannedShiftName(row.day)} shift on ${row.day.date}, '
              '${plannedStateLabel(row)}',
      },
      selectedId: selectedId,
      onOpen: (entry) => switch (entry) {
        _Recorded(:final row) => onOpen(_shiftRef(row)),
        _Planned(:final row) => onOpenDay?.call(row.day.date),
      },
      onActivate: properties == null && dayProperties == null
          ? null
          : (entry) => switch (entry) {
              _Recorded(:final row) => (properties ?? onOpen)(_shiftRef(row)),
              _Planned(:final row) => (dayProperties ?? onOpenDay)?.call(
                row.day.date,
              ),
            },
      actions: properties == null && dayProperties == null
          ? null
          : (entry) => [
              switch (entry) {
                _Recorded(:final row) => RowAction(
                  label: 'Properties',
                  isDefault: true,
                  onInvoke: properties == null
                      ? null
                      : () => properties(_shiftRef(row)),
                ),
                // A planned day's Properties are the day's own.
                _Planned(:final row) => RowAction(
                  label: 'Properties',
                  isDefault: true,
                  onInvoke: dayProperties == null
                      ? null
                      : () => dayProperties(row.day.date),
                ),
              },
            ],
      columns: [
        RegisterColumn(
          key: 'date',
          label: 'Date',
          kind: ColumnKind.date,
          width: 104,
          value: (entry) => switch (entry) {
            _Recorded(:final row) => row.shift.localStartDate.toString(),
            _Planned(:final row) => row.day.date.toString(),
          },
        ),
        if (typed)
          RegisterColumn(
            key: 'type',
            label: 'Type',
            kind: ColumnKind.text,
            width: 72,
            optional: true,
            value: typeName,
          ),
        RegisterColumn(
          key: 'start',
          label: 'Start',
          kind: ColumnKind.time,
          width: 64,
          value: (entry) => switch (entry) {
            _Recorded(:final row) => clock(
              row.shift.startUtc,
              row.shift.timezoneId,
            ),
            _Planned(:final row) => clock(row.day.startUtc, row.day.timezoneId),
          },
        ),
        RegisterColumn(
          key: 'end',
          label: 'End',
          kind: ColumnKind.time,
          width: 64,
          value: (entry) => switch (entry) {
            _Recorded(:final row) => clock(
              row.shift.endUtc,
              row.shift.timezoneId,
            ),
            _Planned(:final row) => clock(row.day.endUtc, row.day.timezoneId),
          },
        ),
        RegisterColumn(
          key: 'break',
          label: 'Break',
          kind: ColumnKind.duration,
          width: 64,
          optional: true,
          value: (entry) {
            final seconds = switch (entry) {
              _Recorded(:final row) => row.breakSeconds,
              _Planned(:final row) => row.day.breaks.fold(
                0,
                (sum, item) => sum + item.end.difference(item.start).inSeconds,
              ),
            };
            return seconds == 0 ? '' : formatDuration(seconds);
          },
        ),
        RegisterColumn(
          key: 'paid',
          label: 'Paid',
          kind: ColumnKind.duration,
          width: 64,
          value: (entry) => switch (entry) {
            _Recorded(:final row) =>
              row.paidSeconds == null ? '' : formatDuration(row.paidSeconds!),
            _Planned(:final row) => formatDuration(row.day.paidSeconds),
          },
          explain: (entry) => switch (entry) {
            _Recorded(row: ShiftSheetRow(:final facts?)) => explainPaidTime(
              facts,
              timezones,
            ),
            _ => null,
          },
        ),
        RegisterColumn(
          key: 'night',
          label: 'Night',
          kind: ColumnKind.derived,
          width: 64,
          optional: true,
          value: (entry) => premium(entry, (pay) => pay.nightPaidSeconds),
          explain: (entry) => premiumExplain(entry, PremiumHours.night),
        ),
        RegisterColumn(
          key: 'holiday',
          label: 'Holiday',
          kind: ColumnKind.derived,
          width: 72,
          optional: true,
          value: (entry) => premium(entry, (pay) => pay.holidayPaidSeconds),
          explain: (entry) => premiumExplain(entry, PremiumHours.holiday),
        ),
        RegisterColumn(
          key: 'overtime',
          label: 'OT',
          description: 'Overtime hours',
          kind: ColumnKind.derived,
          width: 64,
          // Overtime is only known once a day is confirmed (spec 4.1).
          value: (entry) => entry is _Planned
              ? ''
              : premium(entry, (pay) => pay.overtimePaidSeconds),
          explain: (entry) => premiumExplain(entry, PremiumHours.overtime),
        ),
        RegisterColumn(
          key: 'pay',
          label: 'Est. pay',
          description: 'Estimated pay, until a payslip confirms it',
          kind: ColumnKind.money,
          width: 112,
          value: (entry) => switch (entry) {
            _Recorded(:final row) =>
              row.pay == null ? '' : formatMoney(row.pay!.amount),
            _Planned(:final row) =>
              row.pay == null ? '' : formatMoney(row.pay!.amount),
          },
          explain: (entry) => switch (entry) {
            _Recorded(row: ShiftSheetRow(:final facts?, :final pay?)) =>
              explainExpectedPay(facts, pay),
            _ => null,
          },
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          // Room for "Planned (changed)" once the plan is listed.
          width: planned.isEmpty ? 96 : 120,
          value: (entry) => switch (entry) {
            _Recorded(:final row) => shiftStateLabel(row.shift.state),
            _Planned(:final row) => plannedStateLabel(row),
          },
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
    this.onProperties,
    super.key,
  });

  final List<PeriodSheetRow> rows;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;

  /// Opens the row's Properties (Enter, double-click, right-click).
  final ValueChanged<WorkRecordRef>? onProperties;

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
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(ref(row)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(ref(row)),
              ),
            ],
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
    this.onProperties,
    required this.showVoid,
    super.key,
  });

  final List<Payslip> payslips;
  final List<PeriodSheetRow> periods;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;

  /// Opens the row's Properties (Enter, double-click, right-click).
  final ValueChanged<WorkRecordRef>? onProperties;
  final bool showVoid;

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
    return DataRegister<Payslip>(
      label: 'Payslips',
      lines: lines,
      rowId: (value) => workRowId(ref(value)),
      rowLabel: (value) => 'Payslip issued ${value.issuedDate}',
      selectedId: selectedId,
      onOpen: (value) => onOpen(ref(value)),
      onActivate: onProperties == null
          ? null
          : (value) => onProperties!(ref(value)),
      actions: onProperties == null
          ? null
          : (value) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(ref(value)),
              ),
            ],
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
    this.onProperties,
    super.key,
  });

  final List<AgreementSheetRow> rows;
  final String employmentName;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;

  /// Opens the row's Properties (Enter, double-click, right-click).
  final ValueChanged<WorkRecordRef>? onProperties;

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
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(ref(row)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(ref(row)),
              ),
            ],
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
