import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/data/work_history.dart' show WorkRecordKinds;
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/pay_period.dart';
import '../../features/work/domain/payslip.dart';
import '../../features/work/domain/reconciliation.dart';
import '../../features/work/domain/shift.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../edit_session/record_edit_session.dart';
import '../work_edit/pay_edit.dart';
import 'pay_action.dart';
import 'pay_sheet_controller.dart';
import 'shifts_subform.dart' show HistoryGrid, RecordHistoryTab;
import 'work_location.dart';
import 'work_shell.dart' show runCommand;

String payBasis(RateBasis? basis) => basis is GrossBasis
    ? 'Gross'
    : basis is NetBasis
    ? 'Net'
    : 'Mixed basis';
String payStatus(ReconciliationStatus status) => switch (status) {
  Balanced() => 'Balanced',
  Difference() => 'Difference',
  MissingPayslip() => 'Missing payslip',
  UnmatchedPayslip() => 'Unmatched payslip',
  MixedBasis() => 'Mixed basis',
  UnavailableReconciliation() => 'Unavailable',
  EmptyReconciliation() => 'No evidence',
};
String payMoney(Money? value) =>
    value == null ? 'Not recorded' : formatMoney(value);

final class PayLine {
  PayLine(this.id, this.values, this.record, this.periodRow);
  final String id;
  final PayValues values;
  final PayRecord? record;
  final PeriodSheetRow? periodRow;
}

/// All slots of the two pay sheets on the established frame. Stored facts
/// cannot turn into editable cells; only the pending new row is editable.
final class PaySheetPart {
  PaySheetPart({
    required this.sheet,
    required this.editors,
    required this.place,
    required this.today,
    required this.employmentName,
    required this.go,
    required this.addPay,
    required this.setFilter,
  });
  final PaySheetController sheet;
  final EditorSessionController editors;
  final WorkLocation place;
  final LocalDate today;
  final String employmentName;
  final void Function(WorkLocation) go;
  final void Function(PayKind, PayPeriodId?) addPay;
  final void Function(String?, PayPeriodId?) setFilter;
  bool get periods => sheet.kind == PayKind.periods;
  String get title => periods ? 'Pay periods' : 'Payslips';
  static const readOnly =
      'Saved facts are read-only. Use the record actions to change their state or correct evidence.';

  /// The status bar's short form of [readOnly].
  static const readOnlyStatus = 'Read-only: use the record actions.';

  /// What the status bar says over an empty sheet (bead 9pk.4.38).
  static const noPeriods =
      'No pay period yet. New pay period… adds the first one.';
  static const noPayslips =
      'No payslip yet. Record payslip… adds the first one.';
  static const noPeriodForPayslip =
      'No payslip yet. Add a pay period first: each payslip belongs to one.';
  static String noneMatch(bool periods) =>
      'No ${periods ? 'pay period' : 'payslip'} matches the filters. '
      'Clear shows them all.';

  /// The empty sheet's notice; null while it lists a record.
  String? get _emptyNotice {
    if (!sheet.loaded || lines.isNotEmpty) return null;
    if (sheet.records.isNotEmpty) return noneMatch(periods);
    if (sheet.archived) return periods ? 'No pay period.' : 'No payslip.';
    return periods
        ? noPeriods
        : sheet.periods.isEmpty
        ? noPeriodForPayslip
        : noPayslips;
  }

