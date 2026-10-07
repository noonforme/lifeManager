import 'package:flutter/material.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
import '../../../shared/shell/shell_dialog.dart';
import '../../../shared/workbench/era_combo.dart';
import '../../../shared/workbench/era_controls.dart';
import '../../../shared/workbench/era_date_field.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_dialog.dart';
import '../../../shared/workbench/era_field.dart';
import '../../../shared/workbench/era_form.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/era_time_field.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart' show KeyKind;
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/property_sheet.dart';
import '../application/day_plan_service.dart';
import '../domain/day_exception.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import 'employment_agreement_forms.dart' show staleMessage;
import 'work_formats.dart';
import 'work_plan_view.dart';

/// The times of a changed or extra day (schedules spec 3.5).
final class DayTimes {
  const DayTimes({
    required this.start,
    required this.end,
    required this.endDayOffset,
    required this.breaks,
    required this.shiftTypeId,
    this.countsAsOvertime = false,
  });

  final LocalTime start;
  final LocalTime end;
  final int endDayOffset;
  final List<FixedBreak> breaks;
  final ShiftTypeId? shiftTypeId;
  final bool countsAsOvertime;
}

int _minute(LocalTime time) => time.hour * 60 + time.minute;

String _hhmm(LocalTime time) => time.toString().substring(0, 5);

/// A planned shift's times on its own wall clock, to change.
DayTimes dayTimesOf(PlannedShift shift, TimezoneService timezones) {
  final zone = shift.timezoneId;
  int offset(DateTime utc) =>
      timezones.localDateAt(utc, zone).daysSince(shift.date);
  return DayTimes(
    start: timezones.localTimeAt(shift.startUtc, zone),
    end: timezones.localTimeAt(shift.endUtc, zone),
    endDayOffset: offset(shift.endUtc),
    breaks: [
      for (final item in shift.breaks)
        FixedBreak(
          start: timezones.localTimeAt(item.start, zone),
          dayOffset: offset(item.start),
          minutes: item.end.difference(item.start).inMinutes,
        ),
    ],
    shiftTypeId: shift.type?.id,
    countsAsOvertime: shift.countsAsOvertime,
  );
}

/// A type's times, or 08:00–20:00 without breaks when there is no type.
DayTimes dayTimesOfType(ShiftType? type) => type == null
    ? const DayTimes(
        start: LocalTime(8, 0),
        end: LocalTime(20, 0),
        endDayOffset: 0,
        breaks: [],
        shiftTypeId: null,
      )
    : DayTimes(
        start: type.start,
        end: type.end,
        endDayOffset: type.endDayOffset,
        breaks: type.breaks,
        shiftTypeId: type.id,
      );

/// What went wrong with a change to a day, in words; null once saved.
String? dayProblem(MutationOutcome<Object?> outcome) => switch (outcome) {
  Committed() => null,
  Invalid(:final fields) when fields.containsKey('end') =>
    'End must be after start and at most 24 hours later.',
  Invalid(:final fields) when fields.containsKey('breaks') =>
    'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
        'minutes.',
  Invalid(:final fields) when fields.containsKey('illnessStartedOn') =>
    'The illness must start on or before this day.',
  Invalid(:final fields) when fields.containsKey('shiftTypeId') =>
    'Choose a shift type of the schedule in use on this date.',
  Invalid(:final fields) when fields.containsKey('date') =>
    'This date no longer holds what it did. Close it and open it again.',
  Invalid() => 'Check the times and try again.',
  Stale() => staleMessage,
  Missing() => 'This day no longer has that change.',
  Unavailable() || Uncertain() => 'Local storage is unavailable. Try again.',
};

/// What went wrong confirming a day, in words; null once confirmed.
String? confirmProblem(MutationOutcome<ConfirmedDay> outcome) =>
    switch (outcome) {
      Committed() => null,
      Stale() => 'Already confirmed',
      Invalid(:final fields) when fields.containsKey('agreement') =>
        'No pay agreement on this date',
      Invalid() || Missing() => 'Nothing to confirm on this date',
      Unavailable() || Uncertain() => 'Not saved: local storage is unavailable',
    };

