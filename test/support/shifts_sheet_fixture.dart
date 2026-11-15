import 'package:drift/drift.dart' show QueryExecutor;
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import 'schedule_fixture.dart';

/// October 2026 for the synthetic depot: the rotation from 2026-10-05
/// (3 Day, 3 Off, 3 Night, 3 Off), the EUR 18.40 agreement, and the
/// production Work services over the same in-memory database.
final class ShiftsSheetFixture {
  ShiftsSheetFixture._(this.schedule, this.work, this.reads);

  final ScheduleFixture schedule;
  final ProductionWorkProviders work;
  final WorkReads reads;

  static const month = LocalDate(2026, 10, 1);
  static const today = LocalDate(2026, 10, 20);
  static const zone = 'Europe/Vilnius';

  /// Over [executor] when given, else a new in-memory database.
  static Future<ShiftsSheetFixture> create({QueryExecutor? executor}) async {
    final schedule = await ScheduleFixture.create(executor: executor);
    await schedule.saveDepot();
    final work = buildWorkProviders(
      database: schedule.database,
      clock: schedule.clock,
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => zone,
      workIds: schedule.ids,
      shiftIds: schedule.ids,
      evidenceIds: schedule.ids,
      scheduleIds: schedule.ids,
    );
    return ShiftsSheetFixture._(schedule, work, WorkReads(schedule.database));
  }

  Future<void> dispose() => schedule.dispose();

  /// Finalizes a manual shift on [date] of October from [start] to [end],
  /// with [breaks] from and to wall-clock times of that day.
  Future<WorkShift> finishShift(
    int date, {
    LocalTime start = const LocalTime(8, 0),
    LocalTime end = const LocalTime(16, 0),
    List<(LocalTime, LocalTime)> breaks = const [],
  }) async {
    final day = LocalDate(2026, 10, date);
    final outcome = await work.manualShifts.createAndFinalize(
      CreateManualShiftCommand(
        employmentId: fixtureEmployment,
        localStartDate: day,
        localStartTime: start,
        localEndDate: day,
        localEndTime: end,
        timezoneId: zone,
        startFold: null,
        endFold: null,
        breaks: [
          for (final (from, to) in breaks)
            ManualShiftBreak(
              localStartDate: day,
              localStartTime: from,
              localEndDate: day,
              localEndTime: to,
              startFold: null,
              endFold: null,
            ),
        ],
        note: null,
      ),
    );
    return (outcome as Committed<WorkShift>).value;
  }

  /// Corrects the finalized shift on [date] of October, then finalizes its
  /// replacement on the same day of November: a correction whose two
  /// shifts are in different months.
  Future<(WorkShift original, WorkShift replacement)> correctIntoNovember(
    int date,
  ) async {
    final original = await finishShift(date);
    final corrected = await work.shifts.correctShift(
      CorrectShiftCommand(
        originalId: original.id,
        replacementId: schedule.ids.shiftId(),
        expectedRevision: original.revision,
        voidReason: 'Wrong month',
      ),
    );
    final draft = (corrected as Committed<WorkShift>).value;
    final day = LocalDate(2026, 11, date);
    final revised = await work.draftRevisions.reviseAndFinalize(
      ReviseShiftDraftCommand(
        id: draft.id,
        expectedRevision: draft.revision,
        localStartDate: day,
        localStartTime: const LocalTime(8, 0),
        localEndDate: day,
        localEndTime: const LocalTime(16, 0),
        timezoneId: zone,
        startFold: null,
        endFold: null,
        note: null,
      ),
    );
    return (
      (await reads.shift(original.id))!.shift,
      (revised as Committed<WorkShift>).value,
    );
  }

  /// Changes the depot's Day shift on [date] of October to 07:00–20:00,
  /// then reshapes the unused rotation into [blocks]. Where the cycle no
  /// longer plans a Day shift on that date, the change needs review
  /// (schedules spec 3.5).
  Future<DayException> changeThenReshape(
    int date,
    List<CycleBlock> blocks,
  ) async {
    final changed = await work.plans.changeDay(
      fixtureEmployment,
      LocalDate(2026, 10, date),
      start: const LocalTime(7, 0),
      end: const LocalTime(20, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: null,
    );
    final version = (await schedule.repository.schedulesFor(fixtureEmployment))
        .single;
    final reshaped = await schedule.schedules.update(
      version.id,
      expected: version.revision,
      draft: depotDraft(blocks: blocks),
    );
    if (reshaped is! Committed<WorkSchedule>) throw StateError('$reshaped');
    return (changed as Committed<DayException>).value;
  }
}
