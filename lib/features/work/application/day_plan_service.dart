import '../../../core/database/database_identity.dart';
import '../../../core/database/sqlite_errors.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../domain/agreement.dart';
import '../domain/day_exception.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/pay_premiums.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import '../domain/shift.dart';
import 'manual_shift_service.dart';
import 'work_commands.dart';

/// What confirming a planned day wrote.
sealed class ConfirmedDay {
  const ConfirmedDay();
}

final class ConfirmedShift extends ConfirmedDay {
  const ConfirmedShift(this.shift);

  final WorkShift shift;
}

final class ConfirmedLeave extends ConfirmedDay {
  const ConfirmedLeave(this.leave);

  final LeaveRecord leave;
}

/// Everything the planner reads for one employment, read together.
final class PlanInputs {
  const PlanInputs({
    required this.schedules,
    required this.exceptions,
    required this.confirmedDates,
    required this.agreements,
  });

  final List<WorkSchedule> schedules;
  final List<DayException> exceptions;

  /// Planned dates of non-voided linked shifts and of confirmed leave.
  final Set<LocalDate> confirmedDates;
  final List<PayAgreement> agreements;
}

abstract interface class DayPlanRepository {
  Future<PlanInputs> planInputs(EmploymentId id);

  Stream<PlanInputs> watchPlanInputs(EmploymentId id);

  /// Inserts [value], or with [expected] replaces the exception with its id.
  /// A date that already has an exception, or a moved revision, is Stale; a
  /// confirmed date is Invalid on `date`.
  Future<MutationOutcome<DayException>> putException(
    DayException value, {
    Revision? expected,
  });

  /// Removes an exception while its date is not confirmed.
  Future<MutationOutcome<DayException>> removeException(
    DayExceptionId id, {
    required Revision expected,
  });

  /// Every leave record of the employment, voided ones included.
  Future<List<LeaveRecord>> leaveFor(EmploymentId id);

  Future<LeaveRecord?> leaveById(LeaveRecordId id);

  Stream<List<LeaveRecord>> watchLeave(EmploymentId id);

  /// Records confirmed leave; a date already confirmed is Stale.
  Future<MutationOutcome<LeaveRecord>> insertLeave(LeaveRecord value);

  /// Voids [id] and records [replacement] on its date, like payslips.
  Future<MutationOutcome<LeaveRecord>> correctLeave(
    LeaveRecordId id, {
    required Revision expected,
    required LeaveRecord replacement,
    required String reason,
  });
}

/// Plans days from stored schedules and records owner changes to single
/// dates (schedules spec 3.4, 3.5).
final class DayPlanService {
  const DayPlanService({
    required this.repository,
    required this.shifts,
    required this.ids,
    required this.clock,
    required this.zoneClocks,
  });

  final DayPlanRepository repository;

  /// Confirmed worked days are finalized like manual shifts.
  final ManualShiftRepository shifts;
  final ScheduleIdFactory ids;
  final AppClock clock;
  final ZoneClocks zoneClocks;

  Future<List<PlannedDay>> plan(
    EmploymentId id,
    LocalDate from,
    LocalDate to,
  ) async => _plan(await repository.planInputs(id), from, to);

  Stream<List<PlannedDay>> watchPlan(
    EmploymentId id,
    LocalDate from,
    LocalDate to,
  ) => repository.watchPlanInputs(id).map((inputs) => _plan(inputs, from, to));

  /// What the planner reads for one employment, live.
  Stream<PlanInputs> watchInputs(EmploymentId id) =>
      repository.watchPlanInputs(id);

  /// Past planned shifts and leave not yet confirmed, oldest first: from the
  /// first date any schedule is in use up to the day before [today].
  Future<List<PlannedDay>> daysToConfirm(
    EmploymentId id, {
    required LocalDate today,
  }) async => _toConfirm(await repository.planInputs(id), today);

  /// [daysToConfirm], live: a day leaves the list once it is confirmed.
  Stream<List<PlannedDay>> watchDaysToConfirm(
    EmploymentId id, {
    required LocalDate today,
  }) =>
      repository.watchPlanInputs(id).map((inputs) => _toConfirm(inputs, today));

