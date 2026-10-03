import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_time_field.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
import '../application/work_templates.dart';
import '../domain/ids.dart';
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

/// The first step of an empty shift start time.
const _firstShiftStep = LocalTime(9, 0);

final class ShiftCreateInspector extends StatelessWidget {
  const ShiftCreateInspector({required this.onAddManualShift, super.key});

  final VoidCallback? onAddManualShift;

  @override
  Widget build(BuildContext context) => InspectorPane(
    children: [
      const InspectorTitle('Record work'),
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
    super.key,
  });

  final WorkShift shift;
  final FinalizeAction onFinalize;

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
        const InspectorTitle('Finalize shift'),
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
    super.key,
  });

  final EmploymentId employmentId;
  final SubmitManualShift onSubmit;

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
  late final int _endOffset;
  bool _endDatePicked = false;
  late final _timezone = TextEditingController(
    text: widget.prefill?.timezoneId ?? widget.initialTimezoneId ?? '',
  );
  late final _note = TextEditingController(text: widget.prefill?.note ?? '');
  late final _breaks = <_BreakValues>[
    for (final value in widget.prefill?.breaks ?? const <ManualBreakDraft>[])
      _BreakValues(
        startDate: value.startDate,
        start: value.start,
        endDate: value.endDate,
        end: value.end,
      ),
  ];
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _endOffset = _endDate.daysSince(_startDate);
  }

  @override
  void dispose() {
    _timezone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _addBreak() => setState(
    () => _breaks.add(_BreakValues(startDate: _startDate, endDate: _startDate)),
  );

  void _setStartDate(LocalDate value) => setState(() {
    _startDate = value;
    if (!_endDatePicked) _endDate = value.addDays(_endOffset);
  });

  Future<void> _submit() async {
    final timezone = _timezone.text.trim();
    final breaks = <ManualBreakDraft>[];
    final errors = <String, String>{
      if (_startTime == null) 'startTime': shiftStartTimeMessage,
      if (_endTime == null) 'endTime': shiftEndTimeMessage,
      if (timezone.isEmpty) 'timezone': 'Enter an IANA timezone.',
    };
    for (final (index, value) in _breaks.indexed) {
      final (start, end) = (value.start, value.end);
      if (start == null && end == null) continue;
      if (start == null || end == null) {
        errors['break-$index'] = breakTimesMessage;
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
      return;
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
    if (!mounted) return;
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
  }

  Widget _date(
    String key,
    String label,
    LocalDate value,
    ValueChanged<LocalDate> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: EraDateField(
      fieldKey: ValueKey(key),
      label: label,
      value: value,
      today: widget.today,
      onChanged: (picked) => onChanged(picked!),
    ),
  );

  Widget _time(
    String key,
    String label,
    LocalTime? value, {
    required LocalTime emptyStart,
    required ValueChanged<LocalTime> onChanged,
    String? error,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: EraTimeField(
      fieldKey: ValueKey(key),
      label: label,
      value: value,
      emptyStart: emptyStart,
      error: error,
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: widget.prefill == null ? 'Add manual shift' : widget.title,
    child: ListView(
      padding: inspectorInset,
      children: [
        InspectorTitle(widget.title),
        _group(context, 'Times', [
          _date('shift-start-date', 'Start date', _startDate, _setStartDate),
          _time(
            'shift-start-time',
            'Start time',
            _startTime,
            emptyStart: _firstShiftStep,
            error: _errors['startTime'],
            onChanged: (value) => setState(() => _startTime = value),
          ),
          _date(
            'shift-end-date',
            'End date',
            _endDate,
            (value) => setState(() {
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
            onChanged: (value) => setState(() => _endTime = value),
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
              (picked) => setState(() => value.startDate = picked),
            ),
            _time(
              'shift-break-start-$index',
              'Break ${index + 1} start time',
              value.start,
              emptyStart: _startTime ?? _firstShiftStep,
              error: _errors['break-$index'],
              onChanged: (picked) => setState(() => value.start = picked),
            ),
            _date(
              'shift-break-end-date-$index',
              'Break ${index + 1} end date',
              value.endDate,
              (picked) => setState(() => value.endDate = picked),
            ),
            _time(
              'shift-break-end-$index',
              'Break ${index + 1} end time',
              value.end,
              emptyStart: value.start ?? _startTime ?? _firstShiftStep,
              onChanged: (picked) => setState(() => value.end = picked),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: KeyButton(
              label: 'Add break',
              kind: KeyKind.small,
              onPressed: _addBreak,
            ),
          ),
        ]),
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
        FormFooter(
          children: [
            FilledButton(
              key: const ValueKey('save-manual-shift'),
              onPressed: _submit,
              child: const Text('Save manual shift'),
            ),
          ],
        ),
      ],
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

/// One break's picked values; times stay null until set.
final class _BreakValues {
  _BreakValues({
    required this.startDate,
    required this.endDate,
    this.start,
    this.end,
  });

  LocalDate startDate;
  LocalTime? start;
  LocalDate endDate;
  LocalTime? end;
}
