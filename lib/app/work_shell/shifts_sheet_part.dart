import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/planner.dart' show PlannedShift;
import '../../features/work/domain/shift.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import 'basis_total.dart';
import 'calendar_days.dart';
import 'confirm_days_action.dart';
import 'day_action.dart';
import 'shifts_action.dart';
import 'shifts_edit.dart';
import 'shifts_filter.dart';
import 'shifts_filter_strip.dart' show scopeTitle;
import 'shifts_lines.dart';
import 'shifts_rows.dart';
import 'shifts_sheet_controller.dart';
import 'shifts_subform.dart';
import 'work_location.dart' show WorkSheetKind;

/// Words of the property column's record facts (spec 4.2: the description
/// names a read-only value's reason and permitted action).
abstract final class ShiftsPropertyWords {
  static const voidReason = 'Given when the shift was voided.';
  static const illnessOnConfirm = 'Worked out on confirm';
  static const overtime = 'Paid as overtime when confirmed.';
  static const extend = 'Extend pay agreement…';
  static const extendWhy =
      'No pay agreement covers this date, so it has no pay and cannot be '
      'confirmed. Extend pay agreement… widens the nearest agreement to '
      'cover it.';
  static const leave =
      'Vacation or Sick. Changing it here is Change leave; Restore shift '
      'brings the planned shift back.';
  static const shiftType =
      'Any shift type of the schedule in use on this date. Its times and '
      'breaks fill in; change them after if needed.';
  static const illnessOnlySick = 'Only sick leave has an illness start.';
  static const insteadOf = 'The planned shift this leave replaces.';
  static const hours = "The replaced shift's paid hours.";
  static const replacement =
      "A correction's replacement draft: change it, then Save to finalize "
      'it.';
  static const otherMonth = 'In another month: open that month to see it.';
  static const otherMonthLink =
      'In another month: following it opens that month.';
  static const link = 'Select it in the sheet.';
}

/// What a Needs review day's change was.
String changeKindLabel(DayException exception) => switch (exception) {
  ChangedDay() => 'Changed times',
  ExtraDay() => 'Extra shift',
  CancelledDay() => 'Cancelled shift',
  LeaveDay() => 'Leave',
};

/// The Shifts sheet's part of the Work shell's window (spec 3, 4.2): the
/// grid of planned and stored shifts, the property column of the selected
/// one or its open Correct or Void panel, the subform tabs, the toolbar
/// bands, the Record menu and the status line, over a
/// [ShiftsSheetController]. The shell puts them in AppFrame's slots. It
/// keeps only what the sheet's view selects: the selected break and what
/// kept a break command from acting.
final class ShiftsSheetPart extends ChangeNotifier {
  ShiftsSheetPart({
    required this.sheet,
    required this.editors,
    required this.work,
    required this.today,
    required this.followShift,
    this.followLeave,
    this.extendAgreement,
    this.pendingDays,
    this.confirmWorkedDays,
    this.extendAgreementOver,
  }) {
    sheet.addListener(_clearBreakProblem);
    sheet.addListener(_dropLines);
  }

  /// Every line of the sheet, worked out once per change of the sheet:
  /// the grid, the strip's types and Filter by selection share them.
  List<ShiftsLine> get allLines =>
      _allLines ??= shiftsLines(sheet, work.timezones);
  List<ShiftsLine>? _allLines;

  void _dropLines() => _allLines = null;

  /// Extend pay agreement… for a day no agreement covers (plan 4d-1, call
  /// 13): the shell's guarded command. Without it the pay stays blank.
  final void Function(LocalDate date)? extendAgreement;

  /// The employment's past days waiting to be confirmed, all months; the
  /// shell knows them (plan 4d-2).
  final int Function()? pendingDays;

  /// Confirm worked days…: the shell moves to To confirm and opens the
  /// panel there (owner pick 2B).
  final VoidCallback? confirmWorkedDays;

  /// Extend pay agreement… over every day of To confirm's group of days
  /// no agreement covers.
  final void Function(List<LocalDate> days)? extendAgreementOver;

  final ShiftsSheetController sheet;
  final EditorSessionController editors;
  final ProductionWorkProviders work;
  final LocalDate today;

  /// Opens the shift a Replaces or Replaced by link names, in its own
  /// month (a guarded move of the shell, spec 4.5).
  final void Function(ShiftId id) followShift;

  /// Opens a confirmed leave record on its own read-only sheet.
  final void Function(LeaveRecordId id)? followLeave;

  /// The selected break, for Remove break. Its id carries its record's,
  /// so it never applies to another record's breaks.
  String? _selectedBreak;
  String? _breakRecord;
  bool _disposed = false;

  /// What kept Add break or Remove break from acting, for the status line
  /// until the sheet next changes.
  String? _breakProblem;

  void _clearBreakProblem() {
    _breakProblem = null;
    if (_breakRecord != sheet.selectedId) {
      _selectedBreak = null;
      _breakRecord = sheet.selectedId;
    }
  }

  /// The rows as the grid lists them.
  /// The place's filters (spec 3), set by the shell from its route.
  ShiftsFilter filter = ShiftsFilter.none;

  /// The toolbar's Find text: rows showing it, ignoring case.
  String find = '';

  /// The column the grid sorts by, and which way (spec 3, Data band).
  String sortColumn = ShiftsField.date;
  bool sortDescending = false;

  /// A header click: that column ascending, or the other way when it is
  /// the sorted one already.
  void sortBy(String column) {
    if (column == sortColumn) {
      sortDescending = !sortDescending;
    } else {
      sortColumn = column;
      sortDescending = false;
    }
    notifyListeners();
  }

  /// The toolbar's Sort: the sorted column the other way.
  void reverseSort() => sortBy(sortColumn);

  /// The lines the grid lists: the sheet's, filtered and found, never
  /// without the selected or new row, then sorted.
  List<ShiftsLine> get lines {
    final shown = filterShiftsLines(
      allLines,
      filter: filter,
      // Pick mode lists every day it may confirm: Find hides none.
      find: sheet.confirmDays == null ? find : '',
      keep: sheet.selectedId,
    );
    // To confirm lists the days to confirm, those no agreement covers, the
    // selected line and every day the open panel holds a result for (plan
    // 4d-2, call 5).
    if (sheet.kind == WorkSheetKind.toConfirm) {
      final sent = _resultRows();
      shown.retainWhere(
        (line) =>
            line.toConfirm ||
            (line.withoutAgreement && line.date.compareTo(today) < 0) ||
            line.id == sheet.selectedId ||
            sent.containsKey(line.id),
      );
      return shown;
    }
    // By start already: the default needs no sort.
    if (sortColumn == ShiftsField.date && !sortDescending) return shown;
    final order = {for (final (index, line) in shown.indexed) line.id: index};
    int compare(ShiftsLine a, ShiftsLine b) {
      final byValue = _compareBy(sortColumn, a, b);
      final sorted = sortDescending ? -byValue : byValue;
      return sorted != 0 ? sorted : order[a.id]!.compareTo(order[b.id]!);
    }

    // The new row stays last while it is typed, not moving with its values.
    final typed = shown.where((line) => line.id == newRowId).toList();
    return [
      ...shown.where((line) => line.id != newRowId).toList()..sort(compare),
      ...typed,
    ];
  }

