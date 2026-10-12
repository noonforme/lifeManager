import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

final propertyGridDemo = propertyGridDemoAt(306);

/// The property grid demo in a property column [width] pixels wide (306
/// in the wide frame, 260 when the frame narrows). The column keeps its
/// width at any text size; its height grows with the text.
GalleryDemo propertyGridDemoAt(double width) => GalleryDemo(
  id: 'data/property_grid',
  widget: 'PropertyGrid',
  summary:
      'The selected record\'s properties: Categorized or A–Z, an editor '
      'per value kind, muted read-only values with their reason, '
      '"(was …)" after changes, follow links and a description pane.',
  size: Size(width + 24, 484),
  build: (context, knobs) => _PropertyGridDemo(knobs: knobs, width: width),
);

const _types = [
  EraComboItem<Object?>('day', 'Day'),
  EraComboItem<Object?>('night', 'Night'),
  EraComboItem<Object?>('extra', 'Extra'),
];

/// The saved facts of a synthetic extra shift; the demo edits a pending
/// copy, so "(was …)" and the derived pay follow the edits.
final _saved = <String, Object?>{
  'date': const LocalDate(2026, 10, 7),
  'type': 'extra',
  'start': const LocalTime(7, 0),
  'end': const LocalTime(19, 0),
  'overtime': true,
  'note': 'Covering for the night team',
};

/// The hourly rate in cents and the unpaid break in minutes.
const _rate = 1840;
const _break = 30;

String _hours(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

String _euros(int cents) =>
    'EUR ${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

final class _PropertyGridDemo extends StatefulWidget {
  const _PropertyGridDemo({required this.knobs, required this.width});

  final GalleryKnobs knobs;
  final double width;

  @override
  State<_PropertyGridDemo> createState() => _PropertyGridDemoState();
}

final class _PropertyGridDemoState extends State<_PropertyGridDemo> {
  final _controller = EditorSessionController();

  /// The pending values, with End already moved from 19:00 to 19:45.
  final Map<String, Object?> _values = {
    ..._saved,
    'end': const LocalTime(19, 45),
  };
  String _followed = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The demo's draft acceptance, applied to the one demo record.
  EditResult _commit(EditIdentity id, Object? draft) {
    switch (id.field) {
      case 'note' when '$draft'.trim().isEmpty:
        return const EditResult.rejected(
          'Enter a note: it is printed on the monthly summary.',
        );
      case 'end' when _minutes(_values['start'], draft) <= _break:
        return const EditResult.rejected('End after the start and break.');
      case 'start' when _minutes(draft, _values['end']) <= _break:
        return const EditResult.rejected('Start before the end and break.');
    }
    setState(() => _values[id.field] = draft);
    return const EditResult.accepted();
  }

  static int _minutes(Object? start, Object? end) {
    final from = start! as LocalTime;
    final to = end! as LocalTime;
    return to.hour * 60 + to.minute - from.hour * 60 - from.minute;
  }

  int _paid(Map<String, Object?> values) =>
      _minutes(values['start'], values['end']) - _break;

  String? _was(String key, ValueKind kind) => _values[key] == _saved[key]
      ? null
      : formatValue(kind, _saved[key], choices: _types);

  VoidCallback _follow(String what) =>
      () => setState(() => _followed = what);

  List<PropertyItem> _items() {
    final knobs = widget.knobs;
    String text(String short, String long) => knobs.text(short, long);
    final paid = _paid(_values);
    final savedPaid = _paid(_saved);
    final pay = (paid * _rate / 60).round();
    final savedPay = (savedPaid * _rate / 60).round();
    return [
      PropertyItem(
        key: 'date',
        label: 'Date',
        category: 'Extra shift',
        kind: ValueKind.date,
        value: _values['date'],
        was: _was('date', ValueKind.date),
        description: text(
          'The day the shift starts on.',
          'The day the shift starts on. A night shift ends on the next '
              'day, and its pay counts in the period it starts in.',
        ),
      ),
      PropertyItem(
        key: 'type',
        label: 'Type',
        category: 'Extra shift',
        kind: ValueKind.choice,
        value: _values['type'],
        choices: _types,
        was: _was('type', ValueKind.choice),
        description: 'The shift type, or Extra for an added shift.',
      ),
      PropertyItem(
        key: 'start',
        label: 'Start',
        category: 'Extra shift',
        kind: ValueKind.time,
        value: _values['start'],
        was: _was('start', ValueKind.time),
        description: 'When the shift began.',
      ),
      PropertyItem(
        key: 'end',
        label: 'End',
        category: 'Extra shift',
        kind: ValueKind.time,
        value: _values['end'],
        was: _was('end', ValueKind.time),
        error: knobs.errorText,
        description:
            'Saving asks to finalize the shift. Finalized shifts '
            'use Correct.',
      ),
      PropertyItem(
        key: 'overtime',
        label: text('Overtime', 'Counts as overtime for this pay period'),
        category: 'Extra shift',
        kind: ValueKind.check,
        value: _values['overtime'],
        was: _was('overtime', ValueKind.check),
        description: 'Whether the added shift counts as overtime.',
      ),
      PropertyItem(
        key: 'note',
        label: 'Note',
        category: 'Extra shift',
        value: _values['note'],
        was: _was('note', ValueKind.text),
        description: 'Your own words about this shift.',
      ),
      PropertyItem(
        key: 'paid',
        label: 'Paid time',
        category: 'Pay (derived)',
        value: _hours(paid),
        was: paid == savedPaid ? null : _hours(savedPaid),
        kind: ValueKind.duration,
        readOnlyReason: 'Derived: worked time minus unpaid breaks.',
      ),
      PropertyItem(
        key: 'rate',
        label: 'Hourly rate',
        category: 'Pay (derived)',
        kind: ValueKind.money,
        value: _rate,
        display: _euros(_rate),
        readOnlyReason: 'Set by the agreement from 2026-10-01.',
      ),
      PropertyItem(
        key: 'pay',
        label: 'Est. pay',
        category: 'Pay (derived)',
        kind: ValueKind.money,
        value: pay,
        display: _euros(pay),
        was: pay == savedPay ? null : _euros(savedPay),
        readOnlyReason: 'Derived from the agreement; see Working.',
      ),
      PropertyItem(
        key: 'employment',
        label: 'Employment',
        category: 'Belongs to',
        value: 'Synthetic depot',
        onFollow: _follow('Employment'),
        description: 'Opens the employment.',
      ),
      PropertyItem(
        key: 'agreement',
        label: 'Agreement',
        category: 'Belongs to',
        value: 'From 2026-10-01',
        onFollow: _follow('Agreement'),
        description: 'Opens the agreement the pay comes from.',
      ),
      const PropertyItem(
        key: 'payslip',
        label: 'Payslip',
        category: 'Belongs to',
        value: '(not yet)',
        enabled: false,
      ),
      const PropertyItem(
        key: 'state',
        label: 'State',
        category: 'Record',
        value: 'Draft',
        readOnlyReason: 'Saving finalizes the draft.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    final scale = MediaQuery.textScalerOf(context);
    final skin = LifeOSSkinScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: widget.width,
          height: scale.scale(440),
          child: PropertyGrid(
            record: 'shift:demo',
            controller: _controller,
            items: _items(),
            onCommit: _commit,
            today: galleryToday,
            enabled: knobs.enabled,
            edited: true,
          ),
        ),
        if (_followed.isNotEmpty)
          Text(
            'Followed: $_followed',
            style: skin.typography.small.copyWith(color: skin.tokens.muted),
          ),
      ],
    );
  }
}
