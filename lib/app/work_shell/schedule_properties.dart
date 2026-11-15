import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/schedule.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../work_edit/schedule_edit.dart';
import '../work_edit/schedule_fields.dart';
import '../work_edit/schedule_preview.dart';
import '../work_edit/work_records.dart';
import 'basis_total.dart';
import 'schedules_subform.dart' show SchedulesSubformWords;

/// Words of a schedule's and a shift type's properties (spec 4.2: the
/// description names a value's meaning, or why it is read-only).
abstract final class SchedulePropertyWords {
  static const name = 'Your name for this rotation, up to 60 characters.';
  static const timezone =
      'The timezone its times are in, for example Europe/Vilnius.';
  static const cycleStart =
      'The date that is cycle day 1. Dates before it follow the rotation '
      'backwards.';
  static const inUseFrom = 'The first day this schedule plans.';
  static const inUseUntil = 'The last day it plans; empty while it runs on.';
  static const version = 'Given when the schedule was stored.';
  static const derived = 'Worked out from the cycle and its shift types.';
  static const confirmed = 'Counted from confirmed shifts and leave.';
  static const employment = 'Back to the employment.';
  static const typeName = 'Up to 24 characters, different from the others.';
  static const typeStart = 'When the shift starts.';
  static const typeEnd =
      'When it ends; at or before the start is the next day.';
  static const ends =
      'Worked out from the times: an end at or before the start is the next '
      'day. A shift lasts 24 hours at most.';
}

/// The days of [values]' cycle, as lengths in days.
int cycleLengthOf(ScheduleValues values) =>
    values.blocks.fold(0, (sum, block) => sum + block.count);

ShiftType? _typeOf(ScheduleValues values, ShiftTypeId? id) =>
    id == null ? null : values.types.where((t) => t.id == id).firstOrNull;

/// The shifts and paid minutes of one cycle of [values].
({int shifts, int paidMinutes}) cycleTotals(ScheduleValues values) {
  var shifts = 0;
  var paid = 0;
  for (final block in values.blocks) {
    final type = _typeOf(values, block.shiftTypeId);
    if (type == null) continue;
    shifts += block.count;
    paid += block.count * type.paidMinutes;
  }
  return (shifts: shifts, paidMinutes: paid);
}

/// Today's cycle day of [values] and the type it plans (null for Off), or
/// null while it is not in use today or has no cycle.
({int day, ShiftType? type})? todayInCycle(
  ScheduleValues values,
  LocalDate today,
) {
  final length = cycleLengthOf(values);
  final from = values.versionFrom ?? values.inUseFrom;
  final until = values.inUseUntil;
  if (length == 0 ||
      today.compareTo(from) < 0 ||
      (until != null && today.compareTo(until) > 0)) {
    return null;
  }
  final day = today.daysSince(values.cycleStart) % length + 1;
  var left = day;
  for (final block in values.blocks) {
    if (left <= block.count) {
      return (day: day, type: _typeOf(values, block.shiftTypeId));
    }
    left -= block.count;
  }
  return null;
}

/// A version's state on [today]: Ended, Later or In use.
String scheduleState(LocalDate from, LocalDate? until, LocalDate today) {
  if (until != null && until.compareTo(today) < 0) return 'Ended';
  if (from.compareTo(today) > 0) return 'Later';
  return 'In use';
}

/// A count with its noun: "1 day", "12 days".
String countOf(int count, String noun) =>
    '$count ${count == 1 ? noun : '${noun}s'}';

