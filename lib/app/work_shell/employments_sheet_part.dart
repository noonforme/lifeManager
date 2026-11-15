import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/employment.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../edit_session/record_edit_session.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/work_records.dart';
import 'agreement_properties.dart';
import 'employments_sheet_controller.dart';
import 'work_shell_controller.dart' show WorkShellNotices;

/// Words of the Employments sheet's properties and keys (spec 4.9, and the
/// agreement correction texts of bead 9pk.3.6).
abstract final class EmploymentsPropertyWords {
  static const addEmployment = 'Add employment…';
  static const setUpAgreement = 'Set up pay agreement…';
  static const newSchedule = 'New schedule…';
  static const openSchedules = 'Open the Schedules sheet';
  static const scheduleStep =
      'The rotation that plans your shifts: its shift types and cycle.';
  static const statusActive =
      'Archive employment… in the Record menu ends an employment.';
  static const statusArchived =
      'Archived: it sits under Ended employments, read-only.';
  static const archive = 'Archive employment…';
  static const delete = 'Delete employment…';
  static const saveFirst = 'Save the employment first.';
  static const name = 'What you call this employment.';
  static const legalLabel = "The employer's legal name, if you want it.";
}

/// One row of the Employments grid: a stored employment or the new one.
@immutable
final class EmploymentLine {
  const EmploymentLine({
    required this.id,
    required this.name,
    required this.legalLabel,
    required this.status,
    required this.agreements,
    required this.archived,
  });

  /// The employment's id, or [newEmploymentId].
  final String id;
  final String name;
  final String? legalLabel;
  final String status;
  final int? agreements;
  final bool archived;
}

/// The row id of an employment being added.
const newEmploymentId = 'new';

/// The Employments sheet's part of the Work shell's window (spec 4.9): the
/// grid of employments, the property column of the selected one or of its
/// agreement, the toolbar bands, the Record menu and the status line, over
/// an [EmploymentsSheetController]. The shell puts them in AppFrame's
/// slots.
final class EmploymentsSheetPart {
  EmploymentsSheetPart({
    required this.sheet,
    required this.editors,
    required this.today,
    required this.employments,
    required this.openAgreement,
    this.openSchedules,
    this.unreadable = false,
    this.daysToConfirm = 0,
  });

  /// The selected employment's past days to confirm, for the archive
  /// window.
  final int daysToConfirm;

  /// Opens the stored agreement [id] on the Agreements sheet (a guarded
  /// move of the shell).
  final void Function(AgreementId id) openAgreement;

  /// Opens the employment's Schedules sheet, on a new schedule when it has
  /// none.
  final VoidCallback? openSchedules;

  /// The employments could not be read: the sheet says so and offers
  /// nothing to add.
  final bool unreadable;

  final EmploymentsSheetController sheet;
  final EditorSessionController editors;
  final LocalDate today;

  /// Every employment with its agreement count, as the shell lists them.
  final List<EmploymentSummary> employments;

  /// Runs [command] once the open editor's value is taken.
  void _command(Future<Object?> Function() command) {
    if (!editors.flush().isAccepted) return;
    unawaited(command());
  }

  /// How many schedules the selected employment has.
  int get _scheduleCount =>
      employments
          .where((summary) => summary.employment.id == sheet.selected)
          .firstOrNull
          ?.counts
          .schedules ??
      0;

  /// The grid's rows: the employments, then the one being added.
  List<EmploymentLine> get lines {
    final edit = sheet.employment;
    EmploymentLine line(EmploymentSummary summary) {
      final employment = summary.employment;
      final pending = edit != null && edit.baseline?.value.id == employment.id
          ? edit.draft
          : null;
      return EmploymentLine(
        id: employment.id.value,
        name: pending?.name ?? employment.name,
        legalLabel: pending == null
            ? employment.legalLabel
            : pending.legalLabel,
        status: switch (employment.status) {
          EmploymentStatus.active => 'Active',
          EmploymentStatus.archived => 'Archived',
        },
        agreements: summary.agreements,
        archived: employment.status == EmploymentStatus.archived,
      );
    }

    return [
      for (final summary in employments) line(summary),
      if (edit != null && edit.isNew)
        EmploymentLine(
          id: newEmploymentId,
          name: edit.draft.name,
          legalLabel: edit.draft.legalLabel,
          status: 'New',
          agreements: null,
          archived: false,
        ),
    ];
  }

