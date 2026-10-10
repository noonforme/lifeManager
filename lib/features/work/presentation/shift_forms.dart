import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../ui/ui.dart';
import '../application/work_templates.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart' show endDayOffsetOf;
import '../domain/shift.dart';

final class ManualBreakDraft {
  const ManualBreakDraft({
    required this.startDate,
    required this.start,
    required this.endDate,
    required this.end,
  });

  final LocalDate startDate;
  final LocalTime start;
  final LocalDate endDate;
  final LocalTime end;
}

final class ManualShiftDraft {
  const ManualShiftDraft({
    required this.employmentId,
    required this.localStartDate,
    required this.localStartTime,
    required this.localEndDate,
    required this.localEndTime,
    required this.timezoneId,
    required this.startFold,
    required this.endFold,
    required this.breaks,
    required this.note,
  });

  final EmploymentId employmentId;
  final LocalDate localStartDate;
  final LocalTime localStartTime;
  final LocalDate localEndDate;
  final LocalTime localEndTime;
  final String timezoneId;
  final FoldChoice? startFold;
  final FoldChoice? endFold;
  final List<ManualBreakDraft> breaks;
  final String? note;
}

/// Wall-clock values that seed the shift form when revising a draft.
final class ShiftFormPrefill {
  const ShiftFormPrefill({
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.timezoneId,
    required this.breaks,
    required this.note,
  });

  /// Converts a draft's stored UTC facts into its own zone's wall clock.
  factory ShiftFormPrefill.fromShift(
    WorkShift shift,
    List<ShiftBreak> breaks,
    TimezoneService zones,
  ) {
    final zone = shift.timezoneId;
    final end = shift.endUtc;
    return ShiftFormPrefill(
      startDate: zones.localDateAt(shift.startUtc, zone),
      startTime: zones.localTimeAt(shift.startUtc, zone),
      endDate: end == null ? null : zones.localDateAt(end, zone),
      endTime: end == null ? null : zones.localTimeAt(end, zone),
      timezoneId: zone,
      breaks: [
        for (final value in breaks)
          if (value.endUtc case final breakEnd?)
            ManualBreakDraft(
              startDate: zones.localDateAt(value.startUtc, zone),
              start: zones.localTimeAt(value.startUtc, zone),
              endDate: zones.localDateAt(breakEnd, zone),
              end: zones.localTimeAt(breakEnd, zone),
            ),
      ],
      note: shift.note,
    );
  }

  /// A new shift shaped like [template] on [day]. The note stays empty.
  factory ShiftFormPrefill.fromTemplate(
    ShiftTemplate template,
    LocalDate day,
  ) => ShiftFormPrefill(
    startDate: day,
    startTime: template.start,
    endDate: ShiftTemplate.shift(day, template.endDayOffset),
    endTime: template.end,
    timezoneId: template.timezoneId,
    breaks: [
      for (final item in template.breaks)
        ManualBreakDraft(
          startDate: ShiftTemplate.shift(day, item.startDayOffset),
          start: item.start,
          endDate: ShiftTemplate.shift(day, item.endDayOffset),
          end: item.end,
        ),
    ],
    note: null,
  );

  final LocalDate startDate;
  final LocalTime startTime;
  final LocalDate? endDate;
  final LocalTime? endTime;
  final String timezoneId;
  final List<ManualBreakDraft> breaks;
  final String? note;
}

typedef SubmitManualShift = Future<MutationOutcome<WorkShift>> Function(
  ManualShiftDraft draft,
);
typedef FinalizeAction = Future<MutationOutcome<WorkShift>> Function();

const shiftStartTimeMessage = 'Set a start time.';
const shiftEndTimeMessage = 'Set an end time.';
const breakTimesMessage = 'Set both break times, or neither.';
const shiftEndAfterStartMessage = 'The shift must end after it starts.';
const breakInsideShiftMessage = 'Keep the break inside the shift.';

/// The first step of an empty shift start time.
const _firstShiftStep = LocalTime(9, 0);

final class ShiftCreateInspector extends StatelessWidget {
  const ShiftCreateInspector({required this.onAddManualShift, super.key});

  final VoidCallback? onAddManualShift;

  @override
  Widget build(BuildContext context) => InspectorPane(
    children: [
      InspectorActions(
        children: [
          KeyButton(
            label: 'Add manual shift',
            kind: KeyKind.primary,
            onPressed: onAddManualShift,
          ),
        ],
      ),
    ],
  );
}

/// A finished shift waiting to be finalized. Overtime, night and holiday
/// pay are derived from the agreement, so there is nothing to enter.
final class FinalizeShiftInspector extends StatefulWidget {
  const FinalizeShiftInspector({
    required this.shift,
    required this.onFinalize,
    this.fields,
    this.onRemove,
    super.key,
  });

