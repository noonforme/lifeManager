import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import 'facts.dart';
import 'ids.dart';

/// A shift type's id, unique within its schedule version.
final class ShiftTypeId {
  const ShiftTypeId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is ShiftTypeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A break at a fixed wall-clock time (schedules spec 3.2).
final class FixedBreak {
  const FixedBreak({
    required this.start,
    required this.dayOffset,
    required this.minutes,
  });

  final LocalTime start;

  /// 0 on the shift's start date, 1 on the day after.
  final int dayOffset;
  final int minutes;

  /// Minutes from midnight of the shift's start date.
  int get startMinute => dayOffset * 1440 + start.hour * 60 + start.minute;

  int get endMinute => startMinute + minutes;

  @override
  bool operator ==(Object other) =>
      other is FixedBreak &&
      other.start == start &&
      other.dayOffset == dayOffset &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(start, dayOffset, minutes);
}

/// A named kind of shift, such as Day 07:00–19:00.
final class ShiftType {
  const ShiftType({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.endDayOffset,
    this.breaks = const [],
  });

  final ShiftTypeId id;
  final String name;
  final LocalTime start;
  final LocalTime end;

  /// 1 when the shift ends the day after it starts.
  final int endDayOffset;
  final List<FixedBreak> breaks;

  int get startMinute => start.hour * 60 + start.minute;
  int get endMinute => endDayOffset * 1440 + end.hour * 60 + end.minute;
  int get lengthMinutes => endMinute - startMinute;
  int get breakMinutes => breaks.fold(0, (sum, item) => sum + item.minutes);
  int get paidMinutes => lengthMinutes - breakMinutes;
}

/// [count] days of one shift type, or of Off when [shiftTypeId] is null.
final class CycleBlock {
  const CycleBlock({required this.count, required this.shiftTypeId});

  final int count;
  final ShiftTypeId? shiftTypeId;
}

/// One version of a rotation (schedules spec 3.1).
final class WorkSchedule {
  WorkSchedule({
    required this.id,
    required this.employmentId,
    required this.name,
    required this.timezoneId,
    required this.version,
    required this.cycleStart,
    required this.inUseFrom,
    required this.inUseUntil,
    required this.shiftTypes,
    required this.blocks,
    required this.createdAtUtc,
    required this.revision,
    this.usedByConfirmedDay = false,
  }) {
    if (version <= 0) throw ArgumentError.value(version, 'version');
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
  }

  final ScheduleId id;
  final EmploymentId employmentId;
  final String name;
  final String timezoneId;
  final int version;

  /// The date that is cycle day 1.
  final LocalDate cycleStart;
  final LocalDate inUseFrom;

  /// Open when null.
  final LocalDate? inUseUntil;
  final List<ShiftType> shiftTypes;
  final List<CycleBlock> blocks;
  final DateTime createdAtUtc;
  final Revision revision;

  /// Whether a confirmed day was planned from this version; such a version
  /// is never edited in place.
  final bool usedByConfirmedDay;

  int get cycleLength => blocks.fold(0, (sum, block) => sum + block.count);

  bool isInUseOn(LocalDate date) =>
      inUseFrom.compareTo(date) <= 0 &&
      (inUseUntil == null || inUseUntil!.compareTo(date) >= 0);

  /// 1-based; dates before [cycleStart] follow the rotation backwards.
  int cycleDayOf(LocalDate date) =>
      date.daysSince(cycleStart) % cycleLength + 1;

  /// The shift type the cycle places on [date], or null for Off.
  ShiftType? shiftTypeOn(LocalDate date) {
    var day = cycleDayOf(date);
    for (final block in blocks) {
      if (day <= block.count) {
        final id = block.shiftTypeId;
        return id == null ? null : typeById(id);
      }
      day -= block.count;
    }
    return null;
  }