  /// The open panel's result of each day sent, by the row that day selects
  /// now: its plan row, or what confirming it made, never a void shift
  /// beside it.
  Map<String, ConfirmDayOutcome> _resultRows() => {
    for (final MapEntry(:key, :value)
        in (sheet.confirmDays?.results ?? const {}).entries)
      ?sheet.rowIdOn(key): value,
  };

  /// [a] against [b] by [column]'s value; an empty value sorts last.
  static int _compareBy(String column, ShiftsLine a, ShiftsLine b) {
    Comparable<Object?>? key(ShiftsLine line) => switch (column) {
      ShiftsField.date => line.date.toString(),
      ShiftsField.start || ShiftsField.end => switch (line.value(column)) {
        final LocalTime time? => time.hour * 60 + time.minute,
        _ => null,
      },
      'break' => line.breakSeconds,
      'paid' => line.paidSeconds,
      'pay' => line.pay?.minorUnits,
      'status' => line.status.label,
      _ => switch (line.value(column)) {
        final String text? when text.isNotEmpty => text,
        _ => null,
      },
    } as Comparable<Object?>?;
    final (x, y) = (key(a), key(b));
    if (x == null || y == null) return x == y ? 0 : (x == null ? 1 : -1);
    return x.compareTo(y);
  }

  /// Filter by selection (spec 3): the selected row's status group and
  /// type; null with no row selected (or the new one).
  ShiftsFilter? get selectionFilter {
    final selected = sheet.selectedId;
    if (selected == null || selected == newRowId) return null;
    final line = allLines.where((value) => value.id == selected).firstOrNull;
    if (line == null) return null;
    // The Calendar filters by Type only (plan 4d-2, call 7).
    if (sheet.kind == WorkSheetKind.calendar) {
      return line.type == null ? null : ShiftsFilter(type: line.type);
    }
    if (line.status == ShiftsStatus.off) {
      return const ShiftsFilter(offDays: true);
    }
    final status = ShiftsStatusFilter.values.firstWhere(
      (value) =>
          value != ShiftsStatusFilter.all &&
          value != ShiftsStatusFilter.effective &&
          value.admits(line.status),
      orElse: () => ShiftsStatusFilter.all,
    );
    return ShiftsFilter(status: status, type: line.type);
  }

  /// The navigator's note: the filters set, if any.
  String? get filteredNote {
    final set = [
      if (filter.status != ShiftsStatusFilter.all) 'Status',
      if (filter.type != null) 'Type',
      if (filter.offDays) 'Off days',
      if (find.trim().isNotEmpty) 'Find',
    ];
    return set.isEmpty ? null : 'Filtered: ${set.join(', ')}';
  }

  /// The subform's tabs for the selected [line] (spec 3).
  List<SubformTab> subformTabs(ShiftsLine? line) {
    final tabs = _subformTabs(line);
    // Pick mode greys the subform (umbrella 4.4).
    if (sheet.confirmDays == null) return tabs;
    return [
      for (final tab in tabs)
        SubformTab(
          id: tab.id,
          label: tab.label,
          builder: tab.builder,
          icon: tab.icon,
          enabled: false,
          disabledReason: ShiftsCommandWords.actionOpen,
          tooltip: tab.tooltip,
          count: tab.count,
          countLabel: tab.countLabel,
        ),
    ];
  }

  List<SubformTab> _subformTabs(ShiftsLine? line) => shiftsSubformTabs(
    sheet: sheet,
    line: line,
    editors: editors,
    timezones: work.timezones,
    history: work.history,
    today: today,
    selectedBreak: _selectedBreak,
    onSelectBreak: (id) {
      if (_disposed) return;
      _selectedBreak = id;
      notifyListeners();
    },
    onProblem: (problem) {
      if (_disposed) return;
      _breakProblem = problem;
      notifyListeners();
    },
  );

  /// What the subform's caption says it shows.
  Widget? subformTrailing(ShiftsLine? line) => line == null
      ? null
      : Text('for ${line.status.label} ${eraBoxDate(line.date)}');

  /// The property column: the open panel, else the selected row's
  /// properties.
  Widget propertyColumn(List<ShiftsLine> lines) =>
      switch ((sheet.action, sheet.dayAction, sheet.confirmDays)) {
        (final action?, _, _) => actionPanel(action),
        (_, final day?, _) => dayActionPanel(day),
        (_, _, final bulk?) => confirmDaysPanel(bulk),
        _ => properties(lines),
      };

  /// Runs [command] once the open editor's value is taken.
  void _command(Future<Object?> Function() command) {
    if (!editors.flush().isAccepted) return;
    unawaited(command());
  }

  /// The selected planned day's type choices, by name.
  List<EraComboItem<Object?>> get _typeChoices => switch (sheet.edit) {
    PlannedEdit(:final typeChoices) => [
      for (final type in typeChoices)
        EraComboItem<Object?>(type.name, type.name),
    ],
    _ => const [],
  };

  List<GridColumn<ShiftsLine>> get _columns => [
    GridColumn<ShiftsLine>(
      key: ShiftsField.date,
      label: 'Date',
      kind: ValueKind.date,
      width: 104,
      value: (line) => line.date,
      editable: true,
    ),
    GridColumn<ShiftsLine>(
      key: ShiftsField.type,
      label: 'Type',
      kind: ValueKind.choice,
      width: 64,
      value: (line) =>
          line.type ?? (line.status == ShiftsStatus.off ? 'Off' : ''),
      choices: _typeChoices,
      editable: true,
      description: "The schedule's shift type, Extra, or Manual.",
    ),
    GridColumn<ShiftsLine>(
      key: ShiftsField.start,
      label: 'Start',
      kind: ValueKind.time,
      width: 56,
      value: (line) => line.start,
      editable: true,
    ),
    GridColumn<ShiftsLine>(
      key: ShiftsField.end,
      label: 'End',
      kind: ValueKind.time,
      width: 56,
      value: (line) => line.end,
      editable: true,
    ),
    GridColumn<ShiftsLine>(
      key: 'break',
      label: 'Break',
      kind: ValueKind.duration,
      width: 52,
      value: (line) => line.breakSeconds,
      display: (seconds) => formatDuration(seconds as int),
      description: 'Derived from the breaks.',
    ),
    GridColumn<ShiftsLine>(
      key: 'paid',
      label: 'Paid',
      kind: ValueKind.duration,
      width: 52,
      value: (line) => line.paidSeconds,
      display: (seconds) => formatDuration(seconds as int),
      description: 'Derived: the shift minus its breaks.',
    ),
    GridColumn<ShiftsLine>(
      key: 'status',
      label: 'Status',
      kind: ValueKind.text,
      width: 120,
      value: (line) => line.statusText,
    ),
    GridColumn<ShiftsLine>(
      key: 'pay',
      label: 'Est. pay',
      kind: ValueKind.money,
      width: 88,
      value: (line) => line.pay,
      display: (amount) => formatMoney(amount as Money),
      description: 'Derived from the agreement that covers the date.',
    ),
    GridColumn<ShiftsLine>(
      key: ShiftsField.note,
      label: 'Note',
      kind: ValueKind.text,
      width: 140,
      value: (line) => line.note,
      editable: true,
    ),
  ];