/// A day's General page (schedules spec 6.2).
final class DaySheet extends StatefulWidget {
  const DaySheet({
    required this.date,
    required this.today,
    required this.day,
    required this.confirmed,
    required this.schedule,
    required this.pay,
    required this.leavePay,
    required this.timezones,
    required this.onConfirm,
    required this.onChange,
    required this.onCancelShift,
    required this.onMarkLeave,
    required this.onAddExtra,
    required this.onRemoveException,
    super.key,
  });

  final LocalDate date;
  final LocalDate today;

  /// What the plan holds; null when no schedule is in use on [date] or the
  /// date is confirmed.
  final PlannedDay? day;
  final bool confirmed;

  /// The schedule version in use on [date].
  final WorkSchedule? schedule;
  final ExpectedPay? pay;
  final LeavePay? leavePay;
  final TimezoneService timezones;
  final Future<MutationOutcome<ConfirmedDay>> Function() onConfirm;
  final Future<MutationOutcome<DayException>> Function(DayTimes times) onChange;
  final Future<MutationOutcome<DayException>> Function(
    CancelReason reason,
    String? note,
  )
  onCancelShift;
  final Future<MutationOutcome<DayException>> Function(
    LeaveType type,
    LocalDate? illnessStartedOn,
  )
  onMarkLeave;
  final Future<MutationOutcome<DayException>> Function(DayTimes times)
  onAddExtra;
  final Future<MutationOutcome<DayException>> Function() onRemoveException;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

final class _DaySheetState extends State<DaySheet> {
  bool _editing = false;
  bool _busy = false;
  String? _error;

  bool get _past => widget.date.compareTo(widget.today) <= 0;