  ShiftType? typeById(ShiftTypeId id) =>
      shiftTypes.where((type) => type.id == id).firstOrNull;
}

/// Every problem with [value], each naming its field (spec 7).
List<DomainIssue> validateSchedule(WorkSchedule value) {
  final issues = <DomainIssue>[];
  final name = value.name.trim();
  if (name.isEmpty || name.length > 60) {
    issues.add(const DomainIssue('schedule.name', field: 'name'));
  }
  if (value.timezoneId.trim().isEmpty) {
    issues.add(const DomainIssue('schedule.timezone', field: 'timezoneId'));
  }
  final until = value.inUseUntil;
  if (until != null && until.compareTo(value.inUseFrom) < 0) {
    issues.add(const DomainIssue('schedule.until', field: 'inUseUntil'));
  }
  final names = <String>{};
  for (final (index, type) in value.shiftTypes.indexed) {
    final typeName = type.name.trim();
    if (typeName.isEmpty || typeName.length > 24 || !names.add(typeName)) {
      issues.add(
        DomainIssue('schedule.typeName', field: 'shiftTypes[$index].name'),
      );
    }
    final check = checkShiftTimes(type);
    if (!check.times) {
      issues.add(
        DomainIssue('schedule.typeTimes', field: 'shiftTypes[$index].end'),
      );
    }
    if (!check.breaks) {
      issues.add(
        DomainIssue('schedule.breaks', field: 'shiftTypes[$index].breaks'),
      );
    }
  }
  if (value.blocks.isEmpty) {
    issues.add(const DomainIssue('schedule.blocks', field: 'blocks'));
  }
  for (final (index, block) in value.blocks.indexed) {
    if (block.count < 1 || block.count > 99) {
      issues.add(
        DomainIssue('schedule.blockCount', field: 'blocks[$index].count'),
      );
    }
    final typeId = block.shiftTypeId;
    if (typeId != null && value.typeById(typeId) == null) {
      issues.add(
        DomainIssue('schedule.blockType', field: 'blocks[$index].shiftTypeId'),
      );
    }
  }
  final length = value.cycleLength;
  if (value.blocks.isNotEmpty && (length < 1 || length > 366)) {
    issues.add(const DomainIssue('schedule.cycleLength', field: 'blocks'));
  }
  return List.unmodifiable(issues);
}

/// Whether a shift's times and breaks are valid (spec 3.2): it lasts more
/// than a minute and at most 24 h, and its breaks are 1..240 min, lie
/// inside it, do not overlap and leave paid time.
({bool times, bool breaks}) checkShiftTimes(ShiftType type) {
  final times =
      type.endDayOffset >= 0 &&
      type.endDayOffset <= 1 &&
      type.lengthMinutes > 0 &&
      type.lengthMinutes <= 1440;
  final ordered = [...type.breaks]
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  var previousEnd = type.startMinute;
  var breaks = true;
  for (final item in ordered) {
    if (item.minutes < 1 ||
        item.minutes > 240 ||
        item.dayOffset < 0 ||
        item.dayOffset > 1 ||
        item.startMinute < previousEnd ||
        item.endMinute > type.endMinute) {
      breaks = false;
    }
    previousEnd = item.endMinute;
  }
  if (type.breaks.isNotEmpty && type.paidMinutes <= 0) breaks = false;
  return (times: times, breaks: breaks);
}

/// Whether [candidate] shares a date with another schedule version of the
/// same employment (spec 3.1: at most one in use per date).
bool scheduleOverlaps(WorkSchedule candidate, Iterable<WorkSchedule> others) {
  for (final other in others) {
    if (other.employmentId != candidate.employmentId) continue;
    if (other.id == candidate.id && other.version == candidate.version) {
      continue;
    }
    final startsBeforeOtherEnds =
        other.inUseUntil == null ||
        candidate.inUseFrom.compareTo(other.inUseUntil!) <= 0;
    final endsAfterOtherStarts =
        candidate.inUseUntil == null ||
        candidate.inUseUntil!.compareTo(other.inUseFrom) >= 0;
    if (startsBeforeOtherEnds && endsAfterOtherStarts) return true;
  }
  return false;
}
