import '../../../core/time/local_date.dart';
import 'agreement.dart';
import 'facts.dart';
import 'ids.dart';
import 'pay.dart';
import 'pay_premiums.dart';

enum ShiftState { draft, finalized, voided }

/// The planned day a confirmed shift came from (schedules spec 3.6). Its
/// window decides overtime (spec 4.2).
final class ScheduleLink {
  ScheduleLink({
    required this.scheduleId,
    required this.scheduleVersion,
    required this.plannedDate,
    required this.plannedStartUtc,
    required this.plannedEndUtc,
    this.isExtra = false,
    this.extraCountsAsOvertime = false,
  }) {
    _requireUtc(plannedStartUtc, 'plannedStartUtc');
    _requireUtc(plannedEndUtc, 'plannedEndUtc');
    if (!plannedEndUtc.isAfter(plannedStartUtc)) {
      throw ArgumentError.value(plannedEndUtc, 'plannedEndUtc');
    }
    if (scheduleVersion <= 0) {
      throw ArgumentError.value(scheduleVersion, 'scheduleVersion');
    }
  }

  final ScheduleId scheduleId;
  final int scheduleVersion;
  final LocalDate plannedDate;
  final DateTime plannedStartUtc;
  final DateTime plannedEndUtc;
  final bool isExtra;
  final bool extraCountsAsOvertime;

  @override
  bool operator ==(Object other) =>
      other is ScheduleLink &&
      other.scheduleId == scheduleId &&
      other.scheduleVersion == scheduleVersion &&
      other.plannedDate == plannedDate &&
      other.plannedStartUtc == plannedStartUtc &&
      other.plannedEndUtc == plannedEndUtc &&
      other.isExtra == isExtra &&
      other.extraCountsAsOvertime == extraCountsAsOvertime;

  @override
  int get hashCode => Object.hash(
    scheduleId,
    scheduleVersion,
    plannedDate,
    plannedStartUtc,
    plannedEndUtc,
    isExtra,
    extraCountsAsOvertime,
  );
}

final class WorkShift {
  WorkShift({
    required this.id,
    required this.employmentId,
    required this.agreementId,
    required this.state,
    required this.startUtc,
    required this.endUtc,
    required this.timezoneId,
    required this.localStartDate,
    required this.note,
    required this.voidReason,
    required this.replacementShiftId,
    required this.replacedShiftId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
    this.schedule,
  }) {
    _requireUtc(startUtc, 'startUtc');
    _requireUtc(createdAtUtc, 'createdAtUtc');
    _requireUtc(updatedAtUtc, 'updatedAtUtc');
    if (endUtc != null) {
      _requireUtc(endUtc!, 'endUtc');
      if (!endUtc!.isAfter(startUtc)) {
        throw ArgumentError.value(endUtc, 'endUtc');
      }
    }
    if (timezoneId.trim().isEmpty) {
      throw ArgumentError.value(timezoneId, 'timezoneId');
    }
    switch (state) {
      case ShiftState.finalized:
        if (endUtc == null || agreementId == null) {
          throw ArgumentError('Finalized shifts require end and agreement.');
        }
      // A removed shift is void without a replacement (spec 10.7).
      case ShiftState.voided:
        if (voidReason?.trim().isEmpty != false) {
          throw ArgumentError('Voided shifts require a reason.');
        }
      case ShiftState.draft:
        break;
    }
  }

  final ShiftId id;
  final EmploymentId employmentId;
  final AgreementId? agreementId;
  final ShiftState state;
  final DateTime startUtc;
  final DateTime? endUtc;
  final String timezoneId;
  final LocalDate localStartDate;
  final String? note;
  final String? voidReason;
  final ShiftId? replacementShiftId;
  final ShiftId? replacedShiftId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  /// Null for a shift entered by hand rather than confirmed from a plan.
  final ScheduleLink? schedule;

  int get elapsedSeconds => endUtc!.difference(startUtc).inSeconds;