  EditResult _commit(String rowId, String field, Object? draft) {
    final problem = sheet.editField(rowId, field, draft);
    return problem == null
        ? const EditResult.accepted()
        : EditResult.rejected(problem);
  }

  /// The Shifts grid (spec 3): planned and stored rows by start.
  Widget grid(List<ShiftsLine> lines) {
    final edit = sheet.edit;
    // Void shifts and planned estimates are not totalled (spec 3 footer).
    final recorded = lines.where(countsInTotals).toList();
    final pay = BasisTotal([
      for (final line in recorded) (line.pay, line.basis),
    ]);
    final selected = sheet.selectedId;
    return DataGrid<ShiftsLine>(
      label: 'Shifts',
      columns: _columns,
      lines: [
        GridGroup(
          label: sheet.wholeMonth
              ? eraMonthTitle(sheet.from)
              : scopeTitle(sheet.from, sheet.to),
          summary: lines.length == 1 ? '1 row' : '${lines.length} rows',
        ),
        for (final line in lines)
          GridRow(
            line,
            state: switch (line.status) {
              ShiftsStatus.voided => GridRowState.voided,
              ShiftsStatus.planned ||
              ShiftsStatus.changed ||
              ShiftsStatus.extra ||
              ShiftsStatus.review ||
              ShiftsStatus.off => GridRowState.muted,
              _ => GridRowState.normal,
            },
          ),
      ],
      rowId: (line) => line.id,
      rowLabel: (line) => '${line.status.label} ${eraBoxDate(line.date)}',
      selectedId: selected,
      onSelect: (id) => unawaited(sheet.select(id)),
      editorController: editors,
      onEdit: (cell, draft) => _commit(cell.rowId, cell.column, draft),
      readOnlyReason: (line, column) => column.editable
          ? shiftsReadOnlyReason(sheet, line, column.key)
          : null,
      today: today,
      pendingIds: {
        if (selected != null && edit != null && edit.dirty) selected,
      },
      changed: {
        if (selected != null && edit != null)
          for (final field in edit.editable)
            if (edit.changed(field)) GridCell(selected, field),
      },
      errors: {
        if (selected != null && edit != null)
          for (final MapEntry(:key, :value) in edit.issues.entries)
            GridCell(selected, _columnOf(key)): value,
      },
      onNew: () => _command(sheet.addShift),
      note: filteredNote,
      sortColumn: sortColumn,
      sortDescending: sortDescending,
      onSort: sortBy,
      footerLabel:
          'Total (${recorded.length} '
          '${recorded.length == 1 ? 'shift' : 'shifts'})'
          '${pay.labelSuffix}',
      footer: {
        'paid': formatDuration(
          recorded.fold(0, (sum, line) => sum + (line.paidSeconds ?? 0)),
        ),
        'pay': pay.cell,
      },
    );
  }

  /// The Calendar sheet's month (plan 4d-2, owner pick 1A): each day in
  /// words; a click selects the day's row. Type and Find dim the days they
  /// leave out, so the month keeps its shape.
  Widget calendar() {
    final selected = sheet.selectedRow?.date;
    return DayCalendar(
      label: 'Calendar',
      month: sheet.month,
      today: today,
      days: calendarDays(
        sheet: sheet,
        lines: allLines,
        timezones: work.timezones,
        type: filter.type,
        find: find,
      ),
      selected: selected,
      active: sheet.action == null && sheet.dayAction == null,
      // The open editor's value is taken first, as a grid's row click does.
      onSelect: (date) {
        if (!editors.flush().isAccepted) return;
        unawaited(sheet.select(sheet.rowIdOn(date) ?? plannedRowId(date)));
      },
    );
  }

  static const _confirmDaysLabel = 'Confirm worked days…';

  /// Why Confirm worked days… does not apply; null when it does.
  String? get confirmDaysBlocked {
    if (sheet.confirmDaysBlocked case final blocked?) return blocked;
    if (confirmWorkedDays == null) return ConfirmDaysWords.noDays;
    return (pendingDays?.call() ?? 0) == 0 ? ConfirmDaysWords.noDays : null;
  }

  ToolbarItem get _confirmDaysKey => ToolbarItem(
    label: _confirmDaysLabel,
    tooltip: confirmDaysBlocked,
    onPressed: switch ((confirmDaysBlocked, confirmWorkedDays)) {
      (null, final open?) => () {
        if (editors.flush().isAccepted) open();
      },
      _ => null,
    },
  );

  /// The To confirm sheet's grid (plan 4d-2): the days to confirm, oldest
  /// first, then those no pay agreement covers with Extend pay agreement…
  /// on their group row. In pick mode a click ticks a day, the footer
  /// totals the ticked days and each day sent shows its result.
  Widget toConfirmGrid(List<ShiftsLine> lines) {
    final bulk = sheet.confirmDays;
    final results = bulk?.results ?? const <LocalDate, ConfirmDayOutcome>{};
    final sent = _resultRows();
    final unpaid = [
      for (final line in lines)
        if (line.withoutAgreement && !results.containsKey(line.date)) line,
    ];
    final waiting = [
      for (final line in lines)
        if (!unpaid.contains(line)) line,
    ];
    final edit = sheet.edit;
    final selected = sheet.selectedId;
    final counted = waiting.where((line) => line.toConfirm).toList();
    GridRow<ShiftsLine> row(ShiftsLine line) => GridRow(
      line,
      state:
          line.withoutAgreement ||
              sent[line.id]?.result == ConfirmDayResult.confirmed
          ? GridRowState.muted
          : GridRowState.normal,
    );
    final (footerLabel, paid, pay) = switch (bulk) {
      final bulk? => (
        bulk.phase == ConfirmDaysPhase.picking
            ? 'Ticked (${ConfirmDaysWords.days(bulk.ticked.length)})'
            : 'Left (${ConfirmDaysWords.days(bulk.left)})',
        bulk.tickedPaidSeconds,
        bulk.tickedPay,
      ),
      null => (
        'Total (${ConfirmDaysWords.days(counted.length)})',
        counted.fold(0, (sum, line) => sum + (line.paidSeconds ?? 0)),
        BasisTotal([for (final line in counted) (line.pay, line.basis)]),
      ),
    };
    void toggle(String id) {
      final line = lines.where((value) => value.id == id).firstOrNull;
      if (line != null) bulk?.toggle(line.date);
    }

    return DataGrid<ShiftsLine>(
      label: 'To confirm',
      columns: [
        ..._columns,
        if (bulk != null)
          GridColumn<ShiftsLine>(
            key: 'result',
            label: 'Result',
            kind: ValueKind.text,
            width: 230,
            sortable: false,
            value: (line) => sent[line.id]?.words ?? '',
          ),
      ],
      lines: [
        GridGroup(
          label: 'Days to confirm (${counted.length})',
          summary: 'past planned days, oldest first',
        ),
        for (final line in waiting) row(line),
        if (unpaid.isNotEmpty) ...[
          GridGroup(
            label: 'Without a pay agreement (${unpaid.length})',
            summary: "can't be confirmed until an agreement covers them",
            linkLabel: 'Extend pay agreement…',
            onLink: extendAgreementOver == null || sheet.archived
                ? null
                : () => _command(
                    () async => extendAgreementOver!([
                      for (final line in unpaid) line.date,
                    ]),
                  ),
          ),
          for (final line in unpaid) row(line),
        ],
      ],
      rowId: (line) => line.id,
      rowLabel: (line) => '${line.status.label} ${eraBoxDate(line.date)}',
      selectedId: selected,
      onSelect: bulk == null ? (id) => unawaited(sheet.select(id)) : toggle,
      editorController: editors,
      onEdit: (cell, draft) => _commit(cell.rowId, cell.column, draft),
      readOnlyReason: (line, column) => column.editable
          ? shiftsReadOnlyReason(sheet, line, column.key)
          : null,
      today: today,
      pendingIds: {
        if (selected != null && edit != null && edit.dirty) selected,
      },
      changed: {
        if (selected != null && edit != null)
          for (final field in edit.editable)
            if (edit.changed(field)) GridCell(selected, field),
      },
      errors: {
        if (selected != null && edit != null)
          for (final MapEntry(:key, :value) in edit.issues.entries)
            GridCell(selected, _columnOf(key)): value,
      },
      note: filteredNote,
      pickMode: bulk != null,
      pickedIds: {
        if (bulk != null)
          for (final line in lines)
            if (bulk.ticked.contains(line.date) && bulk.canTick(line.date))
              line.id,
      },
      canPick: (line) => bulk?.canTick(line.date) ?? false,
      onPick: (id, _) => toggle(id),
      footerLabel: '$footerLabel${pay.labelSuffix}',
      footer: {'paid': formatDuration(paid), 'pay': pay.cell},
    );
  }

