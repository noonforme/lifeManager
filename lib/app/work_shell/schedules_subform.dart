import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/domain/pay_premiums.dart';
import '../../features/work/domain/schedule.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../edit_session/record_edit_session.dart' show EditProblems;
import '../work_edit/schedule_fields.dart';
import '../work_edit/schedule_preview.dart';
import 'basis_total.dart';
import 'schedule_properties.dart';
import 'schedules_sheet_controller.dart';

/// The Schedules sheet's subform tab ids.
abstract final class SchedulesSubformTab {
  static const cycle = 'cycle';
  static const preview = 'preview';
  static const history = 'history';
  static const breaks = 'breaks';
  static const usedIn = 'usedIn';
}

/// Words of the Schedules sheet's subforms.
abstract final class SchedulesSubformWords {
  static const removeBlock = 'Remove block';
  static const removeBreak = 'Remove break';
  static const noBlocks =
      'No blocks yet. Add the shift types first (Shift types on the '
      'toolbar), then type one block per run of days in the * row: the '
      'number of days and the shift type, or Off.';
  static const unreadable = 'The plan could not be read';
  static const noAgreement = 'No agreement';
  static const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

/// One block of the cycle as the Cycle grid shows it.
@immutable
final class BlockLine {
  const BlockLine({
    required this.index,
    required this.count,
    required this.type,
    required this.firstDay,
  });

  final int index;
  final int count;

  /// Its shift type; null for Off.
  final ShiftType? type;

  /// Its first cycle day.
  final int firstDay;

