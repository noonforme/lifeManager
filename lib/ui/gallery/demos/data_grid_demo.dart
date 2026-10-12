import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

final dataGridDemo = GalleryDemo(
  id: 'data/data_grid',
  widget: 'DataGrid',
  summary:
      'The editable datasheet: sortable, resizable bevelled headers, a group '
      'row, the selector (current, pending, new), muted and void rows, bold '
      'pending values, totals and the record navigator. Click a row to '
      'select it, an editable cell of the selected row to edit it; Pick '
      'days ticks rows and totals them.',
  size: const Size(720, 400),
  build: (context, knobs) => _DataGridDemo(knobs: knobs),
);

/// A synthetic shift of the mockup's depot (spec 11).
final class _Shift {
  _Shift(
    this.id,
    this.date,
    this.type, {
    this.start,
    this.end,
    this.breakMinutes = 0,
    this.confirmed = false,
    this.note = '',
    this.state = 'planned',
  });

  final String id;
  final LocalDate date;
  String type;
  LocalTime? start;
  LocalTime? end;
  int breakMinutes;
  bool confirmed;
  String note;

  /// planned, finalized, void or new.
  final String state;

  _Shift copy() => _Shift(
    id,
    date,
    type,
    start: start,
    end: end,
    breakMinutes: breakMinutes,
    confirmed: confirmed,
    note: note,
    state: state,
  );

  bool get working => type == 'day' || type == 'night';

  int get paidMinutes {
    final from = start;
    final to = end;
    if (!working || from == null || to == null) return 0;
    var minutes = (to.hour * 60 + to.minute) - (from.hour * 60 + from.minute);
    if (minutes <= 0) minutes += 24 * 60;
    return minutes - breakMinutes;
  }

  /// EUR 18.40 an hour, in cents.
  int get payCents => (paidMinutes * 1840 / 60).round();

  Object? field(String key) => switch (key) {
    'type' => type,
    'start' => start,
    'end' => end,
    'break' => breakMinutes,
    'ok' => confirmed,
    'note' => note,
    _ => null,
  };
}

const _types = [
  EraComboItem<Object?>('day', 'Day'),
  EraComboItem<Object?>('night', 'Night'),
  EraComboItem<Object?>('off', 'Off'),
  EraComboItem<Object?>('leave', 'Vacation'),
];

String _minutes(Object minutes) {
  final value = minutes as int;
  return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
}

String _money(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ' ',
  );
  return 'EUR $whole.${(cents % 100).toString().padLeft(2, '0')}';
}

List<_Shift> _october() {
  const day = (LocalTime(7, 0), LocalTime(19, 0));
  const night = (LocalTime(19, 0), LocalTime(7, 0));
  _Shift work(int date, String type, String state, {bool ok = false}) {
    final (start, end) = type == 'night' ? night : day;
    return _Shift(
      'd$date',
      LocalDate(2026, 10, date),
      type,
      start: start,
      end: end,
      breakMinutes: 30,
      confirmed: ok,
      state: state,
    );
  }

  _Shift off(int date) => _Shift('d$date', LocalDate(2026, 10, date), 'off');
  return [
    work(1, 'night', 'finalized', ok: true),
    off(2),
    off(3),
    work(4, 'day', 'void'),
    work(5, 'day', 'finalized', ok: true)..note = 'Swapped',
    work(6, 'day', 'planned'),
    work(7, 'day', 'planned'),
    off(8),
    off(9),
    work(10, 'night', 'planned'),
    _Shift('d12', const LocalDate(2026, 10, 12), 'leave'),
    work(13, 'night', 'planned'),
    work(14, 'day', 'planned'),
  ];
}

final class _DataGridDemo extends StatefulWidget {
  const _DataGridDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_DataGridDemo> createState() => _DataGridDemoState();
}

final class _DataGridDemoState extends State<_DataGridDemo> {
  final _controller = EditorSessionController();