  final WorkShift shift;
  final FinalizeAction onFinalize;

  /// Asks a reason and voids the draft with no replacement.
  final VoidCallback? onRemove;

  /// The draft's times to edit, above the Finalize key.
  final Widget? fields;

  @override
  State<FinalizeShiftInspector> createState() => _FinalizeShiftInspectorState();
}

final class _FinalizeShiftInspectorState extends State<FinalizeShiftInspector> {
  String? _error;

  Future<void> _submit() async {
    final outcome = await widget.onFinalize();
    if (!mounted) return;
    if (outcome case Invalid<WorkShift>()) {
      setState(
        () => _error =
            "This shift can't be finalized. Check its times and that an "
            'agreement covers its date.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Finalize shift',
    child: InspectorPane(
      children: [
        const InspectorTitle('Finalize shift', icon: EraIconKind.shift),
        ?widget.fields,
        const InspectorText(
          'Overtime, night and holiday pay are worked out from the '
          'agreement.',
        ),
        if (_error case final error?)
          InspectorNote(error, tone: FactTone.negative),
        InspectorActions(
          children: [
            KeyButton(
              label: 'Finalize shift',
              kind: KeyKind.primary,
              onPressed: _submit,
            ),
            if (widget.onRemove case final remove?)
              KeyButton(label: 'Remove shift…', onPressed: remove),
          ],
        ),
      ],
    ),
  );
}

final class ShiftEditInspector extends StatefulWidget {
  const ShiftEditInspector({
    required this.employmentId,
    required this.onSubmit,
    required this.today,
    this.initialTimezoneId,
    this.prefill,
    this.title = 'Manual shift',
    this.readOnly = false,
    super.key,
  });

  final EmploymentId employmentId;
  final SubmitManualShift onSubmit;

  /// Shows a finalized shift's times greyed on its property sheet.
  final bool readOnly;

  /// The date a new shift starts on, and the day circled in its calendars.
  final LocalDate today;
  final String? initialTimezoneId;
  final ShiftFormPrefill? prefill;
  final String title;

  @override
  State<ShiftEditInspector> createState() => _ShiftEditInspectorState();
}

final class _ShiftEditInspectorState extends State<ShiftEditInspector> {
  late LocalDate _startDate = widget.prefill?.startDate ?? widget.today;
  late LocalTime? _startTime = widget.prefill?.startTime;
  late LocalDate _endDate = widget.prefill?.endDate ?? _startDate;
  late LocalTime? _endTime = widget.prefill?.endTime;

  /// Days from the start date to the end date. The end date keeps this
  /// distance as the start date moves, until the end date is picked itself.
  late int _endOffset;
  bool _endDatePicked = false;
  late final _timezone = TextEditingController(
    text: widget.prefill?.timezoneId ?? widget.initialTimezoneId ?? '',
  );
  late final _note = TextEditingController(text: widget.prefill?.note ?? '');
  final _breaks = <_BreakValues>[];
  final _errors = <String, String>{};

  /// The property sheet this form edits in place, if it is on one.
  PropertySheetController? _sheet;

  /// On a property sheet the sheet's keys save the form, so it has none.
  bool _onSheet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PropertySheetScope.maybeOf(context);
    _onSheet = scope != null || widget.readOnly;
    final sheet = widget.readOnly ? null : scope;
    if (sheet != _sheet) {
      _sheet?.detach(_applySheet);
      _sheet = sheet?..attach(apply: _applySheet);
    }
  }

  Future<bool> _applySheet() => _submit();

  /// Changes a field and marks the sheet as changed.
  void _edit(VoidCallback change) {
    setState(change);
    _sheet?.markDirty(true);
  }

  void _touched() => _sheet?.markDirty(true);

  @override
  void initState() {
    super.initState();
    _timezone.addListener(_touched);
    _note.addListener(_touched);
    _endOffset = _endDate.daysSince(_startDate);
    // Offsets are taken now, from the prefilled dates, so an untouched
    // draft saves exactly as given.
    for (final value in widget.prefill?.breaks ?? const <ManualBreakDraft>[]) {
      _breaks.add(
        _BreakValues(
          startOffset: value.startDate.daysSince(_startDate),
          startDate: value.startDate,
          start: value.start,
          endOffset: value.endDate.daysSince(value.startDate),
          endDate: value.endDate,
          end: value.end,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sheet?.detach(_applySheet);
    _timezone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _addBreak() => _edit(
    () => _breaks.add(
      _BreakValues(
        startOffset: 0,
        startDate: _startDate,
        endOffset: 0,
        endDate: _startDate,
      ),
    ),
  );

  /// Sets a time and, while the end date is not picked, puts it on the day
  /// the times leave it: the next day when the end time is at or before the
  /// start time, as a shift lasts a day at most, else the start date.
  void _setTimes({LocalTime? start, LocalTime? end}) => _edit(() {
    _startTime = start ?? _startTime;
    _endTime = end ?? _endTime;
    final (from, to) = (_startTime, _endTime);
    if (_endDatePicked || from == null || to == null) return;
    _endOffset = endDayOffsetOf(from, to);
    _endDate = _startDate.addDays(_endOffset);
  });

  void _setStartDate(LocalDate value) => _edit(() {
    _startDate = value;
    if (!_endDatePicked) _endDate = value.addDays(_endOffset);
    for (final pause in _breaks) {
      if (!pause.startDatePicked) {
        pause.moveStartDate(value.addDays(pause.startOffset));
      }
    }
  });

  void _pickBreakStartDate(_BreakValues pause, LocalDate value) => _edit(() {
    pause
      ..startDatePicked = true
      ..moveStartDate(value);
  });

  void _pickBreakEndDate(_BreakValues pause, LocalDate value) => _edit(() {
    pause
      ..endDate = value
      ..endDatePicked = true;
  });

  /// Saves the shift; true when it went through.
  Future<bool> _submit() async {
    final timezone = _timezone.text.trim();
    final breaks = <ManualBreakDraft>[];
    final errors = <String, String>{
      if (_startTime == null) 'startTime': shiftStartTimeMessage,
      if (_endTime == null) 'endTime': shiftEndTimeMessage,
      if (timezone.isEmpty) 'timezone': 'Enter an IANA timezone.',
    };
    final shiftStart = _startTime == null ? null : (_startDate, _startTime!);
    final shiftEnd = _endTime == null ? null : (_endDate, _endTime!);
    if (shiftStart != null &&
        shiftEnd != null &&
        _compareWall(shiftEnd, shiftStart) <= 0) {
      errors['endTime'] = shiftEndAfterStartMessage;
    }
    for (final (index, value) in _breaks.indexed) {
      final (start, end) = (value.start, value.end);
      if (start == null && end == null) continue;
      if (start == null || end == null) {
        errors['break-$index'] = breakTimesMessage;
        continue;
      }
      // Wall-clock checks only; the domain still decides daylight-saving
      // edge cases once the times are placed in their zone.
      final breakStart = (value.startDate, start);
      final breakEnd = (value.endDate, end);
      if (_compareWall(breakEnd, breakStart) <= 0 ||
          (shiftStart != null && _compareWall(breakStart, shiftStart) < 0) ||
          (shiftEnd != null && _compareWall(breakEnd, shiftEnd) > 0)) {
        errors['break-$index'] = breakInsideShiftMessage;
        continue;
      }
      breaks.add(
        ManualBreakDraft(
          startDate: value.startDate,
          start: start,
          endDate: value.endDate,
          end: end,
        ),
      );
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return false;
    }

    final outcome = await widget.onSubmit(
      ManualShiftDraft(
        employmentId: widget.employmentId,
        localStartDate: _startDate,
        localStartTime: _startTime!,
        localEndDate: _endDate,
        localEndTime: _endTime!,
        timezoneId: timezone,
        startFold: null,
        endFold: null,
        breaks: List.unmodifiable(breaks),
        note: _trimOptional(_note.text),
      ),
    );
    if (!mounted) return outcome is Committed<WorkShift>;
    if (outcome case Invalid<WorkShift>(:final fields)) {
      setState(() {
        _errors.clear();
        if (fields.containsKey('localTime')) {
          _errors['timezone'] = 'Check the local times and timezone.';
        } else {
          _errors['shift'] = 'Check the shift facts.';
        }
      });
    }
    return outcome is Committed<WorkShift>;
  }

  Widget _date(
    String key,
    String label,
    LocalDate value,
    ValueChanged<LocalDate> onChanged,
  ) => EraDateField(
    fieldKey: ValueKey(key),
    label: label,
    value: value,
    today: widget.today,
    onChanged: (picked) => onChanged(picked!),
  );

  Widget _time(
    String key,
    String label,
    LocalTime? value, {
    required LocalTime emptyStart,
    required ValueChanged<LocalTime> onChanged,
    String? error,
  }) => EraTimeField(
    fieldKey: ValueKey(key),
    label: label,
    value: value,
    emptyStart: emptyStart,
    error: error,
    onChanged: onChanged,
  );

  /// A dialog form with its own keys, or on a property sheet only the
  /// fields.
  Widget _layout({required List<Widget> fields, required List<Widget> keys}) =>
      _onSheet
      ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: fields,
        )
      : DialogForm(fields: fields, keys: keys);

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: widget.prefill == null ? 'Add manual shift' : widget.title,
    child: EraFormScope(
      labelWidth: 90,
      enabled: !widget.readOnly,
      child: _layout(
        fields: [
          _group(context, 'Times', [
            _date('shift-start-date', 'Start date', _startDate, _setStartDate),
            _time(
              'shift-start-time',
              'Start time',
              _startTime,
              emptyStart: _firstShiftStep,
              error: _errors['startTime'],
              onChanged: (value) => _setTimes(start: value),
            ),
            _date(
              'shift-end-date',
              'End date',
              _endDate,
              (value) => _edit(() {
                _endDate = value;
                _endDatePicked = true;
              }),
            ),
            _time(
              'shift-end-time',
              'End time',
              _endTime,
              emptyStart: _startTime ?? _firstShiftStep,
              error: _errors['endTime'],
              onChanged: (value) => _setTimes(end: value),
            ),
            _field(
              key: const ValueKey('shift-timezone'),
              label: 'Timezone',
              controller: _timezone,
              error: _errors['timezone'],
            ),
          ]),
          _group(context, 'Breaks', [
            for (final (index, value) in _breaks.indexed) ...[
              _date(
                'shift-break-start-date-$index',
                'Break ${index + 1} start date',
                value.startDate,
                (picked) => _pickBreakStartDate(value, picked),
              ),
              _time(
                'shift-break-start-$index',
                'Break ${index + 1} start time',
                value.start,
                emptyStart: _startTime ?? _firstShiftStep,
                error: _errors['break-$index'],
                onChanged: (picked) => _edit(() => value.start = picked),
              ),
              _date(
                'shift-break-end-date-$index',
                'Break ${index + 1} end date',
                value.endDate,
                (picked) => _pickBreakEndDate(value, picked),
              ),
              _time(
                'shift-break-end-$index',
                'Break ${index + 1} end time',
                value.end,
                emptyStart: value.start ?? _startTime ?? _firstShiftStep,
                onChanged: (picked) => _edit(() => value.end = picked),
              ),
            ],
            if (_breaks.isEmpty && widget.readOnly)
              const Text('None')
            else if (!widget.readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: KeyButton(
                  label: 'Add break',
                  kind: KeyKind.small,
                  onPressed: _addBreak,
                ),
              ),
          ]),
          if (!widget.readOnly || _note.text.isNotEmpty)
            _group(context, 'Note', [
              _field(
                key: const ValueKey('shift-note'),
                label: 'Shift note',
                controller: _note,
                maxLines: 3,
              ),
            ]),
          if (_errors['shift'] case final error?) ...[
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
        ],
        keys: [
          KeyButton(
            key: const ValueKey('save-manual-shift'),
            label: 'Save manual shift',
            kind: KeyKind.primary,
            onPressed: _submit,
          ),
          const DialogCancelKey(),
        ],
      ),
    ),
  );
}

/// A form group box on the face colour.
Widget _group(BuildContext context, String legend, List<Widget> children) =>
    GroupBox(
      legend: legend,
      background: LifeOSSkinScope.of(context).tokens.chrome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

final class ValidationFailureInspector extends StatelessWidget {
  const ValidationFailureInspector({
    required this.message,
    required this.child,
    super.key,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    label: message,
    child: child,
  );
}

Widget _field({
  required Key key,
  required String label,
  required TextEditingController controller,
  String? error,
  int maxLines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: EraField(
    fieldKey: key,
    label: label,
    controller: controller,
    error: error,
    maxLines: maxLines,
  ),
);

String? _trimOptional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Orders two wall-clock (date, time) values.
int _compareWall((LocalDate, LocalTime) a, (LocalDate, LocalTime) b) {
  final byDate = a.$1.compareTo(b.$1);
  if (byDate != 0) return byDate;
  int seconds(LocalTime time) =>
      time.hour * 3600 + time.minute * 60 + time.second;
  return seconds(a.$2).compareTo(seconds(b.$2));
}

/// One break's picked values; times stay null until set.
///
/// Its start date keeps [startOffset] days from the shift start date until
/// picked itself, and its end date keeps [endOffset] days from its start
/// date until picked itself, like the shift's own end date.
final class _BreakValues {
  _BreakValues({
    required this.startOffset,
    required this.startDate,
    required this.endOffset,
    required this.endDate,
    this.start,
    this.end,
  });

  final int startOffset;
  LocalDate startDate;
  bool startDatePicked = false;
  LocalTime? start;
  final int endOffset;
  LocalDate endDate;
  bool endDatePicked = false;
  LocalTime? end;

  /// Sets the start date; the end date follows unless it was picked.
  void moveStartDate(LocalDate value) {
    startDate = value;
    if (!endDatePicked) endDate = value.addDays(endOffset);
  }
}
