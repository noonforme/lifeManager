import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/schedule.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave.dart';
import '../edit_session/record_edit_session.dart';
import '../work_edit/leave_day_edit.dart';
import '../work_edit/planned_day_edit.dart';
import '../work_edit/shift_edit.dart';
import '../work_edit/work_records.dart';

/// The Shifts sheet's editable fields, as grid columns and property keys.
abstract final class ShiftsField {
  static const date = 'date';
  static const start = 'start';
  static const end = 'end';
  static const note = 'note';
  static const type = 'type';
  static const overtime = 'countsAsOvertime';
  static const leaveType = 'leaveType';
  static const illness = 'illnessStartedOn';
}

/// The edit of the selected Shifts row: its `RecordEditSession` with the
/// sheet's fields mapped onto the record kind's draft (spec 4.2). A planned
/// day edits its times; a new or draft shift its date, times and note.
sealed class ShiftsEdit {
  const ShiftsEdit();

  /// The session, for what every record kind shares.
  RecordEditSession<Object?, Object?> get session;

  /// The fields this record edits.
  Set<String> get editable;

  /// [field]'s pending value.
  Object? value(String field);

  /// [field]'s saved value, for "(was …)".
  Object? savedValue(String field);

  /// Takes [value] for [field]; returns the problem that keeps it in its
  /// editor, or null when taken.
  String? set(String field, Object? value);

  bool get isNew => session.isNew;
  bool get dirty => session.dirty;
  bool get frozen => session.frozen;
  EditPhase get phase => session.phase;
  String? get problem => session.problem;
  Map<String, String> get issues => session.issues;
  LeaveParticipant get participant => session;

  /// Whether [field] differs from its saved value.
  bool changed(String field) => value(field) != savedValue(field);

  /// The pending breaks, the record's children (spec 4.2: saved and
  /// reverted with it).
  List<BreakLine> get breaks;

  /// The saved breaks, for the changed marks.
  List<BreakLine> get savedBreaks;

  /// Takes [value] as [field] (`start` or `end`) of break [index]: a new
  /// start moves the break and keeps its length, a new end changes its
  /// length. Returns the problem that keeps it in its editor, or null when
  /// taken.
  String? setBreak(int index, String field, Object? value);

  /// Adds a 30-minute break: in the middle of a shift without breaks, else
  /// after the last break or in the first free half hour.
  String? addBreak();

  /// Removes break [index].
  String? removeBreak(int index);

  Future<SaveResult> save(Confirm confirm) => session.save(confirm);
  Future<SaveResult> undo(Confirm confirm) => session.undo(confirm);

  /// Reload record after Stale or Missing; Reload and check after
  /// Uncertain (spec 9).
  Future<void> reload() =>
      phase == EditPhase.uncertain ? session.check() : session.reload();

  void addListener(VoidCallback listener) => session.addListener(listener);
  void removeListener(VoidCallback listener) =>
      session.removeListener(listener);
  void dispose() => session.dispose();
}

/// An unconfirmed planned day: its times and breaks. The end's day follows
/// from the times: an end at or before the start is the next day.
final class PlannedEdit extends ShiftsEdit {
  const PlannedEdit(this.session, {this.typeChoices = const [], this.newDate});

  @override
  final RecordEditSession<PlannedDayRecord, PlannedDayValues> session;

  /// The shift types of the schedule version that plans the day: what its
  /// Type may become (plan 4d-1, Task 2).
  final List<ShiftType> typeChoices;

  /// The Off day a new extra shift is entered on, until its first save
  /// (plan 4d-1, call 8).
  final LocalDate? newDate;

  PlannedDayRecord get record => session.baseline!;

  /// The day's date, stored or new.
  LocalDate get date => session.baseline?.date ?? newDate!;

  /// The values the day is planned with, or a new extra shift's defaults.
  PlannedDayValues get _saved =>
      session.baseline?.values ?? session.adapter.draftOf(null);