  void _command(Future<Object?> Function() command) =>
      runCommand(editors, command);
  bool get editing => sheet.session?.isNew == true;
  bool get canEdit =>
      editing && !sheet.archived && !(sheet.session?.frozen ?? true);
  List<EraComboItem<Object?>> get periodChoices => [
    for (final row in sheet.periods)
      EraComboItem<Object?>(row.period.id, periodName(row.period)),
  ];
  String periodName(PayPeriod period) =>
      period.label ?? '${period.start} – ${period.end}';
  String periodLabel(PayPeriodId? id) =>
      sheet.periods
          .where((row) => row.period.id == id)
          .map((row) => periodName(row.period))
          .firstOrNull ??
      'No period';
  List<PayLine> get lines {
    final records = [...sheet.records];
    final selected = sheet.selected;
    if (selected != null) {
      records.removeWhere((row) => row.id == selected.id);
      records.add(selected);
    }
    final result = <PayLine>[];
    for (final record in records) {
      final period = record.period;
      final slip = record.payslip;
      final held = sheet.action?.original.id == record.id;
      final status = periods
          ? period!.state.name
          : slip!.isEffective
          ? 'effective'
          : 'void';
      if (!held &&
          (place.payStatus ?? (periods ? status : 'effective')) != 'all' &&
          place.payStatus != null &&
          place.payStatus != status) {
        continue;
      }
      if (!periods && place.payStatus == null && !slip!.isEffective && !held) {
        continue;
      }
      if (!periods &&
          place.periodFilter != null &&
          slip!.periodId != place.periodFilter &&
          !held) {
        continue;
      }
      result.add(
        PayLine(
          record.id.value,
          period != null
              ? PayValues(
                  start: period.start,
                  end: period.end,
                  issued: today,
                  label: period.label ?? '',
                )
              : PayValues.ofPayslip(slip!),
          record,
          period == null
              ? null
              : sheet.periods
                    .where((row) => row.period.id == period.id)
                    .firstOrNull,
        ),
      );
    }
    if (editing) result.add(PayLine('new', sheet.session!.draft, null, null));
    result.sort(
      (a, b) => (periods ? a.values.start : a.values.issued).compareTo(
        periods ? b.values.start : b.values.issued,
      ),
    );
    return result;
  }

  Widget middle() {
    if (sheet.failed) {
      return SingleChildScrollView(
        child: OperationalState(
          kind: OperationalStateKind.unavailable,
          title: '$title could not be read',
          message: 'Local storage is unavailable. Try again.',
          action: KeyButton(
            label: 'Retry',
            onPressed: () => _command(sheet.refresh),
          ),
        ),
      );
    }
    final rows = lines;
    return DataGrid<PayLine>(
      label: title,
      columns: periods ? _periodColumns() : _payslipColumns(),
      lines: [
        for (final row in rows)
          GridRow(
            row,
            state: row.record?.payslip?.isEffective == false
                ? GridRowState.voided
                : GridRowState.normal,
          ),
      ],
      rowId: (row) => row.id,
      rowLabel: (row) => periods
          ? '${row.values.start} – ${row.values.end}'
          : '${periodLabel(row.values.period)}, ${row.values.issued}',
      selectedId: sheet.selectedId,
      editorController: editors,
      today: today,
      onSelect: (id) {
        if (id != 'new') {
          final row = rows.firstWhere((row) => row.id == id);
          _command(() => sheet.select(row.record!.id));
        }
      },
      onEdit: (cell, value) => _accept(
        canEdit && cell.rowId == 'new'
            ? sheet.set(cell.column, value)
            : readOnly,
      ),
      readOnlyReason: (row, column) =>
          column.editable && (row.id != 'new' || !canEdit)
          ? editing && sheet.session!.frozen
                ? 'Wait for the save, or reload and check its result.'
                : readOnly
          : null,
      pendingIds: {if (editing && sheet.session!.dirty) 'new'},
      errors: {
        if (editing)
          for (final entry in sheet.session!.issues.entries)
            GridCell('new', entry.key): entry.value,
      },
      onNew: sheet.createBlocked == null
          ? () => addPay(sheet.kind, place.periodFilter)
          : null,
    );
  }

  GridColumn<PayLine> _column(
    String key,
    String label,
    ValueKind kind,
    double width,
    Object? Function(PayLine) value, {
    bool editable = false,
    bool optional = false,
    String Function(Object)? display,
    List<EraComboItem<Object?>> choices = const [],
  }) => GridColumn<PayLine>(
    key: key,
    label: label,
    kind: kind,
    width: width,
    value: value,
    editable: editable,
    optional: optional,
    display: display,
    choices: choices,
  );
  String _periodAmount(PeriodSheetRow? row, String field) {
    if (row == null) return '';
    if (row.groups.length != 1) return 'Mixed basis';
    final group = row.groups.single;
    if (group.status is UnavailableReconciliation) return 'Unavailable';
    return payMoney(switch (field) {
      'expected' => group.expected,
      'paid' => group.paid,
      _ => group.difference,
    });
  }

