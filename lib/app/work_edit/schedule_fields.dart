import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/application/schedule_service.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/schedule.dart';

/// The pending value of one schedule (spec 4.2: "Save the schedule, shift
/// types and cycle together"): its fields, its shift types with their
/// breaks, its cycle and, while a used version is changed from a date, the
/// new version's start. Compared field by field, types and blocks deeply.
@immutable
final class ScheduleValues {
  const ScheduleValues({
    required this.name,
    required this.timezoneId,
    required this.cycleStart,
    required this.inUseFrom,
    required this.inUseUntil,
    required this.types,
    required this.blocks,
    this.versionFrom,
  });

  /// [value]'s fields as stored, with no new version.
  factory ScheduleValues.of(WorkSchedule value) => ScheduleValues(
    name: value.name,
    timezoneId: value.timezoneId,
    cycleStart: value.cycleStart,
    inUseFrom: value.inUseFrom,
    inUseUntil: value.inUseUntil,
    types: value.shiftTypes,
    blocks: value.blocks,
  );

  final String name;
  final String timezoneId;
  final LocalDate cycleStart;
  final LocalDate inUseFrom;
  final LocalDate? inUseUntil;
  final List<ShiftType> types;
  final List<CycleBlock> blocks;

  /// The day a new version starts (Change schedule from…), else null.
  final LocalDate? versionFrom;

  ScheduleValues copyWith({
    String? name,
    String? timezoneId,
    LocalDate? cycleStart,
    LocalDate? inUseFrom,
    LocalDate? Function()? inUseUntil,
    List<ShiftType>? types,
    List<CycleBlock>? blocks,
    LocalDate? Function()? versionFrom,
  }) => ScheduleValues(
    name: name ?? this.name,
    timezoneId: timezoneId ?? this.timezoneId,
    cycleStart: cycleStart ?? this.cycleStart,
    inUseFrom: inUseFrom ?? this.inUseFrom,
    inUseUntil: inUseUntil == null ? this.inUseUntil : inUseUntil(),
    types: types ?? this.types,
    blocks: blocks ?? this.blocks,
    versionFrom: versionFrom == null ? this.versionFrom : versionFrom(),
  );

  /// What `ScheduleService` takes for [employmentId].
  ScheduleDraft toDraft(EmploymentId employmentId) => ScheduleDraft(
    employmentId: employmentId,
    name: name,
    timezoneId: timezoneId,
    cycleStart: cycleStart,
    inUseFrom: inUseFrom,
    inUseUntil: inUseUntil,
    shiftTypes: types,
    blocks: blocks,
  );

  /// A throwaway version of these values, for validation and preview.
  WorkSchedule asSchedule({
    required EmploymentId employmentId,
    required ScheduleId id,
    required int version,
  }) => WorkSchedule(
    id: id,
    employmentId: employmentId,
    name: name,
    timezoneId: timezoneId,
    version: version,
    cycleStart: cycleStart,
    inUseFrom: versionFrom ?? inUseFrom,
    inUseUntil: inUseUntil,
    shiftTypes: types,
    blocks: blocks,
    createdAtUtc: DateTime.utc(2000),
    revision: const Revision(0),
  );

  @override
  bool operator ==(Object other) =>
      other is ScheduleValues &&
      other.name == name &&
      other.timezoneId == timezoneId &&
      other.cycleStart == cycleStart &&
      other.inUseFrom == inUseFrom &&
      other.inUseUntil == inUseUntil &&
      other.versionFrom == versionFrom &&
      _sameList(other.types, types, _sameType) &&
      _sameList(
        other.blocks,
        blocks,
        (a, b) => a.count == b.count && a.shiftTypeId == b.shiftTypeId,
      );

  @override
  int get hashCode => Object.hash(
    name,
    timezoneId,
    cycleStart,
    inUseFrom,
    inUseUntil,
    versionFrom,
    Object.hashAll([
      for (final t in types) Object.hash(t.id, t.name, t.start, t.end),
    ]),
    Object.hashAll([
      for (final b in blocks) Object.hash(b.count, b.shiftTypeId),
    ]),
  );
}