  /// The status line while Confirm worked days is open.
  String confirmDaysNotice(ConfirmDaysAction bulk) {
    if (bulk.phase == ConfirmDaysPhase.picking) {
      return ConfirmDaysWords.picking(bulk.ticked.length);
    }
    List<LocalDate> dates(ConfirmDayResult result) => [
      for (final MapEntry(:key, :value) in bulk.results.entries)
        if (value.result == result) key,
    ];
    final unknown = dates(ConfirmDayResult.unknown);
    final notDone = dates(ConfirmDayResult.notDone);
    return [
      ConfirmDaysWords.summary(bulk.confirmedCount, bulk.results.length),
      if (unknown.isNotEmpty) ConfirmDaysWords.notKnown(unknown),
      if (notDone.isNotEmpty) ConfirmDaysWords.notDone(notDone),
    ].join(' ');
  }

  /// Confirm worked days in the property column (mockup 2B and "Bulk
  /// results").
  Widget confirmDaysPanel(ConfirmDaysAction bulk) {
    final eligible = bulk.days.where((day) => bulk.isEligible(day.date)).length;
    final ticked = [
      for (final day in bulk.days)
        if (bulk.ticked.contains(day.date)) day,
    ];
    final unpaid = [
      for (final day in bulk.days)
        if (!bulk.isEligible(day.date)) day.date,
    ];
    String? said(ConfirmDayChoice day) => switch (day.kind) {
      ConfirmDayKind.changed => ConfirmDaysWords.changed(day.date),
      ConfirmDayKind.extra => ConfirmDaysWords.extra(day.date),
      ConfirmDayKind.vacation => ConfirmDaysWords.leave(
        day.date,
        LeaveType.vacation,
      ),
      ConfirmDayKind.sick => ConfirmDaysWords.leave(day.date, LeaveType.sick),
      ConfirmDayKind.planned => null,
    };
    final special = [for (final day in ticked) ?said(day)];
    final picking = bulk.phase == ConfirmDaysPhase.picking;
    final canRun =
        !bulk.busy &&
        (bulk.hasUnknown ||
            bulk.days.any(
              (day) => bulk.ticked.contains(day.date) && bulk.canTick(day.date),
            ));
    return ActionPanel(
      title: ConfirmDaysWords.title,
      record: bulk,
      controller: editors,
      today: today,
      busy: bulk.busy,
      onChanged: (_, _) {},
      groups: () => [
        if (picking) ...[
          ActionGroup(
            legend: 'Days',
            children: [
              const Text(ConfirmDaysWords.intro),
              Text(
                'Ticked: ${bulk.ticked.length} of '
                '${ConfirmDaysWords.days(eligible)}',
              ),
              Text('Paid: ${formatDuration(bulk.tickedPaidSeconds)}'),
              Text('Est. pay: ${bulk.tickedPay.words}'),
            ],
          ),
          if (special.isNotEmpty)
            ActionGroup(
              legend: 'Changed and leave days',
              children: [for (final words in special) Text(words)],
            ),
        ] else
          ActionGroup(
            legend: 'Result',
            children: [
              Text(
                ConfirmDaysWords.summary(
                  bulk.confirmedCount,
                  bulk.results.length,
                ),
              ),
            ],
          ),
        if (unpaid.isNotEmpty)
          ActionGroup(
            legend: 'Without a pay agreement',
            children: [
              Text(
                ConfirmDaysWords.withoutAgreement(
                  unpaid.length,
                  unpaid.first,
                  unpaid.last,
                ),
              ),
              const Text(ConfirmDaysWords.extendHint),
            ],
          ),
      ],
      results: [
        for (final MapEntry(:key, :value) in bulk.results.entries)
          switch (value.result) {
            ConfirmDayResult.confirmed => ActionResult.done(
              eraBoxDate(key),
              detail: value.words,
            ),
            ConfirmDayResult.notDone => ActionResult.failed(
              eraBoxDate(key),
              value.words,
            ),
            ConfirmDayResult.unknown => ActionResult.uncertain(
              eraBoxDate(key),
              detail: value.words,
            ),
          },
      ],
      primaryLabel: bulk.primaryLabel,
      onPrimary: canRun ? () => _command(sheet.runConfirmDays) : null,
      cancelLabel: picking ? 'Cancel' : 'Close',
      onCancel: () => _command(sheet.closeConfirmDays),
    );
  }

  /// The grid column that shows a problem keyed [key].
  String _columnOf(String key) => switch (key) {
    ShiftsField.date || 'date' => ShiftsField.date,
    'end' || 'timezoneId' => ShiftsField.end,
    'localTime' || 'start' => ShiftsField.start,
    ShiftsField.note => ShiftsField.note,
    _ when key.startsWith('breaks') => 'break',
    _ => 'status',
  };