  WorkShift finalizedWith(PayAgreement agreement) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreement.id,
      state: ShiftState.finalized,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      note: note,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision.next(),
      schedule: schedule,
    );
  }

  WorkShift voidedForCorrection({
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  }) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreementId,
      state: ShiftState.voided,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      note: note,
      voidReason: voidReason,
      replacementShiftId: replacementId,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: nowUtc,
      revision: revision.next(),
      schedule: schedule,
    );
  }

  /// Void with no replacement: kept in history, out of the totals.
  WorkShift removed({required String voidReason, required DateTime nowUtc}) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreementId,
      state: ShiftState.voided,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      note: note,
      voidReason: voidReason,
      replacementShiftId: null,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: nowUtc,
      revision: revision.next(),
      schedule: schedule,
    );
  }

  /// The same shift with owner-revised facts; identity, lineage, agreement and
  /// revision are kept so the write stays revision-checked.
  WorkShift revisedFacts({
    required DateTime startUtc,
    required DateTime endUtc,
    required String timezoneId,
    required LocalDate localStartDate,
    required String? note,
    DateTime? updatedAtUtc,
  }) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreementId,
      state: state,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      note: note,
      voidReason: voidReason,
      replacementShiftId: replacementShiftId,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      revision: revision,
      schedule: schedule,
    );
  }

  WorkShift replacementDraft({
    required ShiftId replacementId,
    required DateTime nowUtc,
  }) {
    return WorkShift(
      id: replacementId,
      employmentId: employmentId,
      agreementId: agreementId,
      state: ShiftState.draft,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      note: note,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: id,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      revision: const Revision(0),
      schedule: schedule,
    );
  }
}

final class ShiftBreak {
  ShiftBreak({
    required this.id,
    required this.shiftId,
    required this.startUtc,
    required this.endUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  }) {
    _requireUtc(startUtc, 'startUtc');
    _requireUtc(createdAtUtc, 'createdAtUtc');
    _requireUtc(updatedAtUtc, 'updatedAtUtc');
    if (endUtc != null) {
      _requireUtc(endUtc!, 'endUtc');
      if (!endUtc!.isAfter(startUtc)) {
        throw ArgumentError.value(endUtc, 'endUtc');
      }
    }
  }

  final ShiftBreakId id;
  final ShiftId shiftId;
  final DateTime startUtc;
  final DateTime? endUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;
}

final class FinalizationFacts {
  const FinalizationFacts({
    required this.shift,
    required this.breaks,
    required this.agreement,
    required this.paidSeconds,
  });

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final PayAgreement agreement;

  /// Paid seconds over whole-second instants, so it always equals the sum of
  /// the pay segments.
  final int paidSeconds;

  /// Whole seconds from start to end, breaks included.
  int get elapsedSeconds => _second(shift.endUtc!) - _second(shift.startUtc);

  int get breakSeconds => elapsedSeconds - paidSeconds;

  /// The shift minus its breaks, in UTC whole seconds and in order.
  List<({DateTime start, DateTime end})> get paidIntervals {
    DateTime whole(DateTime utc) =>
        DateTime.fromMillisecondsSinceEpoch(_second(utc) * 1000, isUtc: true);
    final intervals = <({DateTime start, DateTime end})>[];
    var from = whole(shift.startUtc);
    for (final item in breaks) {
      final breakStart = whole(item.startUtc);
      if (breakStart.isAfter(from)) {
        intervals.add((start: from, end: breakStart));
      }
      from = whole(item.endUtc!);
    }
    final end = whole(shift.endUtc!);
    if (end.isAfter(from)) intervals.add((start: from, end: end));
    return List.unmodifiable(intervals);
  }