  List<GridColumn<PayLine>> _periodColumns() => [
    _column(
      'start',
      'Start',
      ValueKind.date,
      104,
      (row) => row.values.start,
      editable: true,
    ),
    _column(
      'end',
      'End',
      ValueKind.date,
      104,
      (row) => row.values.end,
      editable: true,
    ),
    _column(
      'label',
      'Label',
      ValueKind.text,
      100,
      (row) => row.values.label,
      editable: true,
      optional: true,
    ),
    _column(
      'state',
      'State',
      ValueKind.text,
      64,
      (row) => row.record == null
          ? 'New'
          : row.record!.period!.state == PayPeriodState.open
          ? 'Open'
          : 'Reviewed',
    ),
    _column(
      'shifts',
      'Shifts',
      ValueKind.number,
      52,
      (row) => row.periodRow?.shiftCount,
    ),
    for (final field in ['expected', 'paid', 'difference'])
      _column(
        field,
        field[0].toUpperCase() + field.substring(1),
        ValueKind.money,
        84,
        (row) => _periodAmount(row.periodRow, field),
      ),
  ];
  List<GridColumn<PayLine>> _payslipColumns() => [
    _column(
      'period',
      'Period',
      ValueKind.choice,
      120,
      (row) => row.values.period,
      editable: true,
      choices: periodChoices,
    ),
    _column(
      'issued',
      'Issued',
      ValueKind.date,
      104,
      (row) => row.values.issued,
      editable: true,
    ),
    _column(
      'paid',
      'Paid date',
      ValueKind.date,
      104,
      (row) => row.values.paid,
      editable: true,
      optional: true,
    ),
    _column(
      'amount',
      'Paid amount',
      ValueKind.money,
      88,
      // A saved payslip reads with its currency, as a period's money does.
      (row) => switch (row.record?.payslip) {
        final slip? => formatMoney(slip.amount),
        null => row.values.amount,
      },
      editable: true,
    ),
    _column(
      'basis',
      'Basis',
      ValueKind.choice,
      52,
      (row) => row.values.basis,
      editable: true,
      choices: basisChoices,
    ),
    _column(
      'reference',
      'Reference',
      ValueKind.text,
      100,
      (row) => row.values.reference,
      editable: true,
      optional: true,
    ),
    _column(
      'state',
      'State',
      ValueKind.text,
      64,
      (row) => row.record == null
          ? 'New'
          : row.record!.payslip!.isEffective
          ? 'Effective'
          : 'Void',
    ),
  ];
  static const basisChoices = [
    EraComboItem<Object?>(GrossBasis(), 'Gross'),
    EraComboItem<Object?>(NetBasis(), 'Net'),
  ];
  EditResult _accept(String? problem) => problem == null
      ? const EditResult.accepted()
      : EditResult.rejected(problem);