  Future<void> _run<T>(
    Future<MutationOutcome<T>> Function() action,
    String? Function(MutationOutcome<T>) problem, {
    bool closeOnCommit = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await action();
    if (!mounted) return;
    if (outcome is Committed<T> && closeOnCommit) {
      ShellDialogScope.closeOf(context)?.call();
      return;
    }
    setState(() {
      _busy = false;
      _error = problem(outcome);
    });
  }

  Future<void> _cancelShift() async {
    final answer = await askCancelShift(context);
    if (answer == null) return;
    await _run(
      () => widget.onCancelShift(answer.reason, answer.note),
      dayProblem,
    );
  }

  Future<void> _markLeave({LeaveType initial = LeaveType.vacation}) async {
    final current = widget.day;
    final answer = await askLeave(
      context,
      date: widget.date,
      today: widget.today,
      initial: current is PlannedLeave ? current.leaveType : initial,
      illnessStartedOn: current is PlannedLeave
          ? current.illnessStartedOn
          : null,
    );
    if (answer == null) return;
    await _run(
      () => widget.onMarkLeave(answer.type, answer.illnessStartedOn),
      dayProblem,
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final types = widget.schedule?.shiftTypes ?? const <ShiftType>[];
    final schedule = widget.schedule;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Day',
      child: InspectorPane(
        children: [
          InspectorTitle(
            spokenDate(widget.date),
            icon: EraIconKind.payPeriod,
            meta: schedule == null
                ? null
                : '${schedule.name} · cycle day '
                      '${schedule.cycleDayOf(widget.date)}',
          ),
          if (widget.confirmed)
            const InspectorText(
              'This day is confirmed. Open it from the calendar to see what '
              'was recorded.',
            )
          else
            ...switch (day) {
              null => [
                const InspectorText('No schedule is in use on this date.'),
              ],
              PlannedShift() => _shift(day, types),
              OffDay() => _off(types),
              CancelledPlan() => _cancelled(day),
              PlannedLeave() => _leave(day),
              NeedsReview() => _review(day),
            },
          if (_error case final error?)
            InspectorNote(error, tone: FactTone.negative),
        ],
      ),
    );
  }

  List<Widget> _shift(PlannedShift shift, List<ShiftType> types) {
    final times = shiftTimes(
      shift.startUtc,
      shift.endUtc,
      shift.timezoneId,
      widget.timezones,
    ).split('–');
    String clock(DateTime utc) =>
        _hhmm(widget.timezones.localTimeAt(utc, shift.timezoneId));
    final pay = widget.pay;
    return [
      InspectorFacts(legend: shift.isExtra ? 'Extra shift' : 'Planned shift', [
        Fact.words('Type', plannedShiftName(shift)),
        Fact('Start', times.first),
        Fact('End', times.last),
        Fact.words(
          'Breaks',
          shift.breaks.isEmpty
              ? 'None'
              : [
                  for (final item in shift.breaks)
                    '${clock(item.start)}, '
                        '${item.end.difference(item.start).inMinutes} min',
                ].join('; '),
        ),
        Fact('Paid time', formatDuration(shift.paidSeconds)),
        pay == null
            ? const Fact.words('Planned pay', 'No pay agreement on this date')
            : Fact('Planned pay', formatMoney(pay.amount)),
      ]),
      if (shift.changed)
        const InspectorNote('Changed from the schedule for this day.'),
      if (_editing)
        GroupBox(
          legend: shift.isExtra ? 'Extra shift' : 'Change this day',
          child: shift.isExtra
              ? DayTimesForm(
                  types: types,
                  initial: dayTimesOf(shift, widget.timezones),
                  extra: true,
                  onSubmit: widget.onAddExtra,
                )
              : DayTimesForm(
                  types: types,
                  initial: dayTimesOf(shift, widget.timezones),
                  extra: false,
                  onSubmit: widget.onChange,
                ),
        ),
      InspectorActions(
        children: [
          if (_past && !_editing)
            KeyButton(
              label: 'Confirm',
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.onConfirm,
                      confirmProblem,
                      closeOnCommit: true,
                    ),
            ),
          if (!_editing)
            KeyButton(
              label: 'Change…',
              onPressed: _busy ? null : () => setState(() => _editing = true),
            ),
          if (!shift.isExtra) ...[
            KeyButton(
              label: 'Cancel shift…',
              onPressed: _busy ? null : _cancelShift,
            ),
            KeyButton(
              label: 'Mark as leave…',
              onPressed: _busy ? null : _markLeave,
            ),
          ],
          if (shift.changed || shift.isExtra)
            KeyButton(
              label: shift.isExtra ? 'Remove extra shift' : 'Undo change',
              onPressed: _busy
                  ? null
                  : () => _run(widget.onRemoveException, dayProblem),
            ),
        ],
      ),
    ];
  }

  List<Widget> _off(List<ShiftType> types) => [
    const InspectorText('No shift planned.'),
    if (_editing)
      GroupBox(
        legend: 'Extra shift',
        child: DayTimesForm(
          types: types,
          initial: dayTimesOfType(types.firstOrNull),
          extra: true,
          onSubmit: widget.onAddExtra,
        ),
      )
    else
      InspectorActions(
        children: [
          KeyButton(
            label: 'Add extra shift…',
            onPressed: () => setState(() => _editing = true),
          ),
        ],
      ),
  ];

  List<Widget> _cancelled(CancelledPlan day) => [
    InspectorFacts(legend: 'Cancelled shift', [
      Fact.words('Shift', plannedShiftName(day.replaced)),
      Fact.words('Reason', cancelReasonLabel(day.reason)),
      if (day.note case final note?) Fact.words('Note', note),
    ]),
    InspectorActions(
      children: [
        KeyButton(
          label: 'Restore shift',
          onPressed: _busy
              ? null
              : () => _run(widget.onRemoveException, dayProblem),
        ),
      ],
    ),
  ];