  String get id => blockRowId(index);
  String get days =>
      count == 1 ? '$firstDay' : '$firstDay–${firstDay + count - 1}';
}

/// The blocks of [values] as grid lines.
List<BlockLine> blockLinesOf(ScheduleValues values) {
  var at = 1;
  return [
    for (final (index, block) in values.blocks.indexed)
      () {
        final line = BlockLine(
          index: index,
          count: block.count,
          type: values.types
              .where((t) => t.id == block.shiftTypeId)
              .firstOrNull,
          firstDay: at,
        );
        at += block.count;
        return line;
      }(),
  ];
}

/// [child] at least [base] px tall at 100 % text: a shorter subform
/// scrolls instead of squeezing it (as the shell does for its grid).
Widget _atLeast(double base, Widget child) => LayoutBuilder(
  builder: (context, constraints) {
    final least = MediaQuery.textScalerOf(context).scale(base);
    if (constraints.maxHeight >= least) return child;
    return SingleChildScrollView(
      child: SizedBox(height: least, child: child),
    );
  },
);

/// [index]'s tone among a schedule's shift types.
DayTone toneOf(int? index) =>
    index == null ? DayTone.none : DayTone.values[1 + index % 4];

String _time(LocalTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// A shift type's night time on its first planned day, as the grids show
/// it (bead 9pk.4.16): blank while not known or not planned.
String typeNightWords(SchedulePricing? pricing, ShiftTypeId id) =>
    switch (pricing?.types[id]) {
      final pay? => formatDuration(pay.nightPaidSeconds),
      null => '',
    };

/// A shift type's planned pay on its first planned day: "No agreement"
/// where none covers it, blank while not known or not planned.
String typePayWords(SchedulePricing? pricing, ShiftTypeId id) =>
    switch (pricing?.types) {
      final types? when types.containsKey(id) => switch (types[id]) {
        final pay? => formatMoney(pay.amount),
        null => SchedulesSubformWords.noAgreement,
      },
      _ => '',
    };

/// The Cycle grid's columns, choosing among [types]; [priced] adds each
/// block type's night time and planned pay from [pricing].
List<GridColumn<BlockLine>> _blockColumns(
  List<ShiftType> types, {
  bool priced = false,
  SchedulePricing? pricing,
}) => [
  GridColumn<BlockLine>(
    key: 'block',
    label: 'Block',
    kind: ValueKind.number,
    width: 40,
    value: (line) => line.index + 1,
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: ScheduleField.blockDays,
    label: 'Days',
    kind: ValueKind.number,
    width: 48,
    value: (line) => line.count,
    editable: true,
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: ScheduleField.blockType,
    label: 'Shift type',
    kind: ValueKind.choice,
    width: 96,
    value: (line) => line.type?.id,
    choices: [
      const EraComboItem<Object?>(null, 'Off'),
      for (final type in types) EraComboItem<Object?>(type.id, type.name),
    ],
    editable: true,
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: 'cycleDays',
    label: 'Cycle days',
    kind: ValueKind.text,
    width: 72,
    value: (line) => line.days,
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: 'start',
    label: 'Start',
    kind: ValueKind.text,
    width: 48,
    value: (line) => line.type == null ? '' : _time(line.type!.start),
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: 'end',
    label: 'End',
    kind: ValueKind.text,
    width: 72,
    value: (line) => switch (line.type) {
      null => '',
      final type =>
        '${_time(type.end)}${type.endDayOffset == 1 ? ' (+1)' : ''}',
    },
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: 'break',
    label: 'Break',
    kind: ValueKind.text,
    width: 48,
    value: (line) =>
        line.type == null ? '' : formatDuration(line.type!.breakMinutes * 60),
    sortable: false,
  ),
  GridColumn<BlockLine>(
    key: 'paid',
    label: 'Paid',
    kind: ValueKind.text,
    width: 48,
    value: (line) =>
        line.type == null ? '' : formatDuration(line.type!.paidMinutes * 60),
    sortable: false,
  ),
  if (priced) ...[
    GridColumn<BlockLine>(
      key: 'night',
      label: 'Night',
      kind: ValueKind.text,
      width: 48,
      value: (line) =>
          line.type == null ? '' : typeNightWords(pricing, line.type!.id),
      sortable: false,
    ),
    GridColumn<BlockLine>(
      key: 'pay',
      label: 'Planned pay',
      kind: ValueKind.text,
      width: 88,
      value: (line) =>
          line.type == null ? '' : typePayWords(pricing, line.type!.id),
      sortable: false,
    ),
  ],
];

/// The Cycle tab (owner pick 1B, mockup): the rotation as a [DayStrip],
/// then one row per block, dragged by its grip to reorder, typed into the
/// `*` row to add.
final class CycleTab extends StatelessWidget {
  const CycleTab({
    required this.sheet,
    required this.editors,
    required this.today,
    this.pricing,
    super.key,
  });

  final SchedulesSheetController sheet;
  final EditorSessionController editors;
  final LocalDate today;

  /// What each block's type pays as planned; null while not known.
  final SchedulePricing? pricing;

  EditResult _accept(String? problem) => problem == null
      ? const EditResult.accepted()
      : EditResult.rejected(problem);

  @override
  Widget build(BuildContext context) {
    final edit = sheet.session;
    if (edit == null) {
      return _atLeast(
        200,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: DayStrip(label: 'Cycle, 0 days:', marks: []),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: KeyButton(
                    label: SchedulesSubformWords.removeBlock,
                    onPressed: null,
                  ),
                ),
              ],
            ),
            Expanded(
              // Its own state: the schedule's grid has a grip column.
              child: DataGrid<BlockLine>(
                label: 'Cycle',
                columns: _blockColumns(const [], priced: true),
                lines: const [],
                rowId: (line) => line.id,
                rowLabel: (line) => 'Block ${line.index + 1}',
                selectedId: null,
                editorController: editors,
                showNavigator: false,
              ),
            ),
          ],
        ),
      );
    }
    final values = edit.draft;
    final lines = blockLinesOf(values);
    final letters = typeLetters(values.types);
    final now = todayInCycle(values, today);
    final totals = cycleTotals(values);
    final length = cycleLengthOf(values);
    final stored = edit.baseline?.value;
    final storedValues = stored == null ? null : ScheduleValues.of(stored);
    final storedTotals = storedValues == null
        ? null
        : cycleTotals(storedValues);
    final marks = <DayMark>[
      for (final line in lines)
        for (var day = 0; day < line.count; day++)
          () {
            final cycleDay = line.firstDay + day;
            final type = line.type;
            final index = type == null ? null : values.types.indexOf(type);
            return DayMark(
              text: type == null ? '' : letters[type.id] ?? '',
              tone: toneOf(index),
              ring: now?.day == cycleDay,
              semantics:
                  'Cycle day $cycleDay, ${type?.name ?? 'Off'}'
                  '${now?.day == cycleDay ? ', today' : ''}',
            );
          }(),
    ];
    final trailing = sheet.versioning && storedValues != null
        ? 'v${stored!.version}: ${countOf(cycleLengthOf(storedValues), 'day')} · '
              '${storedTotals!.shifts} shifts, '
              '${formatDuration(storedTotals.paidMinutes * 60)} paid per cycle'
        : [
            if (now != null) 'Today is cycle day ${now.day}',
            '${totals.shifts} shifts, '
                '${formatDuration(totals.paidMinutes * 60)} paid per cycle',
          ].join(' · ');
    final blocked = sheet.editBlocked;
    final selected = sheet.selectedBlock;
    final selectedIndex = selected == null
        ? null
        : int.tryParse(selected.substring(6));
    final canRemove =
        blocked == null &&
        !edit.frozen &&
        selectedIndex != null &&
        selectedIndex < lines.length;
    return _atLeast(
      200,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DayStrip(
                  label: 'Cycle, ${countOf(length, 'day')}:',
                  marks: marks,
                  trailing: marks.isEmpty ? null : trailing,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: KeyButton(
                  label: SchedulesSubformWords.removeBlock,
                  tooltip: blocked,
                  onPressed: canRemove
                      ? () {
                          if (!editors.flush().isAccepted) return;
                          if (sheet.removeBlock(selectedIndex) == null) {
                            sheet.selectBlock(null);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 3, 6, 3),
              child: Text(SchedulesSubformWords.noBlocks),
            ),
          Expanded(
            child: DataGrid<BlockLine>(
              label: 'Cycle',
              columns: _blockColumns(
                values.types,
                priced: true,
                pricing: pricing,
              ),
              lines: [
                for (final line in lines)
                  GridRow(
                    line,
                    state: line.type == null
                        ? GridRowState.muted
                        : GridRowState.normal,
                  ),
              ],
              rowId: (line) => line.id,
              rowLabel: (line) => 'Block ${line.index + 1}',
              selectedId: selected,
              onSelect: sheet.selectBlock,
              editorController: editors,
              onEdit: (cell, draft) {
                final index = int.tryParse(cell.rowId.substring(6));
                if (index == null) {
                  return const EditResult.rejected(
                    ScheduleProblems.notEditable,
                  );
                }
                return _accept(sheet.editBlock(index, cell.column, draft));
              },
              readOnlyReason: (line, column) => blocked,
              today: today,
              errors: {
                for (final MapEntry(:key, :value) in edit.issues.entries)
                  if (key.startsWith('block:'))
                    GridCell(
                      key.substring(0, key.indexOf('.')),
                      key.substring(key.indexOf('.') + 1),
                    ): value,
              },
              onNew: blocked == null && !edit.frozen
                  ? () => sheet.addBlock()
                  : null,
              onReorder: (id, to) => sheet.moveBlock(id, to),
              reorderReason:
                  blocked ?? (edit.frozen ? EditProblems.busy : null),
              footerLabel: 'Total',
              footer: {
                ScheduleField.blockDays: '$length',
                'paid': formatDuration(totals.paidMinutes * 60),
              },
              showNavigator: false,
              note: edit.issues[ScheduleField.cycle],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Preview tab (owner pick 2B): the pending schedule over four months,
/// days across, each month's totals.
final class SchedulePreviewTab extends StatelessWidget {
  const SchedulePreviewTab({
    required this.sheet,
    required this.today,
    required this.zoneClocks,
    super.key,
  });

  final SchedulesSheetController sheet;
  final LocalDate today;
  final ZoneClocks zoneClocks;

  @override
  Widget build(BuildContext context) {
    final edit = sheet.session;
    final inputs = sheet.planInputs;
    if (edit == null) return _noPreview();
    if (inputs == null && sheet.planFailed) {
      return const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: SchedulesSubformWords.unreadable,
        message: SchedulesNotices.unreadable,
      );
    }
    if (inputs == null) return _noPreview();
    final first = sheet.previewFirst;
    final months = previewMonths(
      draft: edit.draft,
      baseline: edit.baseline,
      employmentId: sheet.employmentId,
      inputs: inputs,
      firstMonth: first,
      today: today,
      zoneClocks: zoneClocks,
    );
    if (months.isEmpty) return _noPreview();
    final names = SchedulesSubformWords.months;
    String label(PreviewMonth month) => '${names[month.month]} ${month.year}';
    final types = edit.draft.types;
    final skin = LifeOSSkinScope.of(context);
    return _atLeast(
      180,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(3),
            child: Wrap(
              spacing: 6,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StepKey(
                  forward: false,
                  semanticLabel: 'Previous month',
                  onPressed: () => sheet.stepPreview(-1),
                ),
                Text('${label(months.first)} – ${label(months.last)}'),
                StepKey(
                  forward: true,
                  semanticLabel: 'Next month',
                  onPressed: () => sheet.stepPreview(1),
                ),
                for (final (index, type) in types.indexed)
                  DayStrip(
                    label: type.name,
                    marks: [
                      DayMark(
                        text: typeLetters(types)[type.id] ?? '',
                        tone: toneOf(index),
                        semantics: type.name,
                      ),
                    ],
                  ),
                Text(
                  'Bold: confirmed · hatched: another schedule',
                  style: skin.typography.body.copyWith(
                    color: skin.tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MonthStrip(
              label: 'Preview',
              totalHeads: _previewHeads,
              rows: [
                for (final month in months)
                  MonthStripRow(
                    label: label(month),
                    days: [
                      for (final day in month.days)
                        DayMark(
                          text: day.letter,
                          tone: toneOf(day.typeIndex),
                          ring: day.today,
                          strong: day.confirmed && day.letter.isNotEmpty,
                          hatched: day.otherSchedule != null,
                          weekend:
                              DateTime.utc(
                                day.date.year,
                                day.date.month,
                                day.date.day,
                              ).weekday >=
                              DateTime.saturday,
                          semantics: [
                            eraBoxDate(day.date),
                            if (day.otherSchedule case final other?)
                              other
                            else if (day.typeIndex case final index?)
                              types[index].name
                            else
                              'Off',
                            if (day.today) 'today',
                            if (day.confirmed) 'confirmed',
                          ].join(', '),
                        ),
                    ],
                    totals: [
                      '${month.shifts}',
                      formatDuration(month.paidSeconds),
                      switch (month.pay) {
                        final cents? => BasisTotal.cents(cents).cell,
                        null => SchedulesSubformWords.noAgreement,
                      },
                    ],
                    note: month.otherSchedule,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Preview with no months: its heads over no rows.
Widget _noPreview() => _atLeast(
  180,
  const MonthStrip(label: 'Preview', totalHeads: _previewHeads, rows: []),
);

const _previewHeads = ['Shifts', 'Paid', 'Planned pay'];

/// One break of a shift type as the Breaks grid shows it.
@immutable
final class TypeBreakLine {
  const TypeBreakLine(this.index, this.value);

  final int index;
  final FixedBreak value;

  String get id => 'break:$index';
  LocalTime get start => value.start;
  LocalTime get end {
    final minute = value.endMinute % 1440;
    return LocalTime(minute ~/ 60, minute % 60);
  }
}

/// The Breaks grid's columns.
final _breakColumns = <GridColumn<TypeBreakLine>>[
  GridColumn<TypeBreakLine>(
    key: ScheduleField.breakStart,
    label: 'Start',
    kind: ValueKind.time,
    width: 56,
    value: (line) => line.start,
    editable: true,
  ),
  GridColumn<TypeBreakLine>(
    key: ScheduleField.breakEnd,
    label: 'End',
    kind: ValueKind.time,
    width: 56,
    value: (line) => line.end,
    editable: true,
  ),
  GridColumn<TypeBreakLine>(
    key: 'length',
    label: 'Length',
    kind: ValueKind.duration,
    width: 56,
    value: (line) => line.value.minutes,
    display: (minutes) => formatDuration((minutes as int) * 60),
    description: 'Derived: unpaid time from start to end.',
  ),
];

/// The selected shift type's breaks (owner pick 1B): the same Breaks grid
/// as on Shifts, with Remove break and a `*` row to add one.
final class TypeBreaksTab extends StatelessWidget {
  const TypeBreaksTab({
    required this.sheet,
    required this.editors,
    required this.today,
    super.key,
  });

  final SchedulesSheetController sheet;
  final EditorSessionController editors;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final edit = sheet.session;
    final id = sheet.selectedType;
    final type = edit == null || id == null
        ? null
        : edit.draft.types.where((t) => t.id == id).firstOrNull;
    if (edit == null || type == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(2),
            child: KeyButton(
              label: SchedulesSubformWords.removeBreak,
              onPressed: null,
            ),
          ),
          Expanded(
            child: DataGrid<TypeBreakLine>(
              label: 'Breaks',
              columns: _breakColumns,
              lines: const [],
              rowId: (line) => line.id,
              rowLabel: (line) => 'Break ${line.index + 1}',
              selectedId: null,
              editorController: editors,
              showNavigator: false,
            ),
          ),
        ],
      );
    }
    final lines = [
      for (final (index, value) in type.breaks.indexed)
        TypeBreakLine(index, value),
    ];
    final blocked = sheet.editBlocked;
    final selected = sheet.selectedBreak;
    final selectedIndex = selected == null
        ? null
        : int.tryParse(selected.substring(6));
    final problem = edit.issues[typeKey(type.id, 'breaks')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: KeyButton(
            label: SchedulesSubformWords.removeBreak,
            tooltip: blocked,
            onPressed:
                blocked == null &&
                    !edit.frozen &&
                    selectedIndex != null &&
                    selectedIndex < lines.length
                ? () {
                    if (!editors.flush().isAccepted) return;
                    if (sheet.removeBreak(type.id, selectedIndex) == null) {
                      sheet.selectBreak(null);
                    }
                  }
                : null,
          ),
        ),
        Expanded(
          child: DataGrid<TypeBreakLine>(
            label: 'Breaks',
            columns: _breakColumns,
            lines: [for (final line in lines) GridRow(line)],
            rowId: (line) => line.id,
            rowLabel: (line) => 'Break ${line.index + 1}',
            selectedId: selected,
            onSelect: sheet.selectBreak,
            editorController: editors,
            onEdit: (cell, draft) {
              final index = int.tryParse(cell.rowId.substring(6));
              final problem = index == null
                  ? ScheduleProblems.notEditable
                  : sheet.editBreak(type.id, index, cell.column, draft);
              return problem == null
                  ? const EditResult.accepted()
                  : EditResult.rejected(problem);
            },
            readOnlyReason: (line, column) => blocked,
            today: today,
            errors: {
              if (problem != null && lines.isNotEmpty)
                GridCell(lines.first.id, ScheduleField.breakStart): problem,
            },
            onNew: blocked == null && !edit.frozen
                ? () => sheet.addBreak(type.id)
                : null,
            footerLabel: 'Total',
            footer: {'length': formatDuration(type.breakMinutes * 60)},
            showNavigator: false,
          ),
        ),
      ],
    );
  }
}

/// The Used in cycle grid's columns: a block's number, days and cycle days.
final _usedColumns = <GridColumn<BlockLine>>[
  for (final column in _blockColumns(const []))
    if (const {
      'block',
      ScheduleField.blockDays,
      'cycleDays',
    }.contains(column.key))
      GridColumn<BlockLine>(
        key: column.key,
        label: column.label,
        kind: column.kind,
        width: column.width,
        value: column.value,
        sortable: false,
      ),
];

/// The blocks of the cycle that use the selected shift type.
final class UsedInCycleTab extends StatelessWidget {
  const UsedInCycleTab({required this.sheet, required this.editors, super.key});

  final SchedulesSheetController sheet;
  final EditorSessionController editors;

  @override
  Widget build(BuildContext context) {
    final edit = sheet.session;
    final id = sheet.selectedType;
    final lines = [
      if (edit != null && id != null)
        for (final line in blockLinesOf(edit.draft))
          if (line.type?.id == id) line,
    ];
    return DataGrid<BlockLine>(
      label: 'Used in cycle',
      columns: _usedColumns,
      lines: [for (final line in lines) GridRow(line)],
      rowId: (line) => line.id,
      rowLabel: (line) => 'Block ${line.index + 1}',
      selectedId: null,
      editorController: editors,
      showNavigator: false,
    );
  }
}