  /// The record's fields; a [saved] payslip's money reads with its
  /// currency and its period is the link below, not a field (bead
  /// 9pk.4.24 item 9).
  List<PropertyItem> _fields(
    PayValues value, {
    required bool enabled,
    Payslip? saved,
  }) {
    PropertyItem field(
      String key,
      String label,
      ValueKind kind,
      Object? value, {
      bool optional = false,
      List<EraComboItem<Object?>> choices = const [],
      String? text,
    }) => PropertyItem(
      key: key,
      label: label,
      category: periods ? 'Pay period' : 'Payslip',
      kind: kind,
      value: value,
      text: text,
      optional: optional,
      choices: choices,
      readOnlyReason: enabled ? null : readOnly,
      error: sheet.session?.issues[key],
    );
    PropertyItem money(String key, String label, int? minor) => field(
      key,
      label,
      ValueKind.text,
      minor == null
          ? ''
          : formatMoney(
              Money(minorUnits: minor, currency: saved!.amount.currency),
            ),
    );
    if (saved != null) {
      return [
        field('issued', 'Issued', ValueKind.date, value.issued),
        field('paid', 'Paid date', ValueKind.date, value.paid, optional: true),
        money('amount', 'Paid amount', saved.amount.minorUnits),
        field(
          'basis',
          'Basis',
          ValueKind.choice,
          value.basis,
          choices: basisChoices,
        ),
        money('gross', 'Gross amount', saved.grossMinorUnits),
        money('net', 'Net amount', saved.netMinorUnits),
        money('deductions', 'Deductions', saved.deductionMinorUnits),
        field(
          'reference',
          'Reference',
          ValueKind.text,
          value.reference,
          optional: true,
        ),
        field('note', 'Note', ValueKind.text, value.note, optional: true),
      ];
    }
    return periods
        ? [
            field('start', 'Start', ValueKind.date, value.start),
            field('end', 'End', ValueKind.date, value.end),
            field(
              'label',
              'Label',
              ValueKind.text,
              value.label,
              optional: true,
            ),
          ]
        : [
            field(
              'period',
              'Period',
              ValueKind.choice,
              value.period,
              choices: periodChoices,
            ),
            field('issued', 'Issued', ValueKind.date, value.issued),
            field(
              'paid',
              'Paid date',
              ValueKind.date,
              value.paid,
              optional: true,
            ),
            field(
              'amount',
              'Paid amount',
              ValueKind.money,
              value.amount,
              text: value.amount,
            ),
            field(
              'basis',
              'Basis',
              ValueKind.choice,
              value.basis,
              choices: basisChoices,
            ),
            field(
              'gross',
              'Gross amount',
              ValueKind.money,
              value.gross,
              text: value.gross,
              optional: true,
            ),
            field(
              'net',
              'Net amount',
              ValueKind.money,
              value.net,
              text: value.net,
              optional: true,
            ),
            field(
              'deductions',
              'Deductions',
              ValueKind.money,
              value.deductions,
              text: value.deductions,
              optional: true,
            ),
            field(
              'reference',
              'Reference',
              ValueKind.text,
              value.reference,
              optional: true,
            ),
            field('note', 'Note', ValueKind.text, value.note, optional: true),
          ];
  }

  Widget properties() {
    if (sheet.action case final action?) return _panel(action);
    final record = sheet.selected;
    final draft = editing
        ? sheet.session!.draft
        : record?.payslip != null
        ? PayValues.ofPayslip(record!.payslip!)
        : record?.period != null
        ? PayValues(
            start: record!.period!.start,
            end: record.period!.end,
            issued: today,
            label: record.period!.label ?? '',
          )
        : null;
    PropertyItem fact(
      String key,
      String label,
      Object? value, {
      VoidCallback? follow,
    }) => PropertyItem(
      key: key,
      label: label,
      category: 'Saved record',
      value: value,
      readOnlyReason: readOnly,
      onFollow: follow,
    );
    final period = record?.period;
    final slip = record?.payslip;
    return PropertyGrid(
      record: editing ? 'pay:new' : record?.id.value ?? 'none',
      controller: editors,
      today: today,
      openOn: editing
          ? periods
                ? 'start'
                : 'period'
          : null,
      edited: sheet.session?.dirty ?? false,
      onCommit: (id, value) => _accept(sheet.set(id.field, value)),
      items: [
        if (draft != null)
          ..._fields(draft, enabled: canEdit, saved: editing ? null : slip),
        if (period != null)
          fact(
            'state',
            'State',
            period.state == PayPeriodState.open ? 'Open' : 'Reviewed',
          ),
        if (slip != null) ...[
          fact('state', 'State', slip.isEffective ? 'Effective' : 'Void'),
          if (slip.voidReason != null)
            fact('reason', 'Void reason', slip.voidReason),
          if (slip.replacementPayslipId case final id?)
            fact(
              'replacement',
              'Replacement',
              'Open replacement',
              follow: () => _goRecord(id),
            ),
          if (slip.replacedPayslipId case final id?)
            fact(
              'original',
              'Original',
              'Open original',
              follow: () => _goRecord(id),
            ),
          fact(
            'periodLink',
            'Pay period',
            periodLabel(slip.periodId),
            follow: () => go(
              WorkLocation.pay(
                sheet.employmentId,
                sheet: WorkSheetKind.periods,
                payRecord: slip.periodId,
              ),
            ),
          ),
        ],
        if (draft != null)
          PropertyItem(
            key: 'employment',
            label: 'Employment',
            category: 'Belongs to',
            value: employmentName,
            onFollow: () => go(WorkLocation.employment(sheet.employmentId)),
          ),
      ],
    );
  }

