import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/pay_premiums.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/schedule.dart';
import 'schedule_fields.dart';
import 'work_records.dart';

/// One day of a schedule's Preview.
@immutable
final class PreviewDay {
  const PreviewDay({
    required this.date,
    required this.letter,
    required this.typeIndex,
    required this.confirmed,
    required this.today,
    required this.otherSchedule,
  });

  final LocalDate date;

  /// Its shift type's letters, empty for an off day or a day this schedule
  /// does not plan.
  final String letter;

  /// Its shift type's place among the schedule's types, for its tone.
  final int? typeIndex;

  /// A day already confirmed (as a shift or leave).
  final bool confirmed;
  final bool today;

  /// The name of the other schedule that plans this day, if one does.
  final String? otherSchedule;
}

/// One month of a schedule's Preview: its days and what this schedule
/// plans in it.
@immutable
final class PreviewMonth {
  const PreviewMonth({
    required this.year,
    required this.month,
    required this.days,
    required this.shifts,
    required this.paidSeconds,
    required this.pay,
    required this.otherSchedule,
  });

  final int year;
  final int month;
  final List<PreviewDay> days;
  final int shifts;
  final int paidSeconds;

  /// Planned pay in cents per basis, gross first; null when a planned
  /// shift has no agreement.
  final Map<RateBasis, int>? pay;

  /// The other schedule that plans every day of the month, if one does.
  final String? otherSchedule;
}

/// The employment's schedules with [draft] in place of [baseline] (or as
/// its next version from the draft's `versionFrom`), and the draft's id.
({ScheduleId id, List<WorkSchedule> schedules}) _withDraft({
  required ScheduleValues draft,
  required ScheduleRecord? baseline,
  required EmploymentId employmentId,
  required PlanInputs inputs,
}) {
  final current = baseline?.value;
  final id = current?.id ?? const ScheduleId('pending');
  final versionFrom = draft.versionFrom;
  final schedules = <WorkSchedule>[
    for (final value in inputs.schedules)
      if (current == null ||
          value.id != current.id ||
          value.version != current.version)
        value,
  ];
  if (current != null && versionFrom != null) {
    final dayBefore = versionFrom.addDays(-1);
    final end = current.inUseUntil;
    schedules
      ..add(
        WorkSchedule(
          id: current.id,
          employmentId: current.employmentId,
          name: current.name,
          timezoneId: current.timezoneId,
          version: current.version,
          cycleStart: current.cycleStart,
          inUseFrom: current.inUseFrom,
          inUseUntil: end != null && end.compareTo(dayBefore) < 0
              ? end
              : dayBefore,
          shiftTypes: current.shiftTypes,
          blocks: current.blocks,
          createdAtUtc: current.createdAtUtc,
          revision: current.revision,
        ),
      )
      ..add(
        draft.asSchedule(
          employmentId: employmentId,
          id: id,
          version: current.version + 1,
        ),
      );
  } else {
    schedules.add(
      draft.asSchedule(
        employmentId: employmentId,
        id: id,
        version: current?.version ?? 1,
      ),
    );
  }
  return (id: id, schedules: schedules);
}

/// What a schedule's draft pays as planned (bead 9pk.4.16), beside its
/// Preview: each shift type's price on its first planned day from [today]
/// (null where no agreement covers that day; a type the cycle does not plan
/// is left out), and one whole cycle's pay from its first start on or after
/// [today] or the day the draft starts. Null while the draft does not
/// validate.
SchedulePricing? schedulePricing({
  required ScheduleValues draft,
  required ScheduleRecord? baseline,
  required EmploymentId employmentId,
  required PlanInputs inputs,
  required LocalDate today,
  required ZoneClocks zoneClocks,
}) {
  if (scheduleIssues(draft, employmentId: employmentId).isNotEmpty) {
    return null;
  }
  final (:id, :schedules) = _withDraft(
    draft: draft,
    baseline: baseline,
    employmentId: employmentId,
    inputs: inputs,
  );
  final length = draft.blocks.fold(0, (sum, block) => sum + block.count);
  final starts = draft.versionFrom ?? draft.inUseFrom;
  final from = starts.compareTo(today) > 0 ? starts : today;
  final into = from.daysSince(draft.cycleStart) % length;
  final cycleFrom = into == 0 ? from : from.addDays(length - into);
  final cycleTo = cycleFrom.addDays(length - 1);
  ExpectedPay? price(PlannedShift day) => plannedPay(
    day,
    agreements: inputs.agreements,
    employmentId: employmentId,
    zoneClocks: zoneClocks,
  );
  final types = <ShiftTypeId, ExpectedPay?>{};
  final cycle = <RateBasis, int>{};
  var cycleKnown = true;
  for (final day in planDays(
    from: from,
    to: cycleTo,
    schedules: schedules,
    exceptions: const [],
    confirmedDates: const {},
    zoneClocks: zoneClocks,
  )) {
    final inCycle = day.date.compareTo(cycleFrom) >= 0;
    final mine = switch (day) {
      PlannedShift(:final scheduleId) ||
      OffDay(:final scheduleId) => scheduleId == id,
      _ => false,
    };
    // A cycle another schedule cuts into is not a whole cycle.
    if (inCycle && !mine) cycleKnown = false;
    if (!mine || day is! PlannedShift) continue;
    final pay = price(day);
    if (day.type case final type? when !types.containsKey(type.id)) {
      types[type.id] = pay;
    }
    if (inCycle) {
      if (pay == null) {
        cycleKnown = false;
      } else {
        _add(cycle, pay);
      }
    }
  }
  return SchedulePricing(
    types: types,
    cycleFrom: cycleFrom,
    cyclePay: cycleKnown ? _ordered(cycle) : null,
  );
}

