import 'package:flutter/widgets.dart';

import '../../core/history/record_events.dart';
import '../../core/time/local_date.dart';
import '../../core/time/timezone_service.dart';
import '../../features/work/data/work_history.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import 'leave_working.dart';
import 'shifts_edit.dart';
import 'shifts_lines.dart';
import 'shifts_rows.dart';
import 'shifts_sheet_controller.dart';
import 'shifts_subform_lines.dart';

/// The subform tabs' ids.
abstract final class ShiftsSubformTab {
  static const breaks = 'breaks';
  static const history = 'history';
  static const working = 'working';
  static const dayPlan = 'dayPlan';
}

/// Words of the subform tabs.
abstract final class ShiftsSubformWords {
  static const historyUnreadable = 'History could not be read';
  static const historyTryAgain =
      'Local storage could not be read. Select the shift again to retry.';
  static const noRecord = 'Select a shift first.';
  static const noPlan = 'A manual shift has no plan to compare with.';
  static const noCyclePlan = 'The cycle plans no work on this day.';
  static const selectToEdit = 'Select the shift to change its breaks.';
  static const removeBreak = 'Remove break';
}

/// The selected record's subform tabs (spec 3, 4.2): Breaks, its children,
/// edited in the record's own pending edit; History, the persisted events
/// only; Working, how its pay is worked out; Day plan, its plan beside it.
/// A problem that keeps Add break or Remove break from acting goes to
/// [onProblem], for the status line.
List<SubformTab> shiftsSubformTabs({
  required ShiftsSheetController sheet,
  required ShiftsLine? line,
  required EditorSessionController editors,
  required TimezoneService timezones,
  required RecordHistory history,
  required LocalDate today,
  required String? selectedBreak,
  required ValueChanged<String?> onSelectBreak,
  required ValueChanged<String> onProblem,
}) {
  final breaks = breaksOf(sheet, timezones);
  final plan = line == null ? null : dayPlanLines(sheet, line, timezones);
  final noPlan = switch ((plan, line)) {
    (_?, _) => null,
    (_, null) => ShiftsSubformWords.noRecord,
    _
        when sheet.edit is PlannedEdit ||
            sheet.selectedRow is PlannedRow ||
            sheet.selectedRow is ReviewRow =>
      ShiftsSubformWords.noCyclePlan,
    _ => ShiftsSubformWords.noPlan,
  };
  return [
    SubformTab(
      id: ShiftsSubformTab.breaks,
      label: 'Breaks',
      count: breaks.length,
      countLabel: 'rows',
      builder: (context) => _BreaksTab(
        sheet: sheet,
        recordId: line?.id ?? 'none',
        breaks: breaks,
        editors: editors,
        today: today,
        selected: selectedBreak,
        onSelect: onSelectBreak,
        onProblem: onProblem,
      ),
    ),
    SubformTab(
      id: ShiftsSubformTab.history,
      label: 'History',
      builder: (context) => switch (sheet.selectedRow) {
        StoredRow(:final shift) => RecordHistoryTab(
          history: history,
          recordKind: WorkRecordKinds.shift,
          recordId: shift.id.value,
          editors: editors,
        ),
        _ => HistoryGrid(events: const [], editors: editors),
      },
    ),
    SubformTab(
      id: ShiftsSubformTab.working,
      label: 'Working',
      builder: (context) => _WorkingTab(sheet: sheet, editors: editors),
    ),
    SubformTab(
      id: ShiftsSubformTab.dayPlan,
      label: 'Day plan',
      enabled: plan != null,
      disabledReason: noPlan,
      builder: (context) =>
          _DayPlanTab(lines: plan ?? const [], editors: editors),
    ),
  ];
}

final class _BreaksTab extends StatelessWidget {
  const _BreaksTab({
    required this.sheet,
    required this.recordId,
    required this.breaks,
    required this.editors,
    required this.today,
    required this.selected,
    required this.onSelect,
    required this.onProblem,
  });

  final ShiftsSheetController sheet;
  final String recordId;
  final List<BreakLine> breaks;
  final EditorSessionController editors;
  final LocalDate today;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onProblem;

  int? _indexOf(String? id) {
    final prefix = '$recordId/break:';
    if (id == null || !id.startsWith(prefix)) return null;
    return int.tryParse(id.substring(prefix.length));
  }

