import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/status_line.dart';
import '../../../shared/workbench/operational_state.dart';
import '../domain/day_exception.dart';
import '../domain/ids.dart';
import '../domain/planner.dart';
import 'day_sheet.dart';
import 'work_controller.dart';
import 'work_plan_view.dart';

/// Reads one date's plan and binds its Properties to [DayPlanService].
final class DaySheetHost extends ConsumerWidget {
  const DaySheetHost({
    required this.employmentId,
    required this.date,
    required this.today,
    super.key,
  });

  final EmploymentId employmentId;
  final LocalDate date;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final service = ref.read(dayPlanServiceProvider);
    Future<MutationOutcome<T>> noted<T>(
      Future<MutationOutcome<T>> pending,
      String notice,
    ) async {
      final outcome = await pending;
      if (outcome is Committed<T> && context.mounted) {
        StatusNoticeScope.read(context)?.value = notice;
      }
      return outcome;
    }

    return switch (ref.watch(planInputsProvider(employmentId))) {
      AsyncData(value: final inputs) => () {
        final day = planDays(
          from: date,
          to: date,
          schedules: inputs.schedules,
          exceptions: inputs.exceptions,
          confirmedDates: inputs.confirmedDates,
          zoneClocks: zones,
        ).firstOrNull;
        final exception = inputs.exceptions
            .where((value) => value.date == date)
            .firstOrNull;
        final expected = exception?.revision;
        return DaySheet(
          key: ValueKey(('day', date, exception?.updatedAtUtc)),
          date: date,
          today: today,
          day: day,
          confirmed: inputs.confirmedDates.contains(date),
          schedule: inputs.schedules
              .where((value) => value.isInUseOn(date))
              .firstOrNull,
          pay: day is PlannedShift
              ? plannedPay(
                  day,
                  agreements: inputs.agreements,
                  employmentId: employmentId,
                  zoneClocks: zones,
                )
              : null,
          leavePay: day is PlannedLeave && register != null
              ? plannedLeavePay(
                  day,
                  employmentId: employmentId,
                  agreements: inputs.agreements,
                  shifts: register.shiftSheet,
                  leave: register.leaveSheet,
                )
              : null,
          timezones: timezones,
          onConfirm: () =>
              noted(service.confirm(employmentId, date), 'Day confirmed.'),
          onChange: (times) => noted(
            service.changeDay(
              employmentId,
              date,
              start: times.start,
              end: times.end,
              endDayOffset: times.endDayOffset,
              breaks: times.breaks,
              shiftTypeId: times.shiftTypeId,
              expected: expected,
            ),
            'Day changed.',
          ),
          onCancelShift: (reason, note) => noted(
            service.cancelDay(
              employmentId,
              date,
              reason: reason,
              note: note,
              expected: expected,
            ),
            'Shift cancelled.',
          ),
          onMarkLeave: (type, illness) => noted(
            service.markLeave(
              employmentId,
              date,
              leaveType: type,
              illnessStartedOn: illness,
              expected: expected,
            ),
            'Marked as leave.',
          ),
          onAddExtra: (times) => noted(
            service.addExtra(
              employmentId,
              date,
              start: times.start,
              end: times.end,
              endDayOffset: times.endDayOffset,
              breaks: times.breaks,
              shiftTypeId: times.shiftTypeId,
              countsAsOvertime: times.countsAsOvertime,
              expected: expected,
            ),
            'Extra shift added.',
          ),
          onRemoveException: () => exception == null
              ? Future.value(const Missing<DayException>())
              : noted(
                  service.removeException(
                    exception.id,
                    expected: exception.revision,
                  ),
                  'Day restored to its schedule.',
                ),
        );
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Day unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the day',
        message: 'Planning this date from its schedule.',
      ),
    };
  }
}
