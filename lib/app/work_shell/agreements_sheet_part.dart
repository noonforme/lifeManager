import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/application/work_commands.dart' show AgreementTerms;
import '../../features/work/data/work_history.dart' show WorkRecordKinds;
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/agreement_fields.dart';
import '../work_edit/work_records.dart';
import 'agreement_action.dart';
import 'agreement_properties.dart';
import 'agreements_sheet_controller.dart';
import 'employments_sheet_controller.dart' show EmploymentsWords;
import 'shifts_subform.dart' show HistoryGrid, RecordHistoryTab;
import 'work_shell.dart' show runCommand;

/// Words of the Agreements sheet's keys and empty states.
abstract final class AgreementsPartWords {
  static const add = 'Add pay agreement…';
  static const change = 'Change terms from…';
  static const end = 'End agreement…';
  static const remove = 'Remove agreement…';
  static const unreadableTitle = 'Pay agreements could not be read';
  static const pending =
      'Unsaved changes. Save, or leave the agreement, to keep them.';
}

/// One row of the Agreements grid: a stored version or the new one.
@immutable
final class AgreementLine {
  const AgreementLine({
    required this.id,
    required this.version,
    required this.starts,
    required this.ends,
    required this.rate,
    required this.basis,
    required this.night,
    required this.status,
    required this.paidShifts,
    required this.label,
    required this.ended,
  });

  /// The version's id, or [newAgreementId].
  final String id;
  final String version;
  final LocalDate starts;
  final LocalDate? ends;
  final int rate;
  final String basis;
  final String night;
  final String status;
  final int? paidShifts;
  final String? label;
  final bool ended;
}

/// The Agreements sheet's part of the Work shell's window (spec 3, 4.2,
/// 4.4): the grid of versions, the property column of the selected one or
/// its open panel, the History subform, the toolbar bands, the Record and
/// Add menus and the status line, over an [AgreementsSheetController]. The
/// shell puts them in AppFrame's slots.
final class AgreementsSheetPart {
  AgreementsSheetPart({
    required this.sheet,
    required this.editors,
    required this.work,
    required this.today,
    required this.employmentName,
    required this.onEmployment,
    this.archived = false,
  });

  /// The employment is archived: its agreements are read-only too.
  final bool archived;

  /// Why nothing here may change; null while the employment is active.
  String? get _locked => archived ? EmploymentsWords.archivedReadOnly : null;

  final AgreementsSheetController sheet;
  final EditorSessionController editors;
  final ProductionWorkProviders work;
  final LocalDate today;

  /// The employment's name, for the Belongs to link.
  final String employmentName;

  /// Opens the employment (a guarded move of the shell).
  final VoidCallback onEmployment;

  void _command(Future<Object?> Function() command) =>
      runCommand(editors, command);

  String _basis(RateBasis basis) => switch (basis) {
    GrossBasis() => 'Gross',
    NetBasis() => 'Net',
  };

  /// The grid's rows: the versions, the selected one with its pending
  /// terms, then the one being added.
  List<AgreementLine> get lines {
    final edit = sheet.session;
    AgreementLine line(AgreementRow row) {
      final value = row.agreement;
      final pending = edit != null && edit.baseline?.value.id == value.id
          ? edit.draft.terms
          : null;
      final starts = pending?.effectiveStart ?? value.effectiveStart;
      final ends = pending == null ? value.effectiveEnd : pending.effectiveEnd;
      final ended = ends != null && ends.compareTo(today) < 0;
      return AgreementLine(
        id: value.id.value,
        version: 'v${value.version}',
        starts: starts,
        ends: ends,
        rate: pending?.hourlyRateMicroEur ?? value.hourlyRateMicroEur,
        basis: _basis(pending?.basis ?? value.basis),
        night: nightText(pending ?? AgreementTerms.of(value)),
        status: ended
            ? 'Ended'
            : starts.compareTo(today) > 0
            ? 'Later'
            : 'Current',
        paidShifts: row.paidShifts,
        label: pending == null ? value.label : pending.label,
        ended: ended,
      );
    }

    return [
      for (final row in sheet.rows) line(row),
      if (edit != null && edit.isNew)
        AgreementLine(
          id: newAgreementId,
          version: 'New',
          starts: edit.draft.terms.effectiveStart,
          ends: edit.draft.terms.effectiveEnd,
          rate: edit.draft.terms.hourlyRateMicroEur,
          basis: _basis(edit.draft.terms.basis),
          night: nightText(edit.draft.terms),
          status: 'New',
          paidShifts: null,
          label: edit.draft.terms.label,
          ended: false,
        ),
    ];
  }

