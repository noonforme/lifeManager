import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/shell/status_line.dart';
import '../../../ui/ui.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart' show RationalMultiplier;
import '../domain/day_exception.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import 'day_sheet.dart' show dayProblem;
import 'record_history_panel.dart';
import 'work_controller.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';
import 'work_route_state.dart';
import 'work_sheets.dart' show workRowId;

WorkRecordRef _ref(LeaveRecord leave) =>
    WorkRecordRef(kind: WorkRecordKind.leave, id: leave.id);

/// "100 %", "62.06 %", or "Not paid by the employer".
String leavePercent(LeavePay? pay) {
  final factor = pay?.factor;
  if (pay == null) return '';
  if (factor == null) return 'Not paid by the employer';
  return '${formatMultiplier(RationalMultiplier(numerator: factor.numerator * 100, denominator: factor.denominator))} %';
}

/// The average hourly earnings a leave day used, or "Agreement rate".
String leaveAverage(LeavePay? pay) {
  if (pay == null) return '';
  final average = pay.average;
  if (average == null || average.paidSeconds == 0) return 'Agreement rate';
  final perHour = (average.minorUnits * 3600 / average.paidSeconds).round();
  return '${formatMoney(Money(minorUnits: perHour))}/h';
}

/// The Leave sheet (schedules spec 6.5).
final class LeaveSheet extends StatelessWidget {
  const LeaveSheet({
    required this.rows,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    required this.showVoid,
    super.key,
  });

  final List<LeaveSheetRow> rows;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final ValueChanged<WorkRecordRef>? onProperties;
  final bool showVoid;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in rows)
        if (showVoid || row.record.isEffective) row,
    ]..sort((a, b) => a.record.date.compareTo(b.record.date));
    return DataRegister<LeaveSheetRow>(
      label: 'Leave',
      lines: [
        for (final row in visible)
          RowLine(
            row,
            state: row.record.isEffective ? RowState.normal : RowState.voided,
          ),
      ],
      sortedColumn: 'date',
      rowId: (row) => workRowId(_ref(row.record)),
      rowLabel: (row) =>
          '${leaveTypeLabel(row.record.leaveType)} on ${row.record.date}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(_ref(row.record)),
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(_ref(row.record)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(_ref(row.record)),
              ),
            ],
      columns: [
        RegisterColumn(
          key: 'date',
          label: 'Date',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.record.date.toString(),
        ),
        RegisterColumn(
          key: 'type',
          label: 'Type',
          kind: ColumnKind.text,
          width: 80,
          value: (row) => leaveTypeLabel(row.record.leaveType),
        ),
        RegisterColumn(
          key: 'hours',
          label: 'Hours',
          kind: ColumnKind.duration,
          width: 64,
          value: (row) => formatDuration(row.record.paidMinutes * 60),
        ),
        RegisterColumn(
          key: 'average',
          label: 'Average',
          description: 'Average hourly earnings used',
          kind: ColumnKind.derived,
          width: 104,
          value: (row) => leaveAverage(row.pay),
        ),
        RegisterColumn(
          key: 'percent',
          label: 'Percent',
          kind: ColumnKind.derived,
          width: 72,
          value: (row) => leavePercent(row.pay),
        ),
        RegisterColumn(
          key: 'pay',
          label: 'Pay',
          kind: ColumnKind.money,
          width: 88,
          value: (row) => row.pay == null ? '' : formatMoney(row.pay!.amount),
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 72,
          value: (row) => row.record.isEffective ? 'Confirmed' : 'Void',
        ),
      ],
    );
  }
}

/// A leave record's Properties: General and History (spec 3.6, 6.5).
final class LeavePropertiesHost extends ConsumerStatefulWidget {
  const LeavePropertiesHost({
    required this.leave,
    required this.pay,
    required this.today,
    super.key,
  });

  final LeaveRecord leave;
  final LeavePay? pay;
  final LocalDate today;

  @override
  ConsumerState<LeavePropertiesHost> createState() =>
      _LeavePropertiesHostState();
}