  List<PlannedDay> _toConfirm(PlanInputs inputs, LocalDate today) {
    if (inputs.schedules.isEmpty) return const [];
    final from = inputs.schedules
        .map((value) => value.inUseFrom)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final to = today.addDays(-1);
    if (from.compareTo(to) > 0) return const [];
    return [
      for (final day in _plan(inputs, from, to))
        if (day is PlannedShift || day is PlannedLeave) day,
    ];
  }

  Future<MutationOutcome<DayException>> changeDay(
    EmploymentId id,
    LocalDate date, {
    required LocalTime start,
    required LocalTime end,
    required int endDayOffset,
    required List<FixedBreak> breaks,
    required ShiftTypeId? shiftTypeId,
    Revision? expected,
  }) => _put(
    id,
    date,
    expected: expected,
    needsShift: true,
    times: (start: start, end: end, endDayOffset: endDayOffset, breaks: breaks),
    shiftTypeId: shiftTypeId,
    build: (key, created, now, revision, plannedTypeId) => ChangedDay(
      id: key,
      employmentId: id,
      date: date,
      start: start,
      end: end,
      endDayOffset: endDayOffset,
      breaks: List.unmodifiable(breaks),
      shiftTypeId: shiftTypeId,
      plannedTypeId: plannedTypeId,
      createdAtUtc: created,
      updatedAtUtc: now,
      revision: revision,
    ),
  );

  Future<MutationOutcome<DayException>> cancelDay(
    EmploymentId id,
    LocalDate date, {
    required CancelReason reason,
    required String? note,
    Revision? expected,
  }) => _put(
    id,
    date,
    expected: expected,
    needsShift: true,
    build: (key, created, now, revision, _) => CancelledDay(
      id: key,
      employmentId: id,
      date: date,
      reason: reason,
      note: _trimOptional(note),
      createdAtUtc: created,
      updatedAtUtc: now,
      revision: revision,
    ),
  );

  Future<MutationOutcome<DayException>> markLeave(
    EmploymentId id,
    LocalDate date, {
    required LeaveType leaveType,
    required LocalDate? illnessStartedOn,
    Revision? expected,
  }) {
    if (illnessStartedOn != null &&
        (leaveType != LeaveType.sick || illnessStartedOn.compareTo(date) > 0)) {
      return Future.value(
        const Invalid<DayException>({
          'illnessStartedOn': [FieldIssue(FieldIssueCode.invalid)],
        }),
      );
    }
    return _put(
      id,
      date,
      expected: expected,
      needsShift: true,
      build: (key, created, now, revision, plannedTypeId) => LeaveDay(
        id: key,
        employmentId: id,
        date: date,
        leaveType: leaveType,
        illnessStartedOn: illnessStartedOn,
        plannedTypeId: plannedTypeId,
        createdAtUtc: created,
        updatedAtUtc: now,
        revision: revision,
      ),
    );
  }

  Future<MutationOutcome<DayException>> addExtra(
    EmploymentId id,
    LocalDate date, {
    required LocalTime start,
    required LocalTime end,
    required int endDayOffset,
    required List<FixedBreak> breaks,
    required ShiftTypeId? shiftTypeId,
    required bool countsAsOvertime,
    Revision? expected,
  }) => _put(
    id,
    date,
    expected: expected,
    needsShift: false,
    times: (start: start, end: end, endDayOffset: endDayOffset, breaks: breaks),
    shiftTypeId: shiftTypeId,
    build: (key, created, now, revision, _) => ExtraDay(
      id: key,
      employmentId: id,
      date: date,
      start: start,
      end: end,
      endDayOffset: endDayOffset,
      breaks: List.unmodifiable(breaks),
      shiftTypeId: shiftTypeId,
      countsAsOvertime: countsAsOvertime,
      createdAtUtc: created,
      updatedAtUtc: now,
      revision: revision,
    ),
  );

  Future<MutationOutcome<DayException>> removeException(
    DayExceptionId id, {
    required Revision expected,
  }) => _guard(() => repository.removeException(id, expected: expected));