  void _goRecord(WorkRecordId id) => go(
    WorkLocation.pay(
      sheet.employmentId,
      sheet: id is PayPeriodId ? WorkSheetKind.periods : WorkSheetKind.payslips,
      payRecord: id,
      payStatus: id is PayslipId ? 'all' : null,
    ),
  );
  Widget _panel(PayAction action) {
    final input = action.phase == PayActionPhase.input && !sheet.archived;
    final fields = action.values == null
        ? <PropertyItem>[]
        : _fields(action.values!, enabled: input);
    return ActionPanel(
      title: action.title,
      record: 'pay-action:${action.original.id.value}',
      controller: editors,
      today: today,
      cancelDraft: false,
      groups: () => [
        ActionGroup(legend: 'Record', children: [Text(action.explanation)]),
        if (action.values != null)
          ActionGroup(
            legend: 'Replacement',
            fields: [
              for (final item in fields)
                ActionField(
                  id: item.key,
                  label: item.label,
                  kind: item.kind,
                  value: item.value,
                  text: item.text,
                  choices: item.choices,
                  optional: item.optional,
                  enabled: input && item.key != 'period',
                  error: action.errors[item.key],
                ),
              ActionField(
                id: 'reason',
                label: 'Reason',
                kind: ValueKind.text,
                value: action.reason,
                text: action.reason,
                enabled: input,
                error: action.errors['reason'],
                fieldKey: const ValueKey('pay-correct-reason'),
              ),
            ],
          ),
      ],
      onChanged: action.set,
      primaryLabel: action.primary,
      onPrimary:
          action.canSubmit &&
              (input || action.phase == PayActionPhase.uncertain)
          ? () => unawaited(sheet.submitAction())
          : null,
      onCancel: () => _command(sheet.cancelAction),
      error: action.error,
      busy: action.busy,
      results: [
        if (action.phase == PayActionPhase.uncertain)
          ActionResult.uncertain(action.title, detail: PayAction.unknown),
      ],
    );
  }

  List<SubformTab> subformTabs() => [
    if (periods) ...[
      SubformTab(
        id: 'reconciliation',
        label: 'Reconciliation',
        builder: (_) => _reconciliation(),
      ),
      SubformTab(
        id: 'evidence',
        label: 'Evidence',
        builder: (_) => _evidence(),
      ),
      SubformTab(
        id: 'payslips',
        label: 'Payslips',
        builder: (_) => _payslips(),
      ),
    ],
    SubformTab(
      id: 'history',
      label: 'History',
      builder: (_) => sheet.selected == null
          ? HistoryGrid(events: const [], editors: editors)
          : RecordHistoryTab(
              history: sheet.work.history,
              recordKind: periods
                  ? WorkRecordKinds.payPeriod
                  : WorkRecordKinds.payslip,
              recordId: sheet.selected!.id.value,
              editors: editors,
            ),
    ),
  ];
  Widget _reconciliation() {
    final row = sheet.periods
        .where((row) => row.period.id == sheet.selected?.id)
        .firstOrNull;
    return DataGrid<ReconciliationGroup>(
      label: 'Reconciliation',
      columns: [
        GridColumn(
          key: 'basis',
          label: 'Basis',
          kind: ValueKind.text,
          width: 70,
          value: (row) => payBasis(row.basis),
        ),
        GridColumn(
          key: 'currency',
          label: 'Currency',
          kind: ValueKind.text,
          width: 65,
          value: (row) => row.currency.value,
        ),
        for (final key in ['expected', 'paid', 'difference'])
          GridColumn(
            key: key,
            label: key[0].toUpperCase() + key.substring(1),
            kind: ValueKind.money,
            width: 110,
            value: (row) => row.status is UnavailableReconciliation
                ? 'Unavailable'
                : payMoney(switch (key) {
                    'expected' => row.expected,
                    'paid' => row.paid,
                    _ => row.difference,
                  }),
          ),
        GridColumn(
          key: 'status',
          label: 'Status',
          kind: ValueKind.text,
          width: 125,
          value: (row) => payStatus(row.status),
        ),
      ],
      lines: [
        for (final group in row?.groups ?? const <ReconciliationGroup>[])
          GridRow(group),
      ],
      rowId: (row) => '${payBasis(row.basis)}:${row.currency.value}',
      rowLabel: (row) => payStatus(row.status),
      selectedId: null,
      editorController: editors,
      showNavigator: false,
      note: switch (row?.groups.length) {
        null => null,
        > 1 => 'Gross and net evidence cannot be combined. Expected includes employer-paid leave.',
        _ => 'Expected includes employer-paid leave. Difference is Paid minus Expected.',
      },
    );
  }

