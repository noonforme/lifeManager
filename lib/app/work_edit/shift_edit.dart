import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/app_clock.dart';
import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../core/time/timezone_service.dart';
import '../../features/work/application/manual_shift_service.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/shift.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import 'work_outcomes.dart';
import 'work_records.dart';

/// A break as its editors show it: wall-clock times in the shift's zone.
@immutable
final class BreakValues {
  const BreakValues({
    required this.startDate,
    required this.start,
    required this.endDate,
    required this.end,
    this.startFold,
    this.endFold,
  });

  final LocalDate startDate;
  final LocalTime start;
  final LocalDate endDate;
  final LocalTime end;

  /// Which of a repeated wall-clock time is meant, in the hour the clocks
  /// go back; null elsewhere.
  final FoldChoice? startFold;
  final FoldChoice? endFold;

  @override
  bool operator ==(Object other) =>
      other is BreakValues &&
      other.startDate == startDate &&
      other.start == start &&
      other.endDate == endDate &&
      other.end == end &&
      other.startFold == startFold &&
      other.endFold == endFold;

  @override
  int get hashCode =>
      Object.hash(startDate, start, endDate, end, startFold, endFold);
}

/// The pending facts of a new manual shift or a draft shift and its
/// breaks, saved and reverted together (spec 4.2).
@immutable
final class ShiftValues {
  const ShiftValues({
    required this.startDate,
    required this.start,
    required this.endDate,
    required this.end,
    required this.timezoneId,
    this.breaks = const [],
    this.note,
    this.startFold,
    this.endFold,
  });

  final LocalDate startDate;
  final LocalTime start;
  final LocalDate endDate;
  final LocalTime end;
  final String timezoneId;

  /// Which of a repeated wall-clock time is meant, in the hour the clocks
  /// go back; null elsewhere.
  final FoldChoice? startFold;
  final FoldChoice? endFold;
  final List<BreakValues> breaks;
  final String? note;

  ShiftValues copyWith({
    LocalDate? startDate,
    LocalTime? start,
    LocalDate? endDate,
    LocalTime? end,
    List<BreakValues>? breaks,
    String? Function()? note,
    FoldChoice? Function()? startFold,
    FoldChoice? Function()? endFold,
  }) => ShiftValues(
    startDate: startDate ?? this.startDate,
    start: start ?? this.start,
    endDate: endDate ?? this.endDate,
    end: end ?? this.end,
    timezoneId: timezoneId,
    breaks: breaks ?? this.breaks,
    note: note == null ? this.note : note(),
    startFold: startFold == null ? this.startFold : startFold(),
    endFold: endFold == null ? this.endFold : endFold(),
  );

  @override
  bool operator ==(Object other) =>
      other is ShiftValues &&
      other.startDate == startDate &&
      other.start == start &&
      other.endDate == endDate &&
      other.end == end &&
      other.timezoneId == timezoneId &&
      listEquals(other.breaks, breaks) &&
      other.note == note &&
      other.startFold == startFold &&
      other.endFold == endFold;

  @override
  int get hashCode => Object.hash(
    startDate,
    start,
    endDate,
    end,
    timezoneId,
    Object.hashAll(breaks),
    note,
    startFold,
    endFold,
  );
}

/// Words for a shift's problems, by field key.
abstract final class ShiftProblems {
  static const timezone = 'Set a time zone.';
  static const endAfterStart = 'The shift must end after it starts.';
  static const breakInside =
      'Keep the break inside the shift, after the one before it.';
  static const localTime =
      'That time does not exist, or is ambiguous, on that date in the '
      "shift's time zone.";
  static const cannotFinalize =
      'This shift cannot be finalized. Check its times and breaks, and that '
      'a pay agreement covers its date.';
  static const employment = 'This employment is archived or missing.';
  static const finalized =
      'Finalized: its facts are read-only. Use Correct to change it, or Void '
      'to remove it.';
  static const voided = 'Void: it stays in the history and is no longer paid.';
}

/// Why [shift] cannot be edited in place, for its description; null for a
/// draft (spec 4.2: finalized and voided shifts are read-only).
String? shiftReadOnlyReason(WorkShift shift) => switch (shift.state) {
  ShiftState.draft => null,
  ShiftState.finalized => ShiftProblems.finalized,
  ShiftState.voided => ShiftProblems.voided,
};

/// The finalization window (spec 4.2, 4.3): saving a new manual shift or a
/// draft finalizes it. For a new row Revert is labelled Discard.
ConfirmRequest finalizeRequest({required bool isNew}) => ConfirmRequest(
  title: 'Finalize shift',
  message: 'Saving finalizes this shift. Later changes need Correct.',
  proceed: 'Save and finalize',
  revert: isNew ? 'Discard' : 'Revert',
);

