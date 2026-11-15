import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/data/work_history.dart' show WorkRecordKinds;
import '../../features/work/domain/agreement.dart' show RationalMultiplier;
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/leave.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import 'basis_total.dart';
import 'correct_leave_action.dart';
import 'leave_sheet_controller.dart';
import 'leave_working.dart';
import 'shifts_filter.dart';
import 'shifts_lines.dart' show leaveTypeWord;
import 'shifts_subform.dart' show HistoryGrid, RecordHistoryTab;
import 'work_shell.dart' show runCommand;

String leavePercent(LeavePay? pay) {
  if (pay == null) return '';
  final factor = pay.factor;
  return factor == null
      ? 'Not paid by the employer'
      : '${formatMultiplier(RationalMultiplier(numerator: factor.numerator * 100, denominator: factor.denominator))} %';
}

String leaveAverage(LeavePay? pay) {
  if (pay == null) return '';
  final average = pay.average;
  return average == null || average.paidSeconds == 0
      ? 'Agreement rate'
      : '${formatMoney(Money(minorUnits: (average.minorUnits * 3600 / average.paidSeconds).round()))}/h';
}

/// The shell slots for confirmed leave. Prices are the register's exact
/// projection; the Working tab explains them without another calculation.
final class LeaveSheetPart {
  LeaveSheetPart({
    required this.sheet,
    required this.editors,
    required this.today,
    required this.filter,
    required this.employmentName,
    required this.onEmployment,
    required this.onAgreement,
    required this.onSchedule,
    required this.onLeave,
  });
  final LeaveSheetController sheet;
  final EditorSessionController editors;
  final LocalDate today;
  final ShiftsFilter filter;
  final String employmentName;
  final VoidCallback onEmployment;
  final ValueChanged<AgreementId> onAgreement;
  final void Function(ScheduleId, int) onSchedule;
  final ValueChanged<LeaveRecordId> onLeave;
  void _command(Future<Object?> Function() run) => runCommand(editors, run);

  List<LeaveSheetRow> get rows {
    return [
      for (final row in sheet.rows)
        if (sheet.admits(row, filter)) row,
    ]..sort((a, b) {
      final date = a.record.date.compareTo(b.record.date);
      return date != 0 ? date : a.record.id.value.compareTo(b.record.id.value);
    });
  }

  Widget middle() {
    if (sheet.failed) {
      return SingleChildScrollView(
        child: OperationalState(
          kind: OperationalStateKind.unavailable,
          title: 'Leave could not be read',
          message: LeaveSheetWords.unreadable,
          action: KeyButton(
            label: 'Retry',
            onPressed: () => _command(sheet.reload),
          ),
        ),
      );
    }
    final visible = rows;
    final total = BasisTotal([
      for (final row in visible) (row.pay?.amount, row.pay?.basis),
    ]);
    return DataGrid<LeaveSheetRow>(
      label: 'Leave',
      columns: [
        GridColumn(
          key: 'date',
          label: 'Date',
          kind: ValueKind.date,
          width: 105,
          value: (row) => row.record.date,
        ),
        GridColumn(
          key: 'type',
          label: 'Type',
          kind: ValueKind.text,
          width: 75,
          value: (row) => leaveTypeWord(row.record.leaveType),
        ),
        GridColumn(
          key: 'hours',
          label: 'Hours',
          kind: ValueKind.duration,
          width: 60,
          value: (row) => row.record.paidMinutes * 60,
          display: (v) => formatDuration(v as int),
        ),
        GridColumn(
          key: 'average',
          label: 'Average',
          kind: ValueKind.text,
          width: 104,
          value: (row) => leaveAverage(row.pay),
        ),
        GridColumn(
          key: 'percent',
          label: 'Percent',
          kind: ValueKind.text,
          width: 85,
          value: (row) => leavePercent(row.pay),
        ),
        GridColumn(
          key: 'pay',
          label: 'Pay',
          kind: ValueKind.money,
          width: 85,
          value: (row) => row.pay?.amount.minorUnits,
          display: (v) => formatMoney(Money(minorUnits: v as int)),
        ),
        GridColumn(
          key: 'state',
          label: 'State',
          kind: ValueKind.text,
          width: 75,
          value: (row) => row.record.isEffective ? 'Confirmed' : 'Void',
        ),
      ],
      lines: [
        for (final row in visible)
          GridRow(
            row,
            state: row.record.isEffective
                ? GridRowState.normal
                : GridRowState.voided,
          ),
      ],
      rowId: (row) => row.record.id.value,
      rowLabel: (row) =>
          '${leaveTypeWord(row.record.leaveType)} on ${row.record.date}',
      selectedId: sheet.selectedId?.value,
      editorController: editors,
      onSelect: (id) => _command(() => sheet.select(LeaveRecordId(id))),
      sortColumn: 'date',
      footerLabel: 'Total${total.labelSuffix}',
      footer: {
        'hours': formatDuration(
          visible
              .where((row) => row.record.isEffective)
              .fold(0, (sum, row) => sum + row.record.paidMinutes * 60),
        ),
        'pay': visible.any((row) => row.record.isEffective && row.pay == null)
            ? 'Unavailable'
            : total.cell,
      },
    );
  }