  /// The selected record's problems by the property that shows them, as
  /// the grid marks its columns (spec 9); a break's shows in the Breaks
  /// subform instead.
  Map<String, String> _propertyIssues(ShiftsEdit? edit) {
    final issues = <String, String>{};
    final found = edit?.issues ?? const <String, String>{};
    for (final MapEntry(:key, :value) in found.entries) {
      if (key.startsWith('breaks')) continue;
      issues.putIfAbsent(_columnOf(key), () => value);
    }
    return issues;
  }

  /// The property column of the selected row (spec 3, 4.2).
  Widget properties(List<ShiftsLine> lines) {
    final selected = sheet.selectedId;
    final line = lines.where((value) => value.id == selected).firstOrNull;
    final edit = sheet.edit;
    final issues = _propertyIssues(edit);
    final shift = _selectedShift();
    final row = sheet.selectedRow;
    final notWork =
        row is LeaveRow || row is CancelledRow || row is LeaveTakenRow;
    if (line == null) {
      return PropertyGrid(
        record: 'none',
        controller: editors,
        items: const [],
        onCommit: (_, _) => const EditResult.accepted(),
        today: today,
      );
    }
    String? was(String field, ValueKind kind) =>
        edit != null && edit.changed(field)
        ? formatValue(kind, edit.savedValue(field))
        : null;
    PropertyItem editable(
      String key,
      String label,
      ValueKind kind,
      String description,
    ) => PropertyItem(
      key: key,
      label: label,
      category: 'Shift',
      kind: kind,
      value: line.value(key),
      readOnlyReason: shiftsReadOnlyReason(sheet, line, key),
      was: was(key, kind),
      error: issues[key],
      description: description,
    );
    return PropertyGrid(
      record: line.id,
      controller: editors,
      today: today,
      edited: edit?.dirty ?? false,
      // A new record opens on its first required field (spec 4.3).
      openOn: switch (line.id) {
        newRowId => ShiftsField.date,
        newExtraRowId => ShiftsField.type,
        _ => null,
      },
      onCommit: (id, draft) => _commit(id.record as String, id.field, draft),
      items: [
        editable(
          ShiftsField.date,
          'Date',
          ValueKind.date,
          'The day the shift starts on.',
        ),
        if (edit is PlannedEdit && edit.typeChoices.isNotEmpty)
          PropertyItem(
            key: ShiftsField.type,
            label: 'Shift type',
            category: 'Shift',
            kind: ValueKind.choice,
            value: edit.value(ShiftsField.type),
            choices: _typeChoices,
            readOnlyReason: shiftsReadOnlyReason(sheet, line, ShiftsField.type),
            was: edit.changed(ShiftsField.type)
                ? edit.savedValue(ShiftsField.type) as String?
                : null,
            error: issues[ShiftsField.type],
            description: ShiftsPropertyWords.shiftType,
          ),
        if (edit case PlannedEdit(isExtra: true))
          PropertyItem(
            key: ShiftsField.overtime,
            label: 'Counts as overtime',
            category: 'Shift',
            kind: ValueKind.check,
            value: edit.value(ShiftsField.overtime),
            readOnlyReason: shiftsReadOnlyReason(
              sheet,
              line,
              ShiftsField.overtime,
            ),
            was: edit.changed(ShiftsField.overtime)
                ? formatValue(
                    ValueKind.check,
                    edit.savedValue(ShiftsField.overtime),
                  )
                : null,
            description: ShiftsPropertyWords.overtime,
          ),
        if (!notWork) ...[
          editable(
            ShiftsField.start,
            'Start',
            ValueKind.time,
            'When the shift starts.',
          ),
          editable(
            ShiftsField.end,
            'End',
            ValueKind.time,
            'When the shift ends; at or before its start is the next day.',
          ),
        ],
        ..._notWorkItems(row),
        if (line.status != ShiftsStatus.planned &&
            line.status != ShiftsStatus.changed &&
            line.status != ShiftsStatus.extra &&
            line.status != ShiftsStatus.review)
          editable(
            ShiftsField.note,
            'Note',
            ValueKind.text,
            'Your own words about this shift.',
          ),
        PropertyItem(
          key: 'status',
          label: 'Status',
          category: 'Shift',
          value: line.statusText,
          readOnlyReason: sheet.readOnlyReason ?? 'Set by saving or Correct.',
          error: issues['status'],
          description: shift?.replacedShiftId == null
              ? null
              : ShiftsPropertyWords.replacement,
        ),
        if (sheet.selectedRow case ReviewRow(:final exception))
          PropertyItem(
            key: 'change',
            label: 'Change',
            category: 'Shift',
            value: changeKindLabel(exception),
            readOnlyReason: ShiftsNotices.needsReview,
          ),
        if (shift?.voidReason case final reason?)
          PropertyItem(
            key: 'voidReason',
            label: 'Void reason',
            category: 'Shift',
            value: reason,
            readOnlyReason: ShiftsPropertyWords.voidReason,
          ),
        if (!notWork)
          PropertyItem(
            key: 'paid',
            label: 'Paid time',
            category: 'Pay (derived)',
            value: line.paidSeconds == null
                ? null
                : formatDuration(line.paidSeconds!),
            readOnlyReason: 'Derived: the shift minus its breaks.',
          ),
        if (line.withoutAgreement && extendAgreement != null && !sheet.archived)
          PropertyItem(
            key: 'pay',
            label: 'Est. pay',
            category: 'Pay (derived)',
            value: ShiftsPropertyWords.extend,
            description: ShiftsPropertyWords.extendWhy,
            onFollow: () => _command(() async => extendAgreement!(line.date)),
          )
        else
          PropertyItem(
            key: 'pay',
            label: 'Est. pay',
            category: 'Pay (derived)',
            value: line.pay == null ? null : formatMoney(line.pay!),
            readOnlyReason: 'Derived from the agreement that covers the date.',
          ),
        if (line.planDifferenceSeconds case final difference?)
          PropertyItem(
            key: 'plan',
            label: 'Plan difference',
            category: 'Pay (derived)',
            value:
                '${difference < 0 ? '-' : '+'}'
                '${formatDuration(difference.abs())}',
            readOnlyReason: 'Derived: paid time against the plan.',
          ),
        if (shift?.replacedShiftId case final id?)
          _link('replaces', 'Replaces', id, lines),
        if (shift?.replacementShiftId case final id?)
          _link('replacedBy', 'Replaced by', id, lines),
      ],
    );
  }

