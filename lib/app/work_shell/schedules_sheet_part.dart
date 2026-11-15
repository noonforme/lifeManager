import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/data/work_history.dart'
    show WorkRecordKinds, scheduleRecordId;
import '../../features/work/domain/schedule.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../edit_session/record_edit_session.dart';
import '../production_work_providers.dart';
import '../work_edit/schedule_edit.dart';
import '../work_edit/schedule_fields.dart';
import '../work_edit/schedule_preview.dart';
import '../work_edit/work_records.dart';
import 'employments_sheet_controller.dart' show EmploymentsWords;
import 'schedule_properties.dart';
import 'schedules_sheet_controller.dart';
import 'schedules_subform.dart';
import 'shifts_subform.dart' show HistoryGrid, RecordHistoryTab;
import 'work_shell.dart' show runCommand;

export 'schedules_subform.dart' show SchedulesSubformTab;

/// Words of the Schedules sheet's keys, panel and empty states.
abstract final class SchedulesPartWords {
  static const newSchedule = 'New schedule…';
  static const newKey = 'New schedule';
  static const shiftTypes = 'Shift types';
  static const change = 'Change schedule from…';
  static const delete = 'Delete schedule…';
  static const backToSchedules = 'Back to schedules';
  static const unreadableTitle = 'Schedules could not be read';
  static const pending =
      'Unsaved changes. Save, or leave the schedule, to keep them.';
  static const changeTitle = 'Change schedule';
  static const changePrimary = 'Change schedule';
  static const changeHint =
      'Change schedule: pick the day, edit the new cycle, then press Change '
      'schedule. Nothing changes before that.';
  static const typesTail = '· edits stay in the schedule until you save it';
  static String typesHint(String name) =>
      'Shift types of $name. Back to schedules returns to the cycle; nothing '
      'is saved until Save.';
  static String changeExplain(WorkSchedule v, int days, LocalDate? last) =>
      '${v.name} v${v.version} planned ${countOf(days, 'confirmed day')}'
      '${last == null ? '' : ', the last on ${eraBoxDate(last)}'}. Its cycle '
      'stays as it is.';
  static const changeHow =
      "Edit the new version's cycle and shift types below the grid. They "
      'start on the day you pick here.';
}

/// One row of the Schedules grid: a stored version, the pending next
/// version, or a new schedule.
@immutable
final class ScheduleLine {
  const ScheduleLine({
    required this.id,
    required this.name,
    required this.version,
    required this.from,
    required this.until,
    required this.cycle,
    required this.types,
    required this.confirmed,
    required this.state,
    required this.ended,
  });

  final String id;
  final String name;
  final String version;
  final LocalDate from;
  final LocalDate? until;
  final String cycle;
  final String types;
  final String confirmed;
  final String state;
  final bool ended;
}

/// One shift type of the types view.
@immutable
final class TypeLine {
  const TypeLine(this.type, this.use);

  final ShiftType type;
  final String use;

  String get id => type.id.value;
}

/// The Schedules sheet's part of the Work shell's window (spec 3, 4.2,
/// 4.4; owner picks 1B, 2B, 3B): the grid of versions or of the selected
/// schedule's shift types, the property column of the selected version, its
/// type or the Change schedule panel, the subforms, the toolbar bands, the
/// Record and Add menus and the status line, over a
/// [SchedulesSheetController]. The shell puts them in AppFrame's slots.
final class SchedulesSheetPart {
  SchedulesSheetPart({
    required this.sheet,
    required this.editors,
    required this.work,
    required this.today,
    required this.employmentName,
    required this.onEmployment,
  });

  final SchedulesSheetController sheet;
  final EditorSessionController editors;
  final ProductionWorkProviders work;
  final LocalDate today;
  final String employmentName;
  final VoidCallback onEmployment;

  void _command(Future<Object?> Function() command) =>
      runCommand(editors, command);

  EditResult _accept(String? problem) => problem == null
      ? const EditResult.accepted()
      : EditResult.rejected(problem);