  List<Widget> _leave(PlannedLeave day) {
    final pay = widget.leavePay;
    return [
      InspectorFacts(legend: 'Leave', [
        Fact.words('Leave', leaveTypeLabel(day.leaveType)),
        if (day.leaveType == LeaveType.sick)
          Fact(
            'Illness started on',
            day.illnessStartedOn?.toString() ?? 'Worked out on confirm',
          ),
        Fact('Hours', formatDuration(day.paidMinutes * 60)),
        pay == null
            ? const Fact.words('Planned pay', 'No pay agreement on this date')
            : Fact('Planned pay', formatMoney(pay.amount)),
      ]),
      if (pay != null && !pay.employerPaid)
        const InspectorNote('Paid by the social insurer, not on your payslip.'),
      if (pay != null && pay.usedFallback)
        const InspectorNote(
          'No confirmed work in the 3 months before; using the agreement '
          'rate.',
        ),
      InspectorActions(
        children: [
          if (_past)
            KeyButton(
              label: 'Confirm',
              onPressed: _busy
                  ? null
                  : () => _run(
                      widget.onConfirm,
                      confirmProblem,
                      closeOnCommit: true,
                    ),
            ),
          KeyButton(
            label: 'Change leave…',
            onPressed: _busy ? null : _markLeave,
          ),
          KeyButton(
            label: 'Restore shift',
            onPressed: _busy
                ? null
                : () => _run(widget.onRemoveException, dayProblem),
          ),
        ],
      ),
    ];
  }

  List<Widget> _review(NeedsReview day) => [
    const InspectorNote(
      'This change no longer fits the schedule on this date. It is ignored '
      'until you remove it.',
      tone: FactTone.negative,
    ),
    InspectorActions(
      children: [
        KeyButton(
          label: 'Remove change',
          onPressed: _busy
              ? null
              : () => _run(widget.onRemoveException, dayProblem),
        ),
      ],
    ),
  ];
}

/// Start, end and breaks of one day, with the type they came from.
final class DayTimesForm extends StatefulWidget {
  const DayTimesForm({
    required this.types,
    required this.initial,
    required this.extra,
    required this.onSubmit,
    this.submitLabel,
    this.leading = const [],
    this.describe = dayProblem,
    super.key,
  });

  final List<ShiftType> types;
  final DayTimes initial;

  /// An extra shift: offers "Counts as overtime".
  final bool extra;
  final Future<MutationOutcome<DayException>> Function(DayTimes times) onSubmit;

  /// Outside a Properties sheet, the key that saves; with none, the form
  /// saves through the sheet's OK and Apply.
  final String? submitLabel;

  /// Fields above the times when the form is its own dialog, such as the
  /// date quick add asks for.
  final List<Widget> leading;

  /// The words for a refused save.
  final String? Function(MutationOutcome<DayException> outcome) describe;

  @override
  State<DayTimesForm> createState() => _DayTimesFormState();
}

final class _Break {
  /// [onEdit] runs whenever the minutes are typed, so Apply lights.
  _Break(this.start, int minutes, VoidCallback onEdit)
    : minutes = TextEditingController(text: '$minutes') {
    _seen = this.minutes.text;
    this.minutes.addListener(() {
      // Selection and focus changes notify too; only typing is an edit.
      if (this.minutes.text == _seen) return;
      _seen = this.minutes.text;
      onEdit();
    });
  }

  late String _seen;

  LocalTime start;
  final TextEditingController minutes;
}

final class _DayTimesFormState extends State<DayTimesForm> {
  late ShiftTypeId? _type = widget.initial.shiftTypeId;
  late LocalTime _start = widget.initial.start;
  late LocalTime _end = widget.initial.end;
  late bool _overtime = widget.initial.countsAsOvertime;
  late final List<_Break> _breaks = [
    for (final item in widget.initial.breaks)
      _Break(item.start, item.minutes, _markDirty),
  ];
  String? _error;
  bool _submitting = false;
  PropertySheetController? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sheet = widget.submitLabel == null
        ? PropertySheetScope.maybeOf(context)
        : null;
    if (sheet != _sheet) {
      _sheet?.detach(_apply);
      _sheet = sheet?..attach(apply: _apply);
    }
  }

  @override
  void dispose() {
    _sheet?.detach(_apply);
    for (final item in _breaks) {
      item.minutes.dispose();
    }
    super.dispose();
  }