bool _sameList<T>(List<T> a, List<T> b, bool Function(T, T) same) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!same(a[i], b[i])) return false;
  }
  return true;
}

bool _sameType(ShiftType a, ShiftType b) =>
    a.id == b.id &&
    a.name == b.name &&
    a.start == b.start &&
    a.end == b.end &&
    a.endDayOffset == b.endDayOffset &&
    listEquals(a.breaks, b.breaks);

/// A schedule's field keys, and those of its types, blocks and breaks.
abstract final class ScheduleField {
  static const name = 'name';
  static const timezone = 'timezone';
  static const cycleStart = 'cycleStart';
  static const inUseFrom = 'inUseFrom';
  static const inUseUntil = 'inUseUntil';
  static const versionFrom = 'versionFrom';
  static const typeName = 'name';
  static const typeStart = 'start';
  static const typeEnd = 'end';
  static const blockDays = 'days';
  static const blockType = 'type';
  static const breakStart = 'start';
  static const breakEnd = 'end';

  /// The cycle as a whole, and the shift types as a whole.
  static const cycle = 'cycle';
  static const types = 'types';
}

/// The issue key of a shift type's [field].
String typeKey(ShiftTypeId id, String field) => 'type:${id.value}.$field';

/// The issue key of block [index]'s [field].
String blockKey(int index, String field) => 'block:$index.$field';

/// The issue key of break [index] of type [id].
String breakKey(ShiftTypeId id, int index, String field) =>
    'break:${id.value}:$index.$field';

/// Words for a schedule's problems (schedules spec 7).
abstract final class ScheduleProblems {
  static const name = 'Enter a name of up to 60 characters.';
  static const timezone = 'Enter a timezone, for example Europe/Vilnius.';
  static const until = 'In use until must be on or after In use from.';
  static const overlap =
      'Another schedule of this employment is in use on these dates.';
  static const cycle = 'The cycle needs 1 to 366 days.';
  static const blockDays = 'Enter 1 to 99.';
  static const blockType = 'Choose a shift type.';
  static const typeName = 'Enter a name of up to 24 characters.';
  static const typeNameTaken = 'Another shift type has this name.';
  static const typeTimes =
      'End must be after start and at most 24 hours later.';
  static const breaks =
      'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
      'minutes.';
  static const types =
      'Check the shift types: names must differ and breaks lie inside the '
      'shift.';
  static const schedule = 'Check the schedule.';
  static const typeInCycle = 'The cycle uses this type, so it stays.';
  static const notEditable = 'This value is not edited here.';
  static const versionFromRequired = 'Pick the day the new version starts.';
  static String confirmedUpTo(LocalDate last) =>
      'Days up to $last are confirmed under this version. Pick a later day.';
  static String afterStart(LocalDate start) =>
      'Pick a day after this version starts, $start.';
  static String afterUntil(LocalDate until) =>
      'Pick a day on or before this schedule ends, $until.';
}

/// What an edit made: new values, or the problem that refused it.
typedef ScheduleEdit = ({ScheduleValues? values, String? problem});

ScheduleEdit _ok(ScheduleValues values) => (values: values, problem: null);
ScheduleEdit _no(String problem) => (values: null, problem: problem);

/// [field] of the schedule itself takes [value]: dates as `LocalDate`
/// (In use until and the new version's start may be null), the rest text.
ScheduleEdit withScheduleField(
  ScheduleValues values,
  String field,
  Object? value,
) => switch ((field, value)) {
  (ScheduleField.name, final String text) => _ok(values.copyWith(name: text)),
  (ScheduleField.timezone, final String text) => _ok(
    values.copyWith(timezoneId: text),
  ),
  (ScheduleField.cycleStart, final LocalDate date) => _ok(
    values.copyWith(cycleStart: date),
  ),
  (ScheduleField.inUseFrom, final LocalDate date) => _ok(
    values.copyWith(inUseFrom: date),
  ),
  (ScheduleField.inUseUntil, final LocalDate? date) => _ok(
    values.copyWith(inUseUntil: () => date),
  ),
  (ScheduleField.versionFrom, final LocalDate? date) => _ok(
    values.copyWith(versionFrom: () => date),
  ),
  _ => _no(ScheduleProblems.notEditable),
};