  Widget _evidence() {
    final period = sheet.selected?.period;
    if (period == null) return _linksGrid('Period evidence', const []);
    final facts = <(String, String, String, VoidCallback)>[
      for (final row in sheet.register?.shiftSheet ?? <ShiftSheetRow>[])
        if (row.shift.state == ShiftState.finalized &&
            period.contains(row.shift.localStartDate))
          (
            'shift:${row.shift.id.value}',
            'Shift ${row.shift.localStartDate}',
            row.pay == null ? 'Unavailable' : formatMoney(row.pay!.amount),
            () => go(
              WorkLocation.shifts(
                sheet.employmentId,
                month: row.shift.localStartDate.firstOfMonth,
                shift: row.shift.id,
              ),
            ),
          ),
      for (final row in sheet.register?.leaveSheet ?? <LeaveSheetRow>[])
        if (row.record.isEffective && period.contains(row.record.date))
          (
            'leave:${row.record.id.value}',
            'Leave ${row.record.date}',
            row.pay == null ? 'Unavailable' : formatMoney(row.pay!.amount),
            () => go(
              WorkLocation.leave(
                sheet.employmentId,
                month: row.record.date.firstOfMonth,
                leave: row.record.id,
              ),
            ),
          ),
    ];
    return _linksGrid('Period evidence', facts);
  }

  Widget _payslips() {
    final id = sheet.selected?.period?.id;
    return _linksGrid('Period payslips', [
      for (final row in sheet.payslips)
        if (row.periodId == id && row.isEffective)
          (
            row.id.value,
            'Payslip ${row.issuedDate}',
            '${formatMoney(row.amount)} ${payBasis(row.basis)}',
            () => _goRecord(row.id),
          ),
    ]);
  }

  Widget _linksGrid(
    String title,
    List<(String, String, String, VoidCallback)> facts,
  ) => DataGrid<(String, String, String, VoidCallback)>(
    label: title,
    columns: [
      GridColumn(
        key: 'record',
        label: 'Open record',
        kind: ValueKind.text,
        width: 190,
        value: (row) => row.$2,
      ),
      GridColumn(
        key: 'amount',
        label: 'Amount',
        kind: ValueKind.text,
        width: 140,
        value: (row) => row.$3,
      ),
    ],
    lines: [for (final fact in facts) GridRow(fact)],
    rowId: (row) => row.$1,
    rowLabel: (row) => 'Open ${row.$2}',
    selectedId: null,
    editorController: editors,
    showNavigator: false,
    onSelect: (id) =>
        _command(() async => facts.firstWhere((row) => row.$1 == id).$4()),
  );