/// Adds [pay] to its basis in [cents]: gross and net are never combined
/// (foundation spec 9.5).
void _add(Map<RateBasis, int> cents, ExpectedPay pay) =>
    cents[pay.basis] = (cents[pay.basis] ?? 0) + pay.amount.minorUnits;

/// [cents] gross first, then net.
Map<RateBasis, int> _ordered(Map<RateBasis, int> cents) => {
  for (final basis in const [GrossBasis(), NetBasis()]) basis: ?cents[basis],
};

/// What [schedulePricing] found.
@immutable
final class SchedulePricing {
  const SchedulePricing({
    required this.types,
    required this.cycleFrom,
    required this.cyclePay,
  });

  /// Each planned shift type's price; null where no agreement covers it.
  final Map<ShiftTypeId, ExpectedPay?> types;

  /// The first day of the cycle priced.
  final LocalDate cycleFrom;

  /// One whole cycle's pay in cents per basis, gross first; null when a
  /// day of it has no agreement or another schedule plans part of it.
  final Map<RateBasis, int>? cyclePay;
}

/// Where a Preview starts: the first of today's month, or of the month the
/// schedule (or the new version) starts when that is later.
LocalDate previewStart(ScheduleValues draft, LocalDate today) {
  final start = draft.versionFrom ?? draft.inUseFrom;
  return (start.compareTo(today) > 0 ? start : today).firstOfMonth;
}

/// [months] months of [draft] from [firstMonth] (owner pick 2B): the
/// pending cycle planned without day changes, priced as planned with the
/// stored agreements, beside the employment's other schedules. [baseline]
/// is the version being edited (null for a new schedule); with the draft's
/// `versionFrom` set it ends the day before and the draft follows it as the
/// next version. Empty while the draft does not validate.
List<PreviewMonth> previewMonths({
  required ScheduleValues draft,
  required ScheduleRecord? baseline,
  required EmploymentId employmentId,
  required PlanInputs inputs,
  required LocalDate firstMonth,
  required LocalDate today,
  required ZoneClocks zoneClocks,
  int months = 4,
}) {
  if (scheduleIssues(draft, employmentId: employmentId).isNotEmpty) {
    return const [];
  }
  final (:id, :schedules) = _withDraft(
    draft: draft,
    baseline: baseline,
    employmentId: employmentId,
    inputs: inputs,
  );
  final names = {for (final value in schedules) value.id: value.name};
  final letters = typeLetters(draft.types);
  final first = firstMonth.firstOfMonth;
  var last = first;
  for (var i = 1; i < months; i++) {
    last = last.lastOfMonth.addDays(1);
  }
  last = last.lastOfMonth;
  final planned = {
    for (final day in planDays(
      from: first,
      to: last,
      schedules: schedules,
      exceptions: const [],
      confirmedDates: const {},
      zoneClocks: zoneClocks,
    ))
      day.date: day,
  };
  final result = <PreviewMonth>[];
  for (var month = first; month.compareTo(last) <= 0;) {
    final days = <PreviewDay>[];
    var shifts = 0;
    var paid = 0;
    final pay = <RateBasis, int>{};
    var payKnown = true;
    for (var date = month; date.month == month.month; date = date.addDays(1)) {
      final day = planned[date];
      final scheduleId = switch (day) {
        PlannedShift(:final scheduleId) ||
        OffDay(:final scheduleId) => scheduleId,
        _ => null,
      };
      final mine = scheduleId == id;
      var letter = '';
      int? typeIndex;
      if (mine && day is PlannedShift) {
        final type = day.type;
        if (type != null) {
          letter = letters[type.id] ?? '';
          final at = draft.types.indexWhere((item) => item.id == type.id);
          typeIndex = at < 0 ? null : at;
        }
        shifts++;
        paid += day.paidSeconds;
        final money = plannedPay(
          day,
          agreements: inputs.agreements,
          employmentId: employmentId,
          zoneClocks: zoneClocks,
        );
        if (money == null) {
          payKnown = false;
        } else {
          _add(pay, money);
        }
      }
      days.add(
        PreviewDay(
          date: date,
          letter: letter,
          typeIndex: typeIndex,
          confirmed: inputs.confirmedDates.contains(date),
          today: date == today,
          otherSchedule: scheduleId == null || mine ? null : names[scheduleId],
        ),
      );
    }
    final others = {for (final day in days) day.otherSchedule};
    result.add(
      PreviewMonth(
        year: month.year,
        month: month.month,
        days: days,
        shifts: shifts,
        paidSeconds: paid,
        pay: payKnown ? _ordered(pay) : null,
        otherSchedule: others.length == 1 ? others.single : null,
      ),
    );
    month = month.lastOfMonth.addDays(1);
  }
  return result;
}