  /// Which paid time is overtime (schedules spec 4.2): outside the planned
  /// window for a scheduled shift, all or none for an extra, and the
  /// agreement threshold for a shift without a schedule.
  OvertimeRule get overtimeRule => switch (shift.schedule) {
    null => ThresholdOvertime(agreement.overtimeThresholdMinutes * 60),
    ScheduleLink(isExtra: true, extraCountsAsOvertime: true) =>
      const AllOvertime(),
    ScheduleLink(isExtra: true) => const NoOvertime(),
    ScheduleLink(:final plannedStartUtc, :final plannedEndUtc) =>
      WindowOvertime(start: plannedStartUtc, end: plannedEndUtc),
  };

  /// Expected pay with night, holiday and derived overtime premiums, read on
  /// the shift's own wall clock.
  ExpectedPay expectedPay({
    required ToLocal toLocal,
    required ToInstants toInstants,
  }) => calculateExpectedPay(
    segments: segmentPaidTime(
      paidIntervals: paidIntervals,
      agreement: agreement,
      toLocal: toLocal,
      toInstants: toInstants,
      overtime: overtimeRule,
    ),
    hourlyRateMicroEur: agreement.hourlyRateMicroEur,
    agreement: agreement,
    currency: const CurrencyCode.eur(),
  );
}

final class FinalizationValidation {
  const FinalizationValidation({required this.issues, this.facts});

  final List<DomainIssue> issues;
  final FinalizationFacts? facts;

  bool get isValid => facts != null;
}

FinalizationValidation validateFinalization({
  required WorkShift shift,
  required Iterable<ShiftBreak> breaks,
  required Iterable<PayAgreement> agreements,
}) {
  final issues = <DomainIssue>[];
  final end = shift.endUtc;
  if (end == null) {
    issues.add(const DomainIssue('shift.endMissing', field: 'endUtc'));
  } else if (!end.isAfter(shift.startUtc)) {
    issues.add(const DomainIssue('shift.endNotAfterStart', field: 'endUtc'));
  }

  final ordered = [...breaks]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  var breakSeconds = 0;
  DateTime? previousEnd;
  for (final item in ordered) {
    if (item.shiftId != shift.id) {
      issues.add(const DomainIssue('break.outsideShift', field: 'breaks'));
      continue;
    }
    final breakEnd = item.endUtc;
    if (breakEnd == null) {
      issues.add(const DomainIssue('break.open', field: 'breaks'));
      continue;
    }
    if (end == null ||
        item.startUtc.isBefore(shift.startUtc) ||
        breakEnd.isAfter(end)) {
      issues.add(const DomainIssue('break.outsideShift', field: 'breaks'));
    }
    if (previousEnd != null && item.startUtc.isBefore(previousEnd)) {
      issues.add(const DomainIssue('break.overlap', field: 'breaks'));
    }
    breakSeconds += _second(breakEnd) - _second(item.startUtc);
    previousEnd = breakEnd;
  }

  final paidSeconds = end == null
      ? 0
      : _second(end) - _second(shift.startUtc) - breakSeconds;
  if (end != null && paidSeconds <= 0) {
    issues.add(
      const DomainIssue('shift.paidDurationNotPositive', field: 'duration'),
    );
  }
  if (issues.isNotEmpty) {
    return FinalizationValidation(issues: List.unmodifiable(issues));
  }

  final resolution = resolveAgreement(
    employmentId: shift.employmentId,
    localStartDate: shift.localStartDate,
    agreements: agreements,
  );
  if (resolution is! ResolvedAgreement) {
    return FinalizationValidation(
      issues: [DomainIssue('shift.agreement.${resolution.runtimeType}')],
    );
  }
  final finalized = shift.finalizedWith(resolution.agreement);
  return FinalizationValidation(
    issues: const [],
    facts: FinalizationFacts(
      shift: finalized,
      breaks: List.unmodifiable(ordered),
      agreement: resolution.agreement,
      paidSeconds: paidSeconds,
    ),
  );
}

int _second(DateTime utc) => utc.microsecondsSinceEpoch ~/ 1000000;

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name);
}