/// Minutes from midnight of the shift's start date of a clock time that
/// falls inside or near a shift starting at [start]: before the start on
/// the clock is the next day.
int _absolute(LocalTime clock, LocalTime start) {
  final minute = clock.hour * 60 + clock.minute;
  final from = start.hour * 60 + start.minute;
  return minute < from ? minute + 1440 : minute;
}

LocalTime _clock(int minute) => LocalTime((minute % 1440) ~/ 60, minute % 60);

FixedBreak _breakAt(int startMinute, int minutes) => FixedBreak(
  start: _clock(startMinute),
  dayOffset: startMinute >= 1440 ? 1 : 0,
  minutes: minutes,
);

ScheduleEdit _withType(
  ScheduleValues values,
  ShiftTypeId id,
  ShiftType Function(ShiftType type) change,
) {
  final at = values.types.indexWhere((type) => type.id == id);
  if (at < 0) return _no(ScheduleProblems.notEditable);
  return _ok(
    values.copyWith(
      types: [
        for (final (index, type) in values.types.indexed)
          index == at ? change(type) : type,
      ],
    ),
  );
}

ShiftType _type(
  ShiftType type, {
  String? name,
  LocalTime? start,
  LocalTime? end,
  List<FixedBreak>? breaks,
}) {
  final from = start ?? type.start;
  final to = end ?? type.end;
  return ShiftType(
    id: type.id,
    name: name ?? type.name,
    start: from,
    end: to,
    endDayOffset: endDayOffsetOf(from, to),
    breaks: breaks ?? type.breaks,
  );
}

/// [field] of shift type [id] takes [value]: the name as text, start and
/// end as `LocalTime`. The day the end falls on follows from the times; its
/// breaks keep their clock times.
ScheduleEdit withTypeField(
  ScheduleValues values,
  ShiftTypeId id,
  String field,
  Object? value,
) => switch ((field, value)) {
  (ScheduleField.typeName, final String text) => _withType(
    values,
    id,
    (type) => _type(type, name: text),
  ),
  (ScheduleField.typeStart || ScheduleField.typeEnd, final LocalTime time) =>
    _withType(values, id, (type) {
      final start = field == ScheduleField.typeStart ? time : type.start;
      return _type(
        type,
        start: start,
        end: field == ScheduleField.typeEnd ? time : null,
        breaks: [
          for (final item in type.breaks)
            _breakAt(_absolute(item.start, start), item.minutes),
        ],
      );
    }),
  _ => _no(ScheduleProblems.notEditable),
};

/// A new type "Type n", 08:00–16:00 with no breaks, last.
ScheduleEdit withNewType(ScheduleValues values) {
  final names = {for (final type in values.types) type.name.trim()};
  var n = values.types.length + 1;
  while (names.contains('Type $n')) {
    n++;
  }
  return _ok(
    values.copyWith(
      types: [
        ...values.types,
        ShiftType(
          id: nextShiftTypeId(values.types),
          name: 'Type $n',
          start: const LocalTime(8, 0),
          end: const LocalTime(16, 0),
          endDayOffset: 0,
        ),
      ],
    ),
  );
}

/// Removes type [id], unless a block of the cycle uses it.
ScheduleEdit withoutType(ScheduleValues values, ShiftTypeId id) {
  if (values.blocks.any((block) => block.shiftTypeId == id)) {
    return _no(ScheduleProblems.typeInCycle);
  }
  return _ok(
    values.copyWith(
      types: [
        for (final type in values.types)
          if (type.id != id) type,
      ],
    ),
  );
}