  Widget filterStrip() => FilterStrip(
    onClear: place.payStatus == null && place.periodFilter == null
        ? null
        : () => setFilter(null, null),
    items: [
      if (!periods)
        FilterStripItem(
          label: 'Period',
          child: EraCombo<PayPeriodId?>(
            semanticLabel: 'Pay period filter',
            value: place.periodFilter,
            items: [
              const EraComboItem(null, 'All periods'),
              for (final row in sheet.periods)
                EraComboItem(row.period.id, periodName(row.period)),
            ],
            onSelected: (id) => setFilter(place.payStatus, id),
          ),
        ),
      FilterStripItem(
        label: 'Status',
        child: EraCombo<String>(
          semanticLabel: 'Pay status',
          value: place.payStatus ?? (periods ? 'all' : 'effective'),
          items: periods
              ? const [
                  EraComboItem('all', 'All'),
                  EraComboItem('open', 'Open'),
                  EraComboItem('reviewed', 'Reviewed'),
                ]
              : const [
                  EraComboItem('effective', 'Effective'),
                  EraComboItem('all', 'All'),
                  EraComboItem('void', 'Void'),
                ],
          onSelected: (status) => setFilter(
            status == (periods ? 'all' : 'effective') ? null : status,
            place.periodFilter,
          ),
        ),
      ),
    ],
  );
  List<ToolbarBand> bands() {
    final edit = sheet.session;
    ToolbarItem command(
      String label,
      String? blocked,
      Future<Object?> Function() command,
    ) => ToolbarItem(
      label: label,
      tooltip: blocked,
      onPressed: blocked == null ? () => _command(command) : null,
    );
    return [
      ToolbarBand(
        items: [
          command('Save', canEdit ? null : readOnly, sheet.save),
          ToolbarItem(
            label: 'Undo',
            onPressed: editing && !(edit?.frozen ?? true) ? undo : null,
          ),
          command(
            edit?.phase == EditPhase.uncertain
                ? 'Reload and check'
                : 'Reload record',
            sheet.action != null ? 'Finish the current action first.' : null,
            sheet.reload,
          ),
          if (edit?.gone == true)
            command('Discard and return to sheet', null, sheet.discardMissing),
        ],
      ),
      ToolbarBand(
        row: 1,
        items: periods
            ? [
                command(
                  'Mark reviewed',
                  sheet.actionBlocked ??
                      (sheet.selected?.period?.state != PayPeriodState.open
                          ? 'Select an open period.'
                          : null),
                  () => sheet.openAction(PayActionKind.review),
                ),
                command(
                  'Reopen period',
                  sheet.actionBlocked ??
                      (sheet.selected?.period?.state != PayPeriodState.reviewed
                          ? 'Select a reviewed period.'
                          : null),
                  () => sheet.openAction(PayActionKind.reopen),
                ),
                command(
                  'Record payslip…',
                  sheet.actionBlocked,
                  () async =>
                      addPay(PayKind.payslips, sheet.selected!.period!.id),
                ),
              ]
            : [
                command(
                  'Correct…',
                  sheet.actionBlocked ??
                      (sheet.selected?.payslip?.isEffective != true
                          ? 'Select an effective payslip.'
                          : null),
                  () => sheet.openAction(PayActionKind.correct),
                ),
              ],
      ),
    ];
  }

  void undo() {
    if (!editing || sheet.session!.frozen) return;
    if (!editors.flush().isAccepted) editors.cancel();
    unawaited(sheet.undo());
  }

  List<EraMenuItem> editMenu() => [
    EraMenuItem(
      'Save',
      canEdit ? () => _command(sheet.save) : null,
      disabledReason: readOnly,
    ),
    EraMenuItem(
      'Undo',
      editing && !sheet.session!.frozen ? undo : null,
      disabledReason: readOnly,
    ),
  ];
  List<EraMenuItem> recordMenu() => [
    EraMenuItem(
      periods ? 'New pay period…' : 'Record payslip…',
      sheet.createBlocked == null
          ? () => addPay(sheet.kind, place.periodFilter)
          : null,
      disabledReason: sheet.createBlocked,
    ),
    for (final band in bands().skip(1))
      for (final item in band.items)
        EraMenuItem(item.label, item.onPressed, disabledReason: item.tooltip),
  ];
  List<EraMenuItem> addItems() => [
    EraMenuItem(
      periods ? 'Pay period…' : 'Payslip…',
      sheet.createBlocked == null
          ? () => addPay(sheet.kind, place.periodFilter)
          : null,
      icon: periods ? EraIconKind.payPeriod : EraIconKind.payslip,
      disabledReason: sheet.createBlocked,
    ),
  ];
  String notice() =>
      sheet.action?.notice ??
      sheet.session?.problem ??
      sheet.notice ??
      (editing
          ? periods
                ? 'New pay period: enter its dates and label, then Save.'
                : 'New payslip: enter its period and money evidence, then Save.'
          : sheet.failed
          ? '$title could not be read. Try again.'
          : sheet.selected == null
          ? _emptyNotice ?? 'Ready.'
          : readOnlyStatus);
}