  PropertyItem _fact(
    String key,
    String label,
    Object? value, {
    ValueKind kind = ValueKind.text,
    String? description,
    VoidCallback? follow,
    String category = 'Leave',
  }) => PropertyItem(
    key: key,
    label: label,
    category: category,
    value: value,
    kind: kind,
    readOnlyReason: sheet.selectedRow?.record.isEffective == false
        ? LeaveSheetWords.voided
        : LeaveSheetWords.readOnly,
    description: description,
    onFollow: follow,
  );

  Widget properties() {
    if (sheet.action case final action?) return _panel(action);
    final row = sheet.selectedRow;
    final value = row?.record;
    final pay = row?.pay;
    return PropertyGrid(
      record: value == null ? 'none' : 'leave:${value.id.value}',
      controller: editors,
      today: today,
      onCommit: (_, _) => const EditResult.rejected(LeaveSheetWords.readOnly),
      items: value == null
          ? const []
          : [
              _fact('date', 'Date', value.date, kind: ValueKind.date),
              _fact('type', 'Type', leaveTypeWord(value.leaveType)),
              if (value.leaveType == LeaveType.sick)
                _fact(
                  'illness',
                  'Illness started on',
                  value.illnessStartedOn,
                  kind: ValueKind.date,
                ),
              _fact(
                'hours',
                'Hours',
                formatDuration(value.paidMinutes * 60),
                kind: ValueKind.duration,
              ),
              _fact('state', 'State', value.isEffective ? 'Confirmed' : 'Void'),
              if (value.voidReason != null)
                _fact('reason', 'Void reason', value.voidReason),
              if (value.replacementId case final id?)
                _fact(
                  'replacement',
                  'Replacement',
                  'Open replacement',
                  follow: () => onLeave(id),
                ),
              if (value.replacedId case final id?)
                _fact(
                  'original',
                  'Original',
                  'Open original',
                  follow: () => onLeave(id),
                ),
              _fact(
                'average',
                'Average used',
                leaveAverage(pay),
                category: 'Pay',
                description: 'Average hourly earnings in the three calendar months before this day; the agreement rate when no paid time was confirmed.',
              ),
              _fact('percent', 'Percent', leavePercent(pay), category: 'Pay'),
              _fact(
                'pay',
                'Pay',
                !value.isEffective
                    ? 'Not in totals'
                    : pay == null
                    ? 'Unavailable'
                    : formatMoney(pay.amount),
                kind: ValueKind.money,
                category: 'Pay',
              ),
              _fact(
                'employment',
                'Employment',
                employmentName,
                category: 'Belongs to',
                follow: onEmployment,
              ),
              _fact(
                'agreement',
                'Pay agreement',
                'Open pay agreement',
                category: 'Belongs to',
                follow: () => onAgreement(value.agreementId),
              ),
              _fact(
                'schedule',
                'Schedule',
                'Open version ${value.scheduleVersion}',
                category: 'Belongs to',
                follow: () =>
                    onSchedule(value.scheduleId, value.scheduleVersion),
              ),
            ],
    );
  }