  /// Whether the day is an extra shift: one on an Off day, new or stored.
  bool get isExtra => session.baseline?.day.isExtra ?? true;

  @override
  Set<String> get editable => {
    ShiftsField.start,
    ShiftsField.end,
    if (typeChoices.isNotEmpty) ShiftsField.type,
    if (isExtra) ShiftsField.overtime,
  };

  @override
  Object? value(String field) => _field(session.draft, field);

  @override
  Object? savedValue(String field) => _field(_saved, field);

  /// The cycle's own type on the day; null on an extra day, which has
  /// none.
  ShiftTypeId? get _cycleType => isExtra
      ? null
      : switch (record.exception) {
          ChangedDay(:final plannedTypeId?) => plannedTypeId,
          _ when record.values.shiftTypeId == null => record.day.type?.id,
          _ => null,
        };

  /// The name of the type [values] work: the changed one, else the
  /// cycle's own.
  String? _typeName(PlannedDayValues values) {
    final stored = session.baseline?.day.type?.name;
    final id = values.shiftTypeId ?? _cycleType;
    if (id == null) return stored;
    return typeChoices.where((type) => type.id == id).firstOrNull?.name ??
        stored;
  }

  Object? _field(PlannedDayValues values, String field) => switch (field) {
    ShiftsField.date => date,
    ShiftsField.start => values.start,
    ShiftsField.end => values.end,
    ShiftsField.type => _typeName(values),
    ShiftsField.overtime => values.countsAsOvertime,
    _ => null,
  };

  /// Takes the type named [name]: its times and breaks replace the day's.
  /// The cycle's own type clears the change of type.
  String? _setType(String name) {
    final type = typeChoices.where((value) => value.name == name).firstOrNull;
    if (type == null) return PlannedDayProblems.shiftType;
    return session.edit(
      session.draft.copyWith(
        start: type.start,
        end: type.end,
        endDayOffset: type.endDayOffset,
        breaks: type.breaks,
        shiftTypeId: () => type.id == _cycleType ? null : type.id,
      ),
      field: ShiftsField.type,
    );
  }

  @override
  String? set(String field, Object? value) {
    if (field == ShiftsField.type) {
      return value is String ? _setType(value) : PlannedDayProblems.shiftType;
    }
    if (field == ShiftsField.overtime) {
      if (!isExtra || value is! bool) return ShiftsEditProblems.notEditable;
      return session.edit(
        session.draft.copyWith(countsAsOvertime: value),
        field: field,
      );
    }
    final draft = session.draft;
    final next = switch ((field, value)) {
      (ShiftsField.start, final LocalTime start) => draft.copyWith(
        start: start,
        endDayOffset: _endDayOffset(start, draft.end),
      ),
      (ShiftsField.end, final LocalTime end) => draft.copyWith(
        end: end,
        endDayOffset: _endDayOffset(draft.start, end),
      ),
      _ => null,
    };
    if (next == null) return ShiftsEditProblems.notEditable;
    return session.edit(next, field: field);
  }

  @override
  List<BreakLine> get breaks => _lines(session.draft.breaks);

  @override
  List<BreakLine> get savedBreaks => _lines(_saved.breaks);

  static List<BreakLine> _lines(List<FixedBreak> breaks) => [
    for (final (index, item) in breaks.indexed)
      BreakLine(
        index: index,
        start: item.start,
        end: _timeAt(item.startMinute + item.minutes),
      ),
  ];

  /// A break from [start] to [end] of [draft]'s shift: on the next day
  /// when it starts before the shift does.
  static FixedBreak _break(
    PlannedDayValues draft,
    LocalTime start,
    LocalTime end,
  ) => FixedBreak(
    start: start,
    dayOffset: _minuteOf(start) < _minuteOf(draft.start) ? 1 : 0,
    minutes: _minutesBetween(start, end),
  );