  void _markDirty() => _sheet?.markDirty(true);

  String _signature() => [
    _type,
    _start,
    _end,
    _overtime,
    for (final item in _breaks) '${item.start} ${item.minutes.text}',
  ].join('|');

  void _changed(VoidCallback change) {
    final before = _signature();
    setState(change);
    if (_signature() != before) _markDirty();
  }

  void _useType(ShiftTypeId? id) => _changed(() {
    _type = id;
    final type = widget.types.where((value) => value.id == id).firstOrNull;
    if (type == null) return;
    _start = type.start;
    _end = type.end;
    for (final item in _breaks) {
      item.minutes.dispose();
    }
    _breaks
      ..clear()
      ..addAll([
        for (final item in type.breaks)
          _Break(item.start, item.minutes, _markDirty),
      ]);
  });

  DayTimes _value() => DayTimes(
    start: _start,
    end: _end,
    endDayOffset: endDayOffsetOf(_start, _end),
    breaks: [
      for (final item in _breaks)
        FixedBreak(
          start: item.start,
          // A break earlier on the clock than the start is after midnight.
          dayOffset: _minute(item.start) < _minute(_start) ? 1 : 0,
          minutes: int.tryParse(item.minutes.text.trim()) ?? 0,
        ),
    ],
    shiftTypeId: _type,
    countsAsOvertime: _overtime,
  );

  Future<bool> _apply() async => await _submit() is Committed<DayException>;

  Future<MutationOutcome<DayException>> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final outcome = await widget.onSubmit(_value());
    if (!mounted) return outcome;
    // With its own keys the form is its dialog, which closes once saved.
    if (outcome is Committed<DayException> && widget.submitLabel != null) {
      ShellDialogScope.closeOf(context)?.call();
      return outcome;
    }
    setState(() {
      _submitting = false;
      _error = widget.describe(outcome);
    });
    return outcome;
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      EraLabelled(
        label: 'Shift type',
        field: EraCombo<ShiftTypeId?>(
          key: const ValueKey('day-type'),
          semanticLabel: 'Shift type',
          value: _type,
          minWidth: 120,
          items: [
            for (final type in widget.types)
              EraComboItem<ShiftTypeId?>(type.id, type.name),
            const EraComboItem<ShiftTypeId?>(null, '(custom times)'),
          ],
          onSelected: _useType,
        ),
      ),
      EraTimeField(
        fieldKey: const ValueKey('day-start'),
        label: 'Start',
        value: _start,
        onChanged: (value) => _changed(() => _start = value),
      ),
      EraTimeField(
        fieldKey: const ValueKey('day-end'),
        label: 'End',
        value: _end,
        onChanged: (value) => _changed(() => _end = value),
      ),
      if (endDayOffsetOf(_start, _end) == 1)
        const InspectorNote('Ends the next day.'),
      for (final (index, item) in _breaks.indexed)
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Break ${index + 1}:'),
            EraTimeField(
              fieldKey: ValueKey('day-break-$index-start'),
              semanticLabel: 'Break ${index + 1} start',
              value: item.start,
              onChanged: (value) => _changed(() => item.start = value),
            ),
            EraField(
              fieldKey: ValueKey('day-break-$index-minutes'),
              controller: item.minutes,
              label: 'Minutes',
              width: EraFieldWidth.short,
              keyboardType: TextInputType.number,
            ),
            KeyButton(
              label: 'Remove',
              onPressed: () => _changed(() {
                _breaks.remove(item);
                item.minutes.dispose();
              }),
            ),
          ],
        ),
      KeyButton(
        label: 'Add break',
        onPressed: () => _changed(
          () => _breaks.add(
            _Break(
              LocalTime((_start.hour + 4) % 24, _start.minute),
              30,
              _markDirty,
            ),
          ),
        ),
      ),
      if (widget.extra)
        EraCheckBox(
          key: const ValueKey('day-overtime'),
          label: 'Counts as overtime',
          value: _overtime,
          onChanged: (value) => _changed(() => _overtime = value),
        ),
      if (_error case final error?)
        InspectorNote(error, tone: FactTone.negative),
    ];
    final label = widget.submitLabel;
    final column = EraFormScope(
      labelWidth: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in fields)
            Padding(padding: const EdgeInsets.only(bottom: 7), child: field),
        ],
      ),
    );
    if (label == null) return column;
    // Its own dialog: the keys stay at the dialog's foot (DESIGN.md).
    return DialogForm(
      fields: [...widget.leading, column],
      keys: [
        KeyButton(
          label: label,
          kind: KeyKind.primary,
          onPressed: _submitting ? null : _submit,
        ),
        const DialogCancelKey(),
      ],
    );
  }
}