final class _LeavePropertiesHostState
    extends ConsumerState<LeavePropertiesHost> {
  String? _error;

  Future<void> _correct() async {
    final leave = widget.leave;
    final answer =
        await showDialog<({LeaveType type, LocalDate? illness, String reason})>(
          context: context,
          builder: (_) =>
              _CorrectLeaveDialog(leave: leave, today: widget.today),
        );
    if (answer == null || !mounted) return;
    final outcome = await ref
        .read(dayPlanServiceProvider)
        .correctLeave(
          leave.id,
          expected: leave.revision,
          leaveType: answer.type,
          illnessStartedOn: answer.illness,
          reason: answer.reason,
        );
    if (!mounted) return;
    if (outcome is Committed<LeaveRecord>) {
      StatusNoticeScope.read(context)?.value = 'Leave corrected.';
      ShellDialogScope.closeOf(context)?.call();
      return;
    }
    setState(
      () => _error = switch (outcome) {
        Invalid(:final fields) when fields.containsKey('reason') =>
          'Enter why the leave is corrected.',
        _ => dayProblem(outcome),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final pay = widget.pay;
    return RecordTabs(
      key: ValueKey(('tabs', leave.id)),
      record: _ref(leave),
      details: InspectorPane(
        children: [
          InspectorTitle(
            '${leaveTypeLabel(leave.leaveType)} on ${leave.date}',
            icon: EraIconKind.payPeriod,
          ),
          InspectorFacts(legend: 'Leave', [
            Fact('Date', leave.date.toString()),
            Fact.words('Type', leaveTypeLabel(leave.leaveType)),
            if (leave.illnessStartedOn case final start?)
              Fact('Illness started on', start.toString()),
            Fact('Hours', formatDuration(leave.paidMinutes * 60)),
            Fact('Average used', leaveAverage(pay)),
            Fact.words('Percent', leavePercent(pay)),
            Fact('Pay', pay == null ? '' : formatMoney(pay.amount)),
            Fact.words('State', leave.isEffective ? 'Confirmed' : 'Void'),
            if (leave.voidReason case final reason?)
              Fact.words('Void reason', reason),
          ]),
          if (pay != null && pay.usedFallback)
            const InspectorNote(
              'No confirmed work in the 3 months before; using the agreement '
              'rate.',
            ),
          if (pay != null && !pay.employerPaid)
            const InspectorNote(
              'Paid by the social insurer, not on your payslip.',
            ),
          const InspectorNote('Leave pay defaults, not legal advice.'),
          if (leave.isEffective)
            InspectorActions(
              children: [KeyButton(label: 'Correct…', onPressed: _correct)],
            ),
          if (_error case final error?)
            InspectorNote(error, tone: FactTone.negative),
        ],
      ),
    );
  }
}

final class _CorrectLeaveDialog extends StatefulWidget {
  const _CorrectLeaveDialog({required this.leave, required this.today});

  final LeaveRecord leave;
  final LocalDate today;

  @override
  State<_CorrectLeaveDialog> createState() => _CorrectLeaveDialogState();
}

final class _CorrectLeaveDialogState extends State<_CorrectLeaveDialog> {
  late var _type = widget.leave.leaveType;
  late LocalDate? _illness = widget.leave.illnessStartedOn;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Correct leave',
    body: EraFormScope(
      labelWidth: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The ${widget.leave.date} record is voided and replaced.'),
          const SizedBox(height: 7),
          EraRadioGroup<LeaveType>(
            options: const [
              EraRadioOption(LeaveType.vacation, 'Vacation'),
              EraRadioOption(LeaveType.sick, 'Sick'),
            ],
            groupValue: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          if (_type == LeaveType.sick) ...[
            const SizedBox(height: 7),
            EraDateField(
              fieldKey: const ValueKey('leave-correct-illness'),
              label: 'Illness started on',
              value: _illness,
              optional: true,
              today: widget.today,
              onChanged: (value) => setState(() => _illness = value),
            ),
          ],
          const SizedBox(height: 7),
          EraField(
            fieldKey: const ValueKey('leave-correct-reason'),
            controller: _reason,
            label: 'Reason',
          ),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop((
          type: _type,
          illness: _type == LeaveType.sick ? _illness : null,
          reason: _reason.text,
        )),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}
