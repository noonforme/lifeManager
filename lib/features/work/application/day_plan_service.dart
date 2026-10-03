import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../domain/agreement.dart';
import '../domain/day_exception.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay_premiums.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import 'work_commands.dart';

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
}

/// Plans days from stored schedules and records owner changes to single
/// dates (schedules spec 3.4, 3.5).
final class DayPlanService {
  const DayPlanService({
    required this.repository,
    required this.ids,
    required this.clock,
    required this.zoneClocks,
  });

  final DayPlanRepository repository;
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

  /// Past planned shifts and leave not yet confirmed, oldest first: from the
  /// first date any schedule is in use up to the day before [today].
  Future<List<PlannedDay>> daysToConfirm(
    EmploymentId id, {
    required LocalDate today,
  }) async {
    final inputs = await repository.planInputs(id);
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
    build: (key, created, now, revision) => ChangedDay(
      id: key,
      employmentId: id,
      date: date,
      start: start,
      end: end,
      endDayOffset: endDayOffset,
      breaks: List.unmodifiable(breaks),
      shiftTypeId: shiftTypeId,
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
    build: (key, created, now, revision) => CancelledDay(
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
      build: (key, created, now, revision) => LeaveDay(
        id: key,
        employmentId: id,
        date: date,
        leaveType: leaveType,
        illnessStartedOn: illnessStartedOn,
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
    build: (key, created, now, revision) => ExtraDay(
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
    )
    build,
    ({
      LocalTime start,
      LocalTime end,
      int endDayOffset,
      List<FixedBreak> breaks,
    })?
    times,
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