  @override
  String? setBreak(int index, String field, Object? value) {
    final draft = session.draft;
    if (value is! LocalTime || index < 0 || index >= draft.breaks.length) {
      return ShiftsEditProblems.notEditable;
    }
    final line = breaks[index];
    final changed = switch (field) {
      ShiftsField.start => _break(draft, value, _endAfter(value, line)),
      ShiftsField.end => _break(draft, line.start, value),
      _ => null,
    };
    if (changed == null) return ShiftsEditProblems.notEditable;
    final next = [...draft.breaks]..[index] = changed;
    return session.edit(draft.copyWith(breaks: next), field: 'breaks');
  }

  @override
  String? addBreak() {
    final draft = session.draft;
    final start = _newBreakStart(draft.start, draft.end, breaks);
    return session.edit(
      draft.copyWith(
        breaks: [
          ...draft.breaks,
          _break(draft, start, _timeAt(_minuteOf(start) + 30)),
        ],
      ),
    );
  }

  @override
  String? removeBreak(int index) {
    final draft = session.draft;
    if (index < 0 || index >= draft.breaks.length) {
      return ShiftsEditProblems.notEditable;
    }
    return session.edit(
      draft.copyWith(breaks: [...draft.breaks]..removeAt(index)),
    );
  }
}

/// A new manual shift or a draft shift: its date, start, end and note. The
/// end's date follows from the times, and moving the date moves its breaks
/// with it.
final class StoredEdit extends ShiftsEdit {
  const StoredEdit(this.session);

  @override
  final RecordEditSession<ShiftRecord, ShiftValues> session;

  @override
  Set<String> get editable => const {
    ShiftsField.date,
    ShiftsField.start,
    ShiftsField.end,
    ShiftsField.note,
  };

  @override
  Object? value(String field) => _field(session.draft, field);

  @override
  Object? savedValue(String field) =>
      _field(session.adapter.draftOf(session.baseline), field);

  Object? _field(ShiftValues values, String field) => switch (field) {
    ShiftsField.date => values.startDate,
    ShiftsField.start => values.start,
    ShiftsField.end => values.end,
    ShiftsField.note => values.note ?? '',
    _ => null,
  };

  @override
  String? set(String field, Object? value) {
    final draft = session.draft;
    final next = switch ((field, value)) {
      (ShiftsField.date, final LocalDate date) => _moved(draft, date),
      (ShiftsField.start, final LocalTime start) => draft.copyWith(
        start: start,
        endDate: draft.startDate.addDays(_endDayOffset(start, draft.end)),
      ),
      (ShiftsField.end, final LocalTime end) => draft.copyWith(
        end: end,
        endDate: draft.startDate.addDays(_endDayOffset(draft.start, end)),
      ),
      (ShiftsField.note, final Object? note) => draft.copyWith(
        note: () => note == null || '$note'.trim().isEmpty ? null : '$note',
      ),
      _ => null,
    };
    if (next == null) return ShiftsEditProblems.notEditable;
    return session.edit(next, field: field);
  }

  @override
  List<BreakLine> get breaks => _lines(session.draft.breaks);

  @override
  List<BreakLine> get savedBreaks =>
      _lines(session.adapter.draftOf(session.baseline).breaks);

  static List<BreakLine> _lines(List<BreakValues> breaks) => [
    for (final (index, item) in breaks.indexed)
      BreakLine(index: index, start: item.start, end: item.end),
  ];