/// [field] of block [index] takes [value]: days as text (or a number)
/// from 1 to 99; the type as a `ShiftTypeId` of this schedule, or null for
/// Off.
ScheduleEdit withBlockField(
  ScheduleValues values,
  int index,
  String field,
  Object? value,
) {
  if (index < 0 || index >= values.blocks.length) {
    return _no(ScheduleProblems.notEditable);
  }
  final block = values.blocks[index];
  final CycleBlock changed;
  switch ((field, value)) {
    case (ScheduleField.blockDays, final Object days)
        when days is String || days is int:
      final count = days is int ? days : int.tryParse((days as String).trim());
      if (count == null || count < 1 || count > 99) {
        return _no(ScheduleProblems.blockDays);
      }
      changed = CycleBlock(count: count, shiftTypeId: block.shiftTypeId);
    case (ScheduleField.blockType, final ShiftTypeId? id):
      if (id != null && !values.types.any((type) => type.id == id)) {
        return _no(ScheduleProblems.blockType);
      }
      changed = CycleBlock(count: block.count, shiftTypeId: id);
    default:
      return _no(ScheduleProblems.notEditable);
  }
  return _ok(
    values.copyWith(
      blocks: [
        for (final (at, item) in values.blocks.indexed)
          at == index ? changed : item,
      ],
    ),
  );
}

/// A new block of one Off day, last.
ScheduleEdit withNewBlock(ScheduleValues values) => _ok(
  values.copyWith(
    blocks: [...values.blocks, const CycleBlock(count: 1, shiftTypeId: null)],
  ),
);

/// Removes block [index].
ScheduleEdit withoutBlock(ScheduleValues values, int index) {
  if (index < 0 || index >= values.blocks.length) {
    return _no(ScheduleProblems.notEditable);
  }
  return _ok(values.copyWith(blocks: [...values.blocks]..removeAt(index)));
}

/// Moves block [from] to index [to] of the moved list.
ScheduleEdit withBlockMoved(ScheduleValues values, int from, int to) {
  final count = values.blocks.length;
  if (from < 0 || from >= count || to < 0 || to >= count) {
    return _no(ScheduleProblems.notEditable);
  }
  final blocks = [...values.blocks];
  blocks.insert(to, blocks.removeAt(from));
  return _ok(values.copyWith(blocks: blocks));
}

/// [field] of break [index] of type [id] takes a `LocalTime`: a new start
/// keeps the break's end; a new end sets its length.
ScheduleEdit withBreakField(
  ScheduleValues values,
  ShiftTypeId id,
  int index,
  String field,
  Object? value,
) {
  if (value is! LocalTime ||
      (field != ScheduleField.breakStart && field != ScheduleField.breakEnd)) {
    return _no(ScheduleProblems.notEditable);
  }
  final type = values.types.where((item) => item.id == id).firstOrNull;
  if (type == null || index < 0 || index >= type.breaks.length) {
    return _no(ScheduleProblems.notEditable);
  }
  final item = type.breaks[index];
  final start = item.startMinute;
  final end = item.endMinute;
  final at = _absolute(value, type.start);
  final changed = field == ScheduleField.breakStart
      ? _breakAt(at, end - at)
      : _breakAt(start, at - start);
  return _withType(
    values,
    id,
    (type) => _type(
      type,
      breaks: [
        for (final (i, other) in type.breaks.indexed)
          i == index ? changed : other,
      ],
    ),
  );
}

/// A new 30-minute break of type [id] from its middle, on the quarter hour
/// before it.
ScheduleEdit withNewBreak(ScheduleValues values, ShiftTypeId id) =>
    _withType(values, id, (type) {
      final middle = type.startMinute + type.lengthMinutes ~/ 2;
      return _type(
        type,
        breaks: [...type.breaks, _breakAt(middle - middle % 15, 30)],
      );
    });

/// Removes break [index] of type [id].
ScheduleEdit withoutBreak(ScheduleValues values, ShiftTypeId id, int index) =>
    _withType(values, id, (type) {
      if (index < 0 || index >= type.breaks.length) return type;
      return _type(type, breaks: [...type.breaks]..removeAt(index));
    });

final _indexed = RegExp(r'^(shiftTypes|blocks)\[(\d+)\]\.(\w+)$');

