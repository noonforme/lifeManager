import 'package:flutter/widgets.dart';

import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/task_pane.dart';
import '../../../shared/workbench/era_icons.dart';
import '../data/projections/work_record_projection.dart';
import '../domain/pay_period.dart';
import '../domain/shift.dart';
import 'work_formats.dart';
import 'work_record_names.dart';

/// What the task pane offers for the current selection (XP-authentic shell
/// spec 4.1). A null callback means the action is not offered, and its
/// link is left out rather than greyed.
final class WorkTaskContext {
  const WorkTaskContext({
    required this.selected,
    this.onConfirmDays,
    this.onNewSchedule,
    this.onAddShift,
    this.onNewPeriod,
    this.onRecordPayslip,
    this.onSaveView,
    this.onProperties,
    this.onEmploymentProperties,
    this.onSetUpAgreement,
    this.onFinalize,
    this.onCorrect,
    this.onMarkReviewed,
    this.onReopen,
    this.onRecordPayslipForPeriod,
  });

  final WorkRecordProjection? selected;

  /// Opens Confirm worked days; null without a schedule.
  final VoidCallback? onConfirmDays;

  /// Opens a new schedule; null without an agreement.
  final VoidCallback? onNewSchedule;
  final VoidCallback? onAddShift;
  final VoidCallback? onNewPeriod;
  final VoidCallback? onRecordPayslip;
  final VoidCallback? onSaveView;
  final VoidCallback? onProperties;
  final VoidCallback? onEmploymentProperties;
  final VoidCallback? onSetUpAgreement;
  final VoidCallback? onFinalize;
  final VoidCallback? onCorrect;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onReopen;
  final VoidCallback? onRecordPayslipForPeriod;
}

/// The special task group for [c]'s selection, as Explorer's "File and
/// Folder Tasks" followed the selected item.
List<Widget> workTaskGroups(WorkTaskContext c) {
  Widget group(
    String title,
    List<(String, EraIconKind, VoidCallback?)> entries,
  ) => TaskGroup(
    // Keyed by title so each group keeps its own collapsed state.
    key: ValueKey('work-task-group-$title'),
    title: title,
    special: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, icon, action) in entries)
          if (action != null)
            TaskLink(label: label, icon: icon, onPressed: action),
      ],
    ),
  );

  return switch (c.selected) {
    ShiftRecordProjection(:final shift) => [
      group('Shift tasks', [
        if (shift.state == ShiftState.draft && shift.endUtc != null)
          ('Finalize this shift', EraIconKind.reviewed, c.onFinalize),
        if (shift.state == ShiftState.finalized)
          ('Correct this shift…', EraIconKind.correct, c.onCorrect),
        ('Properties', EraIconKind.properties, c.onProperties),
      ]),
    ],
    PayPeriodRecordProjection(:final period) => [
      group('Period tasks', [
        if (period.state == PayPeriodState.reviewed)
          ('Reopen this period', EraIconKind.payPeriod, c.onReopen)
        else
          ('Mark this period reviewed', EraIconKind.reviewed, c.onMarkReviewed),
        (
          'Record payslip…',
          EraIconKind.recordPayslip,
          c.onRecordPayslipForPeriod,
        ),
        ('Properties', EraIconKind.properties, c.onProperties),
      ]),
    ],
    PayslipRecordProjection(:final payslip) => [
      group('Payslip tasks', [
        if (payslip.isEffective)
          ('Correct this payslip…', EraIconKind.correct, c.onCorrect),
        ('Properties', EraIconKind.properties, c.onProperties),
      ]),
    ],
    EmploymentRecordProjection() => [
      group('Employment tasks', [
        ('Properties', EraIconKind.properties, c.onProperties),
      ]),
    ],
    AgreementRecordProjection() => [
      group('Agreement tasks', [
        ('Properties', EraIconKind.properties, c.onProperties),
      ]),
    ],
    null => [
      group('Work tasks', [
        ('Confirm worked days…', EraIconKind.reviewed, c.onConfirmDays),
        ('New schedule…', EraIconKind.add, c.onNewSchedule),
        ('Add a shift', EraIconKind.add, c.onAddShift),
        ('New pay period', EraIconKind.add, c.onNewPeriod),
        ('Record payslip', EraIconKind.recordPayslip, c.onRecordPayslip),
        ('Set up pay agreement…', EraIconKind.agreement, c.onSetUpAgreement),
        (
          'Employment properties',
          EraIconKind.properties,
          c.onEmploymentProperties,
        ),
        ('Save this view…', EraIconKind.saveView, c.onSaveView),
      ]),
    ],
  };
}

/// The selected record in the Details group: its name, kind and a few
/// facts (spec 4.2).
final class RecordSummary extends StatelessWidget {
  const RecordSummary({required this.record, this.timezones, super.key});

  final WorkRecordProjection record;
  final TimezoneService? timezones;

  @override
  Widget build(BuildContext context) {
    final (kind, facts) = switch (record) {
      ShiftRecordProjection(:final shift, :final pay) => (
        'Shift',
        [
          (
            'State',
            switch (shift.state) {
              ShiftState.draft => 'Draft',
              ShiftState.finalized => 'Finalized',
              ShiftState.voided => 'Void',
            },
          ),
          if (pay != null) ('Paid time', formatDuration(pay.totalPaidSeconds)),
          if (pay != null) ('Expected pay', formatMoney(pay.amount)),
        ],
      ),
      PayPeriodRecordProjection(:final period) => (
        'Pay period',
        [
          ('Dates', '${period.start} – ${period.end}'),
          (
            'State',
            period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open',
          ),
        ],
      ),
      PayslipRecordProjection(:final payslip) => (
        'Payslip',
        [
          ('Amount', formatMoney(payslip.amount)),
          ('Issued', '${payslip.issuedDate}'),
          ('State', payslip.isEffective ? 'Effective' : 'Void'),
        ],
      ),
      EmploymentRecordProjection() => ('Employment', <(String, String)>[]),
      AgreementRecordProjection(:final finishedShifts) => (
        'Pay agreement',
        [('Finished shifts', '$finishedShifts')],
      ),
    };
    return Semantics(
      liveRegion: true,
      child: TaskDetails(
        lines: [
          Row(
            children: [
              EraIcon(recordIcon(record)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  recordName(record),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Text(kind),
          for (final (label, value) in facts) Text('$label: $value'),
        ],
      ),
    );
  }
}
