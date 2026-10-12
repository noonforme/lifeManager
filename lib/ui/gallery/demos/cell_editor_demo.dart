import 'package:flutter/widgets.dart';

import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

final cellEditorDemo = GalleryDemo(
  id: 'controls/cell_editor',
  widget: 'CellEditor',
  summary:
      'One field editor under a shared EditorSessionController: labelled '
      'action-panel rows above, bare grid cells of the same record below. '
      'Enter/Tab commit and open the next field, Esc throws the value away, '
      'a rejected value stays red in its editor.',
  size: const Size(480, 560),
  build: (context, knobs) => _CellEditorDemo(knobs: knobs),
);

const _kinds = {
  'note': ValueKind.text,
  'hours': ValueKind.number,
  'pay': ValueKind.money,
  'start': ValueKind.time,
  'day': ValueKind.date,
  'kind': ValueKind.choice,
  'paid': ValueKind.check,
};

const _choices = [
  EraComboItem<Object?>('shift', 'Shift'),
  EraComboItem<Object?>('leave', 'Leave'),
  EraComboItem<Object?>('off', 'Day off'),
];

/// A synthetic pending shift: the panel and the grid row share one
/// controller, so they never hold different drafts.
final class _CellEditorDemo extends StatefulWidget {
  const _CellEditorDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_CellEditorDemo> createState() => _CellEditorDemoState();
}

final class _CellEditorDemoState extends State<_CellEditorDemo> {
  final _controller = EditorSessionController();
  final Map<String, Object?> _values = {
    'note': 'Late shift',
    'hours': 8,
    'pay': '12.50',
    'start': const LocalTime(14, 0),
    'day': galleryToday,
    'kind': 'shift',
    'paid': true,
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSession);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onSession)
      ..dispose();
    super.dispose();
  }

  void _onSession() => setState(() {});

  /// The demo's draft acceptance: whole hours and amounts like 12.50.
  EditResult _commit(EditIdentity id, Object? draft) {
    Object? value = draft;
    switch (id.field) {
      case 'hours':
        value = int.tryParse('$draft');
        if (value == null) {
          return const EditResult.rejected('Enter whole hours.');
        }
      case 'pay':
        if (!RegExp(r'^\d+\.\d\d$').hasMatch('$draft')) {
          return const EditResult.rejected('Enter an amount like 12.50.');
        }
    }
    setState(() => _values[id.field] = value);
    return const EditResult.accepted();
  }

  EditField _field(String name) => EditField(
    id: EditIdentity(record: 'shift:demo', field: name),
    kind: _kinds[name]!,
    value: _values[name],
    commit: _commit,
  );

  /// Each region's own field order: Enter and Tab go on within it, to a
  /// field it has an editor for.
  static const _panel = ['note', 'hours', 'start', 'kind', 'paid'];
  static const _grid = ['hours', 'pay', 'start', 'day', 'kind', 'paid'];

  EditField? _next(String name, {required bool bare}) {
    final names = bare ? _grid : _panel;
    final at = names.indexOf(name);
    return at + 1 < names.length ? _field(names[at + 1]) : null;
  }

  Widget _editor(String name, String label, {required bool bare}) => CellEditor(
    controller: _controller,
    field: _field(name),
    label: label,
    bare: bare,
    host: bare ? 'grid' : 'panel',
    choices: _choices,
    today: galleryToday,
    error: name == 'hours' ? widget.knobs.errorText : null,
    next: () => _next(name, bare: bare),
  );

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    final skin = LifeOSSkinScope.of(context);
    final scale = MediaQuery.textScalerOf(context);
    String label(String short, String long) => knobs.text(short, long);
    Widget cell(String name, double? width) {
      final box = Container(
        width: width == null ? null : scale.scale(width),
        decoration: BoxDecoration(border: Border.all(color: skin.tokens.rule)),
        child: _editor(name, name, bare: true),
      );
      return width == null ? IntrinsicWidth(child: box) : box;
    }

    final session = _controller.session;
    final open = session == null
        ? 'none'
        : '${session.id.field} '
              '("${formatValue(session.kind, session.draft, choices: _choices)}")';
    final muted = skin.typography.body.copyWith(color: skin.tokens.muted);
    return SizedBox(
      width: scale.scale(440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GroupBox(
            legend: 'Action panel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _editor(
                  'note',
                  label('Note', 'Note for the payroll office'),
                  bare: false,
                ),
                _editor(
                  'hours',
                  label('Hours', 'Hours worked (whole)'),
                  bare: false,
                ),
                _editor(
                  'start',
                  label('Start', 'Shift starts at'),
                  bare: false,
                ),
                _editor('kind', label('Kind', 'Kind of day'), bare: false),
                _editor(
                  'paid',
                  label('Paid', 'Paid by the employer'),
                  bare: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Grid row (bare cells):',
            style: skin.typography.body.copyWith(color: skin.tokens.ink),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              cell('hours', 60),
              cell('pay', EraFieldWidth.money),
              cell('start', null),
              cell('day', EraFieldWidth.date + 2),
              cell('kind', 100),
              cell('paid', 24),
            ],
          ),
          const SizedBox(height: 8),
          Text('Open field: $open', style: muted),
          Text(
            'Pending: ${[for (final MapEntry(:key, :value) in _values.entries)
              if (key != 'note' && key != 'day') formatValue(_kinds[key]!, value, choices: _choices)].join(' · ')}',
            style: muted,
          ),
        ],
      ),
    );
  }
}
