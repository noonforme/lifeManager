import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import 'facts.dart';
import 'ids.dart';
import 'schedule.dart';

enum CancelReason { swapped, dayOff, other }

enum LeaveType { vacation, sick }

/// One owner change to one planned date (schedules spec 3.5).
sealed class DayException {
  const DayException({
    required this.id,
    required this.employmentId,
    required this.date,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  });

  final DayExceptionId id;
  final EmploymentId employmentId;
  final LocalDate date;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;
}

/// Other times, breaks or type on a planned day.
final class ChangedDay extends DayException {
  const ChangedDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.start,
    required this.end,
    required this.endDayOffset,
    required this.breaks,
    required this.shiftTypeId,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final LocalTime start;
  final LocalTime end;
  final int endDayOffset;
  final List<FixedBreak> breaks;

  /// The type worked instead, when the type changed.
  final ShiftTypeId? shiftTypeId;
}

/// A planned day not worked and not paid.
final class CancelledDay extends DayException {
  const CancelledDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.reason,
    required this.note,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final CancelReason reason;
  final String? note;
}

/// A planned day taken as paid leave.
final class LeaveDay extends DayException {
  const LeaveDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.leaveType,
    required this.illnessStartedOn,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final LeaveType leaveType;

  /// Sick leave only; null means the default (spec 4.3).
  final LocalDate? illnessStartedOn;
}

/// A shift on a day the cycle has Off.
final class ExtraDay extends DayException {
  const ExtraDay({
    required super.id,
    required super.employmentId,
    required super.date,
    required this.start,
    required this.end,
    required this.endDayOffset,
    required this.breaks,
    required this.shiftTypeId,
    required this.countsAsOvertime,
    required super.createdAtUtc,
    required super.updatedAtUtc,
    required super.revision,
  });

  final LocalTime start;
  final LocalTime end;
  final int endDayOffset;
  final List<FixedBreak> breaks;
  final ShiftTypeId? shiftTypeId;
  final bool countsAsOvertime;
}
