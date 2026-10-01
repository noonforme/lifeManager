import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
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

final class ShiftCreateInspector extends StatelessWidget {
  const ShiftCreateInspector({
    required this.onStartShift,
    required this.onAddManualShift,
    super.key,
  });

  final VoidCallback? onStartShift;
  final VoidCallback? onAddManualShift;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Record work', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        FilledButton(onPressed: onStartShift, child: const Text('Start shift')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onAddManualShift,
          child: const Text('Add manual shift'),
        ),
      ],
    ),
  );
}

final class RunningShiftInspector extends StatelessWidget {
  const RunningShiftInspector({
    required this.shift,
    required this.onStartBreak,
    required this.onEndShift,
    this.durationLabel,
    super.key,
  });

  final WorkShift shift;
  final VoidCallback onStartBreak;
  final VoidCallback onEndShift;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Running shift',
    child: _LifecyclePane(
      title: 'Shift running',
      durationLabel: durationLabel,
      primaryLabel: 'Start break',
      onPrimary: onStartBreak,
      secondaryLabel: 'End shift',
      onSecondary: onEndShift,
    ),
  );
}

final class OnBreakShiftInspector extends StatelessWidget {
  const OnBreakShiftInspector({
    required this.shift,
    required this.onEndBreak,
    this.durationLabel,
    super.key,
  });

  final WorkShift shift;
  final VoidCallback onEndBreak;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Shift on break',
    child: _LifecyclePane(
      title: 'Break in progress',
      durationLabel: durationLabel,
      primaryLabel: 'End break',
      onPrimary: onEndBreak,
    ),
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
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finalize shift',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Overtime, night and holiday pay are worked out from the '
            'agreement.',
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: _submit, child: const Text('Finalize shift')),
        ],
      ),
    ),
  );
}

final class ShiftEditInspector extends StatefulWidget {
  const ShiftEditInspector({
    required this.employmentId,
    required this.onSubmit,
    this.initialTimezoneId,
    this.prefill,
    this.title = 'Manual shift',
    super.key,
  });

  final EmploymentId employmentId;
  final SubmitManualShift onSubmit;
  final String? initialTimezoneId;
  final ShiftFormPrefill? prefill;
  final String title;

  @override
  State<ShiftEditInspector> createState() => _ShiftEditInspectorState();
}

final class _ShiftEditInspectorState extends State<ShiftEditInspector> {
  late final _startDate = TextEditingController(
    text: widget.prefill?.startDate.toString() ?? '',
  );
  late final _startTime = TextEditingController(
    text: _formatTime(widget.prefill?.startTime),
  );
  late final _endDate = TextEditingController(
    text: widget.prefill?.endDate?.toString() ?? '',
  );
  late final _endTime = TextEditingController(
    text: _formatTime(widget.prefill?.endTime),
  );
  late final _timezone = TextEditingController(
    text: widget.prefill?.timezoneId ?? widget.initialTimezoneId ?? '',
  );
  late final _note = TextEditingController(text: widget.prefill?.note ?? '');
  late final _breaks = <_BreakControllers>[
    for (final value in widget.prefill?.breaks ?? const <ManualBreakDraft>[])
      _BreakControllers()
        ..startDate.text = value.startDate.toString()
        ..start.text = _formatTime(value.start)
        ..endDate.text = value.endDate.toString()
        ..end.text = _formatTime(value.end),
  ];
  final _errors = <String, String>{};

  @override
  void dispose() {
    _startDate.dispose();
    _startTime.dispose();
    _endDate.dispose();
    _endTime.dispose();
    _timezone.dispose();
    _note.dispose();
    for (final value in _breaks) {
      value.dispose();
    }
    super.dispose();
  }

  void _addBreak() => setState(() => _breaks.add(_BreakControllers()));

