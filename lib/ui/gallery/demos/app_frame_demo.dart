import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

/// The whole database shell frame at 1280 x 800 on synthetic data.
final appFrameDemo = appFrameDemoAt(const Size(1280, 800));

/// The frame demo on a client area of [client] (the canvas adds its 12 px
/// padding): 1280 x 800 shows three columns, 960 x 700 folds the tree into
/// the toolbar, 800 x 600 docks the properties beside the subform tabs.
GalleryDemo appFrameDemoAt(Size client) => GalleryDemo(
  id: 'shell/app_frame',
  widget: 'AppFrame',
  summary:
      'The database shell: menu bar, banded toolbar with Save, Undo and '
      'Find, area tabs, the tree and Details, a data grid over its subform, '
      'the property column and the status bar, split by 5 px splitters whose '
      'sizes each area remembers. Narrower than 1024 px the tree folds into '
      'the Tree key; narrower than 860 px Properties becomes a tab beside '
      'the subform tabs. Confirm worked days… puts an action panel in the '
      'property column. Error marks a cell and a property; Long text '
      'lengthens tabs and the notice.',
  size: Size(client.width + 24, client.height + 24),
  build: (context, knobs) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: AppFrameShowcase(knobs: knobs),
    ),
  ),
);

/// A synthetic shift of the mockup's depot (spec 11).
final class _Shift {
  _Shift(
    this.id,
    this.date,
    this.type, {
    this.start,
    this.end,
    this.ok = false,
    this.note = '',
  });

  final String id;
  LocalDate date;
  String type;
  LocalTime? start;
  LocalTime? end;
  bool ok;
  String note;

  _Shift copy() =>
      _Shift(id, date, type, start: start, end: end, ok: ok, note: note);

  bool get working => type == 'day' || type == 'night';

  int get paidMinutes {
    final from = start;
    final to = end;
    if (!working || from == null || to == null) return 0;
    var minutes = (to.hour * 60 + to.minute) - (from.hour * 60 + from.minute);
    if (minutes <= 0) minutes += 24 * 60;
    return minutes - 30;
  }

  Object? field(String key) => switch (key) {
    'date' => date,
    'type' => type,
    'start' => start,
    'end' => end,
    'ok' => ok,
    'note' => note,
    _ => null,
  };
}

const _types = [
  EraComboItem<Object?>('day', 'Day'),
  EraComboItem<Object?>('night', 'Night'),
  EraComboItem<Object?>('off', 'Off'),
];

