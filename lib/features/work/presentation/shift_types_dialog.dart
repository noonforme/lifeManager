import 'package:flutter/material.dart';

import '../../../core/time/local_time.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_time_field.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import '../../../shared/workbench/office_controls.dart';
import '../domain/schedule.dart';
import 'employment_agreement_forms.dart' show formatClock;
import 'work_formats.dart';

/// "07:00–19:00", or "19:00–07:00 +1" for a shift that ends the next day.
String typeTimes(ShiftType type) =>
    '${formatClock(type.startMinute)}–${formatClock(type.endMinute % 1440)}'
    '${type.endDayOffset == 1 ? ' +1' : ''}';

/// "None", "30 min", or "2 breaks, 45 min".
String breakSummary(ShiftType type) => switch (type.breaks.length) {
  0 => 'None',
  1 => '${type.breakMinutes} min',
  final count => '$count breaks, ${type.breakMinutes} min',
};

/// The next "type-N" id not used in [types].
ShiftTypeId nextShiftTypeId(Iterable<ShiftType> types) {
  final taken = {for (final type in types) type.id.value};
  var n = 1;
  while (taken.contains('type-$n')) {
    n++;
  }
  return ShiftTypeId('type-$n');
}

/// The Shift types dialog (schedules spec 6.4); null when cancelled.
Future<List<ShiftType>?> editShiftTypes(
  BuildContext context, {
  required List<ShiftType> types,
  required Set<ShiftTypeId> used,
}) => showDialog<List<ShiftType>>(
  context: context,
  builder: (_) => _ShiftTypesDialog(types: types, used: used),
);

final class _ShiftTypesDialog extends StatefulWidget {
  const _ShiftTypesDialog({required this.types, required this.used});

  final List<ShiftType> types;
  final Set<ShiftTypeId> used;

  @override
  State<_ShiftTypesDialog> createState() => _ShiftTypesDialogState();
}

final class _ShiftTypesDialogState extends State<_ShiftTypesDialog> {
  late final _types = [...widget.types];
  int? _selected;