/// The property items of a schedule's [edit] (spec 4.2): its own fields,
/// "(was …)" after a changed one with its problem, the cycle worked out,
/// and for a stored version the days confirmed from it ([row]). With
/// [readOnly] every field is read-only for that reason.
List<PropertyItem> schedulePropertyItems({
  required ScheduleSession edit,
  required ScheduleRow? row,
  required String? readOnly,
  required LocalDate today,
  SchedulePricing? pricing,
  required VoidCallback? onEmployment,
}) {
  final values = edit.draft;
  final saved = edit.baseline?.value;
  final stored = saved == null ? null : ScheduleValues.of(saved);

  PropertyItem item(
    String key,
    String label,
    String category, {
    required Object? value,
    required Object? Function(ScheduleValues values) of,
    required String description,
    ValueKind kind = ValueKind.text,
    bool optional = false,
  }) {
    final before = stored == null ? null : of(stored);
    return PropertyItem(
      key: key,
      label: label,
      category: category,
      kind: kind,
      value: value,
      optional: optional,
      was: stored != null && before != of(values)
          ? formatValue(kind, before)
          : null,
      error: edit.issues[key],
      description: description,
      readOnlyReason: readOnly,
    );
  }

  PropertyItem derived(
    String key,
    String label,
    String category,
    String value,
  ) => PropertyItem(
    key: key,
    label: label,
    category: category,
    value: value,
    readOnlyReason: SchedulePropertyWords.derived,
  );

  final length = cycleLengthOf(values);
  final totals = cycleTotals(values);
  final now = todayInCycle(values, today);
  return [
    item(
      ScheduleField.name,
      'Name',
      'Schedule',
      value: values.name,
      of: (v) => v.name,
      description: SchedulePropertyWords.name,
    ),
    PropertyItem(
      key: 'version',
      label: 'Version',
      category: 'Schedule',
      value: saved == null ? 'New' : 'v${saved.version}',
      readOnlyReason: SchedulePropertyWords.version,
    ),
    item(
      ScheduleField.timezone,
      'Timezone',
      'Schedule',
      value: values.timezoneId,
      of: (v) => v.timezoneId,
      description: SchedulePropertyWords.timezone,
    ),
    item(
      ScheduleField.cycleStart,
      'Cycle starts on',
      'Schedule',
      kind: ValueKind.date,
      value: values.cycleStart,
      of: (v) => v.cycleStart,
      description: SchedulePropertyWords.cycleStart,
    ),
    item(
      ScheduleField.inUseFrom,
      'In use from',
      'Use',
      kind: ValueKind.date,
      value: values.inUseFrom,
      of: (v) => v.inUseFrom,
      description: SchedulePropertyWords.inUseFrom,
    ),
    item(
      ScheduleField.inUseUntil,
      'In use until',
      'Use',
      kind: ValueKind.date,
      optional: true,
      value: values.inUseUntil,
      of: (v) => v.inUseUntil,
      description: SchedulePropertyWords.inUseUntil,
    ),
    derived(
      'state',
      'State',
      'Use',
      saved == null
          ? 'New'
          : scheduleState(values.inUseFrom, values.inUseUntil, today),
    ),
    derived('length', 'Length', 'Cycle', countOf(length, 'day')),
    derived('shifts', 'Shifts', 'Cycle', '${totals.shifts} per cycle'),
    derived(
      'paid',
      'Paid',
      'Cycle',
      '${formatDuration(totals.paidMinutes * 60)} per cycle',
    ),
    derived('cyclePay', 'Planned pay', 'Cycle', switch (pricing) {
      null => '',
      SchedulePricing(cyclePay: final cents?) =>
        '${BasisTotal.cents(cents).words} per cycle',
      _ => SchedulesSubformWords.noAgreement,
    }),
    if (now != null)
      derived(
        'today',
        'Today',
        'Cycle',
        'Cycle day ${now.day}, ${now.type?.name ?? 'Off'}',
      ),
    if (row != null) ...[
      PropertyItem(
        key: 'confirmed',
        label: 'Confirmed',
        category: 'Confirmed days',
        value: countOf(row.confirmedDays, 'day'),
        readOnlyReason: SchedulePropertyWords.confirmed,
      ),
      PropertyItem(
        key: 'lastConfirmed',
        label: 'Last confirmed',
        category: 'Confirmed days',
        value: row.lastConfirmed == null
            ? 'None yet'
            : eraBoxDate(row.lastConfirmed!),
        readOnlyReason: SchedulePropertyWords.confirmed,
      ),
    ],
    if (onEmployment != null)
      PropertyItem(
        key: 'employment',
        label: 'Employment',
        category: 'Belongs to',
        value: 'Open',
        description: SchedulePropertyWords.employment,
        onFollow: onEmployment,
      ),
  ];
}