  /// A break from [start] to [end] of [draft]'s shift: on the next day
  /// when it starts before the shift does, ending the day after it starts
  /// when its end is at or before its start. An end whose wall time is
  /// [was]'s keeps [was]'s fold, so editing one end of a break in the
  /// repeated autumn hour does not move the other.
  static BreakValues _break(
    ShiftValues draft,
    LocalTime start,
    LocalTime end, {
    BreakValues? was,
  }) {
    final startDate = draft.startDate.addDays(
      _minuteOf(start) < _minuteOf(draft.start) ? 1 : 0,
    );
    final endDate = startDate.addDays(
      _minuteOf(end) <= _minuteOf(start) ? 1 : 0,
    );
    return BreakValues(
      startDate: startDate,
      start: start,
      endDate: endDate,
      end: end,
      startFold: was != null && was.startDate == startDate && was.start == start
          ? was.startFold
          : null,
      endFold: was != null && was.endDate == endDate && was.end == end
          ? was.endFold
          : null,
    );
  }

  @override
  String? setBreak(int index, String field, Object? value) {
    final draft = session.draft;
    if (value is! LocalTime || index < 0 || index >= draft.breaks.length) {
      return ShiftsEditProblems.notEditable;
    }
    final line = breaks[index];
    final was = draft.breaks[index];
    final changed = switch (field) {
      ShiftsField.start => _break(
        draft,
        value,
        _endAfter(value, line),
        was: was,
      ),
      ShiftsField.end => _break(draft, line.start, value, was: was),
      _ => null,
    };
    if (changed == null) return ShiftsEditProblems.notEditable;
    final next = [...draft.breaks]..[index] = changed;
    return session.edit(draft.copyWith(breaks: next), field: 'breaks.$index');
  }

  @override
  String? addBreak() {
    final draft = session.draft;
    final start = _newBreakStart(draft.start, draft.end, breaks);
    return session.edit(
      draft.copyWith(
        breaks: [
          ...draft.breaks,
          _break(draft, start, _timeAt(_minuteOf(start) + 30)),
        ],
      ),
    );
  }

  @override
  String? removeBreak(int index) {
    final draft = session.draft;
    if (index < 0 || index >= draft.breaks.length) {
      return ShiftsEditProblems.notEditable;
    }
    return session.edit(
      draft.copyWith(breaks: [...draft.breaks]..removeAt(index)),
    );
  }

  /// [draft] moved to start on [date], its end and breaks by as many days.
  static ShiftValues _moved(ShiftValues draft, LocalDate date) {
    final days = date.daysSince(draft.startDate);
    return draft.copyWith(
      startDate: date,
      endDate: draft.endDate.addDays(days),
      breaks: [
        for (final item in draft.breaks)
          BreakValues(
            startDate: item.startDate.addDays(days),
            start: item.start,
            endDate: item.endDate.addDays(days),
            end: item.end,
            startFold: item.startFold,
            endFold: item.endFold,
          ),
      ],
    );
  }
}

/// Words of the Shifts sheet's edits.
abstract final class ShiftsEditProblems {
  static const notEditable = 'This value cannot be changed here.';
}

/// 1 when a shift from [start] to [end] ends the next day (its end is at
/// or before its start), else 0.
int _endDayOffset(LocalTime start, LocalTime end) =>
    end.hour * 60 + end.minute <= start.hour * 60 + start.minute ? 1 : 0;

/// A break as the Breaks subform shows it: its wall-clock start and end.
@immutable
final class BreakLine {
  const BreakLine({
    required this.index,
    required this.start,
    required this.end,
  });

  final int index;
  final LocalTime start;

  /// Null while the break is still open.
  final LocalTime? end;

  /// Its length; an end at or before the start is the next day. An open
  /// break has none yet.
  int get minutes => switch (end) {
    final end? => _minutesBetween(start, end),
    null => 0,
  };

