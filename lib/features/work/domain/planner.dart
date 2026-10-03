import '../../../core/time/local_date.dart';
import 'day_exception.dart';
import 'ids.dart';
import 'pay_premiums.dart';
import 'schedule.dart';

typedef Span = ({DateTime start, DateTime end});

/// What one date holds after schedules and exceptions (spec 3.4).
sealed class PlannedDay {
  const PlannedDay(this.date);

  final LocalDate date;
}

/// The cycle has Off and nothing was added.
final class OffDay extends PlannedDay {
  const OffDay(
    super.date, {
    required this.scheduleId,
    required this.scheduleVersion,
  });

  final ScheduleId scheduleId;
  final int scheduleVersion;
}

final class PlannedShift extends PlannedDay {
  const PlannedShift(
    super.date, {
    required this.scheduleId,
    required this.scheduleVersion,
    required this.timezoneId,
    required this.type,
    required this.startUtc,
    required this.endUtc,
    required this.breaks,
    required this.overtimeWindow,
    required this.isExtra,
    required this.countsAsOvertime,
    required this.changed,
  });

  final ScheduleId scheduleId;
  final int scheduleVersion;
  final String timezoneId;

  /// Null for an extra shift with custom times.
  final ShiftType? type;
  final DateTime startUtc;
  final DateTime endUtc;
  final List<Span> breaks;

  /// Paid time outside this window is overtime once confirmed; null for
  /// extras, which are all or nothing.
  final Span? overtimeWindow;
  final bool isExtra;
  final bool countsAsOvertime;
  final bool changed;

  int get paidSeconds =>
      endUtc.difference(startUtc).inSeconds -
      breaks.fold(
        0,
        (sum, item) => sum + item.end.difference(item.start).inSeconds,
      );
}

final class PlannedLeave extends PlannedDay {
  const PlannedLeave(
    super.date, {
    required this.scheduleId,
    required this.scheduleVersion,
    required this.leaveType,
    required this.illnessStartedOn,
    required this.paidMinutes,
    required this.replaced,
  });

  final ScheduleId scheduleId;
  final int scheduleVersion;
  final LeaveType leaveType;
  final LocalDate? illnessStartedOn;
  final int paidMinutes;
  final PlannedShift replaced;
}

final class CancelledPlan extends PlannedDay {
  const CancelledPlan(
    super.date, {
    required this.reason,
    required this.note,
    required this.replaced,
  });

  final CancelReason reason;
  final String? note;
  final PlannedShift replaced;
}

/// An exception that no longer fits what the cycle holds on its date. It
/// is ignored until edited or removed (spec 3.5).
final class NeedsReview extends PlannedDay {
  const NeedsReview(
    super.date, {
    required this.exception,
    required this.underlying,
  });

  final DayException exception;
  final PlannedDay underlying;
}

/// Plans [from]..[to] inclusive. Dates with no version in use, and
/// [confirmedDates], are left out.
List<PlannedDay> planDays({
  required LocalDate from,
  required LocalDate to,
  required Iterable<WorkSchedule> schedules,
  required Iterable<DayException> exceptions,
  required Set<LocalDate> confirmedDates,
  required ZoneClocks zoneClocks,
}) {
  final versions = schedules.toList(growable: false);
  final byDate = {for (final item in exceptions) item.date: item};
  final days = <PlannedDay>[];
  for (var date = from; date.compareTo(to) <= 0; date = date.addDays(1)) {
    if (confirmedDates.contains(date)) continue;
    final schedule = versions
        .where((value) => value.isInUseOn(date))
        .firstOrNull;
    if (schedule == null) continue;
    final clock = zoneClocks(schedule.timezoneId);
    DateTime at(LocalDate day, int minuteOfDay) =>
        clock.toInstants(day, minuteOfDay).first;
    DateTime atMinute(int minuteFromStartDate) => at(
      date.addDays(minuteFromStartDate ~/ 1440),
      minuteFromStartDate % 1440,
    );

    PlannedShift shiftOf({
      required int startMinute,
      required int endMinute,
      required List<FixedBreak> breaks,
      required ShiftType? type,
      required ShiftType? windowType,
      required bool isExtra,
      required bool countsAsOvertime,
      required bool changed,
    }) => PlannedShift(
      date,
      scheduleId: schedule.id,
      scheduleVersion: schedule.version,
      timezoneId: schedule.timezoneId,
      type: type,
      startUtc: atMinute(startMinute),
      endUtc: atMinute(endMinute),
      breaks: [
        for (final item in breaks)
          (
            start: atMinute(item.startMinute),
            end: atMinute(item.startMinute)
                .add(Duration(minutes: item.minutes)),
          ),
      ],
      overtimeWindow: windowType == null
          ? null
          : (
              start: atMinute(windowType.startMinute),
              end: atMinute(windowType.endMinute),
            ),
      isExtra: isExtra,
      countsAsOvertime: countsAsOvertime,
      changed: changed,
    );

    final cycleType = schedule.shiftTypeOn(date);
    final PlannedDay underlying = cycleType == null
        ? OffDay(
            date,
            scheduleId: schedule.id,
            scheduleVersion: schedule.version,
          )
        : shiftOf(
            startMinute: cycleType.startMinute,
            endMinute: cycleType.endMinute,
            breaks: cycleType.breaks,
            type: cycleType,
            windowType: cycleType,
            isExtra: false,
            countsAsOvertime: false,
            changed: false,
          );

    final exception = byDate[date];
    final planned = underlying is PlannedShift ? underlying : null;
    days.add(switch (exception) {
      null => underlying,
      ChangedDay() when planned != null => () {
        final chosen = exception.shiftTypeId == null
            ? null
            : schedule.typeById(exception.shiftTypeId!);
        return shiftOf(
          startMinute: exception.start.hour * 60 + exception.start.minute,
          endMinute:
              exception.endDayOffset * 1440 +
              exception.end.hour * 60 +
              exception.end.minute,
          breaks: exception.breaks,
          type: chosen ?? cycleType,
          windowType: chosen ?? cycleType,
          isExtra: false,
          countsAsOvertime: false,
          changed: true,
        );
      }(),
      CancelledDay() when planned != null => CancelledPlan(
        date,
        reason: exception.reason,
        note: exception.note,
        replaced: planned,
      ),
      LeaveDay() when planned != null => PlannedLeave(
        date,
        scheduleId: schedule.id,
        scheduleVersion: schedule.version,
        leaveType: exception.leaveType,
        illnessStartedOn: exception.illnessStartedOn,
        paidMinutes: planned.paidSeconds ~/ 60,
        replaced: planned,
      ),
      ExtraDay() when planned == null => shiftOf(
        startMinute: exception.start.hour * 60 + exception.start.minute,
        endMinute:
            exception.endDayOffset * 1440 +
            exception.end.hour * 60 +
            exception.end.minute,
        breaks: exception.breaks,
        type: exception.shiftTypeId == null
            ? null
            : schedule.typeById(exception.shiftTypeId!),
        windowType: null,
        isExtra: true,
        countsAsOvertime: exception.countsAsOvertime,
        changed: false,
      ),
      _ => NeedsReview(date, exception: exception, underlying: underlying),
    });
  }
  return List.unmodifiable(days);
}