/// Every problem of [values] by issue key, from the domain's own rules
/// (`validateSchedule`), worded; empty when it may be saved.
Map<String, String> scheduleIssues(
  ScheduleValues values, {
  required EmploymentId employmentId,
}) {
  final issues = validateSchedule(
    values.asSchedule(
      employmentId: employmentId,
      id: const ScheduleId('pending'),
      version: 1,
    ),
  );
  final words = <String, String>{};
  for (final issue in issues) {
    final field = issue.field ?? 'schedule';
    final match = _indexed.firstMatch(field);
    if (match == null) {
      switch (field) {
        case 'name':
          words[ScheduleField.name] = ScheduleProblems.name;
        case 'timezoneId':
          words[ScheduleField.timezone] = ScheduleProblems.timezone;
        case 'inUseUntil':
          words[ScheduleField.inUseUntil] = ScheduleProblems.until;
        case 'blocks':
          words[ScheduleField.cycle] = ScheduleProblems.cycle;
        default:
          words[ScheduleField.cycle] = ScheduleProblems.schedule;
      }
      continue;
    }
    final index = int.parse(match[2]!);
    final part = match[3]!;
    if (match[1] == 'blocks') {
      words[blockKey(
        index,
        part == 'count' ? ScheduleField.blockDays : ScheduleField.blockType,
      )] = part == 'count'
          ? ScheduleProblems.blockDays
          : ScheduleProblems.blockType;
      continue;
    }
    final type = values.types[index];
    switch (part) {
      case 'name':
        final name = type.name.trim();
        final taken =
            name.isNotEmpty &&
            values.types.any(
              (other) => other.id != type.id && other.name.trim() == name,
            );
        words[typeKey(type.id, ScheduleField.typeName)] = taken
            ? ScheduleProblems.typeNameTaken
            : ScheduleProblems.typeName;
        // Every type of that name says so, whichever one was renamed.
        if (taken) {
          for (final other in values.types) {
            if (other.name.trim() == name) {
              words[typeKey(other.id, ScheduleField.typeName)] =
                  ScheduleProblems.typeNameTaken;
            }
          }
        }
      case 'end':
        words[typeKey(type.id, ScheduleField.typeEnd)] =
            ScheduleProblems.typeTimes;
      default:
        words[typeKey(type.id, 'breaks')] = ScheduleProblems.breaks;
    }
  }
  return words;
}

/// Words for a service's Invalid fields that the client checks missed.
Map<String, String> describeScheduleIssues(
  Map<String, List<FieldIssue>> fields, {
  required LocalDate? versionStart,
  required LocalDate? lastConfirmed,
}) => {
  for (final MapEntry(:key, :value) in fields.entries)
    ...switch ((key, value.firstOrNull?.code)) {
      ('inUseFrom', FieldIssueCode.conflict) => {
        ScheduleField.inUseFrom: ScheduleProblems.overlap,
      },
      ('newVersionFrom', FieldIssueCode.required) => {
        ScheduleField.versionFrom: ScheduleProblems.versionFromRequired,
      },
      ('newVersionFrom', FieldIssueCode.conflict) => {
        ScheduleField.versionFrom: lastConfirmed == null
            ? ScheduleProblems.schedule
            : ScheduleProblems.confirmedUpTo(lastConfirmed),
      },
      ('newVersionFrom', _) => {
        ScheduleField.versionFrom: versionStart == null
            ? ScheduleProblems.schedule
            : ScheduleProblems.afterStart(versionStart),
      },
      ('name', _) => {ScheduleField.name: ScheduleProblems.name},
      ('timezoneId', _) => {ScheduleField.timezone: ScheduleProblems.timezone},
      ('inUseUntil', _) => {ScheduleField.inUseUntil: ScheduleProblems.until},
      (final String field, _) when field.startsWith('shiftTypes') => {
        ScheduleField.types: ScheduleProblems.types,
      },
      (final String field, _) when field.startsWith('blocks') => {
        ScheduleField.cycle: ScheduleProblems.cycle,
      },
      _ => {ScheduleField.cycle: ScheduleProblems.schedule},
    },
};