  /// The facts of a day that is not work: a leave day, a cancelled shift
  /// or confirmed leave (plan 4d-1, Task 1).
  List<PropertyItem> _notWorkItems(ShiftsRow? row) {
    String shiftOf(PlannedShift day) {
      final zones = work.timezones;
      String at(DateTime utc) =>
          formatValue(ValueKind.time, zones.localTimeAt(utc, day.timezoneId));
      final name = day.type?.name ?? (day.isExtra ? 'Extra' : 'Shift');
      return '$name ${at(day.startUtc)}–${at(day.endUtc)}';
    }

    PropertyItem fact(String key, String label, Object? value, String why) =>
        PropertyItem(
          key: key,
          label: label,
          category: 'Shift',
          value: value,
          readOnlyReason: why,
        );
    return switch (row) {
      LeaveRow(:final day) => () {
        final edit = sheet.edit is LeaveEdit ? sheet.edit! as LeaveEdit : null;
        final type =
            (edit?.value(ShiftsField.leaveType) as LeaveType?) ?? day.leaveType;
        final illness = edit == null
            ? day.illnessStartedOn
            : edit.value(ShiftsField.illness) as LocalDate?;
        final sick = type == LeaveType.sick;
        return [
          PropertyItem(
            key: ShiftsField.leaveType,
            label: 'Leave',
            category: 'Shift',
            kind: ValueKind.choice,
            value: type,
            choices: [
              for (final value in LeaveType.values)
                EraComboItem<Object?>(value, leaveTypeWord(value)),
            ],
            readOnlyReason: edit == null
                ? sheet.readOnlyReason ?? ShiftsNotices.leaveDay
                : null,
            was: edit != null && edit.changed(ShiftsField.leaveType)
                ? leaveTypeWord(
                    edit.savedValue(ShiftsField.leaveType)! as LeaveType,
                  )
                : null,
            description: ShiftsPropertyWords.leave,
          ),
          PropertyItem(
            key: ShiftsField.illness,
            label: 'Illness started on',
            category: 'Shift',
            kind: ValueKind.date,
            value: illness,
            display: sick && illness == null
                ? ShiftsPropertyWords.illnessOnConfirm
                : null,
            optional: true,
            readOnlyReason: edit == null
                ? sheet.readOnlyReason ?? ShiftsNotices.leaveDay
                : sick
                ? null
                : ShiftsPropertyWords.illnessOnlySick,
            error: edit?.issues[ShiftsField.illness],
            description: DayActionWords.illnessHelp,
          ),
          fact(
            'insteadOf',
            'Instead of',
            shiftOf(day.replaced),
            ShiftsPropertyWords.insteadOf,
          ),
          fact(
            'hours',
            'Hours',
            formatDuration(day.paidMinutes * 60),
            ShiftsPropertyWords.hours,
          ),
        ];
      }(),
      CancelledRow(:final day) => [
        fact(
          'shift',
          'Shift',
          shiftOf(day.replaced),
          ShiftsNotices.cancelledDay,
        ),
        fact(
          'reason',
          'Reason',
          cancelReasonWord(day.reason),
          ShiftsNotices.cancelledDay,
        ),
        fact('cancelNote', 'Note', day.note, ShiftsNotices.cancelledDay),
      ],
      LeaveTakenRow(:final leave) => [
        if (followLeave != null)
          PropertyItem(
            key: 'confirmedLeave',
            label: 'Record',
            category: 'Day',
            value: 'Open confirmed leave',
            description: ShiftsNotices.leaveTaken,
            onFollow: () => followLeave!(leave.record.id),
          ),
        fact(
          'leaveType',
          'Leave',
          leaveTypeWord(leave.record.leaveType),
          ShiftsNotices.leaveTaken,
        ),
        fact(
          'hours',
          'Hours',
          formatDuration(leave.record.paidMinutes * 60),
          ShiftsNotices.leaveTaken,
        ),
      ],
      _ => const [],
    };
  }

  /// The selected stored shift as the sheet lists it, or as its edit read
  /// it when the sheet does not list it yet (a replacement just made).
  WorkShift? _selectedShift() => switch ((sheet.selectedRow, sheet.edit)) {
    (StoredRow(:final shift), _) => shift,
    (_, StoredEdit(:final session)) => session.baseline?.shift,
    _ => null,
  };

  /// A link to the shift [id] a correction ties to this one (spec 4.5):
  /// [followShift] opens it, in another month too.
  PropertyItem _link(
    String key,
    String label,
    ShiftId id,
    List<ShiftsLine> lines,
  ) {
    final line = lines.where((value) => value.id == shiftRowId(id)).firstOrNull;
    return PropertyItem(
      key: key,
      label: label,
      category: 'Belongs to',
      value: line == null
          ? 'Another month'
          : '${line.status.label} ${eraBoxDate(line.date)}',
      description: line == null
          ? ShiftsPropertyWords.otherMonthLink
          : ShiftsPropertyWords.link,
      onFollow: () => _command(() async => followShift(id)),
    );
  }

  /// The open Correct or Void panel in the property column (spec 4.4): the
  /// shift it acts on, the reason, and the primary key and Cancel. The
  /// reason is fixed once sent.
  Widget actionPanel(ShiftsAction action) {
    final shift = action.shift;
    String time(DateTime? utc) => utc == null
        ? '—'
        : formatValue(
            ValueKind.time,
            work.timezones.localTimeAt(utc, shift.timezoneId),
          );
    return ActionPanel(
      title: action.title,
      record: 'action:${action.kind.name}:${shift.id.value}',
      controller: editors,
      today: today,
      cancelDraft: false,
      groups: () => [
        ActionGroup(
          legend: 'Shift',
          children: [
            Text(
              '${eraBoxDate(shift.localStartDate)}, '
              '${time(shift.startUtc)}–${time(shift.endUtc)}',
            ),
            Text(action.explanation),
          ],
        ),
        ActionGroup(
          legend: 'Reason',
          fields: [
            ActionField(
              id: 'reason',
              label: 'Reason',
              kind: ValueKind.text,
              value: action.reason,
              enabled: action.phase == ShiftsActionPhase.input,
              error: action.reasonError,
              fieldKey: const ValueKey('action-reason'),
            ),
          ],
        ),
      ],
      onChanged: (_, value) => action.setReason('${value ?? ''}'),
      primaryLabel: action.primaryLabel,
      onPrimary: action.canSubmit
          ? () => unawaited(sheet.submitAction())
          : null,
      onCancel: () => _command(sheet.cancelAction),
      results: [
        if (action.phase == ShiftsActionPhase.committed)
          const ActionResult.done('Shift saved'),
        if (action.phase == ShiftsActionPhase.uncertain)
          ActionResult.uncertain(
            action.title,
            detail: ShiftsActionWords.uncertain,
          ),
      ],
      error: action.error,
      busy: action.busy,
    );
  }

