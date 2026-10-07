import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/workbench/era_combo.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/property_sheet.dart';
import '../application/schedule_service.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay_premiums.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import 'employment_agreement_forms.dart' show staleMessage;
import 'record_history_panel.dart';
import 'shift_types_dialog.dart';
import 'work_calendar.dart';
import 'work_formats.dart';
import 'work_plan_view.dart';
import 'work_route_state.dart';

typedef SaveSchedule = Future<MutationOutcome<WorkSchedule>> Function(
  ScheduleDraft draft, {
  LocalDate? newVersionFrom,
});

const _scheduleTabFields = {
  'name',
  'timezoneId',
  'inUseFrom',
  'inUseUntil',
  'newVersionFrom',
  'schedule',
};

/// The words for each field a refused save names (schedules spec 7).
Map<String, String> scheduleErrors(Map<String, List<FieldIssue>> fields) => {
  for (final MapEntry(key: field, value: issues) in fields.entries)
    field: switch (field) {
      'name' => 'Enter a name of up to 60 characters.',
      'timezoneId' => 'Enter a timezone, for example Europe/Vilnius.',
      'inUseUntil' => 'In use until must be on or after In use from.',
      'inUseFrom' =>
        'Another schedule of this employment is in use on these dates.',
      'blocks' => 'The cycle needs 1 to 366 days.',
      'newVersionFrom'
          when issues.any((issue) => issue.code == FieldIssueCode.conflict) =>
        'Days up to that date are already confirmed. Choose a later date.',
      'newVersionFrom' => 'Choose a date after this version starts.',
      _ when field.endsWith('.count') => 'Enter 1 to 99.',
      _ when field.endsWith('.shiftTypeId') => 'Choose a shift type.',
      _ when field.startsWith('shiftTypes') =>
        'Check the shift types: names must differ and breaks lie inside '
            'their shift.',
      _ => 'Check the schedule.',
    },
};

/// The tab that shows the first problem: Schedule, else Cycle.
int scheduleErrorTab(Iterable<String> fields) =>
    fields.any(_scheduleTabFields.contains) ? 0 : 1;

/// "Use the new cycle from:" for a version confirmed days use (spec 6.4).
Future<LocalDate?> askNewVersionFrom(
  BuildContext context, {
  required LocalDate today,
}) => showDialog<LocalDate>(
  context: context,
  builder: (_) => _NewVersionDialog(today: today),
);

final class _NewVersionDialog extends StatefulWidget {
  const _NewVersionDialog({required this.today});

  final LocalDate today;

  @override
  State<_NewVersionDialog> createState() => _NewVersionDialogState();
}

final class _NewVersionDialogState extends State<_NewVersionDialog> {
  late LocalDate? _from = widget.today.addDays(1);

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Schedule in use',
    body: EraFormScope(
      labelWidth: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirmed days keep the cycle they were planned from.'),
          const SizedBox(height: 7),
          EraDateField(
            fieldKey: const ValueKey('new-version-from'),
            label: 'Use the new cycle from',
            value: _from,
            today: widget.today,
            onChanged: (value) => setState(() => _from = value),
          ),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: _from == null
            ? null
            : () => Navigator.of(context).pop(_from),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

final class _Block {
  _Block(int count, this.type, VoidCallback onEdit)
    : count = TextEditingController(text: '$count') {
    this.count.addListener(onEdit);
  }

  final key = UniqueKey();
  final TextEditingController count;
  ShiftTypeId? type;
}

/// Six grip dots, the era's drag handle.
final class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) {
    final ink = LifeOSSkinScope.of(context).tokens.muted;
    return SizedBox(
      width: 10,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var row = 0; row < 3; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var column = 0; column < 2; column++)
                  Container(width: 2, height: 2, color: ink),
              ],
            ),
        ],
      ),
    );
  }
}

/// A schedule's Schedule, Cycle and Preview pages, and its History.
final class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({
    required this.employmentId,
    required this.employmentName,
    required this.today,
    required this.defaultTimezoneId,
    required this.agreements,
    required this.zoneClocks,
    required this.timezones,
    required this.onSave,
    this.initial,
    this.onDelete,
    this.historyRecord,
    super.key,
  });

  final EmploymentId employmentId;
  final String employmentName;
  final LocalDate today;

  /// The system's zone, or '' when unknown: a schedule is never placed in a
  /// guessed zone.
  final String defaultTimezoneId;
  final List<PayAgreement> agreements;
  final ZoneClocks zoneClocks;
  final TimezoneService timezones;
  final SaveSchedule onSave;

  /// The latest version; null creates a schedule.
  final WorkSchedule? initial;

  /// Null while a confirmed day uses the schedule.
  final Future<MutationOutcome<WorkSchedule>> Function()? onDelete;
  final WorkRecordRef? historyRecord;

  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