/// Saves a new manual shift with `ManualShiftService.createAndFinalize`
/// and a draft shift, such as a correction's replacement, with
/// `ShiftDraftRevisionService.reviseAndFinalize`, each behind the
/// finalization window (spec 4.2 save matrix, second row). Finalized and
/// voided shifts are read-only: [shiftReadOnlyReason] names why, and a
/// save of one writes nothing. One adapter serves one session.
final class ShiftAdapter
    implements RecordEditAdapter<ShiftRecord, ShiftValues> {
  ShiftAdapter({
    required this.employmentId,
    required this.defaults,
    required this.create,
    required this.revise,
    required this.reads,
    required this.timezones,
    required this.clock,
  });

  final EmploymentId employmentId;

  /// What a new shift starts with, from its schedule and agreement.
  final ShiftValues defaults;
  final ManualShiftService create;
  final ShiftDraftRevisionService revise;
  final WorkReads reads;
  final TimezoneService timezones;
  final AppClock clock;

  /// When the last create was sent: a new shift found by Reload and check
  /// was made no earlier.
  DateTime? _sentAt;

  @override
  ShiftValues draftOf(ShiftRecord? saved) {
    if (saved == null) return defaults;
    final shift = saved.shift;
    final zone = shift.timezoneId;
    // An open draft has no end yet: it starts as a zero-length shift that
    // the owner completes.
    final end = shift.endUtc ?? shift.startUtc;
    return ShiftValues(
      startDate: timezones.localDateAt(shift.startUtc, zone),
      start: timezones.localTimeAt(shift.startUtc, zone),
      endDate: timezones.localDateAt(end, zone),
      end: timezones.localTimeAt(end, zone),
      timezoneId: zone,
      breaks: [
        for (final value in saved.breaks)
          if (value.endUtc case final breakEnd?)
            BreakValues(
              startDate: timezones.localDateAt(value.startUtc, zone),
              start: timezones.localTimeAt(value.startUtc, zone),
              endDate: timezones.localDateAt(breakEnd, zone),
              end: timezones.localTimeAt(breakEnd, zone),
              startFold: _foldOf(value.startUtc, zone),
              endFold: _foldOf(breakEnd, zone),
            ),
      ],
      note: shift.note,
      startFold: _foldOf(shift.startUtc, zone),
      endFold: _foldOf(end, zone),
    );
  }

  /// Which of a repeated wall-clock time [utc] is in [zone]; null when its
  /// wall-clock time happens once.
  FoldChoice? _foldOf(DateTime utc, String zone) {
    final date = timezones.localDateAt(utc, zone);
    final time = timezones.localTimeAt(utc, zone);
    try {
      timezones.resolveLocal(date, time, zone);
      return null;
    } on AmbiguousLocalTime {
      final earlier = timezones.resolveLocal(
        date,
        time,
        zone,
        fold: FoldChoice.earlier,
      );
      return earlier.utc == utc ? FoldChoice.earlier : FoldChoice.later;
    } on Exception {
      return null;
    }
  }

  @override
  Map<String, String> validate(ShiftValues draft) {
    // Real instants when every time resolves in the zone, so a shift across
    // the repeated autumn hour orders correctly; wall-clock values
    // otherwise, and the command names the time that does not resolve.
    final zone = draft.timezoneId.trim();
    DateTime? instant(LocalDate date, LocalTime time, FoldChoice? fold) {
      try {
        return timezones.resolveLocal(date, time, zone, fold: fold).utc;
      } on Exception {
        return null;
      }
    }

    final resolved = [
      instant(draft.startDate, draft.start, draft.startFold),
      instant(draft.endDate, draft.end, draft.endFold),
      for (final item in draft.breaks) ...[
        instant(item.startDate, item.start, item.startFold),
        instant(item.endDate, item.end, item.endFold),
      ],
    ];
    final exact = !resolved.contains(null);
    DateTime moment(int index, LocalDate date, LocalTime time) =>
        exact ? resolved[index]! : _at(date, time);

    final start = moment(0, draft.startDate, draft.start);
    final end = moment(1, draft.endDate, draft.end);
    final problems = <String, String>{
      if (zone.isEmpty) 'timezoneId': ShiftProblems.timezone,
      if (!end.isAfter(start)) 'end': ShiftProblems.endAfterStart,
    };
    // Breaks are checked in start order, as the domain checks them, and a
    // problem is reported under the break's own index in the draft.
    final breaks =
        [
          for (final (index, item) in draft.breaks.indexed)
            (
              index: index,
              start: moment(2 + index * 2, item.startDate, item.start),
              end: moment(3 + index * 2, item.endDate, item.end),
            ),
        ]..sort((a, b) {
          final order = a.start.compareTo(b.start);
          return order != 0 ? order : a.index.compareTo(b.index);
        });
    var previousEnd = start;
    for (final item in breaks) {
      if (item.start.isBefore(previousEnd) ||
          !item.end.isAfter(item.start) ||
          item.end.isAfter(end)) {
        problems['breaks.${item.index}'] = ShiftProblems.breakInside;
      }
      previousEnd = item.end;
    }
    return problems;
  }

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final MapEntry(:key, :value) in fields.entries)
      key: switch ((key, value.firstOrNull?.code)) {
        ('localTime', _) => ShiftProblems.localTime,
        ('shift', FieldIssueCode.conflict) => ShiftProblems.finalized,
        ('shift', _) => ShiftProblems.cannotFinalize,
        ('employmentId', _) => ShiftProblems.employment,
        _ => WorkProblems.unknownField,
      },
  };

  @override
  Future<ConfirmRequest?> guard(
    ShiftRecord? baseline,
    ShiftValues draft,
  ) async {
    if (baseline != null && shiftReadOnlyReason(baseline.shift) != null) {
      return null;
    }
    return finalizeRequest(isNew: baseline == null);
  }

  @override
  Future<SubmitResult<ShiftRecord>> submit(
    ShiftRecord? baseline,
    ShiftValues draft, {
    Object? consent,
  }) async {
    final breaks = [
      for (final item in draft.breaks)
        ManualShiftBreak(
          localStartDate: item.startDate,
          localStartTime: item.start,
          localEndDate: item.endDate,
          localEndTime: item.end,
          startFold: item.startFold,
          endFold: item.endFold,
        ),
    ];
    final MutationOutcome<WorkShift> outcome;
    if (baseline == null) {
      _sentAt = clock.nowUtc();
      outcome = await create.createAndFinalize(
        CreateManualShiftCommand(
          employmentId: employmentId,
          localStartDate: draft.startDate,
          localStartTime: draft.start,
          localEndDate: draft.endDate,
          localEndTime: draft.end,
          timezoneId: draft.timezoneId.trim(),
          startFold: draft.startFold,
          endFold: draft.endFold,
          breaks: breaks,
          note: draft.note,
        ),
      );
    } else if (shiftReadOnlyReason(baseline.shift) != null) {
      // Read-only facts are never written in place.
      outcome = const Invalid<WorkShift>({
        'shift': [FieldIssue(FieldIssueCode.conflict)],
      });
    } else {
      final revised = await revise.reviseAndFinalize(
        ReviseShiftDraftCommand(
          id: baseline.shift.id,
          expectedRevision: baseline.shift.revision,
          localStartDate: draft.startDate,
          localStartTime: draft.start,
          localEndDate: draft.endDate,
          localEndTime: draft.end,
          timezoneId: draft.timezoneId.trim(),
          startFold: draft.startFold,
          endFold: draft.endFold,
          breaks: breaks,
          note: draft.note,
        ),
      );
      outcome = revised is Invalid<WorkShift>
          ? await _changedMeanwhile(baseline) ?? revised
          : revised;
    }
    return Submitted(await settle(outcome, (shift) => reads.shift(shift.id)));
  }

  /// The service refuses a draft that is no longer one before it checks the
  /// revision: a draft finalized, voided or revised elsewhere is Stale (or
  /// Missing), so the owner is offered Reload record rather than told the
  /// values cannot finalize. Null when the draft is unchanged.
  Future<MutationOutcome<WorkShift>?> _changedMeanwhile(
    ShiftRecord baseline,
  ) async {
    final ShiftRecord? current;
    try {
      current = await reads.shift(baseline.shift.id);
    } on Exception {
      return null;
    }
    if (current == null) return const Missing<WorkShift>();
    if (current.shift.state != ShiftState.draft ||
        current.shift.revision != baseline.shift.revision) {
      return const Stale<WorkShift>();
    }
    return null;
  }

  @override
  Future<ReadBack<ShiftRecord>> readBack(
    ShiftRecord? baseline,
    ShiftValues? submitted,
  ) async {
    if (baseline != null) {
      final current = await reads.shift(baseline.shift.id);
      if (current == null) return const ReadGone();
      return ReadFound(
        current,
        saved:
            submitted != null &&
            current.shift.state == ShiftState.finalized &&
            _stored(draftOf(current)) == _stored(submitted),
      );
    }
    final sentAt = _sentAt;
    if (submitted == null || sentAt == null) return const ReadUnknown();
    // A create writes the shift and finalizes it in one transaction: a
    // finalized manual shift with these facts, made since, is the one.
    for (final shift in await reads.shiftsOf(employmentId)) {
      if (shift.schedule != null ||
          shift.state != ShiftState.finalized ||
          shift.createdAtUtc.isBefore(sentAt)) {
        continue;
      }
      final found = await reads.shift(shift.id);
      if (found != null && _stored(draftOf(found)) == _stored(submitted)) {
        return ReadFound(found, saved: true);
      }
    }
    return const ReadNotSaved();
  }
}

/// [values] as the services store them: zone and note trimmed, an empty
/// note none.
ShiftValues _stored(ShiftValues values) {
  final note = values.note?.trim();
  return ShiftValues(
    startDate: values.startDate,
    start: values.start,
    endDate: values.endDate,
    end: values.end,
    timezoneId: values.timezoneId.trim(),
    breaks: values.breaks,
    note: note == null || note.isEmpty ? null : note,
    startFold: values.startFold,
    endFold: values.endFold,
  );
}

/// A wall-clock moment as a comparable value; never a real instant.
DateTime _at(LocalDate date, LocalTime time) => DateTime.utc(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
  time.second,
);