  Object? value(String field) => switch (field) {
    ShiftsField.start => start,
    ShiftsField.end => end,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is BreakLine &&
      other.index == index &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(index, start, end);
}

int _minuteOf(LocalTime time) => time.hour * 60 + time.minute;

/// Minutes from [from] to [to], the next day when [to] is not after [from].
int _minutesBetween(LocalTime from, LocalTime to) {
  final minutes = _minuteOf(to) - _minuteOf(from);
  return minutes <= 0 ? minutes + 1440 : minutes;
}

LocalTime _timeAt(int minute) {
  final wrapped = minute % 1440;
  return LocalTime(wrapped ~/ 60, wrapped % 60);
}

/// The end of [line] moved to start at [start]: it keeps its length.
LocalTime _endAfter(LocalTime start, BreakLine line) =>
    _timeAt(_minuteOf(start) + line.minutes);

/// The half hour nearest the middle of a shift from [start] to [end],
/// rounded down.
LocalTime _middle(LocalTime start, LocalTime end) {
  final middle = _minuteOf(start) + _minutesBetween(start, end) ~/ 2;
  return _timeAt(middle - middle % 30);
}

/// Where a new 30-minute break starts in a shift from [start] to [end]
/// with [breaks]: in the middle when it has none; else where the last
/// break ends, when that half hour is inside the shift and free; else the
/// first free half hour on the clock's half hours from the shift's start;
/// else in the middle, and validation names the problem.
LocalTime _newBreakStart(
  LocalTime start,
  LocalTime end,
  List<BreakLine> breaks,
) {
  if (breaks.isEmpty) return _middle(start, end);
  final length = _minutesBetween(start, end);
  // Minutes from the shift's start; a break before it is on the next day.
  int offset(LocalTime time) => (_minuteOf(time) - _minuteOf(start)) % 1440;
  final taken = [
    for (final line in breaks)
      (from: offset(line.start), to: offset(line.start) + line.minutes),
  ];
  bool free(int from) =>
      from + 30 <= length &&
      taken.every((item) => from + 30 <= item.from || item.to <= from);
  if (free(taken.last.to)) return _timeAt(_minuteOf(start) + taken.last.to);
  for (
    var from = (30 - _minuteOf(start) % 30) % 30;
    from + 30 <= length;
    from += 30
  ) {
    if (free(from)) return _timeAt(_minuteOf(start) + from);
  }
  return _middle(start, end);
}

/// An unconfirmed planned leave day: its leave and, for sick leave, when
/// the illness started (Change leave, plan 4d-1 call 7). It has no times
/// or breaks of its own.
final class LeaveEdit extends ShiftsEdit {
  const LeaveEdit(this.session);

  @override
  final RecordEditSession<LeaveDayRecord, LeaveDayValues> session;

  LeaveDayRecord get record => session.baseline!;

  @override
  Set<String> get editable => {
    ShiftsField.leaveType,
    if (session.draft.leaveType == LeaveType.sick) ShiftsField.illness,
  };

  @override
  Object? value(String field) => _field(session.draft, field);

  @override
  Object? savedValue(String field) => _field(record.values, field);

  Object? _field(LeaveDayValues values, String field) => switch (field) {
    ShiftsField.date => record.date,
    ShiftsField.leaveType => values.leaveType,
    ShiftsField.illness => values.illnessStartedOn,
    _ => null,
  };

  @override
  String? set(String field, Object? value) {
    final draft = session.draft;
    final next = switch ((field, value)) {
      (ShiftsField.leaveType, final LeaveType type) => LeaveDayValues(
        leaveType: type,
        illnessStartedOn: type == LeaveType.sick
            ? draft.illnessStartedOn
            : null,
      ),
      (ShiftsField.illness, final LocalDate? start)
          when draft.leaveType == LeaveType.sick =>
        LeaveDayValues(leaveType: draft.leaveType, illnessStartedOn: start),
      _ => null,
    };
    if (next == null) return ShiftsEditProblems.notEditable;
    return session.edit(next, field: field);
  }

  @override
  List<BreakLine> get breaks => const [];

  @override
  List<BreakLine> get savedBreaks => const [];

  @override
  String? setBreak(int index, String field, Object? value) =>
      ShiftsEditProblems.notEditable;

  @override
  String? addBreak() => ShiftsEditProblems.notEditable;

  @override
  String? removeBreak(int index) => ShiftsEditProblems.notEditable;
}