  @override
  Widget build(BuildContext context) {
    final edit = sheet.edit;
    final saved = edit?.savedBreaks ?? const <BreakLine>[];
    final selectedIndex = _indexOf(selected);
    final canRemove =
        edit != null &&
        !edit.frozen &&
        selectedIndex != null &&
        selectedIndex < breaks.length;
    String rowId(BreakLine line) => breakRowId(recordId, line.index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: KeyButton(
            label: ShiftsSubformWords.removeBreak,
            onPressed: canRemove
                ? () {
                    if (!editors.flush().isAccepted) return;
                    if (edit.removeBreak(selectedIndex) case final problem?) {
                      onProblem(problem);
                    } else {
                      onSelect(null);
                    }
                  }
                : null,
          ),
        ),
        Expanded(
          child: DataGrid<BreakLine>(
            label: 'Breaks',
            columns: [
              GridColumn<BreakLine>(
                key: ShiftsField.start,
                label: 'Start',
                kind: ValueKind.time,
                width: 56,
                value: (line) => line.start,
                editable: true,
              ),
              GridColumn<BreakLine>(
                key: ShiftsField.end,
                label: 'End',
                kind: ValueKind.time,
                width: 56,
                value: (line) => line.end,
                editable: true,
              ),
              GridColumn<BreakLine>(
                key: 'length',
                label: 'Length',
                kind: ValueKind.duration,
                width: 56,
                value: (line) => line.minutes,
                display: (minutes) => formatDuration((minutes as int) * 60),
                description: 'Derived: unpaid time from start to end.',
              ),
            ],
            lines: [for (final line in breaks) GridRow(line)],
            rowId: rowId,
            rowLabel: (line) => 'Break ${line.index + 1}',
            selectedId: selected,
            onSelect: onSelect,
            editorController: editors,
            onEdit: (cell, draft) {
              final index = _indexOf(cell.rowId);
              final problem = edit == null || index == null
                  ? ShiftsSubformWords.selectToEdit
                  : edit.setBreak(index, cell.column, draft);
              return problem == null
                  ? const EditResult.accepted()
                  : EditResult.rejected(problem);
            },
            readOnlyReason: (line, column) => !column.editable || edit != null
                ? null
                : sheet.readOnlyReason ?? ShiftsSubformWords.selectToEdit,
            today: today,
            changed: {
              if (edit != null)
                for (final (index, field) in changedBreakCells(breaks, saved))
                  GridCell(rowId(breaks[index]), field),
            },
            errors: {
              if (edit != null)
                for (final MapEntry(:key, :value) in edit.issues.entries)
                  if (key == 'breaks' && breaks.isNotEmpty)
                    GridCell(rowId(breaks.first), ShiftsField.start): value
                  else if (key.startsWith('breaks.'))
                    if (int.tryParse(key.substring(7)) case final index?)
                      GridCell(breakRowId(recordId, index), ShiftsField.start):
                          value,
            },
            onNew: edit == null || edit.frozen
                ? null
                : () {
                    if (edit.addBreak() case final problem?) onProblem(problem);
                  },
            footerLabel: 'Total',
            footer: {
              'length': formatDuration(
                breaks.fold(0, (sum, line) => sum + line.minutes * 60),
              ),
            },
            showNavigator: false,
          ),
        ),
      ],
    );
  }
}

/// The persisted events of a stored record ([recordKind] is one of
/// `WorkRecordKinds`), oldest first, or why they cannot be read. The
/// stream is opened once per record.
final class RecordHistoryTab extends StatefulWidget {
  const RecordHistoryTab({
    super.key,
    required this.history,
    required this.recordKind,
    required this.recordId,
    required this.editors,
  });

  final RecordHistory history;
  final String recordKind;
  final String recordId;
  final EditorSessionController editors;

  @override
  State<RecordHistoryTab> createState() => _RecordHistoryTabState();
}

final class _RecordHistoryTabState extends State<RecordHistoryTab> {
  late Stream<List<RecordEvent>> _events = _watch();

  Stream<List<RecordEvent>> _watch() =>
      widget.history.watch(widget.recordKind, widget.recordId);

  @override
  void didUpdateWidget(RecordHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordId != widget.recordId ||
        oldWidget.recordKind != widget.recordKind) {
      _events = _watch();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<RecordEvent>>(
    stream: _events,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const OperationalState(
          kind: OperationalStateKind.unavailable,
          title: ShiftsSubformWords.historyUnreadable,
          message: ShiftsSubformWords.historyTryAgain,
        );
      }
      return HistoryGrid(
        events: snapshot.data ?? const [],
        editors: widget.editors,
      );
    },
  );
}

/// A record's events, oldest first, as the History tab lists them; with
/// none, the empty table.
final class HistoryGrid extends StatelessWidget {
  const HistoryGrid({required this.events, required this.editors, super.key});

  final List<RecordEvent> events;
  final EditorSessionController editors;