String _hours(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

String _euros(int minutes) {
  final cents = (minutes * 1840 / 60).round();
  return 'EUR ${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

/// October 2026: day shifts, a night shift on Fridays, weekends off;
/// cheap to build at any size.
List<_Shift> _october() => [
  for (var day = 1; day <= 31; day++)
    if (day % 7 == 3 || day % 7 == 4)
      _Shift('d$day', LocalDate(2026, 10, day), 'off')
    else
      _Shift(
        'd$day',
        LocalDate(2026, 10, day),
        day % 7 == 2 ? 'night' : 'day',
        start: day % 7 == 2 ? const LocalTime(19, 0) : const LocalTime(7, 0),
        end: day % 7 == 2 ? const LocalTime(7, 0) : const LocalTime(19, 0),
        ok: day < 7,
        note: day == 7 ? 'Covering for Ann' : '',
      ),
];

/// The frame demo's owner: synthetic records, a pending copy per edited
/// shift, one editor session for grid, property grid and action panel, and
/// remembered pane sizes per area. Public so the layout tests drive the
/// same composition the gallery shows; [events] records every command.
final class AppFrameShowcase extends StatefulWidget {
  const AppFrameShowcase({required this.knobs, super.key});

  final GalleryKnobs knobs;

  @override
  State<AppFrameShowcase> createState() => AppFrameShowcaseState();
}

final class AppFrameShowcaseState extends State<AppFrameShowcase> {
  final controller = EditorSessionController();
  final frameKey = GlobalKey<AppFrameState>();
  final _find = TextEditingController();

  /// Commands and commits, in order: `commit:d7:end`, `save`, `undo`,
  /// `primary`, `cancel`, `area:tracking`, `menu:Licences`…
  final events = <String>[];

  late final Map<String, _Shift> _saved = {
    for (final shift in _october()) shift.id: shift,
  };
  final _pending = <String, _Shift>{};
  String selectedId = 'd7';
  String area = 'work';
  String treeId = 'night:shifts';
  String? subformTab = 'breaks';
  bool actionOpen = false;

  /// Remembered sizes per area, in baseline pixels.
  final panes = <String, AppFramePanes>{};
  final _action = <String, Object?>{'hours': '11', 'note': ''};

  /// Supplies [value] as [area]'s remembered sizes, as an owner restoring
  /// them from its settings would.
  void restorePanes(String area, AppFramePanes value) =>
      setState(() => panes[area] = value);

  @override
  void initState() {
    super.initState();
    // The mockup's pending edit: End 19:00 changed to 19:45.
    _pending['d7'] = _saved['d7']!.copy()..end = const LocalTime(19, 45);
  }

  @override
  void dispose() {
    controller.dispose();
    _find.dispose();
    super.dispose();
  }

  GalleryKnobs get _knobs => widget.knobs;

  _Shift _shift(String id) => _pending[id] ?? _saved[id]!;

  /// A field of the selected shift as the owner holds it now.
  Object? value(String field) => _shift(selectedId).field(field);

  bool _changed(String id, String field) =>
      _pending.containsKey(id) &&
      _pending[id]!.field(field) != _saved[id]!.field(field);

  EditResult _commit(String id, String field, Object? draft) {
    if (field == 'note' && '$draft'.trim().isEmpty) {
      events.add('reject:$id:$field');
      return const EditResult.rejected(
        'Enter a note: it is printed on the monthly summary.',
      );
    }
    final shift = _shift(id).copy();
    switch (field) {
      case 'date':
        shift.date = draft! as LocalDate;
      case 'type':
        shift.type = draft! as String;
      case 'start':
        shift.start = draft as LocalTime?;
      case 'end':
        shift.end = draft as LocalTime?;
      case 'ok':
        shift.ok = draft! as bool;
      case 'note':
        shift.note = '$draft';
    }
    events.add('commit:$id:$field');
    setState(() => _pending[id] = shift);
    return const EditResult.accepted();
  }

  void _command(String name, VoidCallback action) {
    if (!controller.flush().isAccepted) return;
    events.add(name);
    setState(action);
  }

  void _save() => _command('save', () {
    _saved.addAll(_pending);
    _pending.clear();
  });

  /// Opens the action panel in the property column, showing its tab
  /// while the column is docked.
  void _openAction() => _command('action', () {
    actionOpen = true;
    if (frameKey.currentState?.layout?.propertiesDocked ?? false) {
      subformTab = AppFrame.propertiesTabId;
    }
  });

  void _undo() {
    controller.cancel();
    events.add('undo');
    setState(() => _pending.remove(selectedId));
  }

  String? _lock(_Shift shift, GridColumn<_Shift> column) {
    if (!column.editable) return null;
    if (shift.ok) return 'Confirmed days are read-only; use Correct.';
    if (!shift.working && column.key != 'type' && column.key != 'note') {
      return 'An off day has no times; change its type first.';
    }
    return null;
  }

  late final List<GridColumn<_Shift>> _columns = [
    GridColumn<_Shift>(
      key: 'date',
      label: 'Date',
      kind: ValueKind.date,
      width: 104,
      value: (shift) => shift.date,
    ),
    GridColumn<_Shift>(
      key: 'type',
      label: 'Type',
      kind: ValueKind.choice,
      width: 64,
      value: (shift) => shift.type,
      choices: _types,
      editable: true,
    ),
    GridColumn<_Shift>(
      key: 'start',
      label: 'Start',
      kind: ValueKind.time,
      width: 52,
      value: (shift) => shift.start,
      editable: true,
    ),
    GridColumn<_Shift>(
      key: 'end',
      label: 'End',
      kind: ValueKind.time,
      width: 52,
      value: (shift) => shift.end,
      editable: true,
    ),
    GridColumn<_Shift>(
      key: 'paid',
      label: 'Paid',
      kind: ValueKind.duration,
      width: 60,
      value: (shift) => shift.working ? shift.paidMinutes : null,
      display: (minutes) => _hours(minutes as int),
    ),
    GridColumn<_Shift>(
      key: 'ok',
      label: 'Confirmed',
      kind: ValueKind.check,
      width: 72,
      value: (shift) => shift.ok,
      editable: true,
    ),
    GridColumn<_Shift>(
      key: 'note',
      label: 'Note',
      kind: ValueKind.text,
      width: 140,
      value: (shift) => shift.note,
      editable: true,
    ),
  ];

  Widget _grid() {
    final shifts = [for (final id in _saved.keys) _shift(id)];
    final working = shifts.where((shift) => shift.working);
    final paid = working.fold(0, (sum, shift) => sum + shift.paidMinutes);
    return DataGrid<_Shift>(
      label: 'Shifts',
      columns: _columns,
      lines: [
        GridGroup(label: 'October 2026', summary: '${shifts.length} days'),
        for (final shift in shifts)
          GridRow(
            shift,
            state: shift.working ? GridRowState.normal : GridRowState.muted,
          ),
      ],
      rowId: (shift) => shift.id,
      rowLabel: (shift) => 'Shift ${eraBoxDate(shift.date)}',
      selectedId: selectedId,
      onSelect: (id) => setState(() => selectedId = id),
      editorController: controller,
      onEdit: (cell, draft) => _commit(cell.rowId, cell.column, draft),
      readOnlyReason: _lock,
      today: galleryToday,
      enabled: _knobs.enabled,
      pendingIds: _pending.keys.toSet(),
      changed: {
        for (final id in _pending.keys)
          for (final column in _columns)
            if (_changed(id, column.key)) GridCell(id, column.key),
      },
      errors: {
        if (_knobs.errorText != null)
          const GridCell('d8', 'end'): 'End must be after start.',
      },
      footer: {'paid': _hours(paid)},
      footerLabel: 'Total (${working.length} shifts)',
      note: 'Filtered: Period',
    );
  }

  Widget _properties() {
    final shift = _shift(selectedId);
    final saved = _saved[selectedId]!;
    String? was(String key, ValueKind kind) =>
        shift.field(key) == saved.field(key)
        ? null
        : formatValue(kind, saved.field(key), choices: _types);
    final locked = shift.ok
        ? 'Confirmed days are read-only; use Correct.'
        : null;
    return PropertyGrid(
      record: selectedId,
      controller: controller,
      today: galleryToday,
      enabled: _knobs.enabled,
      edited: _pending.containsKey(selectedId),
      onCommit: (id, draft) => _commit(id.record as String, id.field, draft),
      items: [
        PropertyItem(
          key: 'date',
          label: 'Date',
          category: 'Shift',
          kind: ValueKind.date,
          value: shift.date,
          readOnlyReason: locked,
          was: was('date', ValueKind.date),
          description: 'The day the shift starts on.',
        ),
        PropertyItem(
          key: 'type',
          label: 'Type',
          category: 'Shift',
          kind: ValueKind.choice,
          value: shift.type,
          choices: _types,
          readOnlyReason: locked,
          was: was('type', ValueKind.choice),
          description: 'Day, Night or Off.',
        ),
        PropertyItem(
          key: 'start',
          label: 'Start',
          category: 'Shift',
          kind: ValueKind.time,
          value: shift.start,
          readOnlyReason: locked,
          was: was('start', ValueKind.time),
          description: 'When the shift began.',
        ),
        PropertyItem(
          key: 'end',
          label: 'End',
          category: 'Shift',
          kind: ValueKind.time,
          value: shift.end,
          readOnlyReason: locked,
          was: was('end', ValueKind.time),
          error: _knobs.errorText,
          description:
              'Saving asks to finalize the shift. Finalized shifts use '
              'Correct.',
        ),
        PropertyItem(
          key: 'ok',
          label: _knobs.text('Confirmed', 'Confirmed as worked by the owner'),
          category: 'Shift',
          kind: ValueKind.check,
          value: shift.ok,
          was: was('ok', ValueKind.check),
          description: 'Whether the day was worked as planned.',
        ),
        PropertyItem(
          key: 'note',
          label: 'Note',
          category: 'Shift',
          value: shift.note,
          was: was('note', ValueKind.text),
          description: 'Your own words about this shift.',
        ),
        PropertyItem(
          key: 'paid',
          label: 'Paid time',
          category: 'Pay (derived)',
          kind: ValueKind.duration,
          value: _hours(shift.paidMinutes),
          readOnlyReason: 'Derived: worked time minus the 0:30 break.',
        ),
        PropertyItem(
          key: 'pay',
          label: 'Est. pay',
          category: 'Pay (derived)',
          kind: ValueKind.money,
          value: shift.paidMinutes,
          display: _euros(shift.paidMinutes),
          readOnlyReason: 'Derived from the agreement.',
        ),
        PropertyItem(
          key: 'employment',
          label: 'Employment',
          category: 'Belongs to',
          value: 'Synthetic depot',
          onFollow: _knobs.press(() => events.add('follow:employment')),
        ),
      ],
    );
  }

  Widget _actionPanel() => ActionPanel(
    title: _knobs.text(
      'Confirm worked days',
      'Confirm the worked days of Synthetic depot, October 2026',
    ),
    record: 'action:confirm-days',
    controller: controller,
    today: galleryToday,
    enabled: _knobs.enabled,
    groups: () => [
      ActionGroup(
        legend: 'Worked',
        fields: [
          ActionField(
            id: 'hours',
            label: _knobs.text('Paid hours', 'Paid hours per day (whole)'),
            kind: ValueKind.number,
            value: _action['hours'],
            validate: (draft) =>
                int.tryParse('$draft') == null ? 'Enter whole hours.' : null,
            error: _knobs.errorText,
            fieldKey: const ValueKey('action-hours'),
          ),
          ActionField(
            id: 'note',
            label: 'Note',
            kind: ValueKind.text,
            value: _action['note'],
            fieldKey: const ValueKey('action-note'),
          ),
        ],
      ),
    ],
    onChanged: (field, value) => setState(() => _action[field] = value),
    primaryLabel: 'Confirm 3 days',
    onPrimary: () => _command('primary', () => actionOpen = false),
    onCancel: () {
      events.add('cancel');
      setState(() => actionOpen = false);
    },
  );

  List<TreeNodeData> _nodes() => [
    TreeNodeData(
      id: 'night',
      label: _knobs.text(
        'Night shifts',
        'Night shifts at the harbour logistics depot',
      ),
      icon: EraIconKind.employment,
      bold: true,
      expanded: true,
      children: [
        const TreeNodeData(
          id: 'night:calendar',
          label: 'Calendar',
          icon: EraIconKind.shift,
        ),
        const TreeNodeData(
          id: 'night:shifts',
          label: 'Shifts',
          icon: EraIconKind.shift,
          count: 31,
        ),
        const TreeNodeData(
          id: 'night:periods',
          label: 'Pay periods',
          icon: EraIconKind.payPeriod,
          count: 3,
        ),
        const TreeNodeData(
          id: 'night:payslips',
          label: 'Payslips',
          icon: EraIconKind.payslip,
          count: 2,
        ),
        const TreeNodeData(
          id: 'night:agreements',
          label: 'Agreements',
          icon: EraIconKind.agreement,
          count: 1,
        ),
        TreeNodeData(
          id: 'night:confirm',
          label: 'To confirm',
          icon: EraIconKind.warning,
          count: 3,
          warning: _knobs.error,
        ),
      ],
    ),
    const TreeNodeData(
      id: 'ended',
      label: 'Ended employments',
      icon: EraIconKind.employment,
      count: 1,
      muted: true,
    ),
  ];

  Widget _details() => DetailsBox(
    caption: 'Details',
    sections: [
      DetailsSection(
        facts: [
          DetailsFact(
            'Agreement',
            'Pay from 2026-10-01',
            figure: false,
            onFollow: _knobs.press(() => events.add('follow:agreement')),
          ),
          const DetailsFact('Hourly rate', 'EUR 18.40'),
          const DetailsFact('Night premium', '+50 %'),
          const DetailsFact('Open period', 'October 2026', figure: false),
        ],
      ),
      DetailsSection(
        title: 'October 2026',
        facts: const [
          DetailsFact('Finalized', '6'),
          DetailsFact('To confirm', '3'),
          DetailsFact('Next shift', 'Wed 2026-10-14 07:00'),
        ],
        warnings: [
          if (_knobs.error)
            DetailsWarning(
              '3 days to confirm',
              onFollow: _knobs.press(() => events.add('follow:confirm')),
            ),
        ],
      ),
    ],
  );

  List<SubformTab> _subformTabs() => [
    SubformTab(
      id: 'breaks',
      label: _knobs.text('Breaks', 'Breaks taken during this shift (unpaid)'),
      count: 1,
      countLabel: 'rows',
      builder: (context) => const Padding(
        padding: EdgeInsets.all(6),
        child: Text('Break 12:00 to 12:30, unpaid.'),
      ),
    ),
    SubformTab(
      id: 'history',
      label: 'History',
      builder: (context) => const OperationalState(
        kind: OperationalStateKind.empty,
        title: 'No history yet',
        message: 'Pending changes are not history events.',
      ),
    ),
    SubformTab(
      id: 'working',
      label: _knobs.text('Working', 'How the pay of this day is worked out'),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          'Paid ${_hours(_shift(selectedId).paidMinutes)} at EUR 18.40.',
        ),
      ),
    ),
  ];

  ToolbarItem _key(String label, VoidCallback action, {EraIconKind? icon}) =>
      ToolbarItem(label: label, icon: icon, onPressed: _knobs.press(action));

  Widget _toolbar(ToolbarItem? tree) => BandedToolbar(
    bands: [
      if (tree != null) ToolbarBand(items: [tree]),
      const ToolbarBand(
        items: [
          ToolbarItem(
            label: 'Back',
            leading: Orb(glyph: OrbGlyph.back, tone: OrbTone.grey, size: 18),
            onPressed: null,
          ),
          ToolbarItem(
            label: 'Forward',
            leading: Orb(glyph: OrbGlyph.forward, tone: OrbTone.grey, size: 18),
            onPressed: null,
          ),
        ],
      ),
      ToolbarBand(
        items: [
          _key('Save', _save),
          _key('Undo', _undo),
          _key('Delete', () => events.add('delete'), icon: EraIconKind.delete),
        ],
      ),
      ToolbarBand(
        items: [
          _key(
            _knobs.text('Confirm worked days…', 'Confirm the worked days…'),
            _openAction,
            icon: EraIconKind.reviewed,
          ),
          _key(
            'Correct…',
            () => events.add('correct'),
            icon: EraIconKind.correct,
          ),
        ],
      ),
    ],
    trailing: EraField(controller: _find, label: 'Find'),
  );

  @override
  Widget build(BuildContext context) {
    final knobs = _knobs;
    final shift = _shift(selectedId);
    final pending = _pending[selectedId];
    final notice = pending == null
        ? 'Ready.'
        : knobs.text(
            'Unsaved change: ${eraBoxDate(shift.date)}. Save to keep it.',
            'Unsaved plan change: ${eraBoxDate(shift.date)}, End 19:00 → '
                '${formatValue(ValueKind.time, shift.end)}. Save, or leave '
                'the day, to keep it. Confirmation is separate.',
          );
    return AppFrame(
      key: frameKey,
      controller: controller,
      enabled: knobs.enabled,
      menus: [
        for (final menu in ['File', 'Edit', 'View', 'Record', 'Tools'])
          AppMenu(menu, [
            EraMenuItem('$menu settings…', () => events.add('menu:$menu')),
          ]),
        AppMenu('Window', [
          EraMenuItem('Back', null),
          EraMenuItem('Forward', null),
        ]),
        AppMenu('Help', [
          EraMenuItem('Licences', () => events.add('menu:Licences')),
        ]),
      ],
      toolbarBuilder: (context, tree) => _toolbar(tree),
      areas: [
        const TabItem(id: 'work', label: 'Work', icon: EraIconKind.work),
        const TabItem(
          id: 'finance',
          label: 'Finance',
          icon: EraIconKind.finance,
          enabled: false,
          disabledReason: 'Not built yet',
        ),
        TabItem(
          id: 'tracking',
          label: knobs.text('Tracking', 'Tracking of habits and measures'),
          icon: EraIconKind.tracking,
        ),
        const TabItem(
          id: 'knowledge',
          label: 'Knowledge',
          icon: EraIconKind.knowledge,
        ),
      ],
      areaId: area,
      onAreaSelect: (id) {
        events.add('area:$id');
        setState(() => area = id);
      },
      treeTitle: 'Night shifts',
      treeIcon: EraIconKind.employment,
      tree: TreeView(
        label: 'Object tree',
        nodes: _nodes(),
        selectedId: treeId,
        enabled: knobs.enabled,
        onSelect: (id) {
          if (!controller.flush().isAccepted) return;
          events.add('tree:$id');
          setState(() => treeId = id);
        },
      ),
      details: _details(),
      middle: _grid(),
      subformTabs: _subformTabs(),
      subformSelectedId: subformTab,
      onSubformSelect: (id) => setState(() => subformTab = id),
      subformTrailing: Text('for Shift ${eraBoxDate(shift.date)}'),
      subformLabel: 'Shift details',
      properties: actionOpen ? _actionPanel() : _properties(),
      propertiesLabel: actionOpen ? 'Confirm days' : 'Properties',
      status: StatusBar(
        notice: notice,
        panels: [
          StatusPanel('${_saved.length} days'),
          const StatusPanel('Local database'),
        ],
        warning: knobs.error ? '3 days to confirm' : null,
      ),
      panes: panes[area] ?? AppFramePanes.baseline,
      onPanesChanged: (value) => setState(() => panes[area] = value),
      onPanesChangeEnd: (value) => events.add('panes:$area'),
    );
  }
}
