import 'package:drift/native.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/core/time/wall_clock.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/data/schedule_repository.dart';
import 'package:lifeos/features/work/data/shift_repository.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';

const fixtureEmployment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const fixtureAgreement = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

/// A clock tests move by hand.
final class FixedClock implements AppClock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

/// An in-memory database with one synthetic employment paid EUR 18.40
/// gross from 2026-09-01, and the schedule services under test.
final class ScheduleFixture {
  ScheduleFixture._({
    required this.database,
    required this.clock,
    required this.ids,
    required this.shifts,
    required this.repository,
    required this.schedules,
    required this.plans,
  });

  final AppDatabase database;
  final FixedClock clock;
  final UuidV7WorkIdFactory ids;
  final DriftShiftRepository shifts;
  final DriftScheduleRepository repository;
  final ScheduleService schedules;
  final DayPlanService plans;

  static Future<ScheduleFixture> create() async {
    final database = AppDatabase(NativeDatabase.memory());
    // Late enough that the October days the tests confirm are past.
    final clock = FixedClock(DateTime.utc(2026, 12, 1, 12));
    final ids = UuidV7WorkIdFactory();
    final work = DriftWorkRepository(database, clock: clock);
    await work.insertEmployment(
      Employment.create(
        id: fixtureEmployment,
        name: 'Synthetic depot',
        legalLabel: null,
        nowUtc: clock.value,
      ),
    );
    await work.insertAgreement(
      PayAgreement(
        id: fixtureAgreement,
        employmentId: fixtureEmployment,
        version: 1,
        effectiveStart: const LocalDate(2026, 9, 1),
        effectiveEnd: null,
        hourlyRateMicroEur: 18400000,
        basis: const GrossBasis(),
        overtimeThresholdMinutes: 480,
        overtimeMultiplier: const RationalMultiplier(
          numerator: 3,
          denominator: 2,
        ),
        label: null,
        note: null,
        createdAtUtc: clock.value,
        revision: const Revision(0),
        usedByFinalizedShift: false,
      ),
    );
    final repository = DriftScheduleRepository(database, clock: clock);
    final shifts = DriftShiftRepository(
      database,
      createBreakId: ids.shiftBreakId,
      clock: clock,
    );
    return ScheduleFixture._(
      database: database,
      clock: clock,
      ids: ids,
      shifts: shifts,
      repository: repository,
      schedules: ScheduleService(
        repository: repository,
        ids: ids,
        clock: clock,
      ),
      plans: DayPlanService(
        repository: repository,
        shifts: shifts,
        ids: ids,
        clock: clock,
        zoneClocks: zoneClocksOf(IanaTimezoneService()),
      ),
    );
  }

  Future<void> dispose() => database.close();

  /// Saves the 3 Day / 3 Off / 3 Night / 3 Off rotation from [from].
  Future<WorkSchedule> saveDepot({
    LocalDate from = const LocalDate(2026, 10, 5),
  }) async {
    final outcome = await schedules.create(depotDraft(from: from));
    return (outcome as Committed<WorkSchedule>).value;
  }

  /// Confirms a Day shift on [date] from [version] directly, so the
  /// version counts as used (Task 9 adds the real confirm command).
  Future<MutationOutcome<WorkShift>> markUsed(
    WorkSchedule version, {
    LocalDate date = const LocalDate(2026, 10, 5),
  }) async {
    // 07:00–19:00 in Europe/Vilnius, summer time (UTC+3).
    final start = DateTime.utc(date.year, date.month, date.day, 4);
    final end = DateTime.utc(date.year, date.month, date.day, 16);
    return shifts.createAndFinalizeManual(
      WorkShift(
        id: ids.shiftId(),
        employmentId: fixtureEmployment,
        agreementId: null,
        state: ShiftState.draft,
        startUtc: start,
        endUtc: end,
        timezoneId: 'Europe/Vilnius',
        localStartDate: date,
        note: null,
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: clock.value,
        updatedAtUtc: clock.value,
        revision: const Revision(0),
        schedule: ScheduleLink(
          scheduleId: version.id,
          scheduleVersion: version.version,
          plannedDate: date,
          plannedStartUtc: start,
          plannedEndUtc: end,
        ),
      ),
      const [],
    );
  }
}

/// The owner's rotation: Day 07:00–19:00 and Night 19:00–07:00, each with
/// a 30-minute break, as 3 Day, 3 Off, 3 Night, 3 Off.
ScheduleDraft depotDraft({
  String name = 'Depot rotation',
  int firstCount = 3,
  bool onlyOff = false,
  LocalDate from = const LocalDate(2026, 10, 5),
  LocalDate? until,
  List<CycleBlock>? blocks,
}) => ScheduleDraft(
  employmentId: fixtureEmployment,
  name: name,
  timezoneId: 'Europe/Vilnius',
  cycleStart: from,
  inUseFrom: from,
  inUseUntil: until,
  shiftTypes: const [
    ShiftType(
      id: ShiftTypeId('day'),
      name: 'Day',
      start: LocalTime(7, 0),
      end: LocalTime(19, 0),
      endDayOffset: 0,
      breaks: [FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30)],
    ),
    ShiftType(
      id: ShiftTypeId('night'),
      name: 'Night',
      start: LocalTime(19, 0),
      end: LocalTime(7, 0),
      endDayOffset: 1,
      breaks: [FixedBreak(start: LocalTime(0, 0), dayOffset: 1, minutes: 30)],
    ),
  ],
  blocks:
      blocks ??
      (onlyOff
          ? const [CycleBlock(count: 1, shiftTypeId: null)]
          : [
              CycleBlock(
                count: firstCount,
                shiftTypeId: const ShiftTypeId('day'),
              ),
              const CycleBlock(count: 3, shiftTypeId: null),
              const CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
              const CycleBlock(count: 3, shiftTypeId: null),
            ]),
);