  /// The selected row's id.
  String? get selectedId => switch ((sheet.selected, sheet.employment)) {
    (final id?, _) => id.value,
    (null, final edit?) when edit.isNew => newEmploymentId,
    _ => null,
  };

  late final List<GridColumn<EmploymentLine>> _columns = [
    GridColumn<EmploymentLine>(
      key: EmploymentField.name,
      label: 'Name',
      kind: ValueKind.text,
      width: 180,
      value: (line) => line.name,
      editable: true,
    ),
    GridColumn<EmploymentLine>(
      key: EmploymentField.legalLabel,
      label: 'Legal label',
      kind: ValueKind.text,
      width: 160,
      value: (line) => line.legalLabel,
      editable: true,
      optional: true,
    ),
    GridColumn<EmploymentLine>(
      key: 'status',
      label: 'Status',
      kind: ValueKind.text,
      width: 84,
      value: (line) => line.status,
    ),
    GridColumn<EmploymentLine>(
      key: 'agreements',
      label: 'Agreements',
      kind: ValueKind.number,
      width: 84,
      value: (line) => line.agreements,
      description: 'How many pay agreements it has.',
    ),
  ];

  EditResult _accept(String? problem) => problem == null
      ? const EditResult.accepted()
      : EditResult.rejected(problem);

