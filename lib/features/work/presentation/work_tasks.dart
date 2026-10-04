import 'package:flutter/widgets.dart';

import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/task_pane.dart';
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
  Widget group(String title, List<(String, VoidCallback?)> entries) =>
      TaskGroup(
        // Keyed by title so each group keeps its own collapsed state.
        key: ValueKey('work-task-group-$title'),
        title: title,
        special: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, action) in entries)
              if (action != null) TaskLink(label: label, onPressed: action),
          ],
        ),
      );

  return switch (c.selected) {
    ShiftRecordProjection(:final shift) => [
      group('Shift tasks', [
        if (shift.state == ShiftState.draft && shift.endUtc != null)
          ('Finalize this shift', c.onFinalize),
        if (shift.state == ShiftState.finalized)
          ('Correct this shift…', c.onCorrect),
        ('Properties', c.onProperties),
      ]),
    ],
    PayPeriodRecordProjection(:final period) => [
      group('Period tasks', [
        if (period.state == PayPeriodState.reviewed)
          ('Reopen this period', c.onReopen)
        else
          ('Mark this period reviewed', c.onMarkReviewed),
        ('Record payslip…', c.onRecordPayslipForPeriod),
        ('Properties', c.onProperties),
      ]),
    ],
    PayslipRecordProjection(:final payslip) => [
      group('Payslip tasks', [
        if (payslip.isEffective) ('Correct this payslip…', c.onCorrect),
        ('Properties', c.onProperties),
      ]),
    ],
    EmploymentRecordProjection() => [
      group('Employment tasks', [('Properties', c.onProperties)]),
    ],
    AgreementRecordProjection() => [
      group('Agreement tasks', [('Properties', c.onProperties)]),
    ],
    null => [
      group('Work tasks', [
        ('Add a shift', c.onAddShift),
        ('New pay period', c.onNewPeriod),
        ('Record payslip', c.onRecordPayslip),
        ('Set up pay agreement…', c.onSetUpAgreement),
        ('Employment properties', c.onEmploymentProperties),
        ('Save this view…', c.onSaveView),
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
          Text(
            recordName(record),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(kind),
          for (final (label, value) in facts) Text('$label: $value'),
        ],
      ),
    );
  }
}
