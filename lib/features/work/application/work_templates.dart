import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
import '../domain/ids.dart';
import '../domain/shift.dart';

/// A break placed relative to its shift's start date.
final class BreakTemplate {
  const BreakTemplate({
    required this.startDayOffset,
    required this.start,
    required this.endDayOffset,
    required this.end,
  });

  final int startDayOffset;
  final LocalTime start;
  final int endDayOffset;
  final LocalTime end;
}

/// The shape of an earlier shift on its own wall clock: the employment,
/// zone, start and end times and break pattern, with day offsets so a night
/// shift still ends the next day. Only values the owner entered are kept;
/// the note is not.
final class ShiftTemplate {
  const ShiftTemplate({
    required this.employmentId,
    required this.timezoneId,
    required this.start,
    required this.endDayOffset,
    required this.end,
    required this.breaks,
  });

  final EmploymentId employmentId;
  final String timezoneId;
  final LocalTime start;
  final int endDayOffset;
  final LocalTime end;
  final List<BreakTemplate> breaks;

  /// The date [offset] days after [day].
  static LocalDate shift(LocalDate day, int offset) {
    final value = DateTime.utc(day.year, day.month, day.day + offset);
    return LocalDate(value.year, value.month, value.day);
  }
}

/// "From last time" (shell spec 6.7): the most recent finalized shift among
/// [shifts], as a template; null when there is none.
ShiftTemplate? shiftTemplateFromLast(
  Iterable<({WorkShift shift, List<ShiftBreak> breaks})> shifts,
  TimezoneService zones,
) {
  ({WorkShift shift, List<ShiftBreak> breaks})? last;
  for (final item in shifts) {
    if (item.shift.state != ShiftState.finalized || item.shift.endUtc == null) {
      continue;
    }
    if (last == null || item.shift.startUtc.isAfter(last.shift.startUtc)) {
      last = item;
    }
  }
  if (last == null) return null;
  final shift = last.shift;
  final zone = shift.timezoneId;
  final startDate = zones.localDateAt(shift.startUtc, zone);
  int offset(DateTime utc) {
    final date = zones.localDateAt(utc, zone);
    return DateTime.utc(date.year, date.month, date.day)
        .difference(
          DateTime.utc(startDate.year, startDate.month, startDate.day),
        )
        .inDays;
  }

  LocalTime minute(DateTime utc) {
    final time = zones.localTimeAt(utc, zone);
    return LocalTime(time.hour, time.minute);
  }

  return ShiftTemplate(
    employmentId: shift.employmentId,
    timezoneId: zone,
    start: minute(shift.startUtc),
    endDayOffset: offset(shift.endUtc!),
    end: minute(shift.endUtc!),
    breaks: [
      for (final item in last.breaks)
        if (item.endUtc case final end?)
          BreakTemplate(
            startDayOffset: offset(item.startUtc),
            start: minute(item.startUtc),
            endDayOffset: offset(end),
            end: minute(end),
          ),
    ],
  );
}