  /// The versions as grid rows, the selected one with its pending values.
  List<ScheduleLine> get lines {
    final edit = sheet.session;
    final pendingId = sheet.pendingVersionId;
    ScheduleLine line(ScheduleRow row) {
      final value = row.schedule;
      final rowId = row.rowId;
      final mine = edit != null && !edit.isNew && rowId == sheet.selectedId;
      final draft = mine && !sheet.versioning ? edit.draft : null;
      final pending = rowId == pendingId;
      final from = draft?.inUseFrom ?? value.inUseFrom;
      final until = draft == null ? value.inUseUntil : draft.inUseUntil;
      final values = draft ?? ScheduleValues.of(value);
      final state = pending ? 'New' : scheduleState(from, until, today);
      return ScheduleLine(
        id: rowId,
        name: values.name,
        version: pending ? 'New' : 'v${value.version}',
        from: from,
        until: until,
        cycle: countOf(cycleLengthOf(values), 'day'),
        types: [for (final type in values.types) type.name].join(', '),
        confirmed: pending ? '' : countOf(row.confirmedDays, 'day'),
        state: state,
        ended: state == 'Ended',
      );
    }

    return [
      for (final row in sheet.displayRows) line(row),
      if (edit != null && edit.isNew)
        ScheduleLine(
          id: newScheduleId,
          name: edit.draft.name,
          version: 'New',
          from: edit.draft.inUseFrom,
          until: edit.draft.inUseUntil,
          cycle: countOf(cycleLengthOf(edit.draft), 'day'),
          types: [for (final type in edit.draft.types) type.name].join(', '),
          confirmed: '',
          state: 'New',
          ended: false,
        ),
    ];
  }

  static final List<GridColumn<ScheduleLine>> _columns = [
    GridColumn<ScheduleLine>(
      key: ScheduleField.name,
      label: 'Name',
      kind: ValueKind.text,
      width: 128,
      value: (line) => line.name,
      editable: true,
    ),
    GridColumn<ScheduleLine>(
      key: 'version',
      label: 'Version',
      kind: ValueKind.text,
      width: 56,
      value: (line) => line.version,
    ),
    GridColumn<ScheduleLine>(
      key: ScheduleField.inUseFrom,
      label: 'In use from',
      kind: ValueKind.date,
      width: 104,
      value: (line) => line.from,
      editable: true,
    ),
    GridColumn<ScheduleLine>(
      key: ScheduleField.inUseUntil,
      label: 'Until',
      kind: ValueKind.date,
      width: 104,
      value: (line) => line.until,
      editable: true,
      optional: true,
    ),
    GridColumn<ScheduleLine>(
      key: 'cycle',
      label: 'Cycle',
      kind: ValueKind.text,
      width: 60,
      value: (line) => line.cycle,
    ),
    GridColumn<ScheduleLine>(
      key: 'types',
      label: 'Shift types',
      kind: ValueKind.text,
      width: 100,
      value: (line) => line.types,
    ),
    GridColumn<ScheduleLine>(
      key: 'confirmed',
      label: 'Confirmed',
      kind: ValueKind.text,
      width: 72,
      value: (line) => line.confirmed,
      description: 'Days confirmed from this version.',
    ),
    GridColumn<ScheduleLine>(
      key: 'state',
      label: 'State',
      kind: ValueKind.text,
      width: 64,
      value: (line) => line.state,
    ),
  ];

  /// The selected row the grid edits: the pending next version while
  /// versioning, else the selected one.
  String? get _editedId => sheet.pendingVersionId ?? sheet.selectedId;

  /// A grid cell's edit: on the pending next version In use from is its
  /// start (`versionFrom`).
  String? _editCell(String rowId, String column, Object? draft) {
    if (rowId != _editedId) return ScheduleProblems.notEditable;
    final field = sheet.versioning && column == ScheduleField.inUseFrom
        ? ScheduleField.versionFrom
        : column;
    return sheet.editField(field, draft);
  }

  /// The middle column's band in the types view, else none.
  Widget? middleHeader() {
    if (!sheet.showingTypes) return null;
    final saved = sheet.session?.baseline?.value;
    final name = saved == null
        ? 'the new schedule'
        : '${saved.name} v${saved.version}';
    return FilterStrip(
      items: [
        FilterStripItem(
          label: null,
          child: Text('${SchedulesPartWords.shiftTypes} of $name'),
        ),
        const FilterStripItem(
          label: null,
          child: Text(SchedulesPartWords.typesTail),
        ),
      ],
      onClear: () {
        if (editors.flush().isAccepted) sheet.showTypes(false);
      },
      clearLabel: SchedulesPartWords.backToSchedules,
    );
  }

  /// The grid of versions or the selected schedule's shift types; a
  /// warning when the schedules could not be read.
  Widget middle() => sheet.showingTypes ? _typesGrid() : _schedulesGrid();