  /// The saved shifts, and the pending copies of the edited ones.
  late final Map<String, _Shift> _saved = {
    for (final shift in _october()) shift.id: shift,
  };
  final _pending = <String, _Shift>{};
  late List<String> _order = [..._saved.keys];
  String? _selected = 'd7';
  String _sortColumn = 'date';
  bool _descending = false;
  bool _picking = false;
  final _picked = <String>{};
  final _widths = <String, double>{};
  int _news = 0;

  @override
  void initState() {
    super.initState();
    // The mockup's pending edit: End 19:00 changed to 19:45.
    _pending['d7'] = _saved['d7']!.copy()..end = const LocalTime(19, 45);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Shift? _shift(String id) => _pending[id] ?? _saved[id];

  List<_Shift> get _shifts => [for (final id in _order) ?_shift(id)];

  bool _changed(String id, String field) {
    final pending = _pending[id];
    final saved = _saved[id];
    if (pending == null) return false;
    return saved == null || pending.field(field) != saved.field(field);
  }

  /// The demo's draft acceptance, applied to the field's own record.
  EditResult _commit(GridCell cell, Object? draft) {
    final current = _shift(cell.rowId);
    if (current == null) {
      return const EditResult.rejected('This shift was removed.');
    }
    final shift = current.copy();
    switch (cell.column) {
      case 'type':
        shift.type = draft! as String;
      case 'start':
        shift.start = draft as LocalTime?;
      case 'end':
        shift.end = draft as LocalTime?;
      case 'break':
        final match = RegExp(r'^(\d{1,2}):(\d\d)$').firstMatch('$draft');
        if (match == null) {
          return const EditResult.rejected('Enter a break like 0:30.');
        }
        shift.breakMinutes =
            int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
      case 'ok':
        shift.confirmed = draft! as bool;
      case 'note':
        shift.note = '$draft';
    }
    setState(() => _pending[cell.rowId] = shift);
    return const EditResult.accepted();
  }

  String? _lock(_Shift shift, GridColumn<_Shift> column) {
    if (!column.editable) return null;
    return switch (shift.state) {
      'finalized' =>
        'Finalized shifts are read-only; correct them with '
            'Correct.',
      'void' => 'A voided shift is read-only.',
      _ when !shift.working && column.key != 'type' && column.key != 'note' =>
        'An off day has no times; change its type first.',
      _ => null,
    };
  }

  void _sort(String column) {
    setState(() {
      _descending = column == _sortColumn && !_descending;
      _sortColumn = column;
      final columns = _columns;
      final by = columns.firstWhere((c) => c.key == column);
      String key(String id) {
        final shift = _shift(id)!;
        return column == 'date' ? '${shift.date}' : by.text(shift);
      }

      _order.sort((a, b) {
        final order = key(a).compareTo(key(b));
        return _descending ? -order : order;
      });
    });
  }

  void _save() {
    if (!_controller.flush().isAccepted) return;
    setState(() {
      _saved.addAll(_pending);
      _pending.clear();
    });
  }

  void _newRow() {
    setState(() {
      final id = 'new${++_news}';
      _pending[id] = _Shift(
        id,
        galleryToday,
        'day',
        start: const LocalTime(7, 0),
        end: const LocalTime(19, 0),
        breakMinutes: 30,
        state: 'new',
      );
      _order = [..._order, id];
      _selected = id;
    });
  }

  late final List<GridColumn<_Shift>> _columns = [
    GridColumn<_Shift>(
      key: 'date',
      label: 'Date',
      kind: ValueKind.date,
      width: 104,
      value: (shift) => shift.date,
      description: 'A shift keeps its date.',
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
      key: 'break',
      label: 'Break',
      kind: ValueKind.duration,
      width: 48,
      value: (shift) => shift.working ? shift.breakMinutes : null,
      display: _minutes,
      editText: (shift) => _minutes(shift.breakMinutes),
      editable: true,
    ),
    GridColumn<_Shift>(
      key: 'paid',
      label: 'Paid',
      kind: ValueKind.duration,
      width: 48,
      value: (shift) => shift.working ? shift.paidMinutes : null,
      display: _minutes,
      description: 'Paid time: from start to end, less the break.',
    ),
    GridColumn<_Shift>(
      key: 'pay',
      label: 'Est. pay',
      kind: ValueKind.money,
      width: 104,
      value: (shift) => shift.working ? shift.payCents : null,
      display: (cents) => _money(cents as int),
      description: 'Estimated pay at EUR 18.40 an hour.',
    ),
    GridColumn<_Shift>(
      key: 'ok',
      label: 'Confirmed',
      kind: ValueKind.check,
      width: 64,
      value: (shift) => shift.confirmed,
      editable: true,
    ),
    GridColumn<_Shift>(
      key: 'note',
      label: 'Note',
      kind: ValueKind.text,
      width: 120,
      value: (shift) => widget.knobs.longText && shift.note.isNotEmpty
          ? '${shift.note} with the night team after the depot asked for '
                'cover on short notice'
          : shift.note,
      editable: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    final shifts = _shifts;
    final counted = _picking
        ? [
            for (final shift in shifts)
              if (_picked.contains(shift.id)) shift,
          ]
        : [
            for (final shift in shifts)
              if (shift.working && shift.state != 'void') shift,
          ];
    final paid = counted.fold(0, (sum, shift) => sum + shift.paidMinutes);
    final pay = counted.fold(0, (sum, shift) => sum + shift.payCents);
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              KeyButton(label: 'Save', onPressed: knobs.press(_save)),
              KeyButton(
                label: _picking ? 'Done picking' : 'Pick days…',
                onPressed: knobs.press(
                  () => setState(() {
                    if (!_controller.flush().isAccepted) return;
                    _picking = !_picking;
                    _picked.clear();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: DataGrid<_Shift>(
              label: 'Shifts',
              columns: _columns,
              lines: [
                GridGroup(
                  label: 'October 2026',
                  summary: knobs.text(
                    '${shifts.length} days',
                    '${shifts.length} days in the open pay period',
                  ),
                ),
                for (final shift in shifts)
                  GridRow(
                    shift,
                    state: switch (shift.state) {
                      'void' => GridRowState.voided,
                      _ when !shift.working => GridRowState.muted,
                      _ => GridRowState.normal,
                    },
                  ),
              ],
              rowId: (shift) => shift.id,
              rowLabel: (shift) => 'Shift ${eraBoxDate(shift.date)}',
              selectedId: _selected,
              onSelect: (id) => setState(() => _selected = id),
              editorController: _controller,
              onEdit: _commit,
              readOnlyReason: _lock,
              today: galleryToday,
              enabled: knobs.enabled,
              pendingIds: _pending.keys.toSet(),
              changed: {
                for (final id in _pending.keys)
                  for (final column in _columns)
                    if (_changed(id, column.key)) GridCell(id, column.key),
              },
              errors: {
                if (knobs.errorText != null)
                  const GridCell('d6', 'end'): 'End must be after start.',
              },
              onNew: _newRow,
              sortColumn: _sortColumn,
              sortDescending: _descending,
              onSort: _sort,
              footer: {'paid': _minutes(paid), 'pay': _money(pay)},
              footerLabel: _picking
                  ? 'Total (${counted.length} picked)'
                  : 'Total (${counted.length} shifts)',
              pickMode: _picking,
              pickedIds: _picked,
              canPick: (shift) => shift.working && shift.state == 'planned',
              onPick: (id, picked) =>
                  setState(() => picked ? _picked.add(id) : _picked.remove(id)),
              widths: _widths,
              onResize: (column, width) =>
                  setState(() => _widths[column] = width),
              note: 'Filtered: Period',
            ),
          ),
        ],
      ),
    );
  }
}