/// "Cancel shift": why a planned shift is not worked (spec 6.2).
Future<({CancelReason reason, String? note})?> askCancelShift(
  BuildContext context,
) => showDialog(context: context, builder: (_) => const _CancelShiftDialog());

final class _CancelShiftDialog extends StatefulWidget {
  const _CancelShiftDialog();

  @override
  State<_CancelShiftDialog> createState() => _CancelShiftDialogState();
}

final class _CancelShiftDialogState extends State<_CancelShiftDialog> {
  var _reason = CancelReason.swapped;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Cancel shift',
    body: EraFormScope(
      labelWidth: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why is this shift not worked?'),
          const SizedBox(height: 7),
          EraRadioGroup<CancelReason>(
            options: const [
              EraRadioOption(CancelReason.swapped, 'Swapped'),
              EraRadioOption(CancelReason.dayOff, 'Day off'),
              EraRadioOption(CancelReason.other, 'Other'),
            ],
            groupValue: _reason,
            onChanged: (value) => setState(() => _reason = value),
          ),
          const SizedBox(height: 7),
          EraField(
            fieldKey: const ValueKey('cancel-note'),
            controller: _note,
            label: 'Note',
          ),
          const SizedBox(height: 7),
          const Text('Illness is marked as sick leave, not cancelled.'),
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop((
          reason: _reason,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        )),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

/// "Mark as leave": vacation or sick, and for sick the illness's start
/// (blank works it out from the run of sick days, spec 4.3).
Future<({LeaveType type, LocalDate? illnessStartedOn})?> askLeave(
  BuildContext context, {
  required LocalDate date,
  required LocalDate today,
  LeaveType initial = LeaveType.vacation,
  LocalDate? illnessStartedOn,
}) => showDialog(
  context: context,
  builder: (_) => _LeaveDialog(
    date: date,
    today: today,
    initial: initial,
    illnessStartedOn: illnessStartedOn,
  ),
);

final class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog({
    required this.date,
    required this.today,
    required this.initial,
    required this.illnessStartedOn,
  });

  final LocalDate date;
  final LocalDate today;
  final LeaveType initial;
  final LocalDate? illnessStartedOn;

  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

final class _LeaveDialogState extends State<_LeaveDialog> {
  late var _type = widget.initial;
  late LocalDate? _illness = widget.illnessStartedOn;

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Mark as leave',
    body: EraFormScope(
      labelWidth: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EraRadioGroup<LeaveType>(
            options: const [
              EraRadioOption(LeaveType.vacation, 'Vacation'),
              EraRadioOption(LeaveType.sick, 'Sick'),
            ],
            groupValue: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          if (_type == LeaveType.sick) ...[
            const SizedBox(height: 7),
            EraDateField(
              fieldKey: const ValueKey('leave-illness-start'),
              label: 'Illness started on',
              value: _illness,
              optional: true,
              today: widget.today,
              onChanged: (value) => setState(() => _illness = value),
            ),
            const SizedBox(height: 4),
            const Text('Leave blank to count from the first sick day.'),
          ],
        ],
      ),
    ),
    actions: [
      KeyButton(
        label: 'OK',
        kind: KeyKind.primary,
        onPressed: () => Navigator.of(context).pop((
          type: _type,
          illnessStartedOn: _type == LeaveType.sick ? _illness : null,
        )),
      ),
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}