  late final List<GridColumn<AgreementLine>> _columns = [
    GridColumn<AgreementLine>(
      key: 'version',
      label: 'Version',
      kind: ValueKind.text,
      width: 60,
      value: (line) => line.version,
    ),
    GridColumn<AgreementLine>(
      key: AgreementField.effectiveStart,
      label: 'Starts',
      kind: ValueKind.date,
      width: 88,
      value: (line) => line.starts,
      editable: true,
    ),
    GridColumn<AgreementLine>(
      key: AgreementField.effectiveEnd,
      label: 'Ends',
      kind: ValueKind.date,
      width: 88,
      value: (line) => line.ends,
      editable: true,
      optional: true,
    ),
    GridColumn<AgreementLine>(
      key: AgreementField.hourlyRate,
      label: 'Hourly rate',
      kind: ValueKind.money,
      width: 84,
      value: (line) => line.rate == 0 ? null : line.rate,
      display: (value) => value is int ? formatHourlyRate(value) : '',
      editText: (line) => line.rate == 0 ? '' : hourlyRateText(line.rate),
      editable: true,
    ),
    GridColumn<AgreementLine>(
      key: 'basis',
      label: 'Basis',
      kind: ValueKind.text,
      width: 52,
      value: (line) => line.basis,
    ),
    GridColumn<AgreementLine>(
      key: 'night',
      label: 'Night',
      kind: ValueKind.text,
      width: 120,
      value: (line) => line.night,
    ),
    GridColumn<AgreementLine>(
      key: 'status',
      label: 'Status',
      kind: ValueKind.text,
      width: 64,
      value: (line) => line.status,
    ),
    GridColumn<AgreementLine>(
      key: 'paidShifts',
      label: 'Paid shifts',
      kind: ValueKind.number,
      width: 72,
      value: (line) => line.paidShifts,
      description: 'Finished shifts this version paid.',
    ),
    GridColumn<AgreementLine>(
      key: AgreementField.label,
      label: 'Label',
      kind: ValueKind.text,
      width: 140,
      value: (line) => line.label,
      editable: true,
      optional: true,
    ),
  ];

  EditResult _accept(String? problem) => problem == null
      ? const EditResult.accepted()
      : EditResult.rejected(problem);