/// Where the cycle uses [type]: "Block 2, cycle days 4–6", or "Not in the
/// cycle".
String typeUseOf(ScheduleValues values, ShiftTypeId type) {
  final uses = <String>[];
  var at = 1;
  for (final (index, block) in values.blocks.indexed) {
    if (block.shiftTypeId == type) {
      final days = block.count == 1 ? '$at' : '$at–${at + block.count - 1}';
      uses.add('Block ${index + 1}, cycle days $days');
    }
    at += block.count;
  }
  return uses.isEmpty ? 'Not in the cycle' : uses.join('; ');
}

/// The property items of shift [type] of [edit]'s pending schedule.
List<PropertyItem> shiftTypePropertyItems({
  required ScheduleSession edit,
  required ShiftType type,
  required String? readOnly,
}) {
  final stored = edit.baseline?.value.shiftTypes
      .where((t) => t.id == type.id)
      .firstOrNull;
  String? was(Object? before, Object? now, ValueKind kind) =>
      stored != null && before != now ? formatValue(kind, before) : null;
  return [
    PropertyItem(
      key: ScheduleField.typeName,
      label: 'Name',
      category: 'Shift type',
      value: type.name,
      was: was(stored?.name, type.name, ValueKind.text),
      error: edit.issues[typeKey(type.id, ScheduleField.typeName)],
      description: SchedulePropertyWords.typeName,
      readOnlyReason: readOnly,
    ),
    PropertyItem(
      key: ScheduleField.typeStart,
      label: 'Start',
      category: 'Shift type',
      kind: ValueKind.time,
      value: type.start,
      was: was(stored?.start, type.start, ValueKind.time),
      error: edit.issues[typeKey(type.id, ScheduleField.typeStart)],
      description: SchedulePropertyWords.typeStart,
      readOnlyReason: readOnly,
    ),
    PropertyItem(
      key: ScheduleField.typeEnd,
      label: 'End',
      category: 'Shift type',
      kind: ValueKind.time,
      value: type.end,
      was: was(stored?.end, type.end, ValueKind.time),
      error: edit.issues[typeKey(type.id, ScheduleField.typeEnd)],
      description: SchedulePropertyWords.typeEnd,
      readOnlyReason: readOnly,
    ),
    PropertyItem(
      key: 'ends',
      label: 'Ends',
      category: 'Shift type',
      value: type.endDayOffset == 0 ? 'Same day' : 'Next day',
      readOnlyReason: SchedulePropertyWords.ends,
    ),
    PropertyItem(
      key: 'length',
      label: 'Length',
      category: 'Time (derived)',
      value: formatDuration(type.lengthMinutes * 60),
      readOnlyReason: SchedulePropertyWords.derived,
    ),
    PropertyItem(
      key: 'breaks',
      label: 'Breaks',
      category: 'Time (derived)',
      value: formatDuration(type.breakMinutes * 60),
      error: edit.issues[typeKey(type.id, 'breaks')],
      readOnlyReason: SchedulePropertyWords.derived,
    ),
    PropertyItem(
      key: 'paid',
      label: 'Paid',
      category: 'Time (derived)',
      value: formatDuration(type.paidMinutes * 60),
      readOnlyReason: SchedulePropertyWords.derived,
    ),
    PropertyItem(
      key: 'cycle',
      label: 'Cycle',
      category: 'Used by',
      value: typeUseOf(edit.draft, type.id),
      readOnlyReason: SchedulePropertyWords.derived,
    ),
  ];
}