  Widget _panel(CorrectLeaveAction action) {
    final input = action.phase == CorrectLeavePhase.input && !sheet.archived;
    return ActionPanel(
      title: CorrectLeaveWords.title,
      record: 'correct-leave:${action.original.id.value}',
      controller: editors,
      today: today,
      cancelDraft: false,
      groups: () => [
        ActionGroup(
          legend: 'Confirmed leave',
          children: [
            Text(
              '${leaveTypeWord(action.original.leaveType)} on ${eraBoxDate(action.original.date)}',
            ),
            const Text(CorrectLeaveWords.explanation),
          ],
        ),
        ActionGroup(
          legend: 'Replacement',
          fields: [
            ActionField(
              id: 'type',
              label: 'Type',
              kind: ValueKind.choice,
              value: action.type,
              enabled: input,
              choices: [
                for (final type in LeaveType.values)
                  EraComboItem<Object?>(type, leaveTypeWord(type)),
              ],
            ),
            ActionField(
              id: 'illness',
              label: 'Illness started on',
              kind: ValueKind.date,
              value: action.illness,
              optional: true,
              start: action.original.date,
              enabled: input && action.type == LeaveType.sick,
              error: action.errors['illness'],
              validate: (v) =>
                  v == null ||
                      v is LocalDate && v.compareTo(action.original.date) <= 0
                  ? null
                  : CorrectLeaveWords.illness,
            ),
            ActionField(
              id: 'reason',
              label: 'Reason',
              kind: ValueKind.text,
              value: action.reason,
              text: action.reason,
              enabled: input,
              error: action.errors['reason'],
              fieldKey: const ValueKey('leave-correct-reason'),
            ),
          ],
        ),
      ],
      onChanged: action.set,
      primaryLabel: action.primaryLabel,
      onPrimary:
          action.canSubmit &&
              (input || action.phase == CorrectLeavePhase.uncertain)
          ? () => unawaited(sheet.submitAction())
          : null,
      onCancel: () => _command(sheet.cancelAction),
      results: [
        if (action.phase == CorrectLeavePhase.uncertain)
          const ActionResult.uncertain(
            'Correction',
            detail: CorrectLeaveWords.uncertain,
          ),
      ],
      error: action.error,
      busy: action.busy,
    );
  }

  List<SubformTab> subformTabs() => [
    SubformTab(
      id: 'history',
      label: 'History',
      builder: (_) => sheet.selectedRow == null
          ? HistoryGrid(events: const [], editors: editors)
          : RecordHistoryTab(
              history: sheet.work.history,
              recordKind: WorkRecordKinds.leave,
              recordId: sheet.selectedId!.value,
              editors: editors,
            ),
    ),
    SubformTab(id: 'working', label: 'Working', builder: (_) => _working()),
  ];

  Widget _working() {
    final row = sheet.selectedRow;
    if (row?.pay case final pay?) {
      return leaveWorking(pay: pay, date: row!.record.date, editors: editors);
    }
    return noLeaveWorking(editors);
  }

  /// Reload record with the other sheets' record keys; Correct… with the
  /// sheet's commands on the second row.
  List<ToolbarBand> bands() => [
    ToolbarBand(
      items: [
        ToolbarItem(
          label: 'Reload record',
          onPressed: sheet.action == null ? () => _command(sheet.reload) : null,
        ),
      ],
    ),
    ToolbarBand(
      row: 1,
      items: [
        ToolbarItem(
          label: 'Correct…',
          tooltip: sheet.correctBlocked,
          onPressed: sheet.correctBlocked == null
              ? () => _command(sheet.openCorrect)
              : null,
        ),
      ],
    ),
  ];
  List<EraMenuItem> editMenu() => [
    for (final label in ['Save', 'Undo'])
      EraMenuItem(
        label,
        null,
        disabledReason: sheet.selectedRow == null
            ? 'Select confirmed leave first.'
            : sheet.selectedRow!.record.isEffective
            ? LeaveSheetWords.readOnly
            : LeaveSheetWords.voided,
      ),
  ];
  List<EraMenuItem> recordMenu() => [
    EraMenuItem(
      'Correct…',
      sheet.correctBlocked == null ? () => _command(sheet.openCorrect) : null,
      disabledReason: sheet.correctBlocked,
    ),
  ];
  String notice() =>
      sheet.action?.notice ??
      sheet.notice ??
      (sheet.failed
          ? LeaveSheetWords.unreadable
          : !sheet.loaded
          ? LeaveSheetWords.loading
          : sheet.rows.isEmpty
          ? LeaveSheetWords.empty
          : sheet.selectedRow == null
          ? LeaveSheetWords.ready
          : sheet.selectedRow!.record.isEffective
          ? LeaveSheetWords.readOnlyStatus
          : LeaveSheetWords.voidedStatus);
}