  Future<void> _submit() async {
    final startDate = LocalDate.tryParse(_startDate.text.trim());
    final startTime = _parseTime(_startTime.text.trim());
    final endDate = LocalDate.tryParse(_endDate.text.trim());
    final endTime = _parseTime(_endTime.text.trim());
    final timezone = _timezone.text.trim();
    final breaks = <ManualBreakDraft>[];
    final errors = <String, String>{};

    if (startDate == null) errors['startDate'] = 'Enter a valid ISO date.';
    if (startTime == null) errors['startTime'] = 'Enter a valid local time.';
    if (endDate == null) errors['endDate'] = 'Enter a valid ISO date.';
    if (endTime == null) errors['endTime'] = 'Enter a valid local time.';
    if (timezone.isEmpty) errors['timezone'] = 'Enter an IANA timezone.';
    for (var index = 0; index < _breaks.length; index++) {
      final breakStartDate = LocalDate.tryParse(
        _breaks[index].startDate.text.trim(),
      );
      final start = _parseTime(_breaks[index].start.text.trim());
      final breakEndDate = LocalDate.tryParse(
        _breaks[index].endDate.text.trim(),
      );
      final end = _parseTime(_breaks[index].end.text.trim());
      if (breakStartDate == null ||
          start == null ||
          breakEndDate == null ||
          end == null) {
        errors['break-$index'] = 'Enter valid break dates and times.';
      } else {
        breaks.add(
          ManualBreakDraft(
            startDate: breakStartDate,
            start: start,
            endDate: breakEndDate,
            end: end,
          ),
        );
      }
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
        localStartDate: startDate!,
        localStartTime: startTime!,
        localEndDate: endDate!,
        localEndTime: endTime!,
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

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: widget.prefill == null ? 'Add manual shift' : widget.title,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        _field(
          key: const ValueKey('shift-start-date'),
          label: 'Start date',
          controller: _startDate,
          error: _errors['startDate'],
        ),
        _field(
          key: const ValueKey('shift-start-time'),
          label: 'Start time',
          controller: _startTime,
          error: _errors['startTime'],
        ),
        _field(
          key: const ValueKey('shift-end-date'),
          label: 'End date',
          controller: _endDate,
          error: _errors['endDate'],
        ),
        _field(
          key: const ValueKey('shift-end-time'),
          label: 'End time',
          controller: _endTime,
          error: _errors['endTime'],
        ),
        _field(
          key: const ValueKey('shift-timezone'),
          label: 'Timezone',
          controller: _timezone,
          error: _errors['timezone'],
        ),
        for (var index = 0; index < _breaks.length; index++) ...[
          _field(
            key: ValueKey('shift-break-start-date-$index'),
            label: 'Break ${index + 1} start date',
            controller: _breaks[index].startDate,
            error: _errors['break-$index'],
          ),
          _field(
            key: ValueKey('shift-break-start-$index'),
            label: 'Break ${index + 1} start time',
            controller: _breaks[index].start,
          ),
          _field(
            key: ValueKey('shift-break-end-date-$index'),
            label: 'Break ${index + 1} end date',
            controller: _breaks[index].endDate,
          ),
          _field(
            key: ValueKey('shift-break-end-$index'),
            label: 'Break ${index + 1} end time',
            controller: _breaks[index].end,
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _addBreak,
            child: const Text('Add break'),
          ),
        ),
        _field(
          key: const ValueKey('shift-note'),
          label: 'Shift note',
          controller: _note,
          maxLines: 3,
        ),
        if (_errors['shift'] case final error?) ...[
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          key: const ValueKey('save-manual-shift'),
          onPressed: _submit,
          child: const Text('Save manual shift'),
        ),
      ],
    ),
  );
}

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

final class _LifecyclePane extends StatelessWidget {
  const _LifecyclePane({
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
    this.durationLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? durationLabel;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (durationLabel != null) ...[
          const SizedBox(height: 8),
          Text(durationLabel!),
        ],
        const SizedBox(height: 18),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
      ],
    ),
  );
}

Widget _field({
  required Key key,
  required String label,
  required TextEditingController controller,
  String? error,
  int maxLines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Semantics(
    label: error == null ? label : '$label, $error',
    textField: true,
    excludeSemantics: true,
    child: TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, errorText: error),
    ),
  ),
);

/// Formats as HH:MM, adding seconds only when they are set.
String _formatTime(LocalTime? value) {
  if (value == null) return '';
  final text = value.toString();
  return value.second == 0 ? text.substring(0, 5) : text;
}

LocalTime? _parseTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?$').firstMatch(value);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final second = int.parse(match.group(3) ?? '0');
  if (hour > 23 || minute > 59 || second > 59) return null;
  return LocalTime(hour, minute, second);
}

String? _trimOptional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

final class _BreakControllers {
  final startDate = TextEditingController();
  final start = TextEditingController();
  final endDate = TextEditingController();
  final end = TextEditingController();

  void dispose() {
    startDate.dispose();
    start.dispose();
    endDate.dispose();
    end.dispose();
  }
}