  /// Confirms one past or present planned day (a future date is Invalid on
  /// `date`): a planned shift becomes a
  /// finalized shift linked to its plan, planned leave a leave record
  /// (schedules spec 3.6). A date already confirmed is Stale.
  Future<MutationOutcome<ConfirmedDay>> confirm(
    EmploymentId id,
    LocalDate date,
  ) async {
    try {
      final inputs = await repository.planInputs(id);
      if (inputs.confirmedDates.contains(date)) {
        return const Stale<ConfirmedDay>();
      }
      final day = _plan(inputs, date, date).firstOrNull;
      if (day is! PlannedShift && day is! PlannedLeave) {
        return const Invalid<ConfirmedDay>({
          'date': [FieldIssue(FieldIssueCode.invalid)],
        });
      }
      // Work that has not happened is not confirmed: today at most, on the
      // schedule's own clock.
      final zone = switch (day) {
        PlannedShift(:final timezoneId) => timezoneId,
        PlannedLeave(:final replaced) => replaced.timezoneId,
        _ => throw StateError('unreachable'),
      };
      final today = zoneClocks(zone).toLocal(clock.nowUtc()).date;
      if (date.compareTo(today) > 0) {
        return const Invalid<ConfirmedDay>({
          'date': [FieldIssue(FieldIssueCode.invalid)],
        });
      }
      final resolution = resolveAgreement(
        employmentId: id,
        localStartDate: date,
        agreements: inputs.agreements,
      );
      if (resolution is! ResolvedAgreement) {
        return const Invalid<ConfirmedDay>({
          'agreement': [FieldIssue(FieldIssueCode.unavailable)],
        });
      }
      final now = clock.nowUtc();
      return await switch (day) {
        PlannedShift() => _confirmShift(id, day, now),
        PlannedLeave() => _confirmLeave(
          id,
          day,
          inputs,
          resolution.agreement.id,
          now,
        ),
        _ => throw StateError('unreachable'),
      };
    } on ArgumentError {
      // The plan resolves to no real shift on this date, for example one
      // that falls wholly inside a daylight-saving gap.
      return const Invalid<ConfirmedDay>({
        'date': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on DatabaseOpenFailure {
      return const Unavailable<ConfirmedDay>(
        SafeFailureCode.storageUnavailable,
      );
    } on DatabaseValidationFailure {
      return const Unavailable<ConfirmedDay>(
        SafeFailureCode.storageUnavailable,
      );
    }
  }

  /// Voids confirmed leave and records its replacement on the same date.
  Future<MutationOutcome<LeaveRecord>> correctLeave(
    LeaveRecordId id, {
    required Revision expected,
    required LeaveType leaveType,
    required LocalDate? illnessStartedOn,
    required String reason,
  }) async {
    final why = reason.trim();
    if (why.isEmpty) {
      return const Invalid<LeaveRecord>({
        'reason': [FieldIssue(FieldIssueCode.required)],
      });
    }
    try {
      final original = await repository.leaveById(id);
      if (original == null) return const Missing<LeaveRecord>();
      if (illnessStartedOn != null &&
          (leaveType != LeaveType.sick ||
              illnessStartedOn.compareTo(original.date) > 0)) {
        return const Invalid<LeaveRecord>({
          'illnessStartedOn': [FieldIssue(FieldIssueCode.invalid)],
        });
      }
      final now = clock.nowUtc();
      final replacement = LeaveRecord(
        id: ids.leaveRecordId(),
        employmentId: original.employmentId,
        date: original.date,
        leaveType: leaveType,
        illnessStartedOn: leaveType == LeaveType.sick
            ? illnessStartedOn ??
                  original.illnessStartedOn ??
                  await _illnessStart(
                    original.employmentId,
                    original.date,
                    await repository.planInputs(original.employmentId),
                  )
            : null,
        paidMinutes: original.paidMinutes,
        agreementId: original.agreementId,
        scheduleId: original.scheduleId,
        scheduleVersion: original.scheduleVersion,
        state: LeaveState.confirmed,
        voidReason: null,
        replacementId: null,
        replacedId: original.id,
        createdAtUtc: now,
        updatedAtUtc: now,
        revision: const Revision(0),
      );
      return await repository.correctLeave(
        id,
        expected: expected,
        replacement: replacement,
        reason: why,
      );
    } on DatabaseOpenFailure {
      return const Unavailable<LeaveRecord>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<LeaveRecord>(SafeFailureCode.storageUnavailable);
    }
  }

  Future<MutationOutcome<ConfirmedDay>> _confirmShift(
    EmploymentId id,
    PlannedShift day,
    DateTime now,
  ) async {
    final shiftId = ids.shiftId();
    final window = day.overtimeWindow;
    final draft = WorkShift(
      id: shiftId,
      employmentId: id,
      agreementId: null,
      state: ShiftState.draft,
      startUtc: day.startUtc,
      endUtc: day.endUtc,
      timezoneId: day.timezoneId,
      localStartDate: day.date,
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: now,
      updatedAtUtc: now,
      revision: const Revision(0),
      schedule: ScheduleLink(
        scheduleId: day.scheduleId,
        scheduleVersion: day.scheduleVersion,
        plannedDate: day.date,
        plannedStartUtc: window?.start ?? day.startUtc,
        plannedEndUtc: window?.end ?? day.endUtc,
        isExtra: day.isExtra,
        extraCountsAsOvertime: day.countsAsOvertime,
      ),
    );
    final breaks = [
      for (final item in day.breaks)
        ShiftBreak(
          id: ids.shiftBreakId(),
          shiftId: shiftId,
          startUtc: item.start,
          endUtc: item.end,
          createdAtUtc: now,
          updatedAtUtc: now,
          revision: const Revision(0),
        ),
    ];
    final MutationOutcome<WorkShift> outcome;
    try {
      outcome = await shifts.createAndFinalizeManual(draft, breaks);
    } on Object catch (error) {
      // one_confirmed_shift_per_planned_day: another confirm won the date.
      if (isUniqueViolation(error)) return const Stale<ConfirmedDay>();
      rethrow;
    }
    return switch (outcome) {
      Committed<WorkShift>(:final value) => Committed<ConfirmedDay>(
        ConfirmedShift(value),
      ),
      Invalid<WorkShift>(:final fields) => Invalid<ConfirmedDay>(fields),
      Stale<WorkShift>() => const Stale<ConfirmedDay>(),
      Missing<WorkShift>() => const Missing<ConfirmedDay>(),
      Unavailable<WorkShift>(:final code) => Unavailable<ConfirmedDay>(code),
      Uncertain<WorkShift>(:final code) => Uncertain<ConfirmedDay>(code),
    };
  }

  Future<MutationOutcome<ConfirmedDay>> _confirmLeave(
    EmploymentId id,
    PlannedLeave day,
    PlanInputs inputs,
    AgreementId agreementId,
    DateTime now,
  ) async {
    final illnessStartedOn = day.leaveType == LeaveType.sick
        ? day.illnessStartedOn ?? await _illnessStart(id, day.date, inputs)
        : null;
    final outcome = await repository.insertLeave(
      LeaveRecord(
        id: ids.leaveRecordId(),
        employmentId: id,
        date: day.date,
        leaveType: day.leaveType,
        illnessStartedOn: illnessStartedOn,
        paidMinutes: day.paidMinutes,
        agreementId: agreementId,
        scheduleId: day.scheduleId,
        scheduleVersion: day.scheduleVersion,
        state: LeaveState.confirmed,
        voidReason: null,
        replacementId: null,
        replacedId: null,
        createdAtUtc: now,
        updatedAtUtc: now,
        revision: const Revision(0),
      ),
    );
    return switch (outcome) {
      Committed<LeaveRecord>(:final value) => Committed<ConfirmedDay>(
        ConfirmedLeave(value),
      ),
      Invalid<LeaveRecord>(:final fields) => Invalid<ConfirmedDay>(fields),
      Stale<LeaveRecord>() => const Stale<ConfirmedDay>(),
      Missing<LeaveRecord>() => const Missing<ConfirmedDay>(),
      Unavailable<LeaveRecord>(:final code) => Unavailable<ConfirmedDay>(code),
      Uncertain<LeaveRecord>(:final code) => Uncertain<ConfirmedDay>(code),
    };
  }

  /// The default start of the illness [date] belongs to (spec 4.3): back
  /// across sick days, marked or confirmed, that only Off days separate.
  Future<LocalDate> _illnessStart(
    EmploymentId id,
    LocalDate date,
    PlanInputs inputs,
  ) async {
    final leave = await repository.leaveFor(id);
    final sick = {
      for (final item in inputs.exceptions)
        if (item is LeaveDay && item.leaveType == LeaveType.sick) item.date,
      for (final item in leave)
        if (item.isEffective && item.leaveType == LeaveType.sick) item.date,
    };
    // A year back is the longest run the default follows.
    final before = {
      for (final planned in _plan(inputs, date.addDays(-366), date.addDays(-1)))
        planned.date: planned,
    };
    return defaultIllnessStart(
      date,
      isSick: sick.contains,
      isOff: (day) => before[day] is OffDay,
    );
  }

  List<PlannedDay> _plan(PlanInputs inputs, LocalDate from, LocalDate to) =>
      planDays(
        from: from,
        to: to,
        schedules: inputs.schedules,
        exceptions: inputs.exceptions,
        confirmedDates: inputs.confirmedDates,
        zoneClocks: zoneClocks,
      );

  Future<MutationOutcome<DayException>> _put(
    EmploymentId id,
    LocalDate date, {
    required Revision? expected,
    required bool needsShift,
    required DayException Function(
      DayExceptionId id,
      DateTime createdAtUtc,
      DateTime nowUtc,
      Revision revision,
      ShiftTypeId? plannedTypeId,
    )
    build,
    ({
      LocalTime start,
      LocalTime end,
      int endDayOffset,
      List<FixedBreak> breaks,
    })?
    times,
    ShiftTypeId? shiftTypeId,
  }) => _guard(() async {
    if (times != null) {
      final check = checkShiftTimes(
        ShiftType(
          id: const ShiftTypeId('day'),
          name: 'Day',
          start: times.start,
          end: times.end,
          endDayOffset: times.endDayOffset,
          breaks: times.breaks,
        ),
      );
      if (!check.times || !check.breaks) {
        return Invalid<DayException>({
          if (!check.times) 'end': const [FieldIssue(FieldIssueCode.invalid)],
          if (!check.breaks)
            'breaks': const [FieldIssue(FieldIssueCode.invalid)],
        });
      }
    }
    final inputs = await repository.planInputs(id);
    if (inputs.confirmedDates.contains(date)) return _dateIssue(conflict: true);
    // What the cycle holds on the date, before any exception.
    final cycle = planDays(
      from: date,
      to: date,
      schedules: inputs.schedules,
      exceptions: const [],
      confirmedDates: const {},
      zoneClocks: zoneClocks,
    ).firstOrNull;
    final fits = needsShift ? cycle is PlannedShift : cycle is OffDay;
    if (!fits) return _dateIssue(conflict: false);
    if (shiftTypeId != null &&
        inputs.schedules
                .where((value) => value.isInUseOn(date))
                .firstOrNull
                ?.typeById(shiftTypeId) ==
            null) {
      return const Invalid<DayException>({
        'shiftTypeId': [FieldIssue(FieldIssueCode.invalid)],
      });
    }
    final existing = inputs.exceptions
        .where((value) => value.date == date)
        .firstOrNull;
    // A date holds one exception: without its revision an add is a
    // repeat, and with one there must be something to edit.
    if ((existing == null) != (expected == null)) {
      return const Stale<DayException>();
    }
    final now = clock.nowUtc();
    final value = build(
      existing?.id ?? ids.dayExceptionId(),
      existing?.createdAtUtc ?? now,
      now,
      existing == null ? const Revision(0) : existing.revision.next(),
      cycle is PlannedShift ? cycle.type?.id : null,
    );
    return repository.putException(value, expected: expected);
  });
}

Invalid<DayException> _dateIssue({required bool conflict}) =>
    Invalid<DayException>({
      'date': [
        FieldIssue(conflict ? FieldIssueCode.conflict : FieldIssueCode.invalid),
      ],
    });

String? _trimOptional(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

Future<MutationOutcome<DayException>> _guard(
  Future<MutationOutcome<DayException>> Function() body,
) async {
  try {
    return await body();
  } on DatabaseOpenFailure {
    return const Unavailable<DayException>(SafeFailureCode.storageUnavailable);
  } on DatabaseValidationFailure {
    return const Unavailable<DayException>(SafeFailureCode.storageUnavailable);
  }
}