  Widget _schedulesGrid() {
    final lines = this.lines;
    if (lines.isEmpty && sheet.failed) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: SchedulesPartWords.unreadableTitle,
        message: SchedulesNotices.unreadable,
      );
    }
    final edit = sheet.session;
    final edited = _editedId;
    final blocked = sheet.editBlocked;
    return DataGrid<ScheduleLine>(
      label: 'Schedules',
      columns: _columns,
      lines: [
        for (final line in lines)
          GridRow(
            line,
            state: line.ended ? GridRowState.muted : GridRowState.normal,
          ),
      ],
      rowId: (line) => line.id,
      rowLabel: (line) => '${line.name} ${line.version}',
      selectedId: edited,
      onSelect: (id) {
        if (id == newScheduleId || id == sheet.pendingVersionId) return;
        _command(() => sheet.select(id));
      },
      editorController: editors,
      onEdit: (cell, draft) =>
          _accept(_editCell(cell.rowId, cell.column, draft)),
      readOnlyReason: (line, column) {
        if (!column.editable) return null;
        if (line.id != edited || edit == null) {
          return 'Select the schedule to change it.';
        }
        if (sheet.versioning) {
          return column.key == ScheduleField.inUseUntil
              ? 'The new version runs on; its end is set later.'
              : null;
        }
        return blocked;
      },
      today: today,
      pendingIds: {if (edited != null && edit != null && edit.dirty) edited},
      errors: {
        if (edited != null && edit != null)
          for (final MapEntry(:key, :value) in edit.issues.entries)
            if (key == ScheduleField.versionFrom)
              GridCell(edited, ScheduleField.inUseFrom): value
            else if (const {
              ScheduleField.name,
              ScheduleField.inUseFrom,
              ScheduleField.inUseUntil,
            }.contains(key))
              GridCell(edited, key): value,
      },
      onNew: sheet.archived ? null : () => _command(sheet.addSchedule),
    );
  }

  /// The open schedule's prices as planned (bead 9pk.4.16), once the
  /// employment's plan inputs are read.
  SchedulePricing? get _pricing {
    final edit = sheet.session;
    final inputs = sheet.planInputs;
    if (edit == null || inputs == null) return null;
    return schedulePricing(
      draft: edit.draft,
      baseline: edit.baseline,
      employmentId: sheet.employmentId,
      inputs: inputs,
      today: today,
      zoneClocks: work.plans.zoneClocks,
    );
  }

  Widget _typesGrid() {
    final edit = sheet.session!;
    final pricing = _pricing;
    final values = edit.draft;
    final blocked = sheet.editBlocked;
    final selected = sheet.selectedType;
    return DataGrid<TypeLine>(
      label: SchedulesPartWords.shiftTypes,
      columns: [
        GridColumn<TypeLine>(
          key: ScheduleField.typeName,
          label: 'Name',
          kind: ValueKind.text,
          width: 96,
          value: (line) => line.type.name,
          editable: true,
        ),
        GridColumn<TypeLine>(
          key: ScheduleField.typeStart,
          label: 'Start',
          kind: ValueKind.time,
          width: 64,
          value: (line) => line.type.start,
          editable: true,
        ),
        GridColumn<TypeLine>(
          key: ScheduleField.typeEnd,
          label: 'End',
          kind: ValueKind.time,
          width: 64,
          value: (line) => line.type.end,
          editable: true,
        ),
        GridColumn<TypeLine>(
          key: 'ends',
          label: 'Ends',
          kind: ValueKind.text,
          width: 72,
          value: (line) =>
              line.type.endDayOffset == 0 ? 'Same day' : 'Next day',
          description: SchedulePropertyWords.ends,
        ),
        GridColumn<TypeLine>(
          key: 'break',
          label: 'Break',
          kind: ValueKind.text,
          width: 56,
          value: (line) => formatDuration(line.type.breakMinutes * 60),
        ),
        GridColumn<TypeLine>(
          key: 'paid',
          label: 'Paid',
          kind: ValueKind.text,
          width: 56,
          value: (line) => formatDuration(line.type.paidMinutes * 60),
        ),
        GridColumn<TypeLine>(
          key: 'night',
          label: 'Night',
          kind: ValueKind.text,
          width: 48,
          value: (line) => typeNightWords(pricing, line.type.id),
        ),
        GridColumn<TypeLine>(
          key: 'pay',
          label: 'Planned pay',
          kind: ValueKind.text,
          width: 88,
          value: (line) => typePayWords(pricing, line.type.id),
        ),
        GridColumn<TypeLine>(
          key: 'use',
          label: 'In the cycle',
          kind: ValueKind.text,
          width: 180,
          value: (line) => line.use,
        ),
      ],
      lines: [
        for (final type in values.types)
          GridRow(TypeLine(type, typeUseOf(values, type.id))),
      ],
      rowId: (line) => line.id,
      rowLabel: (line) => 'Shift type ${line.type.name}',
      selectedId: selected?.value,
      onSelect: (id) => sheet.selectType(
        values.types.where((type) => type.id.value == id).firstOrNull?.id,
      ),
      editorController: editors,
      onEdit: (cell, draft) {
        final type = values.types
            .where((type) => type.id.value == cell.rowId)
            .firstOrNull;
        if (type == null) {
          return const EditResult.rejected(ScheduleProblems.notEditable);
        }
        return _accept(sheet.editType(type.id, cell.column, draft));
      },
      readOnlyReason: (line, column) => column.editable ? blocked : null,
      today: today,
      errors: {
        for (final type in values.types)
          for (final field in const [
            ScheduleField.typeName,
            ScheduleField.typeStart,
            ScheduleField.typeEnd,
          ])
            GridCell(type.id.value, field):
                ?edit.issues[typeKey(type.id, field)],
        for (final type in values.types)
          GridCell(type.id.value, 'break'):
              ?edit.issues[typeKey(type.id, 'breaks')],
      },
      onNew: blocked == null && !edit.frozen
          ? () => _command(() async => sheet.addType())
          : null,
    );
  }

  /// The property column: the Change schedule panel, the selected type,
  /// else the selected version, else nothing.
  Widget properties() {
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
    if (sheet.versioning) return _changePanel(edit);
    final readOnly = sheet.editBlocked;
    if (sheet.showingTypes) {
      final type = edit.draft.types
          .where((type) => type.id == sheet.selectedType)
          .firstOrNull;
      if (type == null) {
        return PropertyGrid(
          record: 'type:none',
          controller: editors,
          items: const [],
          onCommit: (_, _) => const EditResult.accepted(),
          today: today,
        );
      }
      return PropertyGrid(
        record: 'type:${type.id.value}',
        controller: editors,
        today: today,
        edited: edit.dirty,
        onCommit: (id, value) =>
            _accept(sheet.editType(type.id, id.field, value)),
        items: shiftTypePropertyItems(
          edit: edit,
          type: type,
          readOnly: readOnly,
        ),
      );
    }
    final saved = edit.baseline?.value;
    return PropertyGrid(
      record: saved == null
          ? 'schedule:new'
          : 'schedule:${scheduleRecordId(saved)}',
      controller: editors,
      today: today,
      edited: edit.dirty,
      onCommit: (id, value) => _accept(sheet.editField(id.field, value)),
      items: schedulePropertyItems(
        edit: edit,
        row: sheet.selectedRow,
        readOnly: readOnly,
        today: today,
        pricing: _pricing,
        onEmployment: () => _command(() async => onEmployment()),
      ),
    );
  }

  Widget _changePanel(ScheduleSession edit) {
    final value = edit.baseline!.value;
    final row = sheet.selectedRow;
    final from = edit.draft.versionFrom;
    final uncertain = edit.phase == EditPhase.uncertain;
    return ActionPanel(
      title: SchedulesPartWords.changeTitle,
      record: 'change:${scheduleRecordId(value)}',
      controller: editors,
      today: today,
      cancelDraft: false,
      groups: () => [
        ActionGroup(
          legend: 'Schedule',
          children: [
            Text(
              SchedulesPartWords.changeExplain(
                value,
                row?.confirmedDays ?? 0,
                row?.lastConfirmed,
              ),
            ),
            const Text(SchedulesPartWords.changeHow),
          ],
        ),
        ActionGroup(
          legend: 'New version',
          fields: [
            ActionField(
              id: ScheduleField.versionFrom,
              label: 'From',
              kind: ValueKind.date,
              value: from,
              enabled: !edit.frozen,
              error: edit.issues[ScheduleField.versionFrom],
              // The rules a save checks, so a refused day stays in its
              // editor with its words instead of being dropped.
              validate: sheet.versionFromProblem,
              fieldKey: const ValueKey('schedule-change-from'),
            ),
          ],
          children: [
            if (from != null)
              Text(
                'v${value.version} ends ${eraBoxDate(from.addDays(-1))}. '
                'Planned days from ${eraBoxDate(from)} on follow the new '
                'version; day changes stay on their dates.',
              ),
          ],
        ),
      ],
      onChanged: (field, draft) => sheet.editField(field, draft),
      primaryLabel: uncertain
          ? 'Reload and check'
          : SchedulesPartWords.changePrimary,
      onPrimary: edit.busy
          ? null
          : () => unawaited(uncertain ? sheet.reload() : sheet.save()),
      onCancel: () => _command(sheet.cancelChange),
      results: [
        if (uncertain)
          ActionResult.uncertain(
            SchedulesPartWords.changeTitle,
            detail: EditProblems.uncertain,
          ),
      ],
      error: uncertain
          ? null
          : edit.problem ?? (edit.dirty ? null : sheet.changeProblem),
      busy: edit.busy,
    );
  }

  /// The subform tabs: Cycle, Preview and History of the selected version,
  /// or in the types view Breaks and Used in cycle of the selected type.
  List<SubformTab> subformTabs() {
    if (sheet.showingTypes) {
      final type = sheet.session?.draft.types
          .where((type) => type.id == sheet.selectedType)
          .firstOrNull;
      return [
        SubformTab(
          id: SchedulesSubformTab.breaks,
          label: 'Breaks',
          count: type?.breaks.length,
          countLabel: 'rows',
          builder: (context) =>
              TypeBreaksTab(sheet: sheet, editors: editors, today: today),
        ),
        SubformTab(
          id: SchedulesSubformTab.usedIn,
          label: 'Used in cycle',
          builder: (context) => UsedInCycleTab(sheet: sheet, editors: editors),
        ),
      ];
    }
    final blocks = sheet.session?.draft.blocks.length;
    return [
      SubformTab(
        id: SchedulesSubformTab.cycle,
        label: 'Cycle',
        count: blocks,
        countLabel: 'blocks',
        builder: (context) => CycleTab(
          sheet: sheet,
          editors: editors,
          today: today,
          pricing: _pricing,
        ),
      ),
      SubformTab(
        id: SchedulesSubformTab.preview,
        label: 'Preview',
        builder: (context) => SchedulePreviewTab(
          sheet: sheet,
          today: today,
          zoneClocks: work.plans.zoneClocks,
        ),
      ),
      if (!sheet.versioning)
        SubformTab(
          id: SchedulesSubformTab.history,
          label: 'History',
          builder: (context) => switch ((sheet.selectedRow, sheet.session)) {
            (final row?, _) => RecordHistoryTab(
              history: work.history,
              recordKind: WorkRecordKinds.schedule,
              recordId: row.rowId,
              editors: editors,
            ),
            _ => HistoryGrid(events: const [], editors: editors),
          },
        ),
    ];
  }

  /// What the subform's caption says it shows.
  Widget? subformTrailing() {
    final edit = sheet.session;
    if (edit == null) return null;
    if (sheet.showingTypes) {
      final type = edit.draft.types
          .where((type) => type.id == sheet.selectedType)
          .firstOrNull;
      return type == null ? null : Text('for Shift type ${type.name}');
    }
    final saved = edit.baseline?.value;
    if (saved == null) return const Text('for New schedule');
    if (sheet.versioning) {
      final from = edit.draft.versionFrom;
      return Text(
        from == null
            ? 'for the new version'
            : 'for the new version from ${eraBoxDate(from)}',
      );
    }
    return Text('for Schedule ${saved.name} v${saved.version}');
  }

  /// The Schedules sheet's toolbar bands.
  List<ToolbarBand> bands() {
    final session = sheet.session;
    final locked = sheet.archived ? EmploymentsWords.archivedReadOnly : null;
    final idle = session != null && !session.frozen && locked == null;
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
      tooltip: locked ?? blocked,
      onPressed: locked == null && blocked == null ? () => _command(run) : null,
    );
    return [
      ToolbarBand(
        items: [
          command(
            SchedulesPartWords.newKey,
            null,
            sheet.addSchedule,
            icon: EraIconKind.schedule,
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
          if (sheet.showingTypes)
            command(
              'Delete',
              _removeTypeBlocked,
              () async => sheet.removeType(sheet.selectedType!),
            )
          else
            command('Delete', sheet.deleteBlocked, sheet.delete),
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
            label: SchedulesPartWords.shiftTypes,
            pressed: sheet.showingTypes,
            icon: EraIconKind.shift,
            tooltip: session == null ? SchedulesCommandWords.selectFirst : null,
            onPressed: session == null ? null : toggleTypes,
          ),
          command(
            SchedulesPartWords.change,
            sheet.changeBlocked,
            sheet.changeFrom,
            icon: EraIconKind.correct,
          ),
        ],
      ),
    ];
  }

  /// Why Delete does not remove the selected shift type; null when it does.
  String? get _removeTypeBlocked {
    if (sheet.editBlocked case final reason?) return reason;
    final id = sheet.selectedType;
    if (id == null) return 'Select a shift type first.';
    final uses = sheet.session!.draft.blocks.any(
      (block) => block.shiftTypeId == id,
    );
    return uses ? ScheduleProblems.typeInCycle : null;
  }

  /// Shift types on the toolbar and the Record menu: shows the selected
  /// schedule's types, or its versions again.
  void toggleTypes() {
    if (!editors.flush().isAccepted) return;
    sheet.showTypes(!sheet.showingTypes);
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
    final locked = sheet.archived ? EmploymentsWords.archivedReadOnly : null;
    EraMenuItem command(
      String label,
      String? blocked,
      Future<Object?> Function() run,
    ) => EraMenuItem(
      label,
      locked == null && blocked == null ? () => _command(run) : null,
      disabledReason: locked ?? blocked,
    );
    return [
      command(SchedulesPartWords.newSchedule, null, sheet.addSchedule),
      const EraMenuItem.separator(),
      EraMenuItem(
        'Save',
        session == null || session.frozen || locked != null
            ? null
            : () => _command(sheet.save),
        disabledReason:
            locked ?? (session == null ? 'No record is open.' : null),
      ),
      const EraMenuItem.separator(),
      EraMenuItem(
        SchedulesPartWords.shiftTypes,
        session == null ? null : toggleTypes,
        checked: sheet.showingTypes,
        disabledReason: session == null
            ? SchedulesCommandWords.selectFirst
            : null,
      ),
      command(SchedulesPartWords.change, sheet.changeBlocked, sheet.changeFrom),
      command(SchedulesPartWords.delete, sheet.deleteBlocked, sheet.delete),
    ];
  }

  /// The Add menu's entries for this sheet (spec 3).
  List<EraMenuItem> addItems() => [
    if (!sheet.archived)
      EraMenuItem(
        'Schedule',
        () => _command(sheet.addSchedule),
        icon: EraIconKind.schedule,
      ),
  ];

  /// The status line: the edit's problem, else what is new, changing,
  /// shown or pending, else what the sheet found, else why there is
  /// nothing yet.
  String notice() {
    final session = sheet.session;
    if (session?.problem case final problem?) {
      // A shift type's problem is out of sight in the schedules view: name
      // the type and say what is wrong.
      final types = session!.draft.types;
      for (final MapEntry(:key, :value) in session.issues.entries) {
        final type = types
            .where((type) => key.startsWith('type:${type.id.value}.'))
            .firstOrNull;
        if (type != null) return '$problem ${type.name}: $value';
      }
      return problem;
    }
    if (session case final edit? when edit.isNew) {
      return SchedulesNotices.newSchedule;
    }
    if (sheet.versioning) return SchedulesPartWords.changeHint;
    if (sheet.showingTypes) {
      final saved = session?.baseline?.value;
      return SchedulesPartWords.typesHint(
        saved == null ? 'the new schedule' : '${saved.name} v${saved.version}',
      );
    }
    if (session case final edit? when edit.dirty) {
      return SchedulesPartWords.pending;
    }
    if (sheet.notice case final notice?) return notice;
    if (sheet.failed) return SchedulesNotices.unreadable;
    if (!sheet.loaded) return SchedulesNotices.loading;
    if (sheet.rows.isEmpty) return SchedulesNotices.empty;
    return SchedulesNotices.ready;
  }

  /// The status bar's count: schedules, or the shift types shown.
  String statusPanel() {
    if (sheet.showingTypes) {
      return countOf(sheet.session?.draft.types.length ?? 0, 'shift type');
    }
    final ids = {for (final row in sheet.rows) row.schedule.id};
    final count = ids.length + ((sheet.session?.isNew ?? false) ? 1 : 0);
    return countOf(count, 'schedule');
  }
}