  /// The open Cancel shift or Mark as leave panel (plan 4d-1, call 6): the
  /// day it acts on, its fields, and the primary key and Cancel.
  Widget dayActionPanel(DayAction action) {
    final day = action.day;
    String time(DateTime utc) => formatValue(
      ValueKind.time,
      work.timezones.localTimeAt(utc, day.timezoneId),
    );
    final input = action.phase == DayActionPhase.input;
    final name = day.type?.name ?? 'Shift';
    final schedule = sheet.scheduleName(day.scheduleId);
    // The panel is open on the selected day.
    final pay = switch (sheet.selectedRow) {
      PlannedRow(:final planned) => planned.pay?.amount,
      _ => null,
    };
    return ActionPanel(
      title: action.title,
      record: 'day-action:${action.kind.name}:${action.date}',
      controller: editors,
      today: today,
      cancelDraft: false,
      groups: () => [
        ActionGroup(
          legend: 'Shift',
          children: [
            Text(
              '${eraBoxDate(action.date)}, $name '
              '${time(day.startUtc)}–${time(day.endUtc)}'
              '${schedule == null ? '' : ', planned by $schedule '
                        'v${day.scheduleVersion}.'}',
            ),
          ],
        ),
        if (action.kind == DayActionKind.cancel) ...[
          ActionGroup(
            legend: 'Why is it not worked?',
            fields: [
              ActionField(
                id: DayActionField.reason,
                label: 'Reason',
                kind: ValueKind.choice,
                value: action.reason,
                choices: [
                  for (final reason in CancelReason.values)
                    EraComboItem<Object?>(reason, cancelReasonWord(reason)),
                ],
                enabled: input,
              ),
              ActionField(
                id: DayActionField.note,
                label: 'Note',
                kind: ValueKind.text,
                value: action.note,
                optional: true,
                enabled: input,
              ),
            ],
            children: const [Text(DayActionWords.illnessNote)],
          ),
          ActionGroup(
            legend: 'What changes',
            children: [
              Text('Paid: ${formatDuration(day.paidSeconds)} → none'),
              if (pay != null) Text('Planned pay: ${formatMoney(pay)} → none'),
              const Text('Afterwards: Restore shift brings it back.'),
            ],
          ),
        ] else
          ActionGroup(
            legend: 'Leave',
            fields: [
              ActionField(
                id: DayActionField.leaveType,
                label: 'Leave',
                kind: ValueKind.choice,
                value: action.leaveType,
                choices: [
                  for (final type in LeaveType.values)
                    EraComboItem<Object?>(type, leaveTypeWord(type)),
                ],
                enabled: input,
              ),
              ActionField(
                id: DayActionField.illness,
                label: 'Illness started on',
                kind: ValueKind.date,
                value: action.illnessStartedOn,
                optional: true,
                enabled: input && action.leaveType == LeaveType.sick,
                error: action.fieldError(DayActionField.illness),
              ),
            ],
            children: const [Text(DayActionWords.illnessHelp)],
          ),
      ],
      onChanged: (field, value) => switch ((field, value)) {
        (DayActionField.reason, final CancelReason reason) => action.setReason(
          reason,
        ),
        (DayActionField.note, _) => action.setNote('${value ?? ''}'),
        (DayActionField.leaveType, final LeaveType type) => action.setLeaveType(
          type,
        ),
        (DayActionField.illness, final LocalDate? date) =>
          action.setIllnessStartedOn(date),
        _ => null,
      },
      primaryLabel: action.primaryLabel,
      onPrimary: action.canSubmit
          ? () => unawaited(sheet.submitDayAction())
          : null,
      onCancel: () => _command(sheet.cancelDayAction),
      results: [
        if (action.phase == DayActionPhase.committed)
          const ActionResult.done('Day changed'),
        if (action.phase == DayActionPhase.uncertain)
          ActionResult.uncertain(
            action.title,
            detail: ShiftsActionWords.uncertain,
          ),
      ],
      error: action.error,
      busy: action.busy,
    );
  }

  /// The status line (spec 3): that the rows could not be read, else what
  /// kept a break command from acting, else the open panel's state, else
  /// the session's problem, else the pending change, else what the last
  /// record command did, else why the row is read-only.
  String notice(List<ShiftsLine> lines) {
    final edit = sheet.edit;
    if (!sheet.loaded) {
      return sheet.failed ? ShiftsNotices.unreadable : ShiftsNotices.loading;
    }
    if (_breakProblem case final problem?) return problem;
    if (sheet.action case final action?) return action.notice;
    if (sheet.dayAction case final action?) return action.notice;
    if (sheet.confirmDays case final bulk?) return confirmDaysNotice(bulk);
    if (edit == null) {
      return sheet.notice ?? sheet.readOnlyReason ?? ShiftsNotices.ready;
    }
    if (edit.problem case final problem?) return problem;
    if (edit case PlannedEdit(isNew: true)) {
      final type = edit.value(ShiftsField.type) ?? 'Extra';
      final start = _shown(ValueKind.time, edit.value(ShiftsField.start));
      final end = _shown(ValueKind.time, edit.value(ShiftsField.end));
      return 'New extra shift on ${eraBoxDate(edit.date)}: $type '
          '$start–$end. Save adds it.';
    }
    if (!edit.dirty) return sheet.notice ?? ShiftsNotices.ready;
    final line = lines
        .where((value) => value.id == sheet.selectedId)
        .firstOrNull;
    if (line == null) return ShiftsNotices.ready;
    String word(String field, Object? value) => switch ((field, value)) {
      (ShiftsField.leaveType, final LeaveType type) => leaveTypeWord(type),
      (ShiftsField.overtime, final bool yes) => yes ? 'Yes' : 'No',
      (ShiftsField.type, _) => '${value ?? ''}',
      (ShiftsField.date || ShiftsField.illness, _) => _shown(
        ValueKind.date,
        value,
      ),
      (ShiftsField.start || ShiftsField.end, _) => _shown(
        ValueKind.time,
        value,
      ),
      _ => _shown(ValueKind.text, value),
    };
    final changes = [
      for (final (field, label) in const [
        (ShiftsField.date, 'Date'),
        (ShiftsField.type, 'Type'),
        (ShiftsField.start, 'Start'),
        (ShiftsField.end, 'End'),
        (ShiftsField.overtime, 'Counts as overtime'),
        (ShiftsField.leaveType, 'Leave'),
        (ShiftsField.illness, 'Illness started on'),
        (ShiftsField.note, 'Note'),
      ])
        if (edit.editable.contains(field) && edit.changed(field))
          '$label ${word(field, edit.savedValue(field))} → '
              '${word(field, edit.value(field))}',
    ];
    // Breaks are children of the record: a change there has no field.
    final what = changes.isEmpty ? '' : ', ${changes.join(', ')}';
    return switch (edit) {
      LeaveEdit() =>
        'Unsaved leave change: ${eraBoxDate(line.date)}$what. Save, or '
            'leave the day, to keep it. Confirmation is separate.',
      PlannedEdit() =>
        'Unsaved plan change: ${eraBoxDate(line.date)}$what. Save, or '
            'leave the day, to keep it. Confirmation is separate.',
      _ when edit.isNew =>
        'New shift: ${eraBoxDate(line.date)}. Save to finalize it.',
      _ =>
        'Unsaved shift: ${eraBoxDate(line.date)}$what. Save to '
            'finalize it.',
    };
  }

  static String _shown(ValueKind kind, Object? value) {
    final text = formatValue(kind, value);
    return text.isEmpty ? '(none)' : text;
  }

  /// The Shifts sheet's toolbar bands: New shift; Save, Undo, Reload and
  /// Void…; Correct… and Remove change.
  List<ToolbarBand> bands() {
    final edit = sheet.edit;
    final idle = edit != null && !edit.frozen;
    final reload = switch (edit?.phase) {
      EditPhase.uncertain => 'Reload and check',
      EditPhase.stale => 'Reload record',
      _ => null,
    };
    final gone = edit?.session.gone ?? false;
    return [
      ToolbarBand(
        items: [
          ToolbarItem(
            label: 'New shift',
            icon: EraIconKind.shift,
            tooltip: sheet.addBlocked,
            onPressed: sheet.addBlocked == null
                ? () => _command(sheet.addShift)
                : null,
          ),
        ],
      ),
      ToolbarBand(
        items: [
          ToolbarItem(
            label: 'Save',
            onPressed: idle ? () => _command(sheet.save) : null,
          ),
          ToolbarItem(label: 'Undo', onPressed: idle ? undo : null),
          if (gone && reload == null)
            ToolbarItem(
              label: 'Discard and return to sheet',
              onPressed: () => _command(sheet.discardAndReturn),
            )
          else
            ToolbarItem(
              label: reload ?? 'Reload record',
              onPressed: reload == null ? null : () => _command(sheet.reload),
            ),
          _commandKey(
            'Void…',
            sheet.voidBlocked,
            () => sheet.openAction(ShiftsActionKind.voidShift),
          ),
        ],
      ),
      ToolbarBand(
        row: 1,
        items: [
          _commandKey(
            'Correct…',
            sheet.correctBlocked,
            () => sheet.openAction(ShiftsActionKind.correct),
          ),
          _commandKey(
            'Remove change',
            sheet.removeChangeBlocked,
            sheet.removeChange,
          ),
        ],
      ),
      // The Day band (plan 4d-1): what a planned day can become.
      ToolbarBand(
        row: 1,
        items: [
          ToolbarItem(
            label: 'Confirm',
            icon: EraIconKind.reviewed,
            tooltip: sheet.confirmBlocked,
            onPressed: sheet.confirmBlocked == null
                ? () => _command(sheet.confirmDay)
                : null,
          ),
          _confirmDaysKey,
          _commandKey(
            sheet.restoreLabel,
            sheet.restoreBlocked,
            sheet.restoreShift,
          ),
          _commandKey(
            'Cancel shift…',
            sheet.cancelBlocked,
            () => sheet.openDayAction(DayActionKind.cancel),
          ),
          _commandKey(
            'Mark as leave…',
            sheet.leaveBlocked,
            () => sheet.openDayAction(DayActionKind.leave),
          ),
          _commandKey('Finalize', sheet.finalizeBlocked, sheet.finalize),
        ],
      ),
    ];
  }

  /// A record command's key: greyed in place, saying why, where it does not
  /// apply (spec 3, 4.9).
  ToolbarItem _commandKey(
    String label,
    String? blocked,
    Future<Object?> Function() command,
  ) => ToolbarItem(
    label: label,
    tooltip: blocked,
    onPressed: blocked == null ? () => _command(command) : null,
  );

  /// Undo (spec 4.2, 4.3), from the toolbar and Edit › Undo. A new
  /// record takes the value being typed, so Undo's window may still save
  /// it; one that cannot be taken, or an existing record's, is dropped.
  void undo() {
    final edit = sheet.edit;
    if (edit == null || edit.frozen) return;
    if (!edit.isNew || !editors.flush().isAccepted) editors.cancel();
    unawaited(sheet.undo());
  }

  /// The Edit menu: Save and Undo as the keys run them, greyed with why.
  List<EraMenuItem> editMenu() {
    final edit = sheet.edit;
    final reason = switch (edit) {
      null => 'No record is open.',
      final open when open.frozen => open.session.problem ?? EditProblems.busy,
      _ => null,
    };
    return [
      EraMenuItem(
        'Save',
        reason == null ? () => _command(sheet.save) : null,
        disabledReason: reason,
      ),
      EraMenuItem('Undo', reason == null ? undo : null, disabledReason: reason),
    ];
  }

  /// The Add menu's Shifts rows after Manual shift (spec 3): the last
  /// finalized shift's copy, and an extra shift on the selected Off day.
  List<EraMenuItem> addItems() {
    final blocked = sheet.extraBlocked;
    final row = sheet.selectedRow;
    final fromLast = sheet.fromLastBlocked;
    return [
      EraMenuItem(
        'Manual shift from last time',
        fromLast == null
            ? () => _command(() => sheet.addShift(fromLast: true))
            : null,
        icon: EraIconKind.shift,
        disabledReason: fromLast,
      ),
      EraMenuItem(
        row is OffRow
            ? 'Extra shift on ${eraBoxDate(row.date)}'
            : 'Extra shift on an Off day',
        blocked == null ? () => _command(sheet.addExtra) : null,
        icon: EraIconKind.shift,
        disabledReason: blocked,
      ),
    ];
  }

  /// The Record menu: the same commands as the keys (spec 4.9).
  List<EraMenuItem> recordMenu() {
    final edit = sheet.edit;
    VoidCallback? run(String? blocked, Future<Object?> Function() command) =>
        blocked == null ? () => _command(command) : null;
    return [
      EraMenuItem(
        'New shift',
        sheet.addBlocked == null ? () => _command(sheet.addShift) : null,
        disabledReason: sheet.addBlocked,
      ),
      EraMenuItem(
        'Save',
        edit == null || edit.frozen ? null : () => _command(sheet.save),
      ),
      const EraMenuItem.separator(),
      EraMenuItem(
        'Correct…',
        run(
          sheet.correctBlocked,
          () => sheet.openAction(ShiftsActionKind.correct),
        ),
        disabledReason: sheet.correctBlocked,
      ),
      EraMenuItem(
        'Void…',
        run(
          sheet.voidBlocked,
          () => sheet.openAction(ShiftsActionKind.voidShift),
        ),
        disabledReason: sheet.voidBlocked,
      ),
      EraMenuItem(
        'Remove change',
        run(sheet.removeChangeBlocked, sheet.removeChange),
        disabledReason: sheet.removeChangeBlocked,
      ),
      const EraMenuItem.separator(),
      EraMenuItem(
        'Confirm',
        run(sheet.confirmBlocked, sheet.confirmDay),
        disabledReason: sheet.confirmBlocked,
      ),
      EraMenuItem(_confirmDaysLabel, switch ((
        confirmDaysBlocked,
        confirmWorkedDays,
      )) {
        (null, final open?) => () {
          if (editors.flush().isAccepted) open();
        },
        _ => null,
      }, disabledReason: confirmDaysBlocked),
      EraMenuItem(
        sheet.restoreLabel,
        run(sheet.restoreBlocked, sheet.restoreShift),
        disabledReason: sheet.restoreBlocked,
      ),
      EraMenuItem(
        'Cancel shift…',
        run(
          sheet.cancelBlocked,
          () => sheet.openDayAction(DayActionKind.cancel),
        ),
        disabledReason: sheet.cancelBlocked,
      ),
      EraMenuItem(
        'Mark as leave…',
        run(sheet.leaveBlocked, () => sheet.openDayAction(DayActionKind.leave)),
        disabledReason: sheet.leaveBlocked,
      ),
      EraMenuItem(
        'Finalize',
        run(sheet.finalizeBlocked, sheet.finalize),
        disabledReason: sheet.finalizeBlocked,
      ),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    sheet
      ..removeListener(_clearBreakProblem)
      ..removeListener(_dropLines);
    super.dispose();
  }
}