  /// The Agreements grid, empty while loading or with none; a warning
  /// when they could not be read.
  Widget middle() {
    final lines = this.lines;
    if (lines.isEmpty && sheet.failed) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: AgreementsPartWords.unreadableTitle,
        message: AgreementsNotices.unreadable,
      );
    }
    final edit = sheet.session;
    final selected = sheet.selectedId;
    return DataGrid<AgreementLine>(
      label: 'Pay agreements',
      columns: _columns,
      lines: [
        for (final line in lines)
          GridRow(
            line,
            state: line.ended ? GridRowState.muted : GridRowState.normal,
          ),
      ],
      rowId: (line) => line.id,
      rowLabel: (line) =>
          line.id == newAgreementId ? 'New pay agreement' : line.version,
      selectedId: selected,
      onSelect: (id) {
        if (id == newAgreementId) return;
        final row = sheet.rows
            .where((value) => value.agreement.id.value == id)
            .firstOrNull;
        if (row != null) _command(() => sheet.select(row.agreement.id));
      },
      editorController: editors,
      onEdit: (cell, draft) => cell.rowId == selected && edit != null
          ? _accept(sheet.editField(cell.rowId, cell.column, draft))
          : const EditResult.rejected(AgreementProblems.notEditable),
      readOnlyReason: (line, column) =>
          column.editable && (line.id != selected || edit == null)
          ? 'Select the agreement to change it.'
          : null,
      today: today,
      pendingIds: {
        if (selected != null && edit != null && edit.dirty) selected,
      },
      errors: {
        if (selected != null && edit != null)
          for (final MapEntry(:key, :value) in edit.issues.entries)
            GridCell(selected, key): value,
      },
      onNew: archived ? null : () => _command(sheet.addAgreement),
    );
  }

  /// The property column: the open panel, else the selected version's
  /// properties, else nothing.
  Widget properties() {
    if (sheet.action case final action?) return _panel(action);
    final edit = sheet.session;
    if (edit == null) {
      return PropertyGrid(
        record: 'none',
        controller: editors,
        items: const [],
        onCommit: (_, _) => const EditResult.accepted(),
        today: today,
      );
    }
    final saved = edit.baseline?.value;
    return PropertyGrid(
      record: saved == null ? 'agreement:new' : 'agreement:${saved.id.value}',
      controller: editors,
      today: today,
      edited: edit.dirty,
      onCommit: (id, value) =>
          _accept(sheet.editField(sheet.selectedId ?? '', id.field, value)),
      items: agreementPropertyItems(
        edit: edit,
        row: sheet.selectedRow,
        employmentName: employmentName,
        onEmployment: () => _command(() async => onEmployment()),
        readOnlyReason: _locked,
      ),
    );
  }

  Widget _panel(AgreementAction action) {
    final value = action.row.agreement;
    final input = action.phase == AgreementActionPhase.input;
    final change = action.kind == AgreementActionKind.changeTerms;
    String? accept(String field, Object? draft) => action.set(field, draft);
    return ActionPanel(
      title: action.title,
      record: 'action:${action.kind.name}:${value.id.value}',
      controller: editors,
      today: today,
      cancelDraft: false,
      groups: () => [
        ActionGroup(
          legend: 'Agreement',
          children: [
            Text(
              'Pay agreement v${value.version}, '
              '${eraBoxDate(value.effectiveStart)} – '
              '${value.effectiveEnd == null ? '(runs on)' : eraBoxDate(value.effectiveEnd!)}',
            ),
            Text(action.explanation),
          ],
        ),
        ActionGroup(
          legend: change ? 'New terms' : 'End',
          fields: [
            ActionField(
              id: 'date',
              label: change
                  ? AgreementActionWords.fromLabel
                  : AgreementActionWords.lastDayLabel,
              kind: ValueKind.date,
              value: action.date,
              enabled: input,
              error: action.errors['date'],
              validate: (draft) =>
                  draft is LocalDate ? null : AgreementProblems.startRequired,
              fieldKey: const ValueKey('agreement-action-date'),
            ),
            if (change) ...[
              ActionField(
                id: AgreementField.hourlyRate,
                label: 'Hourly rate',
                kind: ValueKind.money,
                value: action.rate,
                text: hourlyRateText(action.rate),
                enabled: input,
                validate: (draft) =>
                    switch (parseHourlyRate('${draft ?? ''}')) {
                      final rate? when rate > 0 => null,
                      _ => AgreementProblems.rate,
                    },
              ),
              ActionField(
                id: AgreementField.basis,
                label: 'Basis',
                kind: ValueKind.choice,
                choices: basisChoices,
                value: action.basis,
                enabled: input,
              ),
              ActionField(
                id: AgreementField.label,
                label: 'Label',
                kind: ValueKind.text,
                value: action.label,
                text: action.label ?? '',
                enabled: input,
              ),
              ActionField(
                id: AgreementField.note,
                label: 'Note',
                kind: ValueKind.text,
                value: action.note,
                text: action.note ?? '',
                enabled: input,
              ),
            ],
          ],
        ),
      ],
      onChanged: (field, draft) => accept(field, draft),
      primaryLabel: action.primaryLabel,
      onPrimary: action.canSubmit
          ? () => unawaited(sheet.submitAction())
          : null,
      onCancel: () => _command(sheet.cancelAction),
      results: [
        if (action.phase == AgreementActionPhase.uncertain)
          ActionResult.uncertain(
            action.title,
            detail: AgreementActionWords.uncertain,
          ),
      ],
      error: action.error,
      busy: action.busy,
    );
  }

  /// The History subform tab of the selected version.
  List<SubformTab> subformTabs() => [
    SubformTab(
      id: 'history',
      label: 'History',
      builder: (context) => switch ((sheet.selectedRow, sheet.session)) {
        (final row?, _) => RecordHistoryTab(
          history: work.history,
          recordKind: WorkRecordKinds.agreement,
          recordId: row.agreement.id.value,
          editors: editors,
        ),
        _ => HistoryGrid(events: const [], editors: editors),
      },
    ),
  ];

  /// What the subform's caption says it shows.
  Widget? subformTrailing() => switch (sheet.selectedRow) {
    final row? => Text('for Pay agreement v${row.agreement.version}'),
    null => null,
  };

  /// The Agreements sheet's toolbar bands.
  List<ToolbarBand> bands() {
    final session = sheet.session;
    final idle = session != null && !session.frozen && !archived;
    final reload = switch (session?.phase) {
      EditPhase.uncertain => 'Reload and check',
      EditPhase.stale => 'Reload record',
      _ => null,
    };
    final gone = session?.gone ?? false;
    ToolbarItem command(
      String label,
      String? blocked,
      Future<Object?> Function() run, {
      EraIconKind? icon,
    }) => ToolbarItem(
      label: label,
      icon: icon,
      tooltip: _locked ?? blocked,
      onPressed: _locked == null && blocked == null
          ? () => _command(run)
          : null,
    );
    return [
      ToolbarBand(
        items: [
          ToolbarItem(
            label: 'Save',
            onPressed: idle ? () => _command(sheet.save) : null,
          ),
          ToolbarItem(label: 'Undo', onPressed: idle ? undo : null),
          command('Delete', sheet.removeBlocked, sheet.remove),
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
        ],
      ),
      ToolbarBand(
        row: 1,
        items: [
          command(
            AgreementsPartWords.change,
            sheet.changeBlocked,
            () => sheet.openAction(AgreementActionKind.changeTerms),
            icon: EraIconKind.agreement,
          ),
          command(
            AgreementsPartWords.end,
            sheet.endBlocked,
            () => sheet.openAction(AgreementActionKind.end),
          ),
          // Remove agreement… is the Record band's Delete (spec 3), and a
          // row of its own in the Record menu.
        ],
      ),
    ];
  }

  /// Undo (spec 4.2, 4.3), from the toolbar and Edit › Undo.
  void undo() {
    final session = sheet.session;
    if (session == null || session.frozen) return;
    if (!session.isNew || !editors.flush().isAccepted) editors.cancel();
    unawaited(sheet.undo());
  }

  /// The Edit menu: Save and Undo as the keys run them, greyed with why.
  List<EraMenuItem> editMenu() {
    final session = sheet.session;
    final reason = switch (session) {
      null => 'No record is open.',
      final open when open.frozen => open.problem ?? EditProblems.busy,
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

  /// The Record menu: the same commands as the keys (spec 4.9).
  List<EraMenuItem> recordMenu() {
    final session = sheet.session;
    EraMenuItem command(
      String label,
      String? blocked,
      Future<Object?> Function() run,
    ) => EraMenuItem(
      label,
      _locked == null && blocked == null ? () => _command(run) : null,
      disabledReason: _locked ?? blocked,
    );
    return [
      command(AgreementsPartWords.add, null, sheet.addAgreement),
      const EraMenuItem.separator(),
      EraMenuItem(
        'Save',
        session == null || session.frozen || archived
            ? null
            : () => _command(sheet.save),
        disabledReason:
            _locked ?? (session == null ? 'No record is open.' : null),
      ),
      const EraMenuItem.separator(),
      command(
        AgreementsPartWords.change,
        sheet.changeBlocked,
        () => sheet.openAction(AgreementActionKind.changeTerms),
      ),
      command(
        AgreementsPartWords.end,
        sheet.endBlocked,
        () => sheet.openAction(AgreementActionKind.end),
      ),
      command(AgreementsPartWords.remove, sheet.removeBlocked, sheet.remove),
    ];
  }

  /// The Add menu's entries for this sheet (spec 3).
  List<EraMenuItem> addItems() => [
    if (!archived)
      EraMenuItem(
        'Pay agreement',
        () => _command(sheet.addAgreement),
        icon: EraIconKind.agreement,
      ),
  ];

  /// The status line: the open panel's state, else the edit's problem,
  /// else what is new or pending, else what the sheet found, else why
  /// there is nothing yet.
  String notice() {
    if (sheet.action case final action?) return action.notice;
    final session = sheet.session;
    if (session?.problem case final problem?) return problem;
    if (session case final edit? when edit.isNew) {
      return AgreementsNotices.newAgreement;
    }
    if (session case final edit? when edit.dirty) {
      return AgreementsPartWords.pending;
    }
    if (sheet.notice case final notice?) return notice;
    if (sheet.failed) return AgreementsNotices.unreadable;
    if (!sheet.loaded) return AgreementsNotices.loading;
    if (sheet.rows.isEmpty) return AgreementsNotices.empty;
    return AgreementsNotices.ready;
  }
}