  /// The Employments grid; Add employment… above it while no active
  /// employment exists (spec 4.9).
  Widget middle() {
    if (unreadable && employments.isEmpty) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: EmploymentsWords.unreadable,
        message: WorkShellNotices.unreadable,
      );
    }
    final lines = this.lines;
    final edit = sheet.employment;
    final selected = selectedId;
    final grid = DataGrid<EmploymentLine>(
      label: 'Employments',
      columns: _columns,
      lines: [
        for (final line in lines)
          GridRow(
            line,
            state: line.archived ? GridRowState.muted : GridRowState.normal,
          ),
      ],
      rowId: (line) => line.id,
      rowLabel: (line) => line.name.isEmpty ? 'New employment' : line.name,
      selectedId: selected,
      onSelect: (id) {
        if (id == newEmploymentId) return;
        final summary = employments
            .where((value) => value.employment.id.value == id)
            .firstOrNull;
        if (summary != null) unawaited(sheet.select(summary.employment.id));
      },
      editorController: editors,
      onEdit: (cell, draft) => cell.rowId == selected && sheet.agreement == null
          ? _accept(sheet.editEmployment(cell.column, draft))
          : const EditResult.rejected(EmploymentsWords.notEditable),
      readOnlyReason: (line, column) => !column.editable
          ? null
          : line.archived
          ? EmploymentsWords.archivedReadOnly
          : line.id != selected || sheet.agreement != null
          ? 'Select the employment to change it.'
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
      onNew: () => _command(sheet.addEmployment),
    );
    return grid;
  }

  /// The band over the grid while no employment is active: the key that
  /// adds one, in the strip the other sheets filter in, so the grid starts
  /// where theirs does. Null once one is active, or while none can be read.
  Widget? middleHeader() {
    if (unreadable && employments.isEmpty) return null;
    if (employments.any(
      (value) => value.employment.status == EmploymentStatus.active,
    )) {
      return null;
    }
    return FilterStrip(
      items: [
        FilterStripItem(
          child: KeyButton(
            label: EmploymentsPropertyWords.addEmployment,
            onPressed: () => _command(sheet.addEmployment),
          ),
        ),
      ],
    );
  }

  /// The property column: the agreement's, else the employment's.
  Widget properties() {
    if (sheet.agreement case final agreement?) {
      return _agreementProperties(agreement);
    }
    final edit = sheet.employment;
    if (edit == null) {
      return PropertyGrid(
        record: 'none',
        controller: editors,
        items: const [],
        onCommit: (_, _) => const EditResult.accepted(),
        today: today,
      );
    }
    final draft = edit.draft;
    final saved = edit.baseline?.value;
    final archived = saved?.status == EmploymentStatus.archived;
    String? was(String field, Object? savedValue, Object? value) =>
        saved != null && savedValue != value ? '${savedValue ?? ''}' : null;
    return PropertyGrid(
      record: saved == null ? 'employment:new' : 'employment:${saved.id.value}',
      controller: editors,
      today: today,
      edited: edit.dirty,
      onCommit: (id, value) => _accept(sheet.editEmployment(id.field, value)),
      items: [
        PropertyItem(
          key: EmploymentField.name,
          label: 'Name',
          category: 'Employment',
          value: draft.name,
          was: was(EmploymentField.name, saved?.name, draft.name),
          error: edit.issues[EmploymentField.name],
          description: EmploymentsPropertyWords.name,
          readOnlyReason: archived ? EmploymentsWords.archivedReadOnly : null,
        ),
        PropertyItem(
          key: EmploymentField.legalLabel,
          label: 'Legal label',
          category: 'Employment',
          value: draft.legalLabel,
          was: was(
            EmploymentField.legalLabel,
            saved?.legalLabel,
            draft.legalLabel,
          ),
          description: EmploymentsPropertyWords.legalLabel,
          readOnlyReason: archived ? EmploymentsWords.archivedReadOnly : null,
        ),
        PropertyItem(
          key: 'status',
          label: 'Status',
          category: 'Employment',
          value: switch (saved?.status) {
            EmploymentStatus.archived => 'Archived',
            EmploymentStatus.active => 'Active',
            null => 'New',
          },
          readOnlyReason: switch (saved?.status) {
            EmploymentStatus.archived =>
              EmploymentsPropertyWords.statusArchived,
            EmploymentStatus.active => EmploymentsPropertyWords.statusActive,
            null => EmploymentsPropertyWords.saveFirst,
          },
        ),
        if (saved == null)
          const PropertyItem(
            key: 'agreement',
            label: 'Pay agreement',
            category: 'Next steps',
            value: EmploymentsPropertyWords.setUpAgreement,
            readOnlyReason: EmploymentsPropertyWords.saveFirst,
          )
        else if (sheet.agreements.isEmpty)
          PropertyItem(
            key: 'agreement',
            label: 'Pay agreement',
            category: 'Next steps',
            value: EmploymentsPropertyWords.setUpAgreement,
            description: EmploymentsNotices.noAgreement,
            onFollow: () => _command(sheet.setUpAgreement),
          )
        else
          for (final value in sheet.agreements)
            PropertyItem(
              key: 'agreement:${value.id.value}',
              label: 'Pay agreement v${value.version}',
              category: 'Next steps',
              value: agreementSummary(value),
              description: 'Open these terms on the Agreements sheet.',
              onFollow: () => _command(() async => openAgreement(value.id)),
            ),
        PropertyItem(
          key: 'schedule',
          label: 'Schedule',
          category: 'Next steps',
          value: _scheduleCount == 0
              ? EmploymentsPropertyWords.newSchedule
              : EmploymentsPropertyWords.openSchedules,
          description: EmploymentsPropertyWords.scheduleStep,
          onFollow: openSchedules,
        ),
      ],
    );
  }

  Widget _agreementProperties(AgreementSession edit) {
    final saved = edit.baseline?.value;
    final employment = employments
        .where((value) => value.employment.id == sheet.selected)
        .firstOrNull
        ?.employment;
    return PropertyGrid(
      record: saved == null ? 'agreement:new' : 'agreement:${saved.id.value}',
      controller: editors,
      today: today,
      edited: edit.dirty,
      onCommit: (id, value) => _accept(sheet.editAgreement(id.field, value)),
      items: agreementPropertyItems(
        edit: edit,
        row: null,
        employmentName: employment?.name,
        onEmployment: () => _command(sheet.closeAgreement),
      ),
    );
  }

  /// The Employments sheet's toolbar bands.
  List<ToolbarBand> bands() {
    final session = sheet.session;
    final idle = session != null && !session.frozen;
    final reload = switch (session?.phase) {
      EditPhase.uncertain => 'Reload and check',
      EditPhase.stale => 'Reload record',
      _ => null,
    };
    final gone = session?.gone ?? false;
    return [
      ToolbarBand(
        items: [
          ToolbarItem(
            label: 'New employment',
            icon: EraIconKind.employment,
            tooltip: unreadable ? EmploymentsWords.unreadable : null,
            onPressed: unreadable ? null : () => _command(sheet.addEmployment),
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
          ToolbarItem(
            label: 'Delete',
            tooltip: _deleteBlocked,
            onPressed: _deleteBlocked == null
                ? () => _command(() => sheet.delete(hasHistory: false))
                : null,
          ),
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
          ToolbarItem(
            label: EmploymentsPropertyWords.setUpAgreement,
            icon: EraIconKind.agreement,
            tooltip: _setUpBlocked,
            onPressed: _setUpBlocked == null
                ? () => _command(sheet.setUpAgreement)
                : null,
          ),
        ],
      ),
    ];
  }

  /// The selected employment's summary.
  EmploymentSummary? get _summary => employments
      .where((value) => value.employment.id == sheet.selected)
      .firstOrNull;

  /// Why Delete employment… does not apply; null when it does.
  String? get _deleteBlocked =>
      sheet.deleteBlocked(hasHistory: _summary?.hasHistory ?? true);

  void _archive() =>
      _command(() => sheet.archive(daysToConfirm: daysToConfirm));

  /// Why Set up pay agreement… does not apply; null when it does.
  String? get _setUpBlocked {
    if (sheet.selected == null) return 'Select a saved employment first.';
    if (sheet.employment?.baseline?.value.status == EmploymentStatus.archived) {
      return EmploymentsWords.archivedReadOnly;
    }
    if (sheet.agreement?.isNew ?? false) {
      return 'A new pay agreement is open.';
    }
    return null;
  }

  /// Undo (spec 4.2, 4.3), from the toolbar and Edit › Undo. A new
  /// record takes the value being typed, so Undo's window may still save
  /// it; one that cannot be taken, or an existing record's, is dropped.
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
    return [
      EraMenuItem(
        EmploymentsPropertyWords.addEmployment,
        unreadable ? null : () => _command(sheet.addEmployment),
        disabledReason: unreadable ? EmploymentsWords.unreadable : null,
      ),
      const EraMenuItem.separator(),
      EraMenuItem(
        'Save',
        session == null || session.frozen ? null : () => _command(sheet.save),
        disabledReason: session == null ? 'No record is open.' : null,
      ),
      const EraMenuItem.separator(),
      EraMenuItem(
        EmploymentsPropertyWords.setUpAgreement,
        _setUpBlocked == null ? () => _command(sheet.setUpAgreement) : null,
        disabledReason: _setUpBlocked,
      ),
      const EraMenuItem.separator(),
      EraMenuItem(
        EmploymentsPropertyWords.archive,
        sheet.archiveBlocked == null ? _archive : null,
        disabledReason: sheet.archiveBlocked,
      ),
      EraMenuItem(
        EmploymentsPropertyWords.delete,
        _deleteBlocked == null
            ? () => _command(() => sheet.delete(hasHistory: false))
            : null,
        disabledReason: _deleteBlocked,
      ),
    ];
  }

  /// The status line: the edit's problem, else what is new or pending,
  /// else what the sheet found, else why there is nothing yet.
  String notice() {
    final session = sheet.session;
    if (session?.problem case final problem?) return problem;
    if (session case final edit? when edit.isNew) {
      return identical(edit, sheet.agreement)
          ? EmploymentsNotices.newAgreement
          : EmploymentsNotices.newEmployment;
    }
    if (session case final edit? when edit.dirty) {
      return 'Unsaved changes. Save, or leave the record, to keep them.';
    }
    if (sheet.notice case final notice?) return notice;
    if (employments.isEmpty) return EmploymentsNotices.empty;
    if (!employments.any(
      (value) => value.employment.status == EmploymentStatus.active,
    )) {
      return EmploymentsNotices.onlyEnded;
    }
    return EmploymentsNotices.ready;
  }
}

/// A stored agreement in a line: "18.40/h from 2026-09-01".
String agreementSummary(PayAgreement value) {
  final end = value.effectiveEnd;
  return '${formatHourlyRate(value.hourlyRateMicroEur)} from '
      '${eraBoxDate(value.effectiveStart)}'
      '${end == null ? '' : ' to ${eraBoxDate(end)}'}';
}