final class _ScheduleEditorState extends State<ScheduleEditor> {
  late final _name = TextEditingController(text: widget.initial?.name)
    ..addListener(_edited);
  late final _timezone = TextEditingController(
    text: widget.initial?.timezoneId ?? widget.defaultTimezoneId,
  )..addListener(_edited);
  late final _employment = TextEditingController(text: widget.employmentName);
  late LocalDate _cycleStart = widget.initial?.cycleStart ?? widget.today;
  late LocalDate _from = widget.initial?.inUseFrom ?? widget.today;
  late LocalDate? _until = widget.initial?.inUseUntil;
  late List<ShiftType> _types = [...?widget.initial?.shiftTypes];
  late final List<_Block> _blocks = [
    for (final block
        in widget.initial?.blocks ??
            const [CycleBlock(count: 1, shiftTypeId: null)])
      _Block(block.count, block.shiftTypeId, _edited),
  ];
  late LocalDate _previewMonth = widget.today.firstOfMonth;
  int _tab = 0;
  Map<String, String> _errors = const {};
  bool _saving = false;
  PropertySheetController? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sheet = widget.initial == null
        ? null
        : PropertySheetScope.maybeOf(context);
    if (sheet != _sheet) {
      _sheet?.detach(_apply);
      _sheet = sheet?..attach(apply: _apply);
    }
  }

  @override
  void dispose() {
    _sheet?.detach(_apply);
    _name.dispose();
    _timezone.dispose();
    _employment.dispose();
    for (final block in _blocks) {
      block.count.dispose();
    }
    super.dispose();
  }

  void _edited() {
    _sheet?.markDirty(true);
    if (mounted) setState(() {});
  }

  void _set(VoidCallback change) {
    setState(change);
    _sheet?.markDirty(true);
  }

  ScheduleDraft _draft() => ScheduleDraft(
    employmentId: widget.employmentId,
    name: _name.text,
    timezoneId: _timezone.text,
    cycleStart: _cycleStart,
    inUseFrom: _from,
    inUseUntil: _until,
    shiftTypes: List.unmodifiable(_types),
    blocks: [
      for (final block in _blocks)
        CycleBlock(
          count: int.tryParse(block.count.text.trim()) ?? 0,
          shiftTypeId: block.type,
        ),
    ],
  );

  Future<bool> _apply() async => await _save() is Committed<WorkSchedule>;

  /// Saves; null when the owner cancelled the new-version prompt, which
  /// saves nothing and keeps every edit.
  Future<MutationOutcome<WorkSchedule>?> _save() async {
    LocalDate? from;
    if (widget.initial?.usedByConfirmedDay ?? false) {
      from = await askNewVersionFrom(context, today: widget.today);
      if (from == null) return null;
    }
    setState(() {
      _saving = true;
      _errors = const {};
    });
    final outcome = await widget.onSave(_draft(), newVersionFrom: from);
    if (!mounted) return outcome;
    setState(() {
      _saving = false;
      _errors = switch (outcome) {
        Committed() => const {},
        Invalid(:final fields) => scheduleErrors(fields),
        Stale() => const {'schedule': staleMessage},
        Missing() => const {'schedule': 'This schedule no longer exists.'},
        Unavailable() || Uncertain() => const {
          'schedule': 'Local storage is unavailable. Try again.',
        },
      };
      if (_errors.isNotEmpty) _tab = scheduleErrorTab(_errors.keys);
    });
    return outcome;
  }

  Future<void> _delete() async {
    final name = widget.initial!.name;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => EraDialog(
        title: 'Delete schedule',
        body: Text(
          "Delete $name? No confirmed day uses it. This can't be undone.",
        ),
        actions: [
          KeyButton(
            label: 'Delete',
            kind: KeyKind.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          KeyButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final outcome = await widget.onDelete!();
    if (!mounted || outcome is Committed<WorkSchedule>) return;
    setState(
      () => _errors = {
        'schedule': outcome is Stale<WorkSchedule>
            ? staleMessage
            : 'The schedule could not be deleted. A confirmed day may use it.',
      },
    );
  }

  Future<void> _shiftTypes() async {
    final edited = await editShiftTypes(
      context,
      types: _types,
      used: {for (final block in _blocks) ?block.type},
    );
    if (edited != null) _set(() => _types = edited);
  }

  void _reorder(int from, int to) =>
      _set(() => _blocks.insert(to, _blocks.removeAt(from)));

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Schedule',
      'Cycle',
      'Preview',
      if (widget.historyRecord != null) 'History',
    ];
    final page = switch (_tab) {
      0 => _scheduleTab(),
      1 => _cycleTab(),
      2 => _previewTab(),
      _ => RecordHistoryPanel(record: widget.historyRecord!),
    };
    final tabs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PropertySheetTabs(
          labels: labels,
          selectedIndex: _tab,
          onSelected: (index) => setState(() => _tab = index),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: MillenniumColors.page,
              border: Border(
                left: BorderSide(color: MillenniumColors.tabLine),
                right: BorderSide(color: MillenniumColors.tabLine),
                bottom: BorderSide(color: MillenniumColors.tabLine),
              ),
            ),
            child: page,
          ),
        ),
      ],
    );
    if (widget.initial != null) return tabs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tabs),
        const SizedBox(height: 7),
        FormFooter(
          children: [
            KeyButton(
              label: 'Save schedule',
              kind: KeyKind.primary,
              onPressed: _saving ? null : _save,
            ),
            const DialogCancelKey(),
          ],
        ),
      ],
    );
  }

  Widget _note(String? text) => text == null
      ? const SizedBox.shrink()
      : InspectorNote(text, tone: FactTone.negative);

  Widget _scheduleTab() {
    final initial = widget.initial;
    const gap = SizedBox(height: 7);
    return ListView(
      padding: inspectorInset,
      children: [
        _note(_errors['schedule']),
        _note(_errors['newVersionFrom']),
        GroupBox(
          legend: 'Schedule',
          child: EraFormScope(
            labelWidth: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EraField(
                  fieldKey: const ValueKey('schedule-name'),
                  controller: _name,
                  label: 'Name',
                  error: _errors['name'],
                  autofocus: initial == null,
                ),
                gap,
                // A schedule stays with its employment (see the plan's
                // changes from the spec).
                EraFormScope(
                  labelWidth: 100,
                  enabled: false,
                  child: EraField(controller: _employment, label: 'Employment'),
                ),
                gap,
                EraField(
                  fieldKey: const ValueKey('schedule-timezone'),
                  controller: _timezone,
                  label: 'Timezone',
                  error: _errors['timezoneId'],
                  hint: 'For example Europe/Vilnius',
                ),
                gap,
                EraDateField(
                  fieldKey: const ValueKey('schedule-cycle-start'),
                  label: 'Cycle starts on',
                  value: _cycleStart,
                  today: widget.today,
                  onChanged: (value) =>
                      _set(() => _cycleStart = value ?? _cycleStart),
                ),
                gap,
                EraDateField(
                  fieldKey: const ValueKey('schedule-from'),
                  label: 'In use from',
                  value: _from,
                  today: widget.today,
                  error: _errors['inUseFrom'],
                  onChanged: (value) => _set(() => _from = value ?? _from),
                ),
                gap,
                EraDateField(
                  fieldKey: const ValueKey('schedule-until'),
                  label: 'In use until',
                  value: _until,
                  optional: true,
                  today: widget.today,
                  error: _errors['inUseUntil'],
                  onChanged: (value) => _set(() => _until = value),
                ),
              ],
            ),
          ),
        ),
        if (initial != null) ...[
          InspectorFacts(legend: 'Version', [
            Fact('Version', '${initial.version}'),
            Fact.words(
              'Confirmed days',
              initial.usedByConfirmedDay ? 'Use this version' : 'None yet',
            ),
          ]),
          if (initial.usedByConfirmedDay)
            const InspectorNote(
              'Confirmed days keep this version. Saving a change starts a '
              'new version from a date you choose.',
            ),
        ],
        if (widget.onDelete != null && initial != null)
          InspectorActions(
            children: [
              KeyButton(label: 'Delete schedule…', onPressed: _delete),
            ],
          ),
      ],
    );
  }

  Widget _cycleTab() {
    final days = _blocks.fold(
      0,
      (sum, block) => sum + (int.tryParse(block.count.text.trim()) ?? 0),
    );
    final typeProblem = _errors.entries
        .where((entry) => entry.key.startsWith('shiftTypes'))
        .map((entry) => entry.value)
        .firstOrNull;
    return ListView(
      padding: inspectorInset,
      children: [
        _note(_errors['blocks']),
        _note(typeProblem),
        GroupBox(
          legend: 'Cycle — ${days == 1 ? '1 day' : '$days days'}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _reorder,
                children: [
                  for (final (index, block) in _blocks.indexed)
                    _blockRow(index, block),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                children: [
                  KeyButton(
                    label: 'Add block',
                    onPressed: () =>
                        _set(() => _blocks.add(_Block(1, null, _edited))),
                  ),
                  KeyButton(label: 'Shift types…', onPressed: _shiftTypes),
                ],
              ),
              if (_types.isEmpty)
                const InspectorNote(
                  'Add shift types first, then choose them for the blocks.',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _blockRow(int index, _Block block) {
    final skin = LifeOSSkinScope.of(context);
    final type = block.type == null
        ? null
        : _types.where((value) => value.id == block.type).firstOrNull;
    final error =
        _errors['blocks[$index].count'] ??
        _errors['blocks[$index].shiftTypeId'];
    final summary = type == null
        ? 'Off'
        : '${typeTimes(type)}, '
              '${type.breaks.isEmpty ? 'no break' : 'break ${breakSummary(type)}'}';
    return Focus(
      key: block.key,
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || !HardwareKeyboard.instance.isAltPressed) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && index > 0) {
          _reorder(index, index - 1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            index < _blocks.length - 1) {
          _reorder(index, index + 1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Semantics(
                    label:
                        'Move block ${index + 1}: drag, or Alt+Up and '
                        'Alt+Down',
                    child: const _Grip(),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: EraFieldWidth.short,
                  child: Semantics(
                    label: 'Block ${index + 1} days',
                    textField: true,
                    child: TextField(
                      key: ValueKey('block-$index-count'),
                      controller: block.count,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const Text(' × '),
                EraCombo<ShiftTypeId?>(
                  key: ValueKey('block-$index-type'),
                  semanticLabel: 'Block ${index + 1} shift type',
                  value: block.type,
                  minWidth: 100,
                  items: [
                    const EraComboItem<ShiftTypeId?>(null, 'Off'),
                    for (final value in _types)
                      EraComboItem<ShiftTypeId?>(value.id, value.name),
                  ],
                  onSelected: (value) => _set(() => block.type = value),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: skin.typography.body.copyWith(
                      color: skin.tokens.ink,
                    ),
                  ),
                ),
                KeyButton(
                  label: 'Remove',
                  onPressed: _blocks.length == 1
                      ? null
                      : () => _set(() {
                          _blocks.removeAt(index);
                          block.count.dispose();
                        }),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                  error,
                  style: skin.typography.body.copyWith(
                    color: skin.tokens.negative,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewTab() {
    final month = _previewMonth;
    final draft = _draft();
    final schedule = WorkSchedule(
      id: const ScheduleId('preview'),
      employmentId: widget.employmentId,
      name: draft.name.trim().isEmpty ? 'Preview' : draft.name,
      timezoneId: draft.timezoneId.trim(),
      version: 1,
      cycleStart: draft.cycleStart,
      inUseFrom: draft.inUseFrom,
      inUseUntil: draft.inUseUntil,
      shiftTypes: draft.shiftTypes,
      blocks: draft.blocks,
      createdAtUtc: DateTime.utc(2000),
      revision: const Revision(0),
    );
    Widget body;
    if (validateSchedule(schedule).isNotEmpty) {
      body = const Text('Complete the schedule to see its preview.');
    } else {
      final grid = monthGridDays(month);
      List<PlannedDay>? plan;
      try {
        plan = planDays(
          from: grid.first,
          to: grid.last,
          schedules: [schedule],
          exceptions: const [],
          confirmedDates: const {},
          zoneClocks: widget.zoneClocks,
        );
      } on Object {
        plan = null;
      }
      if (plan == null) {
        body = const Text(
          'Enter a timezone LifeOS knows, for example Europe/Vilnius.',
        );
      } else {
        final days = dayViews(
          from: month.firstOfMonth,
          to: month.lastOfMonth,
          plan: plan,
          shifts: const [],
          leave: const [],
          schedules: [schedule],
          timezones: widget.timezones,
        );
        final totals = monthTotals(
          days.values,
          price: (shift) => plannedPay(
            shift,
            agreements: widget.agreements,
            employmentId: widget.employmentId,
            zoneClocks: widget.zoneClocks,
          ),
        );
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 300,
              child: WorkCalendar(
                month: month,
                today: widget.today,
                days: days,
                readOnly: true,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${totals.shifts == 1 ? '1 shift' : '${totals.shifts} shifts'}'
              ' · ${formatDuration(totals.paidSeconds)} paid · '
              '${formatMoney(totals.planned)} expected',
            ),
          ],
        );
      }
    }
    return ListView(
      padding: inspectorInset,
      children: [
        GroupBox(
          legend: 'Preview — ${eraMonthTitle(month)}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StepKey(
                    forward: false,
                    semanticLabel: 'Previous month',
                    onPressed: () => setState(
                      () => _previewMonth = month.addMonthsClamped(-1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  StepKey(
                    forward: true,
                    semanticLabel: 'Next month',
                    onPressed: () => setState(
                      () => _previewMonth = month.addMonthsClamped(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              body,
            ],
          ),
        ),
      ],
    );
  }
}