  @override
  Widget build(BuildContext context) => DataGrid<HistoryLine>(
    label: 'History',
    columns: [
      GridColumn<HistoryLine>(
        key: 'at',
        label: 'When',
        kind: ValueKind.text,
        width: 128,
        value: (line) => line.at,
      ),
      GridColumn<HistoryLine>(
        key: 'what',
        label: 'What',
        kind: ValueKind.text,
        width: 96,
        value: (line) => line.what,
      ),
      GridColumn<HistoryLine>(
        key: 'changes',
        label: 'Changes',
        kind: ValueKind.text,
        width: 260,
        value: (line) => line.changes,
      ),
      GridColumn<HistoryLine>(
        key: 'reason',
        label: 'Reason',
        kind: ValueKind.text,
        width: 140,
        value: (line) => line.reason,
      ),
    ],
    lines: [for (final event in events) GridRow(historyLine(event))],
    rowId: (line) => 'event:${line.id}',
    rowLabel: (line) => '${line.what} ${line.at}',
    selectedId: null,
    editorController: editors,
    showNavigator: false,
  );
}

final class _WorkingTab extends StatelessWidget {
  const _WorkingTab({required this.sheet, required this.editors});

  final ShiftsSheetController sheet;
  final EditorSessionController editors;

  @override
  Widget build(BuildContext context) {
    // A planned leave day explains its price as the Leave sheet does,
    // while its leave fields are as planned.
    final edit = sheet.edit;
    if (edit == null || edit is LeaveEdit && !edit.dirty) {
      if (sheet.selectedRow case LeaveRow(:final day, pay: final pay?)) {
        return leaveWorking(pay: pay, date: day.date, editors: editors);
      }
    }
    final working = workingOf(sheet);
    return DataGrid<WorkingLine>(
      label: 'Working',
      columns: [
        GridColumn<WorkingLine>(
          key: 'kind',
          label: 'Paid as',
          kind: ValueKind.text,
          width: 140,
          value: (line) => line.kind,
        ),
        GridColumn<WorkingLine>(
          key: 'time',
          label: 'Time',
          kind: ValueKind.duration,
          width: 56,
          value: (line) => line.seconds,
          display: (seconds) => formatDuration(seconds as int),
        ),
        GridColumn<WorkingLine>(
          key: 'rate',
          label: 'Rate',
          kind: ValueKind.text,
          width: 72,
          value: (line) => line.rate,
        ),
        GridColumn<WorkingLine>(
          key: 'multiplier',
          label: '×',
          kind: ValueKind.text,
          width: 48,
          value: (line) => line.multiplier,
        ),
      ],
      lines: [
        if (working case (:final pay, :final agreement))
          for (final line in workingLines(pay, agreement)) GridRow(line),
      ],
      rowId: (line) => 'group:${line.kind}',
      rowLabel: (line) => line.kind,
      selectedId: null,
      editorController: editors,
      footerLabel: switch (working) {
        (:final pay, agreement: _) => 'Est. pay ${formatMoney(pay.amount)}',
        null => null,
      },
      footer: switch (working) {
        (:final pay, agreement: _) => {
          'time': formatDuration(pay.totalPaidSeconds),
        },
        null => null,
      },
      note: switch (working) {
        (pay: _, :final agreement) => 'Pay agreement v${agreement.version}',
        null => null,
      },
      showNavigator: false,
    );
  }
}

/// The plan beside the day; the empty table when the tab is greyed but
/// still shown.
final class _DayPlanTab extends StatelessWidget {
  const _DayPlanTab({required this.lines, required this.editors});

  final List<DayPlanLine> lines;
  final EditorSessionController editors;

  @override
  Widget build(BuildContext context) => DataGrid<DayPlanLine>(
    label: 'Day plan',
    columns: [
      GridColumn<DayPlanLine>(
        key: 'label',
        label: '',
        kind: ValueKind.text,
        width: 72,
        value: (line) => line.label,
      ),
      GridColumn<DayPlanLine>(
        key: 'start',
        label: 'Start',
        kind: ValueKind.time,
        width: 56,
        value: (line) => line.start,
      ),
      GridColumn<DayPlanLine>(
        key: 'end',
        label: 'End',
        kind: ValueKind.time,
        width: 56,
        value: (line) => line.end,
      ),
      GridColumn<DayPlanLine>(
        key: 'paid',
        label: 'Paid',
        kind: ValueKind.duration,
        width: 56,
        value: (line) => line.paidSeconds,
        display: (seconds) => formatDuration(seconds as int),
      ),
    ],
    lines: [for (final line in lines) GridRow(line)],
    rowId: (line) => 'plan:${line.label}',
    rowLabel: (line) => line.label,
    selectedId: null,
    editorController: editors,
    showNavigator: false,
  );
}