  Future<void> _edit(int? index) async {
    final initial = index == null ? null : _types[index];
    final edited = await editShiftType(
      context,
      id: initial?.id ?? nextShiftTypeId(_types),
      initial: initial,
      takenNames: {
        for (final type in _types)
          if (type.id != initial?.id) type.name.trim(),
      },
    );
    if (edited == null) return;
    setState(() {
      if (index == null) {
        _types.add(edited);
        _selected = _types.length - 1;
      } else {
        _types[index] = edited;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final selected = _selected;
    final style = skin.typography.body.copyWith(color: tokens.ink);
    Widget cell(String text, double width, {Color? ink, bool head = false}) =>
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: head
              ? BoxDecoration(
                  color: tokens.chrome,
                  border: Border(right: BorderSide(color: tokens.chromeLine)),
                )
              : null,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: head
                ? skin.typography.label.copyWith(color: tokens.ink)
                : style.copyWith(color: ink),
          ),
        );
    return EraDialog(
      title: 'Shift types',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border.all(color: MillenniumColors.fieldLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    cell('Name', 90, head: true),
                    cell('Times', 104, head: true),
                    cell('Breaks', 90, head: true),
                    cell('Paid', 50, head: true),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final (index, type) in _types.indexed)
                        GestureDetector(
                          key: ValueKey('shift-type-row-$index'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _selected = index),
                          onDoubleTap: () => _edit(index),
                          child: Container(
                            height: 20,
                            color: selected == index ? tokens.selWash : null,
                            child: Row(
                              children: [
                                for (final (text, width) in [
                                  (type.name, 90.0),
                                  (typeTimes(type), 104.0),
                                  (breakSummary(type), 90.0),
                                  (formatDuration(type.paidMinutes * 60), 50.0),
                                ])
                                  cell(
                                    text,
                                    width,
                                    ink: selected == index
                                        ? tokens.selInk
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            children: [
              KeyButton(label: 'Add…', onPressed: () => _edit(null)),
              KeyButton(
                label: 'Edit…',
                onPressed: selected == null ? null : () => _edit(selected),
              ),
              KeyButton(
                label: 'Remove',
                onPressed:
                    selected == null ||
                        widget.used.contains(_types[selected].id)
                    ? null
                    : () => setState(() {
                        _types.removeAt(selected);
                        _selected = null;
                      }),
              ),
            ],
          ),
          if (selected != null && widget.used.contains(_types[selected].id))
            const InspectorNote('The cycle uses this type, so it stays.'),
        ],
      ),
      actions: [
        KeyButton(
          label: 'OK',
          kind: KeyKind.primary,
          onPressed: () => Navigator.of(context).pop(_types),
        ),
        KeyButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The Edit type dialog (spec 6.4); null when cancelled.
Future<ShiftType?> editShiftType(
  BuildContext context, {
  required ShiftTypeId id,
  ShiftType? initial,
  required Set<String> takenNames,
}) => showDialog<ShiftType>(
  context: context,
  builder: (_) =>
      _EditTypeDialog(id: id, initial: initial, takenNames: takenNames),
);

final class _TypeBreak {
  _TypeBreak(this.start, int minutes)
    : minutes = TextEditingController(text: '$minutes');

  LocalTime start;
  final TextEditingController minutes;
}

final class _EditTypeDialog extends StatefulWidget {
  const _EditTypeDialog({
    required this.id,
    required this.initial,
    required this.takenNames,
  });

  final ShiftTypeId id;
  final ShiftType? initial;
  final Set<String> takenNames;

  @override
  State<_EditTypeDialog> createState() => _EditTypeDialogState();
}

final class _EditTypeDialogState extends State<_EditTypeDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late LocalTime _start = widget.initial?.start ?? const LocalTime(7, 0);
  late LocalTime _end = widget.initial?.end ?? const LocalTime(19, 0);
  late bool _nextDay = widget.initial?.endDayOffset == 1;
  late final _breaks = [
    for (final item in widget.initial?.breaks ?? const <FixedBreak>[])
      _TypeBreak(item.start, item.minutes),
  ];
  String? _nameError;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final item in _breaks) {
      item.minutes.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final name = _name.text.trim();
    final startMinute = _start.hour * 60 + _start.minute;
    final type = ShiftType(
      id: widget.id,
      name: name,
      start: _start,
      end: _end,
      endDayOffset: _nextDay ? 1 : 0,
      breaks: [
        for (final item in _breaks)
          FixedBreak(
            start: item.start,
            // Earlier on the clock than the start: after midnight.
            dayOffset: item.start.hour * 60 + item.start.minute < startMinute
                ? 1
                : 0,
            minutes: int.tryParse(item.minutes.text.trim()) ?? 0,
          ),
      ],
    );
    final check = checkShiftTimes(type);
    setState(() {
      _nameError = name.isEmpty || name.length > 24
          ? 'Enter a name of up to 24 characters.'
          : widget.takenNames.contains(name)
          ? 'Another shift type has this name.'
          : null;
      _error = !check.times
          ? 'End must be after start and at most 24 hours later.'
          : !check.breaks
          ? 'Breaks must lie inside the shift, not overlap, and last 1 to '
                '240 minutes.'
          : null;
    });
    if (_nameError == null && _error == null) Navigator.of(context).pop(type);
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: widget.initial == null ? 'New shift type' : 'Edit shift type',
    body: EraFormScope(
      labelWidth: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraField(
            fieldKey: const ValueKey('type-name'),
            controller: _name,
            label: 'Name',
            error: _nameError,
            autofocus: true,
          ),
          const SizedBox(height: 7),
          EraTimeField(
            fieldKey: const ValueKey('type-start'),
            label: 'Start',
            value: _start,
            onChanged: (value) => setState(() => _start = value),
          ),
          const SizedBox(height: 7),
          EraTimeField(
            fieldKey: const ValueKey('type-end'),
            label: 'End',
            value: _end,
            onChanged: (value) => setState(() => _end = value),
          ),
          EraCheckBox(
            key: const ValueKey('type-next-day'),
            label: '+1 day',
            value: _nextDay,
            onChanged: (value) => setState(() => _nextDay = value),
          ),
          const SizedBox(height: 7),
          const Text('Breaks:'),
          for (final (index, item) in _breaks.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EraTimeField(
                    fieldKey: ValueKey('type-break-$index-start'),
                    semanticLabel: 'Break ${index + 1} start',
                    value: item.start,
                    onChanged: (value) => setState(() => item.start = value),
                  ),
                  EraField(
                    fieldKey: ValueKey('type-break-$index-minutes'),
                    controller: item.minutes,
                    label: 'Minutes',
                    width: EraFieldWidth.short,
                    keyboardType: TextInputType.number,
                  ),
                  KeyButton(
                    label: 'Remove',
                    onPressed: () => setState(() {
                      _breaks.remove(item);
                      item.minutes.dispose();
                    }),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          KeyButton(
            label: 'Add',
            onPressed: () => setState(
              () => _breaks.add(
                _TypeBreak(
                  LocalTime((_start.hour + 4) % 24, _start.minute),
                  30,
                ),
              ),
            ),
          ),
          if (_error case final error?)
            InspectorNote(error, tone: FactTone.negative),
        ],
      ),
    ),
    actions: [
      KeyButton(label: 'OK', kind: KeyKind.primary, onPressed: _ok),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}
